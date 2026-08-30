/// Ported from the web app's headless suite. These cover the behaviours that
/// were found to be genuinely fragile while building the web version: streak
/// double-counting, review-date drift, the recognition gate, format rotation
/// starvation, and question integrity.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotolang/core/util.dart';
import 'package:kotolang/domain/models.dart';
import 'package:kotolang/domain/progress_service.dart';
import 'package:kotolang/domain/question_generator.dart';
import 'package:kotolang/domain/srs.dart';

Sentence _sentence(
  String id,
  String text, {
  String ja = '',
  List<String> items = const [],
  String realmId = 'r1',
  String context = 'review',
  String speechAct = 'statement',
  List<String> meaningOptions = const [],
  String paraphrase = '',
  List<String> paraphraseOptions = const [],
  String cue = '',
  String cueJa = '',
  List<String> replyDistractors = const [],
  String registerSituation = '',
  List<String> registerOptions = const [],
  List<String> registerWhy = const [],
  int registerCorrect = -1,
}) =>
    Sentence(
      id: id,
      text: text,
      normKeyValue: normKey(text),
      translationNative: ja,
      realmId: realmId,
      itemIds: items,
      context: context,
      speechAct: speechAct,
      meaningOptionsNative: meaningOptions,
      paraphraseEn: paraphrase,
      paraphraseOptionsEn: paraphraseOptions,
      cueEn: cue,
      cueTranslationNative: cueJa,
      replyDistractorsEn: replyDistractors,
      registerSituationNative: registerSituation,
      registerOptionsEn: registerOptions,
      registerWhyNative: registerWhy,
      registerCorrect: registerCorrect,
    );

LearningItem _item(String id, String text, {String ja = ''}) => LearningItem(
      id: id,
      text: text,
      normKeyValue: normKey(text),
      meaningNative: ja,
      realmIds: const ['r1'],
    );

