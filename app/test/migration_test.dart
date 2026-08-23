/// Upgrading an existing library from schema 1 to schema 2.
///
/// Schema 2 adds the columns the conversation formats need. Someone who has
/// been studying for months has a schema 1 database on their phone, and the
/// upgrade runs on it unattended the first time they open the new build. If it
/// goes wrong their material is gone, so it is worth proving rather than
/// assuming.
///
/// The schema 1 database is made by building schema 2 and taking the new
/// columns back out again, which is both faithful and impossible to let drift
/// out of step with the real definition.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotolang/data/database.dart';
import 'package:kotolang/data/repository.dart';
import 'package:kotolang/domain/models.dart';

const _addedToSentences = [
  'cue_en',
  'cue_translation_native',
  'reply_distractors_en',
  'register_situation_native',
  'register_options_en',
  'register_why_native',
  'register_correct',
];
const _addedToQuestions = ['cue_text', 'cue_translation_native', 'note'];

void main() {
  late File file;

  setUp(() {
    final dir = Directory.systemTemp.createTempSync('kotolang-migration');
    file = File('${dir.path}/app.sqlite');
  });

  tearDown(() {
    if (file.parent.existsSync()) file.parent.deleteSync(recursive: true);
  });

  /// Builds a database that looks exactly like the previous release's, holding
  /// one area, one expression and one sentence.
  Future<void> seedSchemaOne() async {
    final db = AppDatabase(NativeDatabase(file));
    final repo = Repository(db);

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

    // Answer something, so there is progress to lose if the upgrade goes wrong.
    final q = (await repo.questions()).first;
    await repo.recordAnswer(question: q, correct: true, wasDue: false);

    // Now wind the schema back to 1.
    for (final c in _addedToSentences) {
      await db.customStatement('ALTER TABLE sentences DROP COLUMN $c');
    }
    for (final c in _addedToQuestions) {
      await db.customStatement('ALTER TABLE questions DROP COLUMN $c');
    }
    await db.customStatement('PRAGMA user_version = 1');
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

    // A second open finds user_version already at 2. If the migration ran
    // again the ALTER statements would fail on columns that exist.
    final second = AppDatabase(NativeDatabase(file));
    addTearDown(second.close);
    expect((await Repository(second).counts()).sentences, 1);
  });
}
