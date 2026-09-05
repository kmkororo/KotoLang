/// Upgrading an existing library across schema versions: 1 -> 2 -> 3 -> 4.
///
/// Someone who has been studying for months has an old database on their
/// phone, and the upgrade runs on it unattended the first time they open the
/// new build. If it goes wrong their material is gone, so it is worth
/// proving rather than assuming.
///
/// Each seed is made by building the *current* schema and taking the later
/// columns back out again, which is both faithful and impossible to let
/// drift out of step with the real table definitions — if a column is
/// renamed, these `ALTER TABLE ... DROP COLUMN` statements fail loudly
/// instead of silently seeding the wrong shape.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotolang/data/database.dart';
import 'package:kotolang/data/repository.dart';
import 'package:kotolang/domain/models.dart';

const _addedInSchema2ToSentences = [
  'cue_en',
  'cue_translation_native',
  'reply_distractors_en',
  'register_situation_native',
  'register_options_en',
  'register_why_native',
  'register_correct',
];
const _addedInSchema2ToQuestions = ['cue_text', 'cue_translation_native', 'note'];
const _addedInSchema3ToRealms = ['unlocked'];
const _addedInSchema4Tables = ['chunks', 'debates', 'attempts', 'captures', 'failures'];

void main() {
  late File file;

  setUp(() {
    final dir = Directory.systemTemp.createTempSync('kotolang-migration');
    file = File('${dir.path}/app.sqlite');
  });

  tearDown(() {
    if (file.parent.existsSync()) file.parent.deleteSync(recursive: true);
  });

  /// One area, one expression, one sentence, one answered question — enough
  /// to prove material and progress both survive an upgrade.
  Future<void> seedContent(Repository repo) async {
    await repo.saveUiLanguage('ja');
    await repo.importProfile(
      '{"schema_version":"1.0","type":"profile",'
      '"profile":{"english_level":"B2","roles":[],"learning_priorities":[]},'
      '"domains":[{"name":"Work","name_native":"仕事","importance":5}]}',
      uiLanguage: 'ja',
    );
    await repo.importMaterial(
      '{"schema_version":"1.0","type":"material","native_language":"Japanese",'
      '"domain":{"name":"Work","name_native":"仕事","importance":5},'
      '"learning_items":[{"text":"repair policy","meaning_native":"修理の方針",'
      '"distractors_native":["a","b","c"]}],'
      '"sentences":[{"text":"Please confirm the repair policy before the review.",'
      '"translation_native":"レビューの前に修理の方針を確認してください。",'
      '"targets":["repair policy"],'
      '"paraphrase_en":"Check the rules for repairs ahead of the meeting.",'
      '"paraphrase_options_en":["No need to check the rules for repairs.",'
      '"The reviewer checks the rules for repairs.",'
      '"The rules for repairs were checked already."],'
      '"meaning_options_native":["確認は不要","担当者が確認","確認済み"]}]}',
      uiLanguage: 'ja',
    );
    final q = (await repo.questions()).first;
    await repo.recordAnswer(question: q, correct: true, wasDue: false);
  }

  /// Builds a database that looks exactly like the very first release's.
  Future<void> seedSchemaOne() async {
    final db = AppDatabase(NativeDatabase(file));
    await seedContent(Repository(db));

    for (final c in _addedInSchema2ToSentences) {
      await db.customStatement('ALTER TABLE sentences DROP COLUMN $c');
    }
    for (final c in _addedInSchema2ToQuestions) {
      await db.customStatement('ALTER TABLE questions DROP COLUMN $c');
    }
    for (final c in _addedInSchema3ToRealms) {
      await db.customStatement('ALTER TABLE realms DROP COLUMN $c');
    }
    for (final t in _addedInSchema4Tables) {
      await db.customStatement('DROP TABLE $t');
    }
    await db.customStatement('PRAGMA user_version = 1');
    await db.close();
  }

  /// Builds a database shaped like the release with the conversation formats
  /// but no Koto Coin economy yet — the narrower slice schema 3 alone has to
  /// upgrade correctly.
  Future<void> seedSchemaTwo({required bool hasMaterial}) async {
    final db = AppDatabase(NativeDatabase(file));
    final repo = Repository(db);
    if (hasMaterial) {
      await seedContent(repo);
    } else {
      await repo.saveUiLanguage('ja');
    }

    for (final c in _addedInSchema3ToRealms) {
      await db.customStatement('ALTER TABLE realms DROP COLUMN $c');
    }
    for (final t in _addedInSchema4Tables) {
      await db.customStatement('DROP TABLE $t');
    }
    await db.customStatement('PRAGMA user_version = 2');
    await db.close();
  }

  /// Builds a database shaped like the release just before the debate gym:
  /// every column of today's tables, none of the five new tables.
  Future<void> seedSchemaThree() async {
    final db = AppDatabase(NativeDatabase(file));
    await seedContent(Repository(db));
    for (final t in _addedInSchema4Tables) {
      await db.customStatement('DROP TABLE $t');
    }
    await db.customStatement('PRAGMA user_version = 3');
    await db.close();
  }

  test('a schema 1 library opens, keeps its material and keeps its progress',
      () async {
    await seedSchemaOne();

    final db = AppDatabase(NativeDatabase(file));
    final repo = Repository(db);
    addTearDown(db.close);

    // Opening is what runs the migration.
    final counts = await repo.counts();
    expect(counts.realms, 1);
    expect(counts.items, 1);
    expect(counts.sentences, 1);
    expect(counts.questions, greaterThan(0));

    final sentence = (await repo.sentences()).single;
    expect(sentence.text, 'Please confirm the repair policy before the review.');
    expect(sentence.translationNative, isNotEmpty);
    expect(sentence.paraphraseEn, isNotEmpty);

    // The new columns read back as their defaults rather than as nulls.
    expect(sentence.cueEn, isEmpty);
    expect(sentence.replyDistractorsEn, isEmpty);
    expect(sentence.registerOptionsEn, isEmpty);
    expect(sentence.registerCorrect, -1);

    // What the learner had done survives.
    expect(await repo.loadUiLanguage(), 'ja');
    expect((await repo.history()).length, 1);
    expect((await repo.loadProgress()).streak, 1);
    expect(await repo.srsStates(), isNotEmpty);

    // A realm built before Koto Coin existed is grandfathered in as unlocked
    // rather than retroactively charged for.
    final realm = (await repo.realms()).single;
    expect(realm.unlocked, isTrue);
  });

  test('an upgraded library gains the formats it can build, and no others',
      () async {
    await seedSchemaOne();

    final db = AppDatabase(NativeDatabase(file));
    final repo = Repository(db);
    addTearDown(db.close);

    await repo.regenerateQuestions();
    final types = (await repo.questions()).map((q) => q.type).toSet();

    // Produce needs nothing the old material lacks, so it appears at once —
    // this is what makes the rebuild worth offering to an existing learner.
    expect(types, contains(QuestionType.produce));

    // Reply and register need fields that material predating schema 2 does
    // not have. They must stay absent rather than be invented.
    expect(types, isNot(contains(QuestionType.reply)));
    expect(types, isNot(contains(QuestionType.register)));

    // And nothing that used to work has stopped.
    expect(types, contains(QuestionType.paraphrase));
    expect(types, contains(QuestionType.gist));
    expect(types, contains(QuestionType.dictation));
    expect(types, contains(QuestionType.reorder));
  });

  test('opening twice does not try to migrate a second time', () async {
    await seedSchemaOne();

    final first = AppDatabase(NativeDatabase(file));
    expect((await Repository(first).counts()).sentences, 1);
    await first.close();

    // A second open finds user_version already at the latest schema. If any
    // migration step ran again, its ALTER statements would fail on columns
    // that already exist.
    final second = AppDatabase(NativeDatabase(file));
    addTearDown(second.close);
    expect((await Repository(second).counts()).sentences, 1);
  });

  test('a schema 2 realm with material is grandfathered as unlocked', () async {
    await seedSchemaTwo(hasMaterial: true);

    final db = AppDatabase(NativeDatabase(file));
    final repo = Repository(db);
    addTearDown(db.close);

    final realm = (await repo.realms()).single;
    expect(realm.hasMaterial, isTrue);
    expect(realm.unlocked, isTrue,
        reason: 'a realm already built must never be charged for retroactively');
  });

  test('a schema 2 realm the AI only suggested stays locked', () async {
    // A profile import creates a Realm row for every domain the AI names,
    // long before any material exists for it. Only realms actually built or
    // explicitly selected are grandfathered — an untouched suggestion is
    // exactly the kind of realm Koto Coin is meant to gate.
    final db = AppDatabase(NativeDatabase(file));
    final repo = Repository(db);
    await repo.saveUiLanguage('ja');
    await repo.importProfile(
      '{"schema_version":"1.0","type":"profile",'
      '"profile":{"english_level":"B2","roles":[],"learning_priorities":[]},'
      '"domains":[{"name":"Work","importance":5},{"name":"Travel","importance":2}]}',
      uiLanguage: 'ja',
    );
    for (final c in _addedInSchema3ToRealms) {
      await db.customStatement('ALTER TABLE realms DROP COLUMN $c');
    }
    await db.customStatement('PRAGMA user_version = 2');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final reopenedRepo = Repository(reopened);
    addTearDown(reopened.close);

    final realms = await reopenedRepo.realms();
    expect(realms, hasLength(2));
    expect(realms.every((r) => !r.hasMaterial), isTrue,
        reason: 'the fixture is only meaningful if neither realm was built');
    expect(realms.every((r) => !r.unlocked), isTrue);
  });

  test('a schema 3 library gains the debate tables and keeps everything else',
      () async {
    await seedSchemaThree();

    final reopened = AppDatabase(NativeDatabase(file));
    final repo = Repository(reopened);
    addTearDown(reopened.close);

    // Nothing the learner had is touched.
    expect((await repo.realms()).single.unlocked, isTrue);
    expect(await repo.questions(), isNotEmpty);
    expect((await repo.history()), hasLength(1));
    expect((await repo.loadProgress()).streak, 1);

    // The new tables are there, empty, and usable at once.
    for (final t in _addedInSchema4Tables) {
      final n = (await reopened
              .customSelect('SELECT COUNT(*) AS c FROM $t')
              .getSingle())
          .read<int>('c');
      expect(n, 0, reason: '$t should exist and be empty after the upgrade');
    }
    await repo.addCapture(note: 'after the upgrade');
    expect(await repo.captures(), hasLength(1));
    expect(
        (await reopened.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        4);
  });

  test('a fresh schema 4 database needs no migration at all', () async {
    final db = AppDatabase(NativeDatabase(file));
    await seedContent(Repository(db));
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final repo = Repository(reopened);
    addTearDown(reopened.close);

    // Built directly on the current schema: a realm with material is
    // unlocked because `importMaterial` marks it so, not through migration
    // grandfathering.
    expect((await repo.realms()).single.unlocked, isTrue);
    expect(await repo.debates(), isEmpty);
  });
}