void main() {
  // ================================================================ dates
  group('day arithmetic', () {
    test('crosses month, year and leap boundaries', () {
      expect(addDays('2026-01-31', 1), '2026-02-01');
      expect(addDays('2026-12-31', 1), '2027-01-01');
      expect(addDays('2028-02-28', 1), '2028-02-29');
      expect(addDays('2026-03-01', 35), '2026-04-05');
    });

    test('daysBetween is signed and exact', () {
      expect(daysBetween('2026-08-17', '2026-08-22'), 5);
      expect(daysBetween('2026-01-31', '2026-02-01'), 1);
      expect(daysBetween('2026-08-22', '2026-08-17'), -5);
      expect(daysBetween('2026-08-22', '2026-08-22'), 0);
    });

    test('a full year of round trips never drifts', () {
      // Runs across daylight-saving transitions in either hemisphere.
      var key = '2026-01-01';
      for (var i = 0; i < 365; i++) {
        final next = addDays(key, 1);
        expect(daysBetween(key, next), 1, reason: 'from $key');
        key = next;
      }
      expect(key, '2027-01-01');
    });
  });

  // ================================================================ text
  group('normalisation', () {
    test('duplicate detection ignores case, spacing and punctuation', () {
      expect(normKey('Repair  Policy'), normKey('repair policy'));
      expect(normKey('repair policy.'), normKey('repair policy'));
    });

    test('phrase containment respects word boundaries', () {
      expect(containsPhrase('We reviewed the repair policy today.', 'repair policy'), isTrue);
      expect(containsPhrase('We repaired it.', 'repair policy'), isFalse);
    });
  });

  // ================================================================ SRS
  group('SRS scheduling', () {
    test('correct answers climb 1 / 3 / 7 / 16 / 35', () {
      final t = today();
      var s = SrsState.blank('i1');

      s = applyAnswer(s, QuestionType.dictation, true, at: t);
      expect(s.box, 1);
      expect(s.due, addDays(t, 1));

      s = applyAnswer(s, QuestionType.dictation, true, at: t);
      expect(s.box, 2);
      expect(s.due, addDays(t, 3));

      s = applyAnswer(s, QuestionType.reorder, true, at: t);
      expect(s.due, addDays(t, 7));

      s = applyAnswer(s, QuestionType.dictation, true, at: t);
      expect(s.due, addDays(t, 16));

      s = applyAnswer(s, QuestionType.reorder, true, at: t);
      expect(s.due, addDays(t, 35));
      expect(isMastered(s), isTrue);
    });

    test('a production miss resets hard and records a lapse', () {
      final t = today();
      var s = SrsState.blank('i1');
      for (var i = 0; i < 5; i++) {
        s = applyAnswer(s, QuestionType.dictation, true, at: t);
      }
      s = applyAnswer(s, QuestionType.dictation, false, at: t);
      expect(s.box, 0);
      expect(s.due, addDays(t, 1));
      expect(s.lapses, 1);
    });

    test('recognition alone cannot reach mastery', () {
      var s = SrsState.blank('i2');
      for (var i = 0; i < 8; i++) {
        s = applyAnswer(s, QuestionType.gist, true);
      }
      expect(s.box, recognitionCap);
      expect(isMastered(s), isFalse);
      expect(s.heldByGate, isTrue);

      // One production success releases the cap.
      s = applyAnswer(s, QuestionType.dictation, true);
      expect(hasProductionEvidence(s), isTrue);
      s = applyAnswer(s, QuestionType.gist, true);
      expect(s.box, greaterThan(recognitionCap));
    });

    test('due detection', () {
      final t = today();
      var s = SrsState.blank('i4').copyWith(introduced: true, due: addDays(t, -3));
      expect(isDue(s, t), isTrue);
      s = s.copyWith(due: addDays(t, 2));
      expect(isDue(s, t), isFalse);
    });
  });

  group('SRS selection priority', () {
    final t = today();

    test('due outranks new material', () {
      final due = SrsState.blank('a').copyWith(introduced: true, due: addDays(t, -1));
      final pDue = priority(due, _item('a', 'x'), const Realm(id: 'r', name: 'R', normKeyValue: 'r', importance: 1), t);
      final pNew = priority(null, _item('b', 'y'), const Realm(id: 'r', name: 'R', normKeyValue: 'r', importance: 5), t);
      expect(pDue, greaterThan(pNew));
    });

    test('new material outranks something already answered today', () {
      // The regression that made every session feel like the same sentences:
      // an item answered today is not due again for a day, and when it still
      // outranked untouched material the planner never introduced the rest.
      final seen = SrsState.blank('b').copyWith(
        introduced: true,
        lastSeen: t,
        due: addDays(t, 1),
        formats: {QuestionType.gist: const FormatStat(n: 1, ok: 1)},
      );
      final pSeen = priority(seen, _item('b', 'y'),
          const Realm(id: 'r', name: 'R', normKeyValue: 'r', importance: 5), t);
      final pNew = priority(null, _item('c', 'z'),
          const Realm(id: 'r', name: 'R', normKeyValue: 'r', importance: 5), t);
      expect(pNew, greaterThan(pSeen));
    });

    test('weak items are pulled forward, stale items resurface', () {
      final pNew = priority(null, _item('c', 'z'),
          const Realm(id: 'r', name: 'R', normKeyValue: 'r', importance: 5), t);

      final weak = SrsState.blank('w').copyWith(
        introduced: true,
        lastSeen: t,
        due: addDays(t, 1),
        formats: {QuestionType.gist: const FormatStat(n: 4, ok: 1)},
      );
      expect(priority(weak, _item('w', 'x'), null, t), greaterThan(pNew));

      final stale = SrsState.blank('s').copyWith(
        introduced: true,
        lastSeen: addDays(t, -120),
        due: addDays(t, 1),
      );
      final fresh = SrsState.blank('f').copyWith(
        introduced: true,
        lastSeen: t,
        due: addDays(t, 1),
      );
      expect(priority(stale, _item('s', 'x'), null, t),
          greaterThan(priority(fresh, _item('f', 'x'), null, t)));
    });
  });

  group('format rotation', () {
    const all = QuestionType.values;

    test('every format is reachable for a new item', () {
      final seen = <QuestionType>{};
      final rng = Random(7);
      for (var i = 0; i < 500; i++) {
        seen.add(preferredFormat(null, all, rng)!);
      }
      expect(seen.length, all.length,
          reason: 'a deterministic choice once made reorder unreachable');
    });

    test('the rotation puts conversation ahead of comprehension', () {
      final rng = Random(11);
      var s = SrsState.blank('rot').copyWith(
        introduced: true,
        formats: {QuestionType.dictation: const FormatStat(n: 1, ok: 1)},
      );
      final tally = {for (final t in all) t: 0};
      for (var i = 0; i < 700; i++) {
        final t = preferredFormat(s, all, rng)!;
        tally[t] = tally[t]! + 1;
        final f = Map<QuestionType, FormatStat>.from(s.formats);
        f[t] = s.statFor(t).plus(true);
        s = s.copyWith(formats: f);
      }
      for (final t in all) {
        expect(tally[t], greaterThan(0), reason: '$t was starved');
      }

      // The weighting is the app's statement about what matters. KotoLang is
      // listening-first: understanding the main idea (`gist`) and choosing
      // the right response (`reply`) tie for the top, well ahead of every
      // other format. `reorder` trails because `produce` asks the same thing
      // without playing the answer first.
      final ranked = all.toList()..sort((a, b) => tally[b]!.compareTo(tally[a]!));
      expect(ranked.take(2).toSet(), {QuestionType.gist, QuestionType.reply});
      expect(ranked.last, QuestionType.reorder);

      final leading = tally[QuestionType.gist]! + tally[QuestionType.reply]!;
      final rest = 700 - leading;
      expect(leading, greaterThan(rest));
    });

    test('a capped item is pushed towards production', () {
      final s = SrsState.blank('gate').copyWith(
        introduced: true,
        box: recognitionCap,
        formats: {QuestionType.gist: const FormatStat(n: 5, ok: 5)},
      );
      for (var i = 0; i < 20; i++) {
        expect(productionTypes.contains(preferredFormat(s, all)), isTrue);
      }
    });
  });

  // ================================================================ streak
  group('streak', () {
    final t = today();

    test('a day counts once no matter how many answers', () {
      var p = const Progress();
      var r = registerStudyDay(p, t);
      p = r.progress;
      expect(p.streak, 1);
      expect(r.result.advanced, isTrue);

      for (var i = 0; i < 30; i++) {
        r = registerStudyDay(p, t);
        p = r.progress;
      }
      expect(p.streak, 1, reason: '30 answers on one day is still one day');
      expect(r.result.advanced, isFalse);
    });

    test('consecutive days chain', () {
      var p = const Progress();
      p = registerStudyDay(p, t).progress;
      p = registerStudyDay(p, addDays(t, 1)).progress;
      expect(p.streak, 2);
      expect(p.bestStreak, 2);
    });

    test('a freeze covers a missed day', () {
      var p = Progress(streak: 9, bestStreak: 9, freezes: 2, lastStudyDay: addDays(t, -2));
      p = reconcileStreak(p, t);
      expect(p.streak, 9);
      expect(p.freezes, 1);
      expect(p.freezeUsed, 1);
      p = registerStudyDay(p, t).progress;
      expect(p.streak, 10);
    });

    test('insufficient freezes break the streak but are not wasted', () {
      var p = Progress(streak: 20, bestStreak: 20, freezes: 1, lastStudyDay: addDays(t, -4));
      p = reconcileStreak(p, t);
      expect(p.streak, 0);
      expect(p.freezes, 1, reason: 'a freeze that cannot save the streak is kept');
      expect(p.streakLostFrom, 20);
      expect(p.bestStreak, 20, reason: 'the best is a record, not a current state');
      p = registerStudyDay(p, t).progress;
      expect(p.streak, 1);
      expect(p.bestStreak, 20);
    });

    test('reconciling twice on the same day spends nothing extra', () {
      var p = Progress(streak: 4, freezes: 2, lastStudyDay: addDays(t, -2));
      p = reconcileStreak(p, t);
      final after = p.freezes;
      p = reconcileStreak(p, t);
      expect(p.freezes, after);
    });
  });

  // ============================================================= chest
  group('chest', () {
    test('all three chest rewards occur and each has an effect', () {
      final ids = <String>{};
      for (var i = 0; i < 3000; i++) {
        ids.add(openChest().id);
      }
      expect(ids.length, 3);

      const p = Progress();
      expect(applyChest(p, chestTable[0]).freezes, p.freezes + 1);
      expect(applyChest(p, chestTable[1]).pendingBoost, chestBoost);
      expect(applyChest(p, chestTable[2]).seeds, p.seeds + chestSeedBonus);
    });

    test('every reward is denominated in something that still exists', () {
      // The chest used to pay in XP, which the app no longer has. A reward
      // nobody can see is worse than no reward at all.
      for (final r in chestTable) {
        expect(applyChest(const Progress(), r), isNot(const Progress()),
            reason: r.id);
      }
    });
  });

  group('dragging a word into place', () {
    /// The list operation the quiz screen performs, so the index arithmetic
    /// can be checked without a widget test.
    List<String> drop(List<String> words, String word, int gap) {
      final out = [...words];
      final from = out.indexOf(word);
      final at = reinsertIndex(from, gap);
      if (from >= 0) out.removeAt(from);
      out.insert(at.clamp(0, out.length), word);
      return out;
    }

    test('a new word goes in at the gap it was dropped on', () {
      expect(drop(['b', 'c'], 'a', 0), ['a', 'b', 'c']);
      expect(drop(['a', 'c'], 'b', 1), ['a', 'b', 'c']);
      expect(drop(['a', 'b'], 'c', 2), ['a', 'b', 'c']);
    });

    test('moving a word to its right does not land one place short', () {
      // The off-by-one: removing the word first shifts every later gap down.
      expect(drop(['a', 'b', 'c'], 'a', 3), ['b', 'c', 'a']);
      expect(drop(['a', 'b', 'c'], 'a', 2), ['b', 'a', 'c']);
    });

    test('moving a word to its left lands exactly on the gap', () {
      expect(drop(['a', 'b', 'c'], 'c', 0), ['c', 'a', 'b']);
      expect(drop(['a', 'b', 'c'], 'c', 1), ['a', 'c', 'b']);
    });

    test('dropping a word back where it already is changes nothing', () {
      expect(drop(['a', 'b', 'c'], 'b', 1), ['a', 'b', 'c']);
      expect(drop(['a', 'b', 'c'], 'b', 2), ['a', 'b', 'c']);
    });

    test('fixing the first word does not disturb the rest', () {
      // The reported pain: a wrong word early on used to mean clearing
      // everything after it.
      expect(drop(['wrong', 'should', 'set'], 'We', 0),
          ['We', 'wrong', 'should', 'set']);
    });
  });

  group('the next thing worth finishing', () {
    HistoryEntry entry(String day, {bool correct = true, QuestionType? type}) =>
        HistoryEntry(
          day: day,
          at: DateTime.now(),
          questionId: 'q$day${type?.name ?? ''}${correct ? 'c' : 'w'}',
          realmId: 'r1',
          type: type ?? QuestionType.gist,
          correct: correct,
          wasDue: false,
        );

    test('a streak milestone one day away comes first', () {
      final goal = nextGoal(
          history: [entry('2026-08-28')],
          streak: 2,
          today: '2026-08-29',
          studiedToday: false);
      expect(goal?.kind, 'streak');
      expect(goal?.remaining, 1);
      expect(goal?.target, 3);
    });

    test('a streak already claimed today is not offered again', () {
      final goal = nextGoal(
          history: [entry('2026-08-29')],
          streak: 2,
          today: '2026-08-29',
          studiedToday: true);
      expect(goal?.kind, isNot('streak'));
    });

    test('beating last week is named while it is within reach', () {
      final history = [
        for (var i = 7; i <= 11; i++) entry(addDays('2026-08-29', -i)),
        entry('2026-08-28'),
        entry('2026-08-29'),
      ];
      final goal = nextGoal(
          history: history, streak: 9, today: '2026-08-29', studiedToday: true);
      expect(goal?.kind, 'week');
      // Five last week, two so far: four more would pass it.
      expect(goal?.remaining, 4);
      expect(goal?.target, 6);
    });

    test('a week too far ahead is not dangled', () {
      final history = [for (var i = 7; i <= 13; i++) ...[entry(addDays('2026-08-29', -i)), entry(addDays('2026-08-29', -i))]];
      final goal = nextGoal(
          history: [...history, entry('2026-08-29')],
          streak: 9,
          today: '2026-08-29',
          studiedToday: true);
      expect(goal?.kind, isNot('week'), reason: '14 answers behind is not one more question');
    });

    test('with nothing else close, today rounds up to the next five', () {
      final goal = nextGoal(
          history: [for (var i = 0; i < 7; i++) entry('2026-08-29')],
          streak: 9,
          today: '2026-08-29',
          studiedToday: true);
      expect(goal?.kind, 'today');
      expect(goal?.target, 10);
      expect(goal?.remaining, 3);
    });

    test('a day with nothing on it offers nothing', () {
      expect(
          nextGoal(history: const [], streak: 0, today: '2026-08-29', studiedToday: true),
          isNull);
    });
  });

  group('badges', () {
    test('a threshold reached is earned, and progress never overshoots', () {
      final history = [
        for (var i = 0; i < 12; i++)
          HistoryEntry(
            day: '2026-08-29',
            at: DateTime.now(),
            questionId: 'q$i',
            realmId: 'r1',
            type: QuestionType.gist,
            correct: true,
            wasDue: false,
          ),
      ];
      final shelf = badges(
          history: history, bestStreak: 0, masteredItems: 0, realmsWithMaterial: 0);
      final ten = shelf.firstWhere((b) => b.id == 'answers10');
      expect(ten.earned, isTrue);
      expect(ten.ratio, 1.0);

      final hundred = shelf.firstWhere((b) => b.id == 'answers100');
      expect(hundred.earned, isFalse);
      expect(hundred.progress, 12);
    });

    test('a perfect day needs five answers and no mistakes', () {
      HistoryEntry e(String day, bool ok, int i) => HistoryEntry(
            day: day,
            at: DateTime.now(),
            questionId: 'q$day$i',
            realmId: 'r1',
            type: QuestionType.gist,
            correct: ok,
            wasDue: false,
          );
      final spoiled = [for (var i = 0; i < 5; i++) e('2026-08-29', i != 2, i)];
      expect(
          badges(history: spoiled, bestStreak: 0, masteredItems: 0, realmsWithMaterial: 0)
              .firstWhere((b) => b.id == 'perfectDay')
              .earned,
          isFalse);

      final clean = [for (var i = 0; i < 5; i++) e('2026-08-29', true, i)];
      expect(
          badges(history: clean, bestStreak: 0, masteredItems: 0, realmsWithMaterial: 0)
              .firstWhere((b) => b.id == 'perfectDay')
              .earned,
          isTrue);
    });

    test('the shelf shows locked badges too, so they read as goals', () {
      final shelf = badges(
          history: const [], bestStreak: 0, masteredItems: 0, realmsWithMaterial: 0);
      expect(shelf, isNotEmpty);
      expect(shelf.every((b) => !b.earned), isTrue);
    });
  });

  group('combo', () {
    test('a short run pays nothing, a long one is capped', () {
      expect(comboBonus(0), 0);
      expect(comboBonus(2), 0);
      expect(comboBonus(3), 1);
      expect(comboBonus(5), 3);
      expect(comboBonus(50), maxComboBonus);
    });

    test('the bonus only ever adds', () {
      for (var i = 0; i < 30; i++) {
        expect(comboBonus(i), greaterThanOrEqualTo(0));
      }
    });
  });

  group('mastery stages', () {
    SrsState at(int box, {bool introduced = true}) =>
        SrsState(itemId: 'i1', due: today(), box: box, introduced: introduced);

    test('an untouched item is still a seed', () {
      expect(stageFor(null), MasteryStage.seed);
      expect(stageFor(at(0, introduced: false)), MasteryStage.seed);
    });

    test('the stages climb with the box and never skip backwards', () {
      final seen = [for (var box = 0; box <= maxBox; box++) stageFor(at(box))];
      expect(seen.first, MasteryStage.seed);
      expect(seen.last, MasteryStage.star);
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i].index, greaterThanOrEqualTo(seen[i - 1].index),
            reason: 'box $i dropped a stage');
      }
    });

    test('only the top box is fully grown', () {
      expect(stageFor(at(maxBox - 1)), isNot(MasteryStage.star));
      expect(stageFor(at(maxBox)), MasteryStage.star);
    });

    test('every stage has a label and an emoji', () {
      for (final stage in MasteryStage.values) {
        expect(stageEmoji[stage], isNotNull);
        expect(stageKey[stage], isNotNull);
      }
    });
  });

  group('perfect run', () {
    test('a clean session of a decent length counts', () {
      expect(isPerfectRun(answered: perfectRunMin, missed: 0), isTrue);
      expect(isPerfectRun(answered: 10, missed: 0), isTrue);
    });

    test('one miss is enough to end it', () {
      expect(isPerfectRun(answered: 10, missed: 1), isFalse);
    });

    test('a session too short to be an achievement does not count', () {
      expect(isPerfectRun(answered: perfectRunMin - 1, missed: 0), isFalse);
    });
  });

  group('format filter', () {
    test('each filter names real question types and they do not overlap', () {
      final seen = <QuestionType>{};
      for (final entry in formatFilters.entries) {
        expect(entry.value, isNotEmpty, reason: '${entry.key} draws from nothing');
        for (final t in entry.value) {
          expect(seen.add(t), isTrue, reason: '$t is in two filters');
        }
      }
      // Between them the filters have to cover everything, or a type could
      // only ever be reached by choosing "all".
      expect(seen, QuestionType.values.toSet());
    });

    test('an unknown filter means no restriction', () {
      expect(typesFor('all'), isNull);
      expect(typesFor('nonsense'), isNull);
      expect(typesFor('listening'), contains(QuestionType.gist));
    });
  });

  group('breakthrough', () {
    SrsState at({required int box, required int lapses}) =>
        SrsState(itemId: 'i1', due: today(), box: box, lapses: lapses);

    test('crossing the line after repeated failures counts', () {
      expect(
          isBreakthrough(at(box: 3, lapses: 3), at(box: 4, lapses: 3)), isTrue);
    });

    test('an item that never gave trouble does not', () {
      expect(
          isBreakthrough(at(box: 3, lapses: 1), at(box: 4, lapses: 1)), isFalse);
    });

    test('staying above the line is not a second breakthrough', () {
      expect(
          isBreakthrough(at(box: 4, lapses: 5), at(box: 5, lapses: 5)), isFalse);
    });

    test('a correct answer below the line is not one yet', () {
      expect(
          isBreakthrough(at(box: 2, lapses: 4), at(box: 3, lapses: 4)), isFalse);
    });

    test('nothing to judge means no bonus', () {
      // An answer that produced no schedule at all — a question with no
      // learning item behind it — cannot be a breakthrough.
      expect(isBreakthrough(at(box: 3, lapses: 3), null), isFalse);
    });
  });

  group('listening hint', () {
    test('hides the content words and keeps the scaffolding', () {
      final hint = blankedHint('We should set the delivery date.');
      expect(hint, 'We ______ ___ the ________ ____.');
    });

    test('word lengths and punctuation survive, so the shape still shows', () {
      final hint = blankedHint('Could you confirm the repair policy?');
      // Same number of words, same trailing mark.
      expect(hint.split(' ').length, 6);
      expect(hint.endsWith('?'), isTrue);
      expect(hint.contains('the'), isTrue);
    });

    test('a sentence of nothing but function words still hides something', () {
      final hint = blankedHint('It is on the desk');
      expect(hint, isNot('It is on the desk'));
      expect(hint.contains('_'), isTrue);
    });

    test('an empty sentence is left alone rather than crashing', () {
      expect(blankedHint(''), '');
      expect(blankedHint('   '), '   ');
    });
  });

  group('koto seeds', () {
    test('a balance saved as Koto Coin comes back as the same many Seeds', () {
      // The rename must not cost anybody what they earned. Old blobs carry
      // `kotoCoins` and an `xpTotal` the app no longer has.
      final old = Progress.fromJson({
        'streak': 4,
        'bestStreak': 9,
        'lastStudyDay': '2026-08-28',
        'freezes': 2,
        'xpTotal': 350,
        'pendingBoost': 2,
        'kotoCoins': 142,
        'journeyBonusDay': '2026-08-28',
      });

      expect(old.seeds, 142);
      expect(old.streak, 4);
      expect(old.bestStreak, 9);
      expect(old.freezes, 2);
      expect(old.pendingBoost, 2);
      expect(old.journeyBonusDay, '2026-08-28');

      // Saved again, it is written under the new name and reads back the same.
      expect(Progress.fromJson(old.toJson()).seeds, 142);
      expect(old.toJson()['seeds'], 142);
    });

    test('the new name wins when a blob somehow carries both', () {
      expect(
          Progress.fromJson({'seeds': 7, 'kotoCoins': 142}).seeds, 7);
    });

    test('a wrong answer earns nothing, regardless of format', () {
      // Quality over quantity: Seeds only reward genuine understanding.
      for (final t in QuestionType.values) {
        expect(seedsFor(t, false), 0);
        expect(seedsFor(t, false, wasDue: true, firstCorrect: true), 0);
      }
    });

    test('the two listening formats pay more than the rest', () {
      expect(seedsFor(QuestionType.gist, true), greaterThan(seedsFor(QuestionType.dictation, true)));
      expect(seedsFor(QuestionType.reply, true), greaterThan(seedsFor(QuestionType.produce, true)));
      expect(seedsFor(QuestionType.gist, true), seedsFor(QuestionType.reply, true));
    });

    test('firstCorrect and wasDue stack on top of the base amount', () {
      final base = seedsFor(QuestionType.dictation, true);
      expect(seedsFor(QuestionType.dictation, true, firstCorrect: true), base + 4);
      expect(seedsFor(QuestionType.dictation, true, wasDue: true), base + 2);
      expect(seedsFor(QuestionType.dictation, true, firstCorrect: true, wasDue: true), base + 6);
    });

    test('the completion bonus is paid for finishing what was started', () {
      // The size of a session is now a setting rather than a purchase, so the
      // bonus is flat and the target is whatever the learner chose.
      expect(sessionCompletionBonus(0, 5), 0);
      expect(sessionCompletionBonus(4, 5), 0);
      expect(sessionCompletionBonus(5, 5), sessionBonus);
      expect(sessionCompletionBonus(9, 5), sessionBonus);
    });

    test('a run to the end of the material counts as finished', () {
      // Target zero means "everything there is", and the run ends when the
      // questions do — refusing the bonus there would punish a small library.
      expect(sessionCompletionBonus(3, 0), sessionBonus);
      expect(sessionCompletionBonus(0, 0), 0);
    });

    test('listening mastery reads accuracy on gist and reply only', () {
      final now = today();
      HistoryEntry h(QuestionType t, bool ok) => HistoryEntry(
            day: now,
            at: DateTime.now(),
            questionId: 'q',
            realmId: 'r',
            type: t,
            correct: ok,
            wasDue: false,
          );

      expect(listeningMastery(const []), isNull, reason: 'nothing to compute from yet');

      final history = [
        h(QuestionType.gist, true),
        h(QuestionType.gist, false),
        h(QuestionType.reply, true),
        // Ignored: neither format counts toward the score.
        h(QuestionType.dictation, false),
        h(QuestionType.dictation, false),
      ];
      expect(listeningMastery(history), 67); // 2 of 3 gist/reply answers, rounded
    });

    test('the weekly strip is a 7-day window ending today, oldest first', () {
      const t = '2026-08-24';
      HistoryEntry on(String day) => HistoryEntry(
            day: day,
            at: DateTime.now(),
            questionId: 'q',
            realmId: 'r',
            type: QuestionType.gist,
            correct: true,
            wasDue: false,
          );
      final history = [on(addDays(t, -6)), on(addDays(t, -2)), on(t)];
      final week = weeklyStrip(history, t);
      expect(week, hasLength(7));
      expect(week.first, isTrue); // 6 days ago
      expect(week[4], isTrue); // 2 days ago
      expect(week.last, isTrue); // today
      expect(week.where((d) => d).length, 3);
    });
  });

  // ================================================================ questions
  group('question generation', () {
    final items = {
      'it1': _item('it1', 'repair policy', ja: '修理方針'),
      'it2': _item('it2', 'damage tolerance', ja: '損傷許容'),
    };
    final corpus = [
      _sentence('s1', 'We need to review the repair policy before proceeding.',
          ja: '先に進む前に修理方針を確認する必要があります。',
          items: ['it1'],
          meaningOptions: ['確認は不要です。', '先方が確認します。', '確認済みです。'],
          paraphrase: 'We should go over the rules for repairs before moving on.',
          paraphraseOptions: [
            'We can move on without going over the rules for repairs.',
            'The rules for repairs will be reviewed by someone else.',
            'The rules for repairs were already reviewed last week.',
          ],
          cue: 'Shall we go straight to the sign-off?',
          cueJa: 'このまま承認に進みますか。',
          replyDistractors: [
            'Yes, the repair policy was withdrawn last year.',
            'No, I have never seen that drawing before.',
            'Please send the sign-off sheet to the supplier.',
          ],
          registerSituation: '初めて話す取引先に、確認をお願いするとき',
          registerOptions: [
            'Could we go over the repair policy first?',
            'Go over the repair policy first.',
            'You have to go over the repair policy first.',
          ],
          registerWhy: [
            '依頼の形になっていて、初対面でも angry に聞こえません。',
            '命令形なので、対等または目下にしか使えません。',
            'have to は義務の押しつけに聞こえます。',
          ],
          registerCorrect: 0),
      _sentence('s2', 'The damage tolerance analysis is still in progress.',
          ja: '損傷許容解析はまだ進行中です。',
          items: ['it2'],
          meaningOptions: ['解析は完了しました。', '解析はこれから始まります。', '解析は中止されました。'],
          paraphrase: 'Work on the tolerance study has not finished yet.',
          paraphraseOptions: [
            'Work on the tolerance study finished some time ago.',
            'Work on the tolerance study has not started at all.',
            'Work on the tolerance study was handed to another team.',
          ],
          cue: 'Is the damage tolerance work done?',
          cueJa: '損傷許容の作業は終わりましたか。',
          replyDistractors: [
            'The analysis was never requested by anyone.',
            'Please repeat the question a little more slowly.',
            'We should go over the rules for repairs instead.',
          ]),
    ];

    test('produces every format, each with a valid structure', () {
      final qs = generateForSentences(corpus, items, corpus, Random(3));
      final byType = groupBy(qs, (Question q) => q.type);
      for (final t in QuestionType.values) {
        expect(byType[t], isNotNull, reason: '$t was not generated');
      }
      final byId = {for (final s in corpus) s.id: s};
      for (final q in qs) {
        expect(validateQuestion(q, byId), isEmpty, reason: q.id);
      }
    });

    test('ids are deterministic so re-import cannot duplicate', () {
      final a = generateForSentences(corpus, items, corpus, Random(1)).map((q) => q.id).toList();
      final b = generateForSentences(corpus, items, corpus, Random(2)).map((q) => q.id).toList();
      expect(a, b);
    });

    test('multiple choice has exactly one correct option', () {
      final qs = generateForSentences(corpus, items, corpus, Random(5));
      for (final q in qs.where((q) =>
          q.type == QuestionType.paraphrase || q.type == QuestionType.gist)) {
        final answer = q.options[q.correct];
        expect(q.options.where((o) => normKey(o) == normKey(answer)).length, 1);
        expect(q.options.length, 4);
      }
    });

    test('paraphrase options never echo the source sentence', () {
      final qs = generateForSentences(corpus, items, corpus, Random(9));
      for (final q in qs.where((q) => q.type == QuestionType.paraphrase)) {
        for (final o in q.options) {
          expect(normKey(o), isNot(normKey(q.text)));
          expect(o.split(' ').length, greaterThanOrEqualTo(4),
              reason: 'options must be sentences, not fragments');
        }
      }
    });

    test('dictation targets a phrase that occurs in the sentence', () {
      final qs = generateForSentences(corpus, items, corpus, Random(4));
      for (final q in qs.where((q) => q.type == QuestionType.dictation)) {
        expect(q.answerWords.length, lessThanOrEqualTo(4));
        expect(q.answerWords.join(' '), q.answerText);
        expect(normKey(q.text).contains(normKey(q.answerText)), isTrue);
        // A decoy must never collide with an answer word.
        final answers = q.answerWords.map((w) => w.toLowerCase()).toSet();
        expect(q.bankPool.any((w) => answers.contains(w.toLowerCase())), isFalse);
      }
    });

    test('reorder rebuilds the sentence exactly, duplicates included', () {
      final s = _sentence('sd', 'The team sent the report to the client.',
          ja: 'チームはその報告書を顧客に送りました。', items: ['it1']);
      final q = buildReorder(s, [items['it1']!])!;
      expect(q.tokens.where((t) => t.toLowerCase() == 'the').length, 3);
      expect('${q.tokens.join(' ')}${q.finalPunct}', s.text);
      expect(gradeReorder(q.tokens, q), isTrue);
      expect(gradeReorder(q.tokens.reversed.toList(), q), isFalse);
    });

    test('gist falls back to related sentences when options are absent', () {
      final bare = [
        _sentence('b1', 'The item was approved yesterday.', ja: 'その項目は昨日承認されました。', realmId: 'r9'),
        _sentence('b2', 'The item will be approved tomorrow.', ja: 'その項目は明日承認されます。', realmId: 'r9'),
        _sentence('b3', 'The item was rejected yesterday.', ja: 'その項目は昨日却下されました。', realmId: 'r9'),
        _sentence('b4', 'Please approve the item today.', ja: '本日中にその項目を承認してください。', realmId: 'r9'),
      ];
      final q = buildGist(bare.first, bare.sublist(1), Random(2));
      expect(q, isNotNull);
      expect(q!.options.length, 4);
      expect(q.options.where((o) => normKey(o) == normKey(q.answerText)).length, 1);
    });
  });

  group('dictation grading', () {
    test('forgiving about form, strict about spelling', () {
      expect(gradeDictation('repair policy', 'repair policy').correct, isTrue);
      expect(gradeDictation('Repair Policy', 'repair policy').correct, isTrue);
      expect(gradeDictation('  repair   policy ', 'repair policy').correct, isTrue);
      expect(gradeDictation('repair policy.', 'repair policy').correct, isTrue);
      expect(gradeDictation('pull request', 'pull request').correct, isTrue);

      expect(gradeDictation('repair plan', 'repair policy').correct, isFalse);
      expect(gradeDictation('', 'repair policy').correct, isFalse);

      final typo = gradeDictation('repair polcy', 'repair policy');
      expect(typo.correct, isFalse);
      expect(typo.close, isTrue, reason: 'a single slip is flagged, not passed');
    });
  });

  group('difficulty', () {
    test('dials move together and the default is the harder level', () {
      final easy = difficulties['easy']!;
      final normal = difficulties['normal']!;
      final hard = difficulties['hard']!;

      expect(easy.rate, lessThan(normal.rate));
      expect(normal.rate, lessThan(hard.rate));
      expect(easy.replays, 0, reason: '0 means unlimited');
      expect(normal.replays, greaterThan(hard.replays));
      expect(easy.bankExtra, lessThan(normal.bankExtra));
      expect(normal.bankExtra, lessThan(hard.bankExtra));

      const s = AppSettings();
      expect(s.difficulty, 'hard');
      expect(s.inputMode, 'tap');
      expect(s.dailyGoal, 1);
      expect(s.rate, hard.rate, reason: 'speed follows the level by default');
      expect(const AppSettings(speechRate: 1.15).rate, 1.15,
          reason: 'an explicit override wins');
    });
  });
}
