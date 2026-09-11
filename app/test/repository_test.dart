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

import 'fixtures.dart' show pack, scene, turn;

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
      expect(await repo.freeFieldSlotsLeft(), freeRealmSlots);
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
      final broken = scene('Broken', turns: [
        turn(replies: [
          {'text': 'a', 'correct': false},
          {'text': 'b', 'correct': false},
          {'text': 'c', 'correct': false},
        ])
      ]);
      final out = await repo.importScenes(pack([scene('Good'), broken]),
          uiLanguage: 'en', field: 'work');
      expect(out.scenes, 1);
      expect(out.rejected.single.title, 'Broken');
      expect(out.rejected.single.reason, contains('no right reply'));
    });

    test('a reply that is not conversations says which reply it is', () async {
      final out = await repo.importScenes(profileJson(['Work']), uiLanguage: 'en');
      expect(out.ok, isFalse);
      expect(out.errors, contains('not a scenes reply'));
    });

    test('a conversation survives the trip through the database', () async {
      await repo.importScenes(
          pack([
            scene('Talk', windowMs: 2400, turns: [turn(type: 'polarity')])
          ]),
          uiLanguage: 'en',
          field: 'work');
      final s = (await repo.scenes()).single;
      final t = s.turns.single;
      expect(s.windowMs, 2400);
      expect(t.keyWord, 'Thursday');
      expect(t.restate, isNotEmpty);
      expect(t.replies, hasLength(3));
      expect(t.replies[t.answer].native, isNotEmpty,
          reason: 'the translation followed its own reply through the shuffle');
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
        await repo.recordTurn(sceneId: id, turn: 0, correct: true);
      }
      expect((await repo.loadLadder()).maxOf(LadderAxis.speed), 1);

      for (var i = 0; i < ladderWindow; i++) {
        await repo.recordTurn(sceneId: id, turn: 0, correct: true, review: true);
      }
      expect((await repo.loadLadder()).maxOf(LadderAxis.speed), 1,
          reason: 'a second look says nothing about holding a setting');
    });

    test('what comes back names the axes that went up', () async {
      final id = await oneScene();
      var promoted = <LadderAxis>[];
      for (var i = 0; i < ladderWindow; i++) {
        promoted =
            (await repo.recordTurn(sceneId: id, turn: 0, correct: true)).promoted;
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

    test('the starting fields are chosen, and cost nothing', () async {
      final ids = await fourAreas();
      await repo.chooseFields(ids.take(freeRealmSlots).toList());
      expect((await repo.realms()).where((r) => r.unlocked), hasLength(freeRealmSlots));
      expect(await repo.freeFieldSlotsLeft(), 0);
      expect((await repo.loadProgress()).seeds, 0);
    });

    test('an opening is only spent while the field it opened is open', () async {
      final ids = await fourAreas();
      await repo.chooseFields(ids.take(2).toList());
      expect(await repo.freeFieldSlotsLeft(), freeRealmSlots - 2);

      await repo.clearField(ids.first, closeField: true);
      expect(await repo.freeFieldSlotsLeft(), freeRealmSlots - 1,
          reason: 'closing a field hands its opening back');
    });

    test('the first batch in a field is free and the next one is not', () async {
      expect(await repo.sceneAddCostFor('work'), 0);
      await repo.importScenes(pack([scene('Talk')]), uiLanguage: 'en', field: 'work');
      expect(await repo.sceneAddCostFor('work'), sceneAddCost);
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
        await repo.recordTurn(sceneId: id, turn: 0, correct: true);
      }
      expect((await repo.loadLadder()).reached, greaterThan(0));

      await repo.forgetAnswers();
      expect(await repo.turnResults(), isEmpty);
      expect(await repo.scenes(), isNotEmpty, reason: 'the material stays');
      expect((await repo.loadLadder()).reached, 0,
          reason: 'a step is a claim about answers that are gone');
      expect(await repo.freeFieldSlotsLeft(), freeRealmSlots - 1,
          reason: 'the field it opened is still open');
    });

    test('clearing the profile hands the starting fields back', () async {
      await seeded();
      await repo.resetProfileAndFields();
      expect(await repo.realms(), isEmpty);
      expect(await repo.scenes(), isEmpty);
      expect(await repo.loadProfile(), isNull);
      expect(await repo.freeFieldSlotsLeft(), freeRealmSlots);
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
      await repo.recordTurn(sceneId: id, turn: 0, correct: true);
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
