/// Fields: every scene has one, the built-ins by kind, the learner's own by
/// the field they were made for; a field opens because the ladder moved, and
/// never makes a twin of an area that already exists.
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
import 'fixtures.dart' show builtScene, pack, realm, scene;

void main() {
  late AppDatabase db;
  late Repository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = Repository(db, rng: Random(1));
  });
  tearDown(() => db.close());

  test('a field keeps the samples and the learner’s own apart', () {
    // Read from the scenes given, not from the shipped catalogue: the samples
    // are being written again for the rebuilt shape, so the shipped one is
    // empty on purpose and would make this pass for the wrong reason.
    final all = [
      builtScene('Sample travel', builtin: true, field: 'travel'),
      builtScene('Sample work', builtin: true, field: 'work'),
      builtScene('Their own', field: 'travel'),
    ];
    final travel = splitField(all, 'travel');
    expect(travel.samples.map((s) => s.title), ['Sample travel']);
    expect(travel.own.map((s) => s.title), ['Their own']);
    expect(splitField(all, 'school').samples, isEmpty);
  });

  test('every sample the app ships belongs to one of the four sample fields', () {
    // Empty today, which is the honest state. The check stands so that the
    // first sample written for the new shape cannot land in a field that is
    // never offered.
    for (final sc in builtinScenes('en')) {
      expect(builtinFieldIds, contains(fieldOf(sc)), reason: sc.id);
    }
  });

  test('imported scenes land in the field they were asked for; older ones default',
      () async {
    await repo.importScenes(pack([scene('Stay late')]), uiLanguage: 'en', field: 'work');
    await repo.importScenes(pack([scene('Old one')]), uiLanguage: 'en');
    final own = await repo.scenes();
    final byTopic = {for (final s in own) s.title: s};
    expect(fieldOf(byTopic['Stay late']!), 'work');
    expect(fieldOf(byTopic['Old one']!), defaultFieldId);

    expect(splitField(own, 'work').own.map((s) => s.title), ['Stay late']);
  });

  test('the fields are the four built-ins and then the unlocked areas', () async {
    await repo.importProfile(profileJson(['Nursing', 'Cycling']), uiLanguage: 'en');
    await repo.chooseFields([for (final r in await repo.realms()) r.id]);
    final realms = await repo.realms();
    // Both areas came off the profile and were chosen: the built-ins, then them.
    final fields = fieldsFrom(realms, (id) => id.toUpperCase());
    expect(fields.map((f) => f.label).take(4), ['WORK', 'TRAVEL', 'SCHOOL', 'DAILY']);
    expect(fields.skip(4).map((f) => f.label).toSet(), {'Nursing', 'Cycling'});
    expect(fields.last.builtin, isFalse);
    // A locked area stays out of the open list.
    await db.into(db.realms).insertOnConflictUpdate(realmToRow(
        realm('Sailing').copyWith(unlocked: false)));
    expect(fieldsFrom(await repo.realms(), (id) => id).map((f) => f.id), isNot(contains('Sailing')));
  });

  test('the profile opens nothing by itself; the learner chooses the starting fields', () async {
    await repo.importProfile(profileJson(['Nursing', 'Cycling', 'Gardening', 'Chess', 'Sailing']),
        uiLanguage: 'en');
    final realms = await repo.realms();
    expect(realms.where((r) => r.unlocked), isEmpty);
    expect(await repo.fieldOpeningsLeft(), freeRealmSlots);
    // Any three, not the top three.
    await repo.chooseFields([realms[4].id, realms[1].id, realms[3].id]);
    final after = await repo.realms();
    expect(after.where((r) => r.unlocked).map((r) => r.name).toSet(), {'Sailing', 'Cycling', 'Chess'});
    expect(fieldsFrom(after, (id) => id).where((f) => !f.builtin), hasLength(freeRealmSlots));
    expect(lockedFieldsFrom(after, (id) => id), hasLength(5 - freeRealmSlots));
    expect(await repo.fieldOpeningsLeft(), 0);
    // A second import does not hand out more starting picks.
    await repo.importProfile(profileJson(['Nursing', 'Cycling', 'Gardening', 'Chess', 'Sailing', 'Rowing']),
        uiLanguage: 'en');
    expect(await repo.fieldOpeningsLeft(), 0);
    expect((await repo.realms()).where((r) => r.unlocked), hasLength(freeRealmSlots));
  });

  test('a field the learner types costs the same as any other', () async {
    // Three openings are owed from the start, so the first three land; the
    // fourth is bought.
    for (final n in ['Cooking', 'Sailing', 'Rowing']) {
      expect(await repo.addField(n), isNotNull, reason: n);
    }
    expect(await repo.fieldOpeningsLeft(), 0);
    expect(await repo.addField('Chess'), isNull, reason: 'nothing in the balance');

    await repo.saveProgress(
        (await repo.loadProgress()).copyWith(seeds: realmUnlockCost));
    final more = await repo.addField('Chess');
    expect(more, isNotNull);
    expect(more!.unlocked, isTrue);

    // The same name again is the same field, and needs no room.
    final again = await repo.addField('cooking');
    expect(again?.label, 'Cooking');
    expect((await repo.realms()).where((r) => r.normKeyValue == 'cooking'), hasLength(1));
  });

  test('three open at the start, and the fourth is paid for', () async {
    for (final n in ['A', 'B', 'C', 'D']) {
      await db.into(db.realms).insertOnConflictUpdate(realmToRow(realm(n).copyWith(unlocked: false)));
    }
    expect(await repo.fieldOpeningsLeft(), freeRealmSlots);
    expect(await repo.openField('A'), isTrue);
    expect(await repo.openField('B'), isTrue);
    expect(await repo.openField('C'), isTrue);
    expect(await repo.fieldOpeningsLeft(), 0);

    // The fourth needs Seeds, and a short balance opens nothing.
    expect(await repo.openField('D'), isFalse);
    expect((await repo.realms()).where((r) => r.unlocked), hasLength(3));

    await repo.saveProgress(
        (await repo.loadProgress()).copyWith(seeds: realmUnlockCost));
    expect(await repo.openField('D'), isTrue);
    expect((await repo.loadProgress()).seeds, 0, reason: 'and it was spent');
    expect(await repo.openField('D'), isTrue, reason: 'already open, nothing owed');
  });

  test('what is already open is counted, so nothing is owed twice', () async {
    // Two fields open, one not. The room left is what the ladder has earned
    // less what is standing open — read off the fields themselves, so it
    // cannot drift.
    for (final n in ['A', 'B']) {
      await db.into(db.realms).insertOnConflictUpdate(realmToRow(realm(n)));
    }
    await db.into(db.realms).insertOnConflictUpdate(realmToRow(realm('C').copyWith(unlocked: false)));
    expect(await repo.fieldOpeningsLeft(), freeRealmSlots - 2);
    expect(await repo.openField('C'), isTrue);
    expect(await repo.fieldOpeningsLeft(), 0);
  });

  test('the prompt names the field the scenes are for', () async {
    final realm = (await repo.addField('Cooking'))!;
    final work = await repo.scenesPromptText(uiLanguage: 'en', field: 'work');
    expect(work, contains('This set is about: English at work'));
    final cooking = await repo.scenesPromptText(uiLanguage: 'en', field: realm.id);
    expect(cooking, contains('This set is about: Cooking'));
    final none = await repo.scenesPromptText(uiLanguage: 'en');
    expect(none, isNot(contains('This set is about')));
  });

  test('the feedback prompt carries the field, the score and what was missed', () async {
    await repo.importScenes(pack([scene('Stay late')]), uiLanguage: 'en', field: 'work');
    final sc = (await repo.scenes()).single;
    await repo.recordTurn(sceneId: sc.id, turn: 0, correct: false);
    await repo.recordTurn(sceneId: sc.id, turn: 1, correct: true);

    final text = await repo.feedbackPromptText(
        uiLanguage: 'en', fieldId: 'work', fieldLabel: 'English at work');
    expect(text, contains('"English at work"'));
    expect(text, contains('conversations finished: 1'));
    expect(text, contains('chose the right reply: 50%'));
    expect(text, contains('got it on the first hearing, inside the window: 50%'));
    expect(text, contains('missed: the line as a whole'));
    expect(text, contains(sc.turns[0].line));
    // Nothing to import comes back, so the reply is asked for as prose.
    expect(text, contains('No JSON'));

    // A field with nothing answered has nothing to say about it.
    final empty = await repo.feedbackPromptText(
        uiLanguage: 'en', fieldId: 'travel', fieldLabel: 'Travel');
    expect(empty, contains('(nothing missed)'));
    expect(empty, contains('conversations finished: 0'));
  });

  test('deleting a field takes its conversations and the record of them', () async {
    final mine = (await repo.addField('Cooking'))!;
    await repo.importScenes(pack([scene('Stew')]), uiLanguage: 'en', field: mine.id);
    await repo.importScenes(pack([scene('Standup')]), uiLanguage: 'en', field: 'work');
    final here = (await repo.scenes()).firstWhere((s) => fieldOf(s) == mine.id);
    await repo.recordTurn(sceneId: here.id, turn: 0, correct: false);
    expect(await repo.turnResults(), isNotEmpty);
    expect(await repo.reviews(), isNotEmpty);

    // The plan says what is about to go, in the terms the app now uses.
    expect((await repo.planFieldClear(mine.id)).scenes, 1);

    await repo.clearField(mine.id, closeField: true);
    final left = await repo.scenes();
    expect(left.map((s) => fieldOf(s)), everyElement('work'));
    expect(await repo.turnResults(), isEmpty);
    expect(await repo.reviews(), isEmpty);
    // The field is closed rather than destroyed: it goes back to the list it
    // came off, where it can be opened again.
    final after = (await repo.realms()).firstWhere((r) => r.id == mine.id);
    expect(after.unlocked, isFalse);
    expect(lockedFieldsFrom(await repo.realms(), (id) => id).map((f) => f.id),
        contains(mine.id));
  });

  test('deleting every conversation takes the answers to them too', () async {
    await repo.importScenes(pack([scene('Standup')]), uiLanguage: 'en', field: 'work');
    final sc = (await repo.scenes()).single;
    await repo.recordTurn(sceneId: sc.id, turn: 0, correct: false);

    await repo.clearEveryField();
    expect(await repo.scenes(), isEmpty);
    // A grown tree and a full record with nothing behind them is the bug.
    expect(await repo.turnResults(), isEmpty);
    expect(await repo.reviews(), isEmpty);
  });

  test('a progress reset does not hand back the fields already opened for nothing',
      () async {
    for (final n in ['A', 'B', 'C']) {
      await db.into(db.realms).insertOnConflictUpdate(
          realmToRow(realm(n).copyWith(unlocked: false)));
    }
    expect(await repo.openField('A'), isTrue);
    expect(await repo.openField('B'), isTrue);
    expect(await repo.fieldOpeningsLeft(), freeRealmSlots - 2);

    await repo.forgetAnswers();
    // The streak and the ladder go. The two fields stay open: the ladder
    // that opened them is being forgotten as well, and shutting a field
    // somebody is in the middle of would punish them for tidying up.
    expect((await repo.loadProgress()).streak, 0);
    expect(await repo.fieldOpeningsLeft(), freeRealmSlots - 2);
    expect((await repo.realms()).where((r) => r.unlocked), hasLength(2));
  });

  test('clearing the profile gives the starting fields back', () async {
    await repo.importProfile(profileJson(['Nursing', 'Cycling']), uiLanguage: 'en');
    await repo.chooseFields([for (final r in await repo.realms()) r.id]);
    expect(await repo.fieldOpeningsLeft(), freeRealmSlots - 2);

    await repo.resetProfileAndFields();
    expect(await repo.realms(), isEmpty);
    // The next profile must not arrive with its fields already priced.
    expect(await repo.fieldOpeningsLeft(), freeRealmSlots);
  });

  test('deleting every field gives the starting openings back', () async {
    await repo.importProfile(profileJson(['Nursing', 'Cycling']), uiLanguage: 'en');
    final ids = [for (final r in await repo.realms()) r.id];
    await repo.chooseFields(ids);
    expect(await repo.fieldOpeningsLeft(), freeRealmSlots - 2);

    await repo.clearField(ids.first, closeField: true);
    expect(await repo.fieldOpeningsLeft(), freeRealmSlots - 1);
    await repo.clearField(ids.last, closeField: true);
    // Nothing is open, so nothing has been opened: the three are owed again,
    // and both fields are still on the list to be opened with.
    expect((await repo.realms()).where((r) => r.unlocked), isEmpty);
    expect(lockedFieldsFrom(await repo.realms(), (id) => id), hasLength(2));
    expect(await repo.fieldOpeningsLeft(), freeRealmSlots);
  });
}
