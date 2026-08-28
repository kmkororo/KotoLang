/// Local storage. SQLite via Drift.
///
/// Chosen over a key-value store because the data genuinely grows and is
/// genuinely relational: sentences belong to realms, questions to sentences,
/// review state to learning items, and the session planner queries across all
/// of them by due date. Drift also gives an explicit migration path, which
/// matters for an app whose only backup is the user's own export.
///
/// List-valued fields (option arrays, id lists) are stored as JSON text rather
/// than in join tables. They are always read and written whole, never queried
/// across, so a join table would add schema surface without buying anything.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../core/util.dart';
import '../domain/models.dart' as m;

part 'database.g.dart';

// ---------------------------------------------------------------- converters

class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();
  @override
  List<String> fromSql(String fromDb) {
    if (fromDb.isEmpty) return const [];
    final decoded = jsonDecode(fromDb);
    return decoded is List ? decoded.cast<String>() : const [];
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

// ------------------------------------------------------------------- tables

@DataClassName('RealmRow')
class Realms extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get nameNative => text().withDefault(const Constant(''))();
  TextColumn get normKeyValue => text()();
  IntColumn get importance => integer().withDefault(const Constant(3))();
  RealColumn get confidence => real().withDefault(const Constant(0.5))();
  TextColumn get contexts => text().withDefault(const Constant('[]')).map(const StringListConverter())();
  BoolColumn get selected => boolean().withDefault(const Constant(false))();
  BoolColumn get hasMaterial => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  // Added in schema 3. Defaults false so the migration can grandfather
  // existing realms in explicitly rather than unlocking everything for free.
  BoolColumn get unlocked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ItemRow')
class Items extends Table {
  TextColumn get id => text()();
  // Named `phrase` because a getter called `text` would shadow Table.text().
  TextColumn get phrase => text().named('text')();
  TextColumn get normKeyValue => text()();
  TextColumn get type => text().withDefault(const Constant('term'))();
  TextColumn get meaningNative => text().withDefault(const Constant(''))();
  IntColumn get priority => integer().withDefault(const Constant(3))();
  RealColumn get confidence => real().withDefault(const Constant(0.7))();
  TextColumn get relatedTerms => text().withDefault(const Constant('[]')).map(const StringListConverter())();
  TextColumn get contexts => text().withDefault(const Constant('[]')).map(const StringListConverter())();
  TextColumn get distractorsNative => text().withDefault(const Constant('[]')).map(const StringListConverter())();
  TextColumn get realmIds => text().withDefault(const Constant('[]')).map(const StringListConverter())();
  BoolColumn get disabled => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SentenceRow')
class Sentences extends Table {
  TextColumn get id => text()();
  TextColumn get body => text().named('text')();
  TextColumn get normKeyValue => text()();
  TextColumn get translationNative => text().withDefault(const Constant(''))();
  TextColumn get level => text().withDefault(const Constant('B1'))();
  TextColumn get context => text().withDefault(const Constant(''))();
  TextColumn get speechAct => text().withDefault(const Constant('statement'))();
  IntColumn get naturalness => integer().withDefault(const Constant(4))();
  IntColumn get quality => integer().nullable()();
  TextColumn get realmId => text()();
  TextColumn get itemIds => text().withDefault(const Constant('[]')).map(const StringListConverter())();
  TextColumn get meaningOptionsNative => text().withDefault(const Constant('[]')).map(const StringListConverter())();
  TextColumn get paraphraseEn => text().withDefault(const Constant(''))();
  TextColumn get paraphraseOptionsEn => text().withDefault(const Constant('[]')).map(const StringListConverter())();
  // Added in schema 2, for the conversation formats. All defaulted, so
  // material imported before then simply generates fewer question types.
  TextColumn get cueEn => text().withDefault(const Constant(''))();
  TextColumn get cueTranslationNative => text().withDefault(const Constant(''))();
  TextColumn get replyDistractorsEn => text().withDefault(const Constant('[]')).map(const StringListConverter())();
  TextColumn get registerSituationNative => text().withDefault(const Constant(''))();
  TextColumn get registerOptionsEn => text().withDefault(const Constant('[]')).map(const StringListConverter())();
  TextColumn get registerWhyNative => text().withDefault(const Constant('[]')).map(const StringListConverter())();
  IntColumn get registerCorrect => integer().withDefault(const Constant(-1))();
  BoolColumn get disabled => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('QuestionRow')
class Questions extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get sentenceId => text()();
  TextColumn get realmId => text()();
  TextColumn get itemId => text().nullable()();
  TextColumn get body => text().named('text')();
  TextColumn get translationNative => text().withDefault(const Constant(''))();
  TextColumn get level => text().withDefault(const Constant('B1'))();
  TextColumn get context => text().withDefault(const Constant(''))();
  TextColumn get options => text().withDefault(const Constant('[]')).map(const StringListConverter())();
  IntColumn get correct => integer().withDefault(const Constant(-1))();
  TextColumn get before => text().withDefault(const Constant(''))();
  TextColumn get after => text().withDefault(const Constant(''))();
  TextColumn get answerWords => text().withDefault(const Constant('[]')).map(const StringListConverter())();
  TextColumn get bankPool => text().withDefault(const Constant('[]')).map(const StringListConverter())();
  TextColumn get tokens => text().withDefault(const Constant('[]')).map(const StringListConverter())();
  TextColumn get finalPunct => text().withDefault(const Constant(''))();
  // Added in schema 2.
  TextColumn get cueText => text().withDefault(const Constant(''))();
  TextColumn get cueTranslationNative => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get answerText => text().withDefault(const Constant(''))();
  BoolColumn get disabled => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SrsRow')
class SrsStates extends Table {
  TextColumn get itemId => text()();
  IntColumn get box => integer().withDefault(const Constant(0))();
  TextColumn get due => text()();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();
  TextColumn get lastResult => text().nullable()();
  TextColumn get lastSeen => text().nullable()();
  BoolColumn get introduced => boolean().withDefault(const Constant(false))();
  BoolColumn get heldByGate => boolean().withDefault(const Constant(false))();
  TextColumn get lastSentenceId => text().nullable()();
  /// `{"gist":{"n":1,"ok":1}, ...}` — read and written as a unit.
  TextColumn get formats => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {itemId};
}

@DataClassName('QuestionStatRow')
class QuestionStats extends Table {
  TextColumn get questionId => text()();
  IntColumn get n => integer().withDefault(const Constant(0))();
  IntColumn get ok => integer().withDefault(const Constant(0))();
  IntColumn get lastAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {questionId};
}

@DataClassName('HistoryRow')
class Histories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get day => text()();
  IntColumn get at => integer()();
  TextColumn get questionId => text()();
  TextColumn get itemId => text().nullable()();
  TextColumn get realmId => text()();
  TextColumn get type => text()();
  BoolColumn get correct => boolean()();
  BoolColumn get wasDue => boolean()();
}

@DataClassName('BatchRow')
class Batches extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get realmId => text().nullable()();
  TextColumn get promptVersion => text().withDefault(const Constant(''))();
  TextColumn get language => text().withDefault(const Constant(''))();
  IntColumn get at => integer()();
  TextColumn get counts => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Single-row-per-key store for settings, profile and progress.
@DataClassName('MetaRow')
class Meta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ----------------------------------------------------------------- database

@DriftDatabase(tables: [
  Realms,
  Items,
  Sentences,
  Questions,
  SrsStates,
  QuestionStats,
  Histories,
  Batches,
  Meta,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'kotolang'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (mig) async {
          await mig.createAll();
          await _createIndexes();
        },
        onUpgrade: (mig, from, to) async {
          // 1 -> 2 adds the columns the conversation formats need. Every one
          // has a default, so existing rows stay valid and material imported
          // under schema 1 keeps working — it just yields fewer formats.
          if (from < 2) {
            for (final column in [
              sentences.cueEn,
              sentences.cueTranslationNative,
              sentences.replyDistractorsEn,
              sentences.registerSituationNative,
              sentences.registerOptionsEn,
              sentences.registerWhyNative,
              sentences.registerCorrect,
            ]) {
              await mig.addColumn(sentences, column);
            }
            for (final column in [
              questions.cueText,
              questions.cueTranslationNative,
              questions.note,
            ]) {
              await mig.addColumn(questions, column);
            }
          }
          // 2 -> 3 adds Koto Coin realm unlocking. A realm the learner has
          // already built or explicitly selected is grandfathered in as
          // unlocked — nobody who already invested in a realm should be asked
          // to pay for it retroactively. Anything else defaults to locked,
          // which is the correct state for a realm the AI merely suggested
          // during profile import but the learner never touched.
          if (from < 3) {
            await mig.addColumn(realms, realms.unlocked);
            await customStatement(
              'UPDATE realms SET unlocked = 1 WHERE has_material = 1 OR selected = 1',
            );
          }
          await _createIndexes();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// The planner filters questions by realm and joins them to sentences and
  /// review state on every session, so those paths are indexed.
  Future<void> _createIndexes() async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS idx_sentences_realm ON sentences (realm_id)',
      'CREATE INDEX IF NOT EXISTS idx_sentences_key ON sentences (norm_key_value)',
      'CREATE INDEX IF NOT EXISTS idx_questions_sentence ON questions (sentence_id)',
      'CREATE INDEX IF NOT EXISTS idx_questions_realm ON questions (realm_id)',
      'CREATE INDEX IF NOT EXISTS idx_questions_item ON questions (item_id)',
      'CREATE INDEX IF NOT EXISTS idx_questions_type ON questions (type)',
      'CREATE INDEX IF NOT EXISTS idx_items_key ON items (norm_key_value)',
      'CREATE INDEX IF NOT EXISTS idx_srs_due ON srs_states (due)',
      'CREATE INDEX IF NOT EXISTS idx_history_day ON histories (day)',
    ];
    for (final s in statements) {
      await customStatement(s);
    }
  }
}

// ------------------------------------------------------------------ mapping
// Row <-> domain entity. Kept here so nothing outside this file sees Drift.
// The generated row classes are named explicitly (RealmRow, SentenceRow, ...)
// because Drift's defaults would collide with the domain entities.

extension RealmRowX on RealmRow {
  m.Realm toDomain() => m.Realm(
        id: id,
        name: name,
        nameNative: nameNative,
        normKeyValue: normKeyValue,
        importance: importance,
        confidence: confidence,
        contexts: contexts,
        selected: selected,
        hasMaterial: hasMaterial,
        unlocked: unlocked,
      );
}

RealmsCompanion realmToRow(m.Realm r) => RealmsCompanion.insert(
      id: r.id,
      name: r.name,
      nameNative: Value(r.nameNative),
      normKeyValue: r.normKeyValue,
      importance: Value(r.importance),
      confidence: Value(r.confidence),
      contexts: Value(r.contexts),
      selected: Value(r.selected),
      hasMaterial: Value(r.hasMaterial),
      unlocked: Value(r.unlocked),
    );

extension ItemRowX on ItemRow {
  m.LearningItem toDomain() => m.LearningItem(
        id: id,
        text: phrase,
        normKeyValue: normKeyValue,
        type: type,
        meaningNative: meaningNative,
        priority: priority,
        confidence: confidence,
        relatedTerms: relatedTerms,
        contexts: contexts,
        distractorsNative: distractorsNative,
        realmIds: realmIds,
        disabled: disabled,
      );
}

ItemsCompanion itemToRow(m.LearningItem i) => ItemsCompanion.insert(
      id: i.id,
      phrase: i.text,
      normKeyValue: i.normKeyValue,
      type: Value(i.type),
      meaningNative: Value(i.meaningNative),
      priority: Value(i.priority),
      confidence: Value(i.confidence),
      relatedTerms: Value(i.relatedTerms),
      contexts: Value(i.contexts),
      distractorsNative: Value(i.distractorsNative),
      realmIds: Value(i.realmIds),
      disabled: Value(i.disabled),
    );

extension SentenceRowX on SentenceRow {
  m.Sentence toDomain() => m.Sentence(
        id: id,
        text: body,
        normKeyValue: normKeyValue,
        translationNative: translationNative,
        level: level,
        context: context,
        speechAct: speechAct,
        naturalness: naturalness,
        quality: quality,
        realmId: realmId,
        itemIds: itemIds,
        meaningOptionsNative: meaningOptionsNative,
        paraphraseEn: paraphraseEn,
        paraphraseOptionsEn: paraphraseOptionsEn,
        cueEn: cueEn,
        cueTranslationNative: cueTranslationNative,
        replyDistractorsEn: replyDistractorsEn,
        registerSituationNative: registerSituationNative,
        registerOptionsEn: registerOptionsEn,
        registerWhyNative: registerWhyNative,
        registerCorrect: registerCorrect,
        disabled: disabled,
      );
}

SentencesCompanion sentenceToRow(m.Sentence s) => SentencesCompanion.insert(
      id: s.id,
      body: s.text,
      normKeyValue: s.normKeyValue,
      translationNative: Value(s.translationNative),
      level: Value(s.level),
      context: Value(s.context),
      speechAct: Value(s.speechAct),
      naturalness: Value(s.naturalness),
      quality: Value(s.quality),
      realmId: s.realmId,
      itemIds: Value(s.itemIds),
      meaningOptionsNative: Value(s.meaningOptionsNative),
      paraphraseEn: Value(s.paraphraseEn),
      paraphraseOptionsEn: Value(s.paraphraseOptionsEn),
      cueEn: Value(s.cueEn),
      cueTranslationNative: Value(s.cueTranslationNative),
      replyDistractorsEn: Value(s.replyDistractorsEn),
      registerSituationNative: Value(s.registerSituationNative),
      registerOptionsEn: Value(s.registerOptionsEn),
      registerWhyNative: Value(s.registerWhyNative),
      registerCorrect: Value(s.registerCorrect),
      disabled: Value(s.disabled),
    );

extension QuestionRowX on QuestionRow {
  m.Question toDomain() => m.Question(
        id: id,
        type: m.QuestionType.parse(type) ?? m.QuestionType.gist,
        sentenceId: sentenceId,
        realmId: realmId,
        itemId: itemId,
        text: body,
        translationNative: translationNative,
        level: level,
        context: context,
        options: options,
        correct: correct,
        before: before,
        after: after,
        answerWords: answerWords,
        bankPool: bankPool,
        tokens: tokens,
        finalPunct: finalPunct,
        cueText: cueText,
        cueTranslationNative: cueTranslationNative,
        note: note,
        answerText: answerText,
        disabled: disabled,
      );
}

QuestionsCompanion questionToRow(m.Question q) => QuestionsCompanion.insert(
      id: q.id,
      type: q.type.name,
      sentenceId: q.sentenceId,
      realmId: q.realmId,
      itemId: Value(q.itemId),
      body: q.text,
      translationNative: Value(q.translationNative),
      level: Value(q.level),
      context: Value(q.context),
      options: Value(q.options),
      correct: Value(q.correct),
      before: Value(q.before),
      after: Value(q.after),
      answerWords: Value(q.answerWords),
      bankPool: Value(q.bankPool),
      tokens: Value(q.tokens),
      finalPunct: Value(q.finalPunct),
      cueText: Value(q.cueText),
      cueTranslationNative: Value(q.cueTranslationNative),
      note: Value(q.note),
      answerText: Value(q.answerText),
      disabled: Value(q.disabled),
    );

extension SrsRowX on SrsRow {
  m.SrsState toDomain() {
    final decoded = jsonDecode(formats);
    final map = <m.QuestionType, m.FormatStat>{};
    if (decoded is Map) {
      decoded.forEach((k, v) {
        final t = m.QuestionType.parse('$k');
        if (t != null && v is Map) {
          map[t] = m.FormatStat.fromJson(Map<String, dynamic>.from(v));
        }
      });
    }
    return m.SrsState(
      itemId: itemId,
      box: box,
      due: due,
      reps: reps,
      lapses: lapses,
      lastResult: lastResult,
      lastSeen: lastSeen,
      introduced: introduced,
      heldByGate: heldByGate,
      lastSentenceId: lastSentenceId,
      formats: map,
    );
  }
}

SrsStatesCompanion srsToRow(m.SrsState s) => SrsStatesCompanion.insert(
      itemId: s.itemId,
      box: Value(s.box),
      due: s.due,
      reps: Value(s.reps),
      lapses: Value(s.lapses),
      lastResult: Value(s.lastResult),
      lastSeen: Value(s.lastSeen),
      introduced: Value(s.introduced),
      heldByGate: Value(s.heldByGate),
      lastSentenceId: Value(s.lastSentenceId),
      formats: Value(jsonEncode({
        for (final e in s.formats.entries) e.key.name: e.value.toJson(),
      })),
    );

extension HistoryRowX on HistoryRow {
  m.HistoryEntry toDomain() => m.HistoryEntry(
        id: id,
        day: day,
        at: DateTime.fromMillisecondsSinceEpoch(at),
        questionId: questionId,
        itemId: itemId,
        realmId: realmId,
        type: m.QuestionType.parse(type) ?? m.QuestionType.gist,
        correct: correct,
        wasDue: wasDue,
      );
}

HistoriesCompanion historyToRow(m.HistoryEntry h) => HistoriesCompanion.insert(
      day: h.day,
      at: h.at.millisecondsSinceEpoch,
      questionId: h.questionId,
      itemId: Value(h.itemId),
      realmId: h.realmId,
      type: h.type.name,
      correct: h.correct,
      wasDue: h.wasDue,
    );

/// Convenience for import batches and reset flows.
String newBatchId() => uid('batch');
