/// Not a test of the app: a way to produce a backup file for hand-testing on
/// a device, using the same seeding the suite already uses.
///
///   flutter test test/make_fixture_test.dart
///
/// writes `build/fixture-backup.json`, which "Import data" on a device will
/// restore. Kept beside the tests so it cannot drift from the real schema.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotolang/core/util.dart';
import 'package:kotolang/data/database.dart';
import 'package:kotolang/data/repository.dart';
import 'package:kotolang/domain/models.dart';
import 'package:kotolang/domain/srs.dart' show maxBox;

import 'repository_test.dart' show materialJson, profileJson;

void main() {
  test('write a seeded database for device testing', () async {
    // A ready-made kotolang.sqlite, so a device can be put into a realistic
    // state without pasting a multi-kilobyte AI reply through `adb input`:
    //
    //   adb push build/kotolang.sqlite /data/local/tmp/
    //   adb shell run-as com.kmkor.kotolang cp /data/local/tmp/kotolang.sqlite \
    //     app_flutter/kotolang.sqlite
    final file = File('build/kotolang.sqlite');
    await file.parent.create(recursive: true);
    if (await file.exists()) await file.delete();

    final seeded = AppDatabase(NativeDatabase(file));
    final seedRepo = Repository(seeded, rng: Random(7));
    await seedRepo.saveUiLanguage('ja');
    await seedRepo.importProfile(
        profileJson(['Work', 'Travel', 'Music']), uiLanguage: 'ja');
    await seedRepo.markRealmsUnlocked(
        (await seedRepo.realms()).map((r) => r.id).toList());
    await seedRepo.importMaterial(
      materialJson(realm: 'Work', terms: [
        ('repair policy', '修理の方針'),
        ('delivery date', '納期'),
        ('damage tolerance', '損傷許容'),
      ], sentencesPerTerm: 3),
      uiLanguage: 'ja',
    );
    // A second area, so the tree has more than one bough to draw.
    await seedRepo.importMaterial(
      materialJson(realm: 'Travel', terms: [
        ('boarding pass', '搭乗券'),
        ('connecting flight', '乗り継ぎ便'),
      ], sentencesPerTerm: 3),
      uiLanguage: 'ja',
    );
    // A history to grow it from. Answered lopsidedly on purpose: an even tree
    // would not show that neglecting an area is visible in its shape.
    final answered = await seedRepo.questions();
    for (final q in answered.where((q) => q.realmId == answered.first.realmId).take(24)) {
      await seedRepo.recordAnswer(question: q, correct: true, wasDue: false);
    }
    for (final q in answered.where((q) => q.realmId != answered.first.realmId).take(4)) {
      await seedRepo.recordAnswer(question: q, correct: true, wasDue: false);
    }
    // One expression left one step below the line, with a record of repeated
    // failures behind it, so the next correct answer on the device shows the
    // breakthrough celebration without having to fail it by hand first.
    final items = await seedRepo.items();
    await seeded.into(seeded.srsStates).insertOnConflictUpdate(srsToRow(SrsState(
          itemId: items.first.id,
          due: today(),
          box: 3,
          reps: 9,
          lapses: 3,
          introduced: true,
          formats: const {QuestionType.produce: FormatStat(n: 2, ok: 1)},
        )));
    // And one a single correct answer away from its next stage, so the growth
    // banner can be seen too.
    await seeded.into(seeded.srsStates).insertOnConflictUpdate(srsToRow(SrsState(
          itemId: items[1].id,
          due: today(),
          box: 1,
          reps: 2,
          introduced: true,
        )));
    // A few expressions carried all the way to the top box, so the tree can be
    // seen bearing fruit without waiting out the real schedule — which takes
    // sixty-odd days per expression.
    for (final item in items.take(3)) {
      await seeded.into(seeded.srsStates).insertOnConflictUpdate(srsToRow(SrsState(
            itemId: item.id,
            due: addDays(today(), 30),
            box: maxBox,
            reps: 14,
            introduced: true,
            formats: const {QuestionType.produce: FormatStat(n: 3, ok: 3)},
          )));
    }
    await seedRepo.saveProgress(const Progress(seeds: 150, streak: 2));
    expect((await seedRepo.counts()).questions, greaterThan(5));
    await seeded.close();

    final db = AppDatabase(NativeDatabase.memory());
    final repo = Repository(db, rng: Random(7));
    addTearDown(db.close);

    await repo.saveUiLanguage('ja');
    await repo.importProfile(
        profileJson(['Work', 'Travel', 'Cooking', 'Music']),
        uiLanguage: 'ja');
    await repo.markRealmsUnlocked(
        (await repo.realms()).take(3).map((r) => r.id).toList());

    for (final realm in ['Work', 'Travel']) {
      await repo.importMaterial(
        materialJson(realm: realm, terms: [
          ('repair policy', '修理の方針'),
          ('delivery date', '納期'),
          ('damage tolerance', '損傷許容'),
        ]),
        uiLanguage: 'ja',
      );
    }
    await repo.saveProgress(const Progress(seeds: 150, streak: 2, bestStreak: 4));

    // Also the raw AI reply for one area, so a device can be seeded by
    // pasting it into the import box.
    final reply = File('build/fixture-material.json');
    await reply.parent.create(recursive: true);
    await reply.writeAsString(materialJson(
        realm: 'Work',
        terms: [('repair policy', '修理の方針')],
        sentencesPerTerm: 2));

    final out = File('build/fixture-backup.json');
    await out.parent.create(recursive: true);
    await out.writeAsString(jsonEncode(await repo.exportAll()));

    expect(await out.exists(), isTrue);
    expect((await repo.counts()).questions, greaterThan(10));
    // ignore: avoid_print
    print('fixture written to ${out.absolute.path}');
  });
}
