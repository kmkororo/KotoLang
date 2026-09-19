/// The repository, over a real (in-memory) SQLite database.
///
/// These cover the places where something is written down and read back: a
/// profile becomes fields, a pasted reply becomes conversations, an answer
/// becomes a record and a step of the ladder, and a reset takes exactly what
/// it said it would take and nothing else.
library;

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kotolang/data/database.dart';
import 'package:kotolang/data/repository.dart';
import 'package:kotolang/domain/field.dart';
import 'package:kotolang/domain/ladder.dart';
import 'package:kotolang/domain/progress_service.dart';

import 'package:kotolang/domain/scene.dart' show predictSeeds;

import 'fixtures.dart' show pack, scene;

/// A profile reply naming [realms] as the learner's areas. Exported because
/// three other suites start from the same place.
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
          {
            'name': r,
            'name_native': r,
            'importance': 4,
            'confidence': 0.9,
            'contexts': ['work'],
          }
      ],
    });

void main() {
  // Restoring a backup needs somewhere to restore it to, so one test opens a
  // second database on purpose. Drift's warning is about sharing an executor,
  // which these two never do.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Repository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = Repository(db, rng: Random(42));
  });

  tearDown(() async => db.close());

  group('the profile', () {
    test('becomes fields, and the profile itself is kept', () async {
      final out = await repo.importProfile(
          profileJson(['Code review', 'Meetings']),
          uiLanguage: 'en');
      expect(out.ok, isTrue);
      expect(out.realms, 2);
      expect(await repo.realms(), hasLength(2));
      expect((await repo.loadProfile())?.englishLevel, 'B2');
    });

    test('opens nothing by itself', () async {
      await repo.importProfile(profileJson(['Code review', 'Meetings']),
          uiLanguage: 'en');
      expect((await repo.realms()).where((r) => r.unlocked), isEmpty,
          reason: 'the learner chooses the starting fields on the next screen');
      expect(await repo.fieldOpeningsLeft(), freeRealmSlots);
    });

    test('the same area pasted twice is the same field', () async {
      await repo.importProfile(profileJson(['Code review']), uiLanguage: 'en');
      await repo.importProfile(profileJson(['code  review', 'Meetings']),
          uiLanguage: 'en');
      expect(await repo.realms(), hasLength(2));
    });

    test('a reply that is not a profile is refused, and nothing is written',
        () async {
      final out =
          await repo.importProfile('I am afraid I cannot do that.', uiLanguage: 'en');
      expect(out.ok, isFalse);
      expect(await repo.realms(), isEmpty);
    });
  });

  group('conversations', () {
    test('a pasted reply is stored, and the same one twice is stored once',
        () async {
      final reply = pack([scene('Moving a deadline'), scene('A visitor at three')]);
      final first = await repo.importScenes(reply, uiLanguage: 'en', field: 'work');
      expect(first.ok, isTrue);
      expect(first.scenes, 2);

      await repo.importScenes(reply, uiLanguage: 'en', field: 'work');
      expect(await repo.scenes(), hasLength(2));
    });

    test('they land in the field they were asked for', () async {
      await repo.importScenes(pack([scene('Talk')]),
          uiLanguage: 'en', field: 'travel');
      expect(fieldOf((await repo.scenes()).single), 'travel');
    });

    test('one the importer cannot make sound is named, not silently dropped',
        () async {
      // A wrong reply with no reason is a second right answer.
      final broken = scene('Broken', replyWhy: const ['', '', 'スライドは正午まで']);
      final out = await repo.importScenes(pack([scene('Good'), broken]),
          uiLanguage: 'en', field: 'work');
      expect(out.scenes, 1);
      expect(out.rejected.single.title, 'Broken');
      expect(out.rejected.single.reason, contains('reply.why is empty'));
    });

    test('what was refused can be handed back to be mended, and costs nothing',
        () async {
      final broken = scene('Broken', replyWhy: const ['', '', 'スライドは正午まで']);
      await repo.importScenes(pack([scene('Good'), broken], batch: 'b1'),
          uiLanguage: 'ja', field: 'work');
      expect((await repo.pendingFix()).count, 1);
      final prompt = await repo.fixPromptText(uiLanguage: 'ja');
      expect(prompt, contains('Broken'));
      expect(prompt, contains('reply.why is empty'));
      expect(prompt, contains('"batch": "b1"'));

      // The mended one comes back in the same batch: taken, and not charged,
      // though the field already has something in it.
      await repo.saveProgress((await repo.loadProgress()).copyWith(seeds: 0));
      final out = await repo.importScenes(pack([scene('Broken')], batch: 'b1'),
          uiLanguage: 'ja', field: 'work');
      expect(out.ok, isTrue);
      expect(out.spent, 0);
      expect((await repo.pendingFix()).count, 0);
    });

    test('the rest of a batch after "continue" is not charged again', () async {
      await repo.importScenes(pack([scene('One')], batch: 'b2'),
          uiLanguage: 'en', field: 'work');
      await repo.saveProgress((await repo.loadProgress()).copyWith(seeds: 0));
      final more = await repo.importScenes(pack([scene('Two')], batch: 'b2'),
          uiLanguage: 'en', field: 'work');
      expect(more.ok, isTrue);
      final fresh = await repo.importScenes(pack([scene('Three')], batch: 'b3'),
          uiLanguage: 'en', field: 'work');
      expect(fresh.shortOf, sceneAddCost, reason: 'a new batch is paid for');
    });

    test('a reply in the shape of before is told apart', () async {
      final old = jsonEncode({
        'schema_version': '4.0',
        'type': 'scenes',
        'scenes': [
          {'title': 'Old', 'turns': []}
        ],
      });
      final out = await repo.importScenes(old, uiLanguage: 'en', field: 'work');
      expect(out.errors, contains('old format'));
    });

    test('a reply that is not conversations says which reply it is', () async {
      final out = await repo.importScenes(profileJson(['Work']), uiLanguage: 'en');
      expect(out.ok, isFalse);
      expect(out.errors, contains('not a scenes reply'));
    });

    test('a set survives the trip through the database', () async {
      await repo.importScenes(pack([scene('Talk')]), uiLanguage: 'en', field: 'work');
      final s = (await repo.scenes()).single;
      final set = s.set!;
      expect(s.playable, isTrue);
      expect(set.partner.text, startsWith('Talk.'));
      expect(set.reply.options, hasLength(3));
      expect(set.reply.why[set.reply.answer], isEmpty,
          reason: 'the reasons followed their options through the shuffle');
      expect(set.reply.options[set.reply.answer], startsWith('Thursday at three on'));
      expect(set.predict.options[set.predict.answer], startsWith('お礼を言って'));
      expect(s.turns.single.line, set.partner.text,
          reason: 'everything that reads turns reads the set as one');
    });
  });

  group('predicting', () {
    test('a prediction is kept apart from the replies, and a right one pays',
        () async {
      await repo.importScenes(pack([scene('Talk')]), uiLanguage: 'en', field: 'work');
      final id = (await repo.scenes()).single.id;
      final before = (await repo.loadProgress()).seeds;
      expect(await repo.recordPrediction(sceneId: id, hit: true), predictSeeds);
      expect(await repo.recordPrediction(sceneId: id, hit: false), 0);
      expect(await repo.recordPrediction(sceneId: id, hit: true, review: true), 0);
      expect((await repo.loadProgress()).seeds, before + predictSeeds);
      expect(await repo.turnResults(), isEmpty, reason: 'not a reply');
      expect(await repo.predictResults(), hasLength(3));
    });
  });

  group('answering', () {
    Future<String> oneScene() async {
      await repo.importScenes(pack([scene('Talk')]),
          uiLanguage: 'en', field: 'work');
      return (await repo.scenes()).single.id;
    }

    test('an answer is written down as it happened', () async {
      final id = await oneScene();
      await repo.recordTurn(sceneId: id, turn: 0, correct: true, inWindow: false);
      final r = (await repo.turnResults()).single;
      expect(r.sceneId, id);
      expect(r.correct, isTrue);
      expect(r.inWindow, isFalse);
      expect(r.day, isNotEmpty);
    });

    test('a miss books another look, and getting it right moves it on', () async {
      final id = await oneScene();
      await repo.recordTurn(sceneId: id, turn: 0, correct: false);
      expect((await repo.reviews()).single.stage, 0);

      await repo.recordTurn(sceneId: id, turn: 0, correct: true, review: true);
      expect((await repo.reviews()).single.stage, 1);

      await repo.recordTurn(sceneId: id, turn: 0, correct: true, review: true);
      expect(await repo.reviews(), isEmpty, reason: 'out of gaps, so it is done');
    });

    test('a second look that goes wrong comes back tomorrow', () async {
      final id = await oneScene();
      await repo.recordTurn(sceneId: id, turn: 0, correct: false);
      await repo.recordTurn(sceneId: id, turn: 0, correct: true, review: true);
      await repo.recordTurn(sceneId: id, turn: 0, correct: false, review: true);
      expect((await repo.reviews()).single.stage, 0);
    });

    test('an answer moves the ladder, and a second look does not', () async {
      final id = await oneScene();
      for (var i = 0; i < ladderWindow; i++) {
        await repo.recordTurn(sceneId: id, turn: 0, correct: true, windowLeft: 1);
      }
      expect((await repo.loadLadder()).maxOf(LadderAxis.speed), 1);

      for (var i = 0; i < ladderWindow; i++) {
        await repo.recordTurn(sceneId: id, turn: 0, correct: true, review: true);
      }
      expect((await repo.loadLadder()).maxOf(LadderAxis.speed), 1,
          reason: 'a second look says nothing about holding a setting');
    });

    test('a wrong answer given in time is weighed with the rest', () async {
      // The pass rate only means something if the misses reach the buffer.
      // They did not: the screen sent "in the window" only for answers that
      // were also right, so the buffer filled with nothing but successes and
      // every window passed.
      final id = await oneScene();
      for (var i = 0; i < ladderWindow; i++) {
        await repo.recordTurn(
            sceneId: id, turn: 0, correct: i.isEven, windowLeft: 1);
      }
      expect((await repo.loadLadder()).maxOf(LadderAxis.speed), 0,
          reason: 'half right is not holding a setting');
    });

    test('an answer too slow for the gauge says nothing to the ladder', () async {
      final id = await oneScene();
      for (var i = 0; i < ladderWindow * 2; i++) {
        await repo.recordTurn(sceneId: id, turn: 0, correct: true, windowLeft: 0.1);
      }
      expect((await repo.loadLadder()).maxOf(LadderAxis.speed), 0);
      expect((await repo.loadProgress()).seeds, greaterThan(0),
          reason: 'it was right, so it was paid for');
    });

    test('what comes back names the axes that went up', () async {
      final id = await oneScene();
      var promoted = <LadderAxis>[];
      for (var i = 0; i < ladderWindow; i++) {
        promoted =
            (await repo.recordTurn(sceneId: id, turn: 0, correct: true, windowLeft: 1))
                .promoted;
      }
      expect(promoted, isNotEmpty, reason: 'the screen can say so on the spot');
    });

    test('finishing a conversation is what keeps the streak', () async {
      expect((await repo.loadProgress()).streak, 0);
      expect((await repo.completeScene()).streak, 1);
    });
  });

  group('fields', () {
    Future<List<String>> fourAreas() async {
      await repo.importProfile(
          profileJson(['Nursing', 'Cycling', 'Gardening', 'Chess']),
          uiLanguage: 'en');
      return [for (final r in await repo.realms()) r.id];
    }

    test('the starting fields are chosen, and nothing is owed for them', () async {
      final ids = await fourAreas();
      await repo.chooseFields(ids.take(freeRealmSlots).toList());
      expect((await repo.realms()).where((r) => r.unlocked), hasLength(freeRealmSlots));
      expect(await repo.fieldOpeningsLeft(), 0);
    });

    test('an opening is only spent while the field it opened is open', () async {
      final ids = await fourAreas();
      await repo.chooseFields(ids.take(2).toList());
      expect(await repo.fieldOpeningsLeft(), freeRealmSlots - 2);

      await repo.clearField(ids.first, closeField: true);
      expect(await repo.fieldOpeningsLeft(), freeRealmSlots - 1,
          reason: 'closing a field hands its opening back');
    });

    test('the first batch in a field is free and the next one is not', () async {
      expect(await repo.sceneAddCostFor('work'), 0);
      await repo.importScenes(pack([scene('Talk')]), uiLanguage: 'en', field: 'work');
      expect(await repo.sceneAddCostFor('work'), sceneAddCost);
    });

    test('the second batch in a field is paid for, the first is not', () async {
      // The price used to be worked out and never charged: the function that
      // knew it had no caller, so a learner with nothing could fill a field.
      await repo.importProfile(profileJson(['Nursing']), uiLanguage: 'en');
      await repo.chooseFields([for (final r in await repo.realms()) r.id]);

      final first = await repo.importScenes(pack([scene('One')]),
          uiLanguage: 'en', field: 'work');
      expect(first.ok, isTrue);
      expect(first.spent, 0, reason: 'a field with nothing in it is not yet a field');

      // Nothing earned yet, so the second batch cannot be paid for.
      final broke = await repo.importScenes(pack([scene('Two')]),
          uiLanguage: 'en', field: 'work');
      expect(broke.ok, isFalse);
      expect(broke.shortOf, sceneAddCost);
      expect((await repo.scenes()).length, 1, reason: 'and nothing was taken in');

      // With enough in hand it goes through, and the balance is the poorer.
      await repo.saveProgress(
          (await repo.loadProgress()).copyWith(seeds: sceneAddCost + 7));
      final paid = await repo.importScenes(pack([scene('Three')]),
          uiLanguage: 'en', field: 'work');
      expect(paid.ok, isTrue);
      expect(paid.spent, sceneAddCost);
      expect((await repo.loadProgress()).seeds, 7);
      expect((await repo.scenes()).length, 2);
    });

    test('answering quickly is what fills the balance', () async {
      await repo.importScenes(pack([scene('Talk')]), uiLanguage: 'en', field: 'work');
      final id = (await repo.scenes()).single.id;

      final quick = await repo.recordTurn(
          sceneId: id, turn: 0, correct: true, windowLeft: 1);
      final slow = await repo.recordTurn(
          sceneId: id, turn: 0, correct: true, windowLeft: 0);
      final wrong = await repo.recordTurn(sceneId: id, turn: 0, correct: false);
      expect(quick.seeds, greaterThan(slow.seeds));
      expect(wrong.seeds, 0);
      expect((await repo.loadProgress()).seeds, quick.seeds + slow.seeds);
    });
  });

  group('resets', () {
    /// One field open, one conversation in it, one turn missed.
    Future<String> seeded() async {
      await repo.importProfile(profileJson(['Nursing']), uiLanguage: 'en');
      await repo.chooseFields([for (final r in await repo.realms()) r.id]);
      await repo.importScenes(pack([scene('Talk')]), uiLanguage: 'en', field: 'work');
      final id = (await repo.scenes()).single.id;
      await repo.recordTurn(sceneId: id, turn: 0, correct: false);
      return id;
    }

    test('clearing a field says first what it will take, then takes it', () async {
      await seeded();
      final plan = await repo.planFieldClear('work');
      expect(plan.scenes, 1);
      expect(plan.answered, 1);

      await repo.clearField('work');
      expect(await repo.scenes(), isEmpty);
      expect(await repo.turnResults(), isEmpty);
      expect(await repo.reviews(), isEmpty);
    });

    test('closing a field leaves it on the list it came from', () async {
      await seeded();
      final id = (await repo.realms()).single.id;
      await repo.clearField(id, closeField: true);
      expect((await repo.realms()).single.unlocked, isFalse,
          reason: 'the area came off the profile, so it can be opened again');
    });

    test('clearing every field leaves the fields themselves standing', () async {
      await seeded();
      await repo.clearEveryField();
      expect(await repo.scenes(), isEmpty);
      expect(await repo.turnResults(), isEmpty);
      expect(await repo.realms(), hasLength(1));
    });

    test('forgetting the answers forgets the ladder with them', () async {
      final id = await seeded();
      for (var i = 0; i < ladderWindow; i++) {
        await repo.recordTurn(sceneId: id, turn: 0, correct: true, windowLeft: 1);
      }
      expect((await repo.loadLadder()).reached, greaterThan(0));

      await repo.forgetAnswers();
      expect(await repo.turnResults(), isEmpty);
      expect(await repo.scenes(), isNotEmpty, reason: 'the material stays');
      expect((await repo.loadLadder()).reached, 0,
          reason: 'a step is a claim about answers that are gone');
      expect(await repo.fieldOpeningsLeft(), freeRealmSlots - 1,
          reason: 'the field it opened is still open');
    });

    test('clearing the profile hands the starting fields back', () async {
      await seeded();
      await repo.resetProfileAndFields();
      expect(await repo.realms(), isEmpty);
      expect(await repo.scenes(), isEmpty);
      expect(await repo.loadProfile(), isNull);
      expect(await repo.fieldOpeningsLeft(), freeRealmSlots);
      expect((await repo.loadProgress()).streak, 0);
      expect((await repo.loadLadder()).reached, 0);
    });

    test('a factory reset keeps the language and nothing else', () async {
      await repo.saveUiLanguage('ja');
      await seeded();
      await repo.factoryReset();
      expect(await repo.loadUiLanguage(), 'ja',
          reason: 'nobody is dropped into a language they cannot read');
      expect(await repo.realms(), isEmpty);
      expect(await repo.scenes(), isEmpty);
      expect(await repo.loadProfile(), isNull);
    });
  });

  group('backup', () {
    test('export then restore reproduces what was there', () async {
      await repo.importProfile(profileJson(['Nursing']), uiLanguage: 'en');
      await repo.importScenes(pack([scene('Talk')]), uiLanguage: 'en', field: 'work');
      final id = (await repo.scenes()).single.id;
      await repo.recordTurn(sceneId: id, turn: 0, correct: true, windowLeft: 1);
      final file = await repo.exportAll();

      final fresh = AppDatabase(NativeDatabase.memory());
      addTearDown(fresh.close);
      final other = Repository(fresh, rng: Random(1));
      await other.restore(file);

      expect((await other.scenes()).single.id, id);
      expect(await other.realms(), hasLength(1));
      expect(await other.turnResults(), hasLength(1));
    });

    test('a file from another app is refused', () async {
      expect(() => repo.restore({'app': 'something else'}), throwsFormatException);
    });

    test('a backup from before the rebuild is refused, not half-read', () async {
      expect(
        () => repo.restore({
          'app': 'kotolang',
          'backup_version': '1.0',
          'data': {
            'sentences': [
              {'id': 'x'}
            ]
          },
        }),
        throwsFormatException,
      );
    });
  });

  group('counts and repair', () {
    test('the counts say what is actually there', () async {
      await repo.importProfile(profileJson(['Nursing']), uiLanguage: 'en');
      await repo.importScenes(pack([scene('Talk')]), uiLanguage: 'en', field: 'work');
      final c = await repo.counts();
      expect(c.realms, 1);
      expect(c.scenes, 1);
      expect(c.answered, 0);
    });

    test('the has-material flag is recomputed from what is stored', () async {
      await repo.importProfile(profileJson(['Nursing']), uiLanguage: 'en');
      final id = (await repo.realms()).single.id;
      await repo.importScenes(pack([scene('Talk')]), uiLanguage: 'en', field: id);

      expect(await repo.repairRealmFlags(), 1);
      expect((await repo.realms()).single.hasMaterial, isTrue);
      expect(await repo.repairRealmFlags(), 0, reason: 'nothing left to fix');
    });
  });
}
