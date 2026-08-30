/// End-to-end tests over a real (in-memory) SQLite database.
///
/// These cover the paths that a unit test of the domain layer cannot: that
/// imports actually persist, that questions survive a round trip through the
/// schema, that the planner reads back what it wrote, and that the reset flows
/// remove exactly what they promise and nothing more.
library;

import 'dart:convert';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotolang/core/util.dart';
import 'package:kotolang/data/database.dart';
import 'package:kotolang/data/repository.dart';
import 'package:kotolang/domain/models.dart';
import 'package:kotolang/domain/progress_service.dart';
import 'package:kotolang/domain/srs.dart';

/// A material reply of the shape the prompt asks for.
String materialJson({
  required String realm,
  required List<(String term, String meaning)> terms,
  int sentencesPerTerm = 2,
}) {
  final items = terms
      .map((t) => {
            'text': t.$1,
            'type': 'term',
            'meaning_native': t.$2,
            'priority': 4,
            'confidence': 0.9,
            'distractors_native': ['wrong1 ${t.$1}', 'wrong2 ${t.$1}', 'wrong3 ${t.$1}'],
          })
      .toList();

  final sentences = <Map<String, dynamic>>[];
  for (final t in terms) {
    final frames = [
      ('Please confirm the ${t.$1} before the review.', 'confirm'),
      ('The ${t.$1} has not been recorded yet.', 'record'),
      ('We should discuss the ${t.$1} with the supplier.', 'discuss'),
    ];
    for (var i = 0; i < sentencesPerTerm && i < frames.length; i++) {
      sentences.add({
        'text': frames[i].$1,
        'translation_native': '${t.$2} — ${frames[i].$2}',
        'level': 'B2',
        'context': 'review',
        'speech_act': i == 0 ? 'request' : 'report',
        'targets': [t.$1],
        'naturalness': 5,
        'paraphrase_en': 'Someone ought to ${frames[i].$2} the ${t.$1} soon enough.',
        'paraphrase_options_en': [
          'Nobody needs to ${frames[i].$2} the ${t.$1} at all.',
          'The supplier will ${frames[i].$2} the ${t.$1} instead.',
          'The ${t.$1} was already handled last week entirely.',
        ],
        'meaning_options_native': [
          '${t.$2} — not needed',
          '${t.$2} — someone else',
          '${t.$2} — already done',
        ],
        // The conversation fields. Present on every sentence so the round trip
        // covers them; real material will have them only where they apply.
        'cue_en': 'What should we do about the ${t.$1}?',
        'cue_translation_native': '${t.$2} — what now',
        'reply_distractors_en': [
          'The ${t.$1} belongs to a different project entirely.',
          'Please ask me that question again a bit later.',
          'Nobody has ever mentioned the ${t.$1} to me before.',
        ],
        'register': {
          'situation_native': '${t.$2} — asking someone senior for the first time',
          'variants': [
            {
              'text': 'Could you take a look at the ${t.$1} when you have a moment?',
              'fits': true,
              'why_native': '依頼の形で、相手の都合も尊重している。',
            },
            {
              'text': 'Look at the ${t.$1}.',
              'fits': false,
              'why_native': '命令形なので目上には使えない。',
            },
            {
              'text': 'You need to look at the ${t.$1} right now.',
              'fits': false,
              'why_native': '義務の押しつけに聞こえる。',
            },
          ],
        },
      });
    }
  }

  return jsonEncode({
    'schema_version': '1.0',
    'type': 'material',
    'native_language': 'English',
    'domain': {'name': realm, 'name_native': realm, 'importance': 5, 'confidence': 0.9},
    'learning_items': items,
    'sentences': sentences,
  });
}

String profileJson(List<String> realms) => jsonEncode({
      'schema_version': '1.0',
      'type': 'profile',
      'profile': {
        'english_level': 'B2',
        'roles': ['engineer'],
        'learning_priorities': ['reviews'],
      },
      'domains': [
        for (final r in realms)
          {'name': r, 'name_native': r, 'importance': 4, 'confidence': 0.9, 'contexts': ['work']}
      ],
    });

