/// Fields: every scene has one, the built-ins by kind, the learner's own by
/// the field they were made for; adding a field costs Seeds and never makes
/// a twin of an area that already exists.
library;

import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kotolang/data/builtin_scenes.dart';
import 'package:kotolang/data/database.dart';
import 'package:kotolang/data/repository.dart';
import 'package:kotolang/domain/field.dart';
import 'package:kotolang/domain/progress_service.dart';

import 'repository_test.dart' show profileJson;
import 'scene_test.dart' show pack, scene;
import 'tree_test.dart' show realm;

void main() {
  late AppDatabase db;
  late Repository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = Repository(db, rng: Random(1));
  });
  tearDown(() => db.close());

  test('built-in scenes carry their kind as their field', () {
    for (final sc in builtinScenes('en')) {
      expect(builtinFieldIds, contains(fieldOf(sc)), reason: sc.id);
    }
    final split = splitField(builtinScenes('ja'), 'travel');
    expect(split.samples, hasLength(10));
    expect(split.own, isEmpty);
  });

  test('imported scenes land in the field they were asked for; older ones default',
      () async {
    await repo.importScenes(pack([scene('Stay late')]), uiLanguage: 'en', field: 'work');
    await repo.importScenes(pack([scene('Old one')]), uiLanguage: 'en');
    final own = await repo.scenes();
    final byTopic = {for (final s in own) s.topic: s};
    expect(fieldOf(byTopic['Stay late']!), 'work');
    expect(fieldOf(byTopic['Old one']!), defaultFieldId);

    final work = splitField([...own, ...builtinScenes('en')], 'work');
    expect(work.own.map((s) => s.topic), ['Stay late']);
    expect(work.samples, hasLength(10));
  });

  test('the fields are the four built-ins and then the unlocked areas', () async {
    await repo.importProfile(profileJson(['Nursing', 'Cycling']), uiLanguage: 'en');
    final realms = await repo.realms();
    // Both areas came off the profile and are open: the built-ins, then them.
    final fields = fieldsFrom(realms, (id) => id.toUpperCase());
    expect(fields.map((f) => f.label).take(4), ['WORK', 'TRAVEL', 'SCHOOL', 'DAILY']);
    expect(fields.skip(4).map((f) => f.label).toSet(), {'Nursing', 'Cycling'});
    expect(fields.last.builtin, isFalse);
    // A locked area stays out of the open list.
    await db.into(db.realms).insertOnConflictUpdate(realmToRow(
        realm('Sailing').copyWith(unlocked: false)));
    expect(fieldsFrom(await repo.realms(), (id) => id).map((f) => f.id), isNot(contains('Sailing')));
  });

  test('the profile opens its first three areas as fields; the rest wait, priced', () async {
    await repo.importProfile(profileJson(['Nursing', 'Cycling', 'Gardening', 'Chess', 'Sailing']),
        uiLanguage: 'en');
    final realms = await repo.realms();
    expect(realms.where((r) => r.unlocked), hasLength(freeRealmSlots));
    final open = fieldsFrom(realms, (id) => id);
    expect(open.where((f) => !f.builtin), hasLength(freeRealmSlots));
    final locked = lockedFieldsFrom(realms, (id) => id);
    expect(locked, hasLength(5 - freeRealmSlots));
    // A second import does not hand out more free slots.
    await repo.importProfile(profileJson(['Nursing', 'Cycling', 'Gardening', 'Chess', 'Sailing', 'Rowing']),
        uiLanguage: 'en');
    expect((await repo.realms()).where((r) => r.unlocked), hasLength(freeRealmSlots));
  });

  test('adding a field costs Seeds and needs the balance', () async {
    expect(await repo.addField('Cooking'), isNull);
    await repo.saveProgress((await repo.loadProgress()).copyWith(seeds: realmUnlockCost));
    final realm = await repo.addField('  Cooking ');
    expect(realm, isNotNull);
    expect(realm!.unlocked, isTrue);
    expect(realm.label, 'Cooking');
    expect((await repo.loadProgress()).seeds, 0);

    // The same name again is the same field, and free.
    final again = await repo.addField('cooking');
    expect(again?.id, realm.id);
    expect((await repo.realms()).where((r) => r.normKeyValue == 'cooking'), hasLength(1));
  });

  test('the prompt names the field the scenes are for', () async {
    await repo.saveProgress((await repo.loadProgress()).copyWith(seeds: realmUnlockCost));
    final realm = (await repo.addField('Cooking'))!;
    final work = await repo.scenesPromptText(uiLanguage: 'en', field: 'work');
    expect(work, contains('This set is about: English at work'));
    final cooking = await repo.scenesPromptText(uiLanguage: 'en', field: realm.id);
    expect(cooking, contains('This set is about: Cooking'));
    final none = await repo.scenesPromptText(uiLanguage: 'en');
    expect(none, isNot(contains('This set is about')));
  });
}