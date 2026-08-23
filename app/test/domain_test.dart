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

      // The weighting is the app's statement about what matters. Deciding what
      // to say is the scarcest skill, so `reply` leads; `reorder` trails
      // because `produce` asks the same thing without playing the answer.
      final ranked = all.toList()..sort((a, b) => tally[b]!.compareTo(tally[a]!));
      expect(ranked.first, QuestionType.reply);
      expect(ranked.last, QuestionType.reorder);

      final conversation = tally[QuestionType.reply]! +
          tally[QuestionType.produce]! +
          tally[QuestionType.register]!;
      final comprehension =
          tally[QuestionType.gist]! + tally[QuestionType.paraphrase]!;
      expect(conversation, greaterThan(comprehension));

      // ...but listening is still what the app is for, so comprehension must
      // not be squeezed out either.
      expect(comprehension / 700, greaterThan(0.25));
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

  // ================================================================ xp
  group('xp and chest', () {
    test('every award lands inside 2..10', () {
      for (final t in QuestionType.values) {
        for (final c in [true, false]) {
          final v = xpFor(t, c, wasDue: true, firstCorrect: true);
          expect(v, inInclusiveRange(2, 10));
        }
      }
    });

    test('production pays more than recognition, wrong still pays', () {
      expect(xpFor(QuestionType.dictation, true), greaterThan(xpFor(QuestionType.gist, true)));
      expect(xpFor(QuestionType.gist, false), 2);
    });

    test('all three chest rewards occur and each has an effect', () {
      final ids = <String>{};
      for (var i = 0; i < 3000; i++) {
        ids.add(openChest().id);
      }
      expect(ids.length, 3);

      const p = Progress();
      expect(applyChest(p, chestTable[0]).freezes, p.freezes + 1);
      expect(applyChest(p, chestTable[1]).pendingBoost, 2);
      expect(applyChest(p, chestTable[2]).xpTotal, p.xpTotal + 20);
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