void main() {
  late AppDatabase db;
  late Repository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = Repository(db, rng: Random(42));
  });

  tearDown(() async => db.close());

  group('import', () {
    test('profile creates realms and stores the profile', () async {
      final res = await repo.importProfile(profileJson(['Work', 'Travel']), uiLanguage: 'en');
      expect(res.ok, isTrue);
      expect(res.realms, 2);

      final realms = await repo.realms();
      expect(realms.length, 2);
      expect((await repo.loadProfile())?.englishLevel, 'B2');
    });

    test('material persists and generates questions', () async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      final res = await repo.importMaterial(
        materialJson(realm: 'Work', terms: [('repair policy', 'meaning A'), ('damage tolerance', 'meaning B')]),
        uiLanguage: 'en',
      );

      expect(res.ok, isTrue, reason: res.errors.join(', '));
      expect(res.newItems, 2);
      expect(res.newSentences, 4);
      expect(res.questions, greaterThan(0));

      final counts = await repo.counts();
      expect(counts.items, 2);
      expect(counts.sentences, 4);
      expect(counts.questions, res.questions);

      // Every format should be represented.
      final types = (await repo.questions()).map((q) => q.type).toSet();
      expect(types, containsAll(QuestionType.values));
    });

    test('questions survive the schema round trip intact', () async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await repo.importMaterial(
        materialJson(realm: 'Work', terms: [('repair policy', 'meaning A')]),
        uiLanguage: 'en',
      );

      for (final q in await repo.questions()) {
        expect(q.text, isNotEmpty);
        switch (q.type) {
          case QuestionType.paraphrase:
          case QuestionType.gist:
            expect(q.options.length, 4);
            expect(q.correct, inInclusiveRange(0, 3));
            expect(q.options[q.correct], q.answerText);
          case QuestionType.dictation:
            expect(q.answerWords, isNotEmpty);
            expect(q.answerWords.join(' '), q.answerText);
            expect(q.bankPool, isNotEmpty);
          case QuestionType.reorder:
          case QuestionType.produce:
            expect(q.tokens.length, greaterThanOrEqualTo(4));
            expect('${q.tokens.join(' ')}${q.finalPunct}', q.text);
          case QuestionType.reply:
            expect(q.options.length, 4);
            expect(q.options[q.correct], q.answerText);
            expect(q.cueText, isNotEmpty);
          case QuestionType.register:
            expect(q.options.length, greaterThanOrEqualTo(3));
            expect(q.options[q.correct], q.answerText);
            expect(q.translationNative, isNotEmpty);
        }
      }
    });

    test('rebuilding the questions changes nothing that was already answered',
        () async {
      // Questions are only built at import, so a library imported before a
      // format existed would never see it. Rebuilding has to be safe to run on
      // a library someone has been studying for months.
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await repo.importMaterial(
        materialJson(realm: 'Work', terms: [('repair policy', 'meaning A')]),
        uiLanguage: 'en',
      );

      final before = await repo.questions();
      final answered = before.first;
      await repo.recordAnswer(question: answered, correct: true, wasDue: false);
      final srsBefore = await repo.srsStates();
      final historyBefore = (await repo.history()).length;

      final n = await repo.regenerateQuestions();
      expect(n, before.length, reason: 'nothing new to add on a fresh import');

      final after = await repo.questions();
      expect(after.map((q) => q.id).toSet(), before.map((q) => q.id).toSet(),
          reason: 'ids are derived from sentence and type, so they must be stable');

      // The answer history is keyed to the question id and the schedule to the
      // learning item; neither may be disturbed.
      final stat = await (db.select(db.questionStats)
            ..where((t) => t.questionId.equals(answered.id)))
          .getSingleOrNull();
      expect(stat, isNotNull, reason: 'the answer history was thrown away');
      expect(stat!.n, 1);
      expect(await repo.srsStates(), hasLength(srsBefore.length));
      expect((await repo.history()).length, historyBefore);
    });

    test('re-importing the same material adds nothing', () async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      final payload = materialJson(realm: 'Work', terms: [('repair policy', 'x')]);
      await repo.importMaterial(payload, uiLanguage: 'en');
      final before = await repo.counts();

      final again = await repo.importMaterial(payload, uiLanguage: 'en');
      expect(again.ok, isTrue);
      expect(again.newSentences, 0);
      expect(again.newItems, 0);
      expect(again.duplicateSentences, greaterThan(0));
      expect(await repo.counts(), before);
    });

    test('a term shared with another realm is linked, not duplicated', () async {
      await repo.importProfile(profileJson(['Work', 'Travel']), uiLanguage: 'en');
      await repo.importMaterial(
        materialJson(realm: 'Work', terms: [('boarding pass', 'x'), ('work only', 'y')]),
        uiLanguage: 'en',
      );
      final res = await repo.importMaterial(
        materialJson(realm: 'Travel', terms: [('boarding pass', 'x'), ('travel only', 'z')]),
        uiLanguage: 'en',
      );

      expect(res.linkedItems, 1);
      final shared =
          (await repo.items()).where((i) => i.normKeyValue == 'boarding pass').toList();
      expect(shared.length, 1, reason: 'one concept, one record');
      expect(shared.first.realmIds.length, 2);
    });

    test('malformed replies never throw', () async {
      const cases = [
        '',
        'Sorry, I could not produce JSON.',
        '{"schema_version":"1.0","type":"material","sentences":[{"text":"hi"',
        '[1,2,3]',
        'null',
        '{"schema_version":"9.9","type":"material","domain":{"name":"x"},"learning_items":[],"sentences":[{"text":"a b c"}]}',
        '{"schema_version":"1.0","type":"material","learning_items":[],"sentences":[]}',
      ];
      for (final c in cases) {
        final res = await repo.importMaterial(c, uiLanguage: 'en');
        expect(res.ok, isFalse, reason: 'should reject: $c');
        expect(res.errors, isNotEmpty);
      }
      // And the database is untouched.
      expect((await repo.counts()).sentences, 0);
    });

    test('prose wrapped around a fenced block is still read', () async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      final wrapped = 'Here you go!\n\n```json\n'
          '${materialJson(realm: 'Work', terms: [('repair policy', 'x')])}'
          '\n```\n\nHope that helps.';
      final res = await repo.importMaterial(wrapped, uiLanguage: 'en');
      expect(res.ok, isTrue, reason: res.errors.join(', '));
      expect(res.newSentences, greaterThan(0));
    });
  });

  group('session planning', () {
    Future<void> seed({int termCount = 12, int sentencesPerTerm = 2}) async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await repo.importMaterial(
        materialJson(
          realm: 'Work',
          terms: [for (var i = 0; i < termCount; i++) ('term number $i', 'meaning $i')],
          sentencesPerTerm: sentencesPerTerm,
        ),
        uiLanguage: 'en',
      );
    }

    test('a session never repeats a sentence', () async {
      await seed();
      final slots = await repo.buildSession(count: 8);
      expect(slots.length, 8);
      final ids = slots.map((s) => s.question.sentenceId).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('a session fills up even when there are fewer items than slots',
        () async {
      // The reported complaint. One question per item made a session as short
      // as the library had items, however long the session was set to — two
      // terms meant two questions, even with six sentences to draw on.
      await seed(termCount: 2, sentencesPerTerm: 3);
      expect((await repo.sentences()).length, 6);

      final slots = await repo.buildSession(count: 6);
      expect(slots.length, 6, reason: 'every sentence can carry a slot');
      final ids = slots.map((s) => s.question.sentenceId).toList();
      expect(ids.toSet().length, ids.length, reason: 'still no repeated sentence');
    });

    test('questions already asked give way to ones that have not been',
        () async {
      await seed(termCount: 4);
      final all = await repo.questions();

      // Wear out half the library by answering it.
      final worn = all.take(all.length ~/ 2).toList();
      for (final q in worn) {
        await repo.recordAnswer(question: q, correct: true, wasDue: false);
      }
      final wornIds = worn.map((q) => q.id).toSet();

      // Recency alone cannot explain the result: clear it, so the only thing
      // left to go on is how often each question has been asked.
      await repo.saveProgress(await repo.loadProgress());
      final picked = <String>{};
      for (var i = 0; i < 4; i++) {
        for (final s in await repo.buildSession(count: 6)) {
          picked.add(s.question.id);
        }
      }

      final freshPicked = picked.where((id) => !wornIds.contains(id)).length;
      final wornPicked = picked.where((id) => wornIds.contains(id)).length;
      expect(freshPicked, greaterThan(wornPicked),
          reason: 'unasked questions should lead: $freshPicked vs $wornPicked');
    });

    test('breadth first: every item gets introduced before any is drilled', () async {
      await seed(termCount: 12);
      final seenItems = <String>{};
      final seenSentences = <String>{};

      for (var session = 0; session < 12; session++) {
        final slots = await repo.buildSession(count: 5);
        for (final s in slots) {
          if (s.itemId != null) seenItems.add(s.itemId!);
          seenSentences.add(s.question.sentenceId);
          await repo.recordAnswer(
              question: s.question, correct: true, wasDue: s.wasDue);
        }
      }

      final totals = await repo.counts();
      expect(seenItems.length, totals.items,
          reason: 'every expression should have been introduced');
      expect(seenSentences.length, totals.sentences,
          reason: 'every sentence should have been used');
    });

    test('consecutive sessions do not repeat sentences', () async {
      await seed();
      var previous = <String>{};
      for (var i = 0; i < 8; i++) {
        final slots = await repo.buildSession(count: 5);
        final ids = slots.map((s) => s.question.sentenceId).toSet();
        expect(ids.intersection(previous), isEmpty,
            reason: 'session $i repeated a sentence from the one before');
        for (final s in slots) {
          await repo.recordAnswer(question: s.question, correct: true, wasDue: s.wasDue);
        }
        previous = ids;
      }
    });

    test('a real session mixes every format, conversation first', () async {
      await seed();
      final tally = <QuestionType, int>{};
      for (var i = 0; i < 12; i++) {
        for (final s in await repo.buildSession(count: 5)) {
          tally[s.question.type] = (tally[s.question.type] ?? 0) + 1;
          await repo.recordAnswer(question: s.question, correct: true, wasDue: s.wasDue);
        }
      }
      final total = tally.values.fold(0, (a, b) => a + b);
      for (final t in QuestionType.values) {
        expect(tally[t] ?? 0, greaterThan(0), reason: '$t never appeared');
      }

      // The point of the rebalance: what to say and how to say it now get more
      // of the session than understanding what was said.
      final conversation = (tally[QuestionType.reply] ?? 0) +
          (tally[QuestionType.produce] ?? 0) +
          (tally[QuestionType.register] ?? 0);
      final comprehension =
          (tally[QuestionType.gist] ?? 0) + (tally[QuestionType.paraphrase] ?? 0);
      expect(conversation, greaterThan(comprehension));

      // Listening is still the spine of the app and must keep a real share.
      expect(comprehension / total, greaterThan(0.2));
    });

    test('filtering by realm only serves that realm', () async {
      await repo.importProfile(profileJson(['Work', 'Travel']), uiLanguage: 'en');
      await repo.importMaterial(
          materialJson(realm: 'Work', terms: [('work term', 'a')]), uiLanguage: 'en');
      await repo.importMaterial(
          materialJson(realm: 'Travel', terms: [('travel term', 'b')]), uiLanguage: 'en');

      final travel = (await repo.realms()).firstWhere((r) => r.name == 'Travel');
      final slots = await repo.buildSession(realmId: travel.id, count: 5);
      expect(slots, isNotEmpty);
      expect(slots.every((s) => s.question.realmId == travel.id), isTrue);
    });
  });

  group('answering', () {
    test('records schedule, history, streak and XP together', () async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await repo.importMaterial(
          materialJson(realm: 'Work', terms: [('repair policy', 'x')]), uiLanguage: 'en');

      final slot = (await repo.buildSession(count: 1)).single;
      final res = await repo.recordAnswer(
          question: slot.question, correct: true, wasDue: slot.wasDue);

      expect(res.correct, isTrue);
      expect(res.seeds, greaterThan(0));
      expect(res.progress.streak, 1);
      expect(res.streak.advanced, isTrue);
      expect((await repo.history()).length, 1);
      expect((await repo.srsStates()).length, 1);
      expect((await repo.srsStates()).single.box, greaterThan(0));
    });

    test('answering many times in one day advances the streak once', () async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await repo.importMaterial(
          materialJson(realm: 'Work', terms: [('a term', 'x'), ('b term', 'y')]),
          uiLanguage: 'en');

      for (var i = 0; i < 6; i++) {
        for (final s in await repo.buildSession(count: 2)) {
          await repo.recordAnswer(question: s.question, correct: true, wasDue: s.wasDue);
        }
      }
      expect((await repo.loadProgress()).streak, 1);
      expect((await repo.history()).length, 12);
    });

    test('a wrong answer schedules the item for tomorrow', () async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await repo.importMaterial(
          materialJson(realm: 'Work', terms: [('repair policy', 'x')]), uiLanguage: 'en');

      final slot = (await repo.buildSession(count: 1)).single;
      await repo.recordAnswer(question: slot.question, correct: false, wasDue: false);

      final state = (await repo.srsStates()).single;
      expect(state.box, 0);
      expect(state.due, addDays(today(), 1));
      expect(state.lapses, 1);
    });
  });

  group('counts', () {
    test('new material is all fresh, none due', () async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await repo.importMaterial(
          materialJson(realm: 'Work', terms: [('a term', 'x'), ('b term', 'y')]),
          uiLanguage: 'en');

      final c = await repo.homeCounts('all');
      expect(c.due, 0);
      expect(c.fresh, 2);
      expect(c.total, 2);
      expect(c.questions, greaterThan(0));
    });
  });

  group('resets', () {
    Future<({String work, String travel})> seedTwoRealms() async {
      await repo.importProfile(profileJson(['Work', 'Travel']), uiLanguage: 'en');
      await repo.importMaterial(
          materialJson(realm: 'Work', terms: [('shared term', 's'), ('work only', 'w')]),
          uiLanguage: 'en');
      await repo.importMaterial(
          materialJson(realm: 'Travel', terms: [('shared term', 's'), ('travel only', 't')]),
          uiLanguage: 'en');
      final rs = await repo.realms();
      return (
        work: rs.firstWhere((r) => r.name == 'Work').id,
        travel: rs.firstWhere((r) => r.name == 'Travel').id,
      );
    }

    test('deleting a realm keeps shared expressions and other realms', () async {
      final ids = await seedTwoRealms();

      final plan = await repo.planRealmDeletion(ids.work);
      expect(plan.items, 1, reason: 'only the work-exclusive expression');
      expect(plan.sharedItems, 1);

      await repo.deleteRealmMaterial(ids.work);

      final items = await repo.items();
      expect(items.any((i) => i.normKeyValue == 'work only'), isFalse);
      expect(items.any((i) => i.normKeyValue == 'travel only'), isTrue);

      final shared = items.firstWhere((i) => i.normKeyValue == 'shared term');
      expect(shared.realmIds, [ids.travel], reason: 'unlinked from Work only');

      expect((await repo.sentences()).any((s) => s.realmId == ids.work), isFalse);
      expect((await repo.sentences()).any((s) => s.realmId == ids.travel), isTrue);

      // The realm itself survives so fresh material can be pasted straight back.
      final work = (await repo.realms()).firstWhere((r) => r.id == ids.work);
      expect(work.hasMaterial, isFalse);
    });

    test('no question is left pointing at a deleted sentence', () async {
      final ids = await seedTwoRealms();
      await repo.deleteRealmMaterial(ids.work);
      final sentenceIds = (await repo.sentences()).map((s) => s.id).toSet();
      final dangling =
          (await repo.questions()).where((q) => !sentenceIds.contains(q.sentenceId));
      expect(dangling, isEmpty);
    });

    test('resetting progress keeps material', () async {
      await seedTwoRealms();
      for (final s in await repo.buildSession(count: 3)) {
        await repo.recordAnswer(question: s.question, correct: true, wasDue: s.wasDue);
      }
      final before = await repo.counts();

      await repo.resetProgress();

      expect(await repo.counts(), before);
      expect(await repo.srsStates(), isEmpty);
      expect(await repo.history(), isEmpty);
      expect((await repo.loadProgress()).streak, 0);
    });

    test('factory reset clears everything but keeps the chosen language', () async {
      await repo.saveUiLanguage('ja');
      await seedTwoRealms();
      await repo.factoryReset();

      final c = await repo.counts();
      expect(c.realms, 0);
      expect(c.items, 0);
      expect(c.sentences, 0);
      expect(c.questions, 0);
      expect(await repo.loadProfile(), isNull);
      expect(await repo.loadUiLanguage(), 'ja',
          reason: 'never strand the user in a language they cannot read');
    });
  });

  group('backup', () {
    test('export then restore reproduces the database', () async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await repo.importMaterial(
          materialJson(realm: 'Work', terms: [('repair policy', 'x'), ('other term', 'y')]),
          uiLanguage: 'en');
      for (final s in await repo.buildSession(count: 2)) {
        await repo.recordAnswer(question: s.question, correct: true, wasDue: s.wasDue);
      }

      final before = await repo.counts();
      final progressBefore = await repo.loadProgress();
      final payload = await repo.exportAll();
      final json = jsonEncode(payload);

      await repo.factoryReset(keepLanguage: false);
      expect((await repo.counts()).sentences, 0);

      final restored =
          await repo.restore(jsonDecode(json) as Map<String, dynamic>);
      expect(restored, greaterThan(0));

      expect(await repo.counts(), before);
      expect((await repo.loadProgress()).streak, progressBefore.streak);
      expect((await repo.loadProgress()).seeds, progressBefore.seeds);
      expect((await repo.srsStates()).length, greaterThan(0));

      // Referential integrity survives the round trip.
      final sentenceIds = (await repo.sentences()).map((s) => s.id).toSet();
      expect((await repo.questions()).where((q) => !sentenceIds.contains(q.sentenceId)),
          isEmpty);
    });

    test('a foreign file is rejected', () async {
      expect(
        () => repo.restore({'app': 'something-else', 'data': {}}),
        throwsA(isA<FormatException>()),
      );
    });

    test('a backup taken before the rename restores its balance as Seeds',
        () async {
      // Backups carry the progress blob verbatim, so a file exported while
      // the currency was still called Koto Coin has to come back whole.
      final restored = await repo.restore({
        'app': 'kotolang',
        'backup_version': 1,
        'data': {
          'meta': [
            {
              'key': 'progress',
              'value': jsonEncode({
                'streak': 3,
                'bestStreak': 5,
                'freezes': 1,
                'xpTotal': 210,
                'kotoCoins': 142,
              }),
            },
          ],
        },
      });
      expect(restored, 1);

      final progress = await repo.loadProgress();
      expect(progress.seeds, 142);
      expect(progress.streak, 3);
      expect(progress.bestStreak, 5);
    });
  });

  group('library operations', () {
    test('hiding an expression hides its questions', () async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await repo.importMaterial(
          materialJson(realm: 'Work', terms: [('a term', 'x'), ('b term', 'y')]),
          uiLanguage: 'en');

      final item = (await repo.items()).first;
      await repo.setItemDisabled(item.id, true);

      final slots = await repo.buildSession(count: 10);
      expect(slots.any((s) => s.itemId == item.id), isFalse);

      await repo.setItemDisabled(item.id, false);
      final after = await repo.buildSession(count: 10);
      expect(after.any((s) => s.itemId == item.id), isTrue);
    });

    test('deleting an expression removes its schedule but keeps sentences', () async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await repo.importMaterial(
          materialJson(realm: 'Work', terms: [('a term', 'x'), ('b term', 'y')]),
          uiLanguage: 'en');
      final sentencesBefore = (await repo.sentences()).length;

      final item = (await repo.items()).first;
      await repo.deleteItem(item.id);

      expect((await repo.items()).any((i) => i.id == item.id), isFalse);
      expect((await repo.questions()).any((q) => q.itemId == item.id), isFalse);
      expect((await repo.sentences()).length, sentencesBefore);
    });
  });

  group('maintenance', () {
    test('realm flags are repaired from what is actually stored', () async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      final realm = (await repo.realms()).single;

      // Simulate drift: claim material that does not exist.
      await db.into(db.realms).insertOnConflictUpdate(
          realmToRow(realm.copyWith(hasMaterial: true)));
      expect((await repo.realms()).single.hasMaterial, isTrue);

      final fixed = await repo.repairRealmFlags();
      expect(fixed, 1);
      expect((await repo.realms()).single.hasMaterial, isFalse);
    });
  });

  group('paying for a brand-new realm', () {
    test('re-opening the prompt does not charge a second time', () async {
      // The reported failure. Copying the "add a new area" prompt charged the
      // unlock up front, and nothing recorded that it had been paid — so
      // coming back to copy the prompt again, which is what anyone does after
      // losing the clipboard, charged the same realm over and over.
      await repo.saveProgress(const Progress(seeds: 250));

      expect(await repo.spendForNewRealm(), isTrue);
      expect((await repo.loadProgress()).seeds, 250 - realmUnlockCost);

      expect(await repo.spendForNewRealm(), isTrue);
      expect((await repo.loadProgress()).seeds, 250 - realmUnlockCost);
    });

    test('the realm that arrives uses the credit up, so the next one pays',
        () async {
      await repo.saveProgress(const Progress(seeds: 250));
      await repo.spendForNewRealm();

      await repo.importMaterial(
        materialJson(realm: 'Sailing', terms: [('close haul', 'x')]),
        uiLanguage: 'en',
      );
      expect((await repo.loadProgress()).seeds, 250 - realmUnlockCost);

      expect(await repo.spendForNewRealm(), isTrue);
      expect((await repo.loadProgress()).seeds, 250 - realmUnlockCost * 2);
    });

    test('confirming an unlock twice pays for the area once', () async {
      // Two taps on the tile stack two confirmation dialogs, and both can be
      // confirmed. The second one must not charge again.
      await repo.importProfile(
          profileJson(['Work', 'Sailing', 'Cooking', 'Travel']),
          uiLanguage: 'en');
      final locked = (await repo.realms()).firstWhere((r) => !r.unlocked);
      await repo.saveProgress(const Progress(seeds: 250));

      expect(await repo.unlockRealm(locked.id), isTrue);
      expect(await repo.unlockRealm(locked.id), isTrue);
      expect((await repo.loadProgress()).seeds, 250 - realmUnlockCost);
    });

    test('the first batch in an area is free, later ones are not', () async {
      // Opening an area and then filling it should not be two charges: an
      // area with nothing in it is not yet usable. The question is asked of
      // the paste itself rather than of a dropdown, because the area a batch
      // belongs to is written in the batch.
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      final batch = materialJson(realm: 'Work', terms: [('repair policy', 'x')]);
      expect(await repo.materialWouldCost(batch), isFalse);

      await repo.importMaterial(batch, uiLanguage: 'en');
      expect(await repo.materialWouldCost(batch), isTrue);
    });

    test('a batch for an area that does not exist yet is free', () async {
      // It opens the area as well as filling it, and opening is what the
      // Seeds were already spent on.
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      expect(
        await repo.materialWouldCost(
            materialJson(realm: 'Sailing', terms: [('reef the main', 'x')])),
        isFalse,
      );
    });

    test('a paste that is not material at all is never charged for', () async {
      expect(await repo.materialWouldCost('not json'), isFalse);
      expect(await repo.materialWouldCost(profileJson(['Work'])), isFalse);
    });

    test('a further batch spends its cost, and is refused when short',
        () async {
      await repo.saveProgress(const Progress(seeds: extraMaterialCost));
      expect(await repo.spendForExtraMaterial(), isTrue);
      expect((await repo.loadProgress()).seeds, 0);

      expect(await repo.spendForExtraMaterial(), isFalse);
      expect((await repo.loadProgress()).seeds, 0);
    });

    test('a short balance spends nothing and stays refused', () async {
      await repo.saveProgress(Progress(seeds: realmUnlockCost - 1));
      expect(await repo.spendForNewRealm(), isFalse);
      expect((await repo.loadProgress()).seeds, realmUnlockCost - 1);
    });
  });

  group('breakthrough bonus', () {
    /// Puts [itemId] one step below the line, with a record of repeated
    /// failures and production already shown, so the only thing left to happen
    /// is the answer itself.
    Future<void> primeStruggling(String itemId, {int box = 3}) async {
      await db.into(db.srsStates).insertOnConflictUpdate(srsToRow(SrsState(
            itemId: itemId,
            due: today(),
            box: box,
            reps: 9,
            lapses: breakthroughLapses,
            introduced: true,
            formats: const {QuestionType.produce: FormatStat(n: 2, ok: 1)},
          )));
    }

    test('an item that finally clicks pays once, not every time', () async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await repo.importMaterial(
        materialJson(realm: 'Work', terms: [('repair policy', 'meaning A')]),
        uiLanguage: 'en',
      );
      final questions = await repo.questions();
      final q = questions.firstWhere((x) => x.itemId != null);
      await primeStruggling(q.itemId!);

      final first =
          await repo.recordAnswer(question: q, correct: true, wasDue: true);
      expect(first.breakthrough, isTrue);
      expect(first.seeds, greaterThanOrEqualTo(breakthroughBonus));
      expect(first.progress.breakthroughs, [q.itemId]);

      // Slipping back and recovering must not pay a second time — otherwise it
      // could be farmed by missing on purpose.
      final balance = first.progress.seeds;
      await primeStruggling(q.itemId!);
      final again =
          await repo.recordAnswer(question: q, correct: true, wasDue: true);
      expect(again.breakthrough, isFalse);
      expect(again.seeds, lessThan(breakthroughBonus));
      expect(again.progress.seeds - balance, again.seeds);
      expect(again.progress.breakthroughs, [q.itemId]);
    });

    test('an item that was never a struggle pays nothing extra', () async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await repo.importMaterial(
        materialJson(realm: 'Work', terms: [('repair policy', 'meaning A')]),
        uiLanguage: 'en',
      );
      final questions = await repo.questions();
      final q = questions.firstWhere((x) => x.itemId != null);
      await db.into(db.srsStates).insertOnConflictUpdate(srsToRow(SrsState(
            itemId: q.itemId!,
            due: today(),
            box: 3,
            reps: 4,
            lapses: 0,
            introduced: true,
            formats: const {QuestionType.produce: FormatStat(n: 2, ok: 2)},
          )));

      final res =
          await repo.recordAnswer(question: q, correct: true, wasDue: true);
      expect(res.breakthrough, isFalse);
      expect(res.progress.breakthroughs, isEmpty);
    });
  });

  group('format filter', () {
    Future<void> seedWork() async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await repo.importMaterial(
        materialJson(realm: 'Work', terms: [
          ('repair policy', 'a'),
          ('delivery date', 'b'),
          ('damage tolerance', 'c'),
        ], sentencesPerTerm: 3),
        uiLanguage: 'en',
      );
    }

    test('a session keeps to the kinds of question asked for', () async {
      await seedWork();
      final allow = typesFor('listening')!;
      final slots = await repo.buildSession(count: 8, allow: allow);
      expect(slots, isNotEmpty);
      expect(slots.every((s) => allow.contains(s.question.type)), isTrue,
          reason: 'served ${slots.map((s) => s.question.type).toSet()}');
    });

    test('a filter with nothing behind it still gives a session', () async {
      await seedWork();
      // Nothing in the library can satisfy this, so the filter is ignored
      // rather than obeyed into an empty screen.
      final slots = await repo.buildSession(count: 5, allow: const {});
      expect(slots, isNotEmpty);
    });
  });

  group('using the whole library', () {
    test('a session keeps going past the sentence count', () async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await repo.importMaterial(
        materialJson(realm: 'Work', terms: [('repair policy', 'a')],
            sentencesPerTerm: 2),
        uiLanguage: 'en',
      );
      final sentences = (await repo.sentences()).length;
      final questions = (await repo.questions()).length;
      expect(questions, greaterThan(sentences), reason: 'setup');

      // Refilling means a trip to an assistant, so what is already here gets
      // used rather than held back.
      final slots = await repo.buildSession(count: questions);
      expect(slots.length, greaterThan(sentences));
      expect(slots.length, lessThanOrEqualTo(questions));
    });

    test('nothing is ever served twice in one session', () async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await repo.importMaterial(
        materialJson(realm: 'Work', terms: [('repair policy', 'a')],
            sentencesPerTerm: 2),
        uiLanguage: 'en',
      );
      final slots = await repo.buildSession(count: 200);
      final ids = slots.map((s) => s.question.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every sentence is met once before any is met again', () async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await repo.importMaterial(
        materialJson(realm: 'Work', terms: [('repair policy', 'a')],
            sentencesPerTerm: 3),
        uiLanguage: 'en',
      );
      final sentences = (await repo.sentences()).length;
      final slots = await repo.buildSession(count: sentences + 3);
      final firstRound = slots.take(sentences).map((s) => s.question.sentenceId);
      expect(firstRound.toSet().length, sentences,
          reason: 'a repeat before the fresh ones ran out');
    });
  });

  group('ornaments', () {
    test('a decoration is bought once and hangs on the tree', () async {
      await repo.saveProgress(const Progress(seeds: ornamentCost + 5));
      final next = await repo.spendForOrnament('star');
      expect(next, isNotNull);
      expect(next!.seeds, 5);
      expect(next.ornaments, ['star']);
      expect((await repo.loadProgress()).ornaments, ['star']);
    });

    test('a short balance buys nothing and spends nothing', () async {
      await repo.saveProgress(const Progress(seeds: ornamentCost - 1));
      expect(await repo.spendForOrnament('bell'), isNull);
      final p = await repo.loadProgress();
      expect(p.seeds, ornamentCost - 1);
      expect(p.ornaments, isEmpty);
    });

    test('an unknown decoration is refused rather than stored', () async {
      await repo.saveProgress(const Progress(seeds: 500));
      expect(await repo.spendForOrnament('rocket'), isNull);
      expect((await repo.loadProgress()).seeds, 500);
    });

    test('decorations survive a backup and restore', () async {
      await repo.saveProgress(const Progress(seeds: 500));
      await repo.spendForOrnament('ribbon');
      await repo.spendForOrnament('ribbon');
      final blob = jsonEncode((await repo.loadProgress()).toJson());
      final back = Progress.fromJson(jsonDecode(blob) as Map<String, dynamic>);
      expect(back.ornaments, ['ribbon', 'ribbon'],
          reason: 'two of the same is a choice, not a mistake');
    });
  });

  group('discovery', () {
    test('the first meeting is flagged, later ones are not', () async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await repo.importMaterial(
        materialJson(realm: 'Work', terms: [('repair policy', 'meaning A')]),
        uiLanguage: 'en',
      );
      final q = (await repo.questions()).firstWhere((x) => x.itemId != null);

      final first = await repo.recordAnswer(question: q, correct: true, wasDue: false);
      expect(first.discovered, isTrue);

      final second = await repo.recordAnswer(question: q, correct: true, wasDue: false);
      expect(second.discovered, isFalse);
    });
  });

  group('session size', () {
    test('a size bought under the old rules is snapped to an offered one',
        () async {
      // Sessions used to be lengthened ten slots at a time up to forty-five.
      // Those numbers are not on the settings screen any more, and the
      // dropdown fell back to showing 5 without writing 5 back — so it read
      // "5 questions" while the session went on serving twenty-five.
      for (final (stored, expected) in const [
        (15, 10), // a tie goes to the shorter session
        (25, 20),
        (35, 20),
        (45, 20),
        (7, 5),
        (1, 3),
      ]) {
        await repo.saveSettings(AppSettings(sessionSize: stored));
        expect((await repo.loadSettings()).sessionSize, expected,
            reason: 'a stored $stored should become $expected');
      }
    });

    test('a size the screen offers is left exactly as it is', () async {
      for (final n in sessionSizes) {
        await repo.saveSettings(AppSettings(sessionSize: n));
        expect((await repo.loadSettings()).sessionSize, n);
      }
    });

    test('what is loaded is always something the screen can show', () async {
      // The property the dropdown depends on: it throws outright if handed a
      // value with no matching item.
      for (final stored in [0, 1, 5, 9, 12, 18, 30, 45, 999]) {
        await repo.saveSettings(AppSettings(sessionSize: stored));
        expect(sessionSizes.contains((await repo.loadSettings()).sessionSize),
            isTrue);
      }
    });
  });

  group('perfect run', () {
    test('a clean session pays the perfect-run bonus as well', () async {
      await repo.saveProgress(const Progress());
      final clean = await repo.finishSession(
          answered: perfectRunMin, missed: 0, target: perfectRunMin);
      expect(clean.perfect, isTrue);
      expect(clean.bonus,
          sessionCompletionBonus(perfectRunMin, perfectRunMin) + perfectRunBonus);

      await repo.saveProgress(const Progress());
      final marred = await repo.finishSession(
          answered: perfectRunMin, missed: 1, target: perfectRunMin);
      expect(marred.perfect, isFalse);
      expect(marred.bonus,
          sessionCompletionBonus(perfectRunMin, perfectRunMin));
    });

    test('the Seeds actually land in the balance', () async {
      await repo.saveProgress(const Progress(seeds: 5));
      final res = await repo.finishSession(answered: 10, missed: 0);
      expect(res.progress.seeds, 5 + res.bonus);
      expect((await repo.loadProgress()).seeds, res.progress.seeds);
    });
  });

  group('mastery stages', () {
    test('an answer that moves the item up a stage says so', () async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await repo.importMaterial(
        materialJson(realm: 'Work', terms: [('repair policy', 'meaning A')]),
        uiLanguage: 'en',
      );
      final q = (await repo.questions()).firstWhere((x) => x.itemId != null);

      // Box 1 is still a seed; box 2 is the first sprout.
      await db.into(db.srsStates).insertOnConflictUpdate(srsToRow(SrsState(
            itemId: q.itemId!,
            due: today(),
            box: 1,
            reps: 2,
            introduced: true,
          )));

      final up = await repo.recordAnswer(question: q, correct: true, wasDue: true);
      expect(up.stageUp, MasteryStage.sprout);

      // Answering again inside the same stage is not another promotion.
      final flat =
          await repo.recordAnswer(question: q, correct: true, wasDue: false);
      expect(flat.stageUp, isNull);
    });
  });
}
