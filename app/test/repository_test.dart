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
    Future<void> seed({int termCount = 12}) async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await repo.importMaterial(
        materialJson(
          realm: 'Work',
          terms: [for (var i = 0; i < termCount; i++) ('term number $i', 'meaning $i')],
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
      expect(res.xp, inInclusiveRange(2, 10));
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
      expect((await repo.loadProgress()).xpTotal, progressBefore.xpTotal);
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
}
