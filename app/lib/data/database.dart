/// Local storage. SQLite via Drift.
///
/// Five tables hold everything: the fields the AI read off the profile, the
/// conversations, what was answered, what is owed another look, and a
/// key-value shelf for the settings, the profile, the progress and the
/// ladder. Nothing here leaves the phone.
///
/// List-valued fields are stored as JSON text rather than in join tables.
/// They are always read and written whole, never queried across, so a join
/// table would add schema surface without buying anything. The same goes for
/// a conversation's turns: a conversation is read as one unit and walked in
/// order, never queried turn by turn.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../core/util.dart';
import '../domain/scene.dart' as sc;
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

/// A field the AI read off the learner's profile. It exists as a row long
/// before it is open: that is what lets it be listed and opened later without
/// running the profile import again.
@DataClassName('RealmRow')
class Realms extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get nameNative => text().withDefault(const Constant(''))();
  TextColumn get normKeyValue => text()();
  IntColumn get importance => integer().withDefault(const Constant(3))();
  RealColumn get confidence => real().withDefault(const Constant(0.5))();
  TextColumn get contexts =>
      text().withDefault(const Constant('[]')).map(const StringListConverter())();
  BoolColumn get selected => boolean().withDefault(const Constant(false))();
  BoolColumn get hasMaterial => boolean().withDefault(const Constant(false))();
  BoolColumn get unlocked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One conversation. The turns are JSON in the row: a conversation is played
/// from the first line to the last and never asked about a turn at a time.
@DataClassName('SceneRow')
class Scenes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get titleNative => text().withDefault(const Constant(''))();

  /// The situation inside a field — "meetings" inside "work". What opens as
  /// the ladder is climbed.
  TextColumn get situation => text().withDefault(const Constant(''))();
  TextColumn get settingNative => text().withDefault(const Constant(''))();

  /// How long the reply window stays open here. Carried per conversation
  /// because the gap between turns is part of what is being practised.
  IntColumn get windowMs => integer().withDefault(const Constant(sc.defaultWindowMs))();

  TextColumn get turns => text()();

  /// 'ai' for conversations the learner's own AI made. Built-ins never sit
  /// here — they ship with the app.
  TextColumn get source => text().withDefault(const Constant('ai'))();
  TextColumn get realmId => text().nullable()();
  IntColumn get createdAt => integer()();
  BoolColumn get disabled => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One turn answered.
@DataClassName('TurnResultRow')
class SceneResults extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sceneId => text()();
  IntColumn get turn => integer()();
  BoolColumn get correct => boolean()();

  /// For a missed multiFact turn: the fact that was dropped, so the same
  /// weakness can be found again.
  TextColumn get missedSlot => text().nullable()();

  /// Answered inside the window, without waiting to be told again. Keeping up
  /// at conversation speed is only claimed when this is true.
  BoolColumn get inWindow => boolean().withDefault(const Constant(true))();

  /// Came up as a review rather than inside its conversation.
  BoolColumn get review => boolean().withDefault(const Constant(false))();
  TextColumn get day => text()();
  IntColumn get at => integer()();
}

/// A turn that was missed and is owed another look: the next day, then three
/// days on, then gone.
@DataClassName('ReviewRow')
class Reviews extends Table {
  TextColumn get sceneId => text()();
  IntColumn get turn => integer()();
  TextColumn get dueDay => text()();
  IntColumn get stage => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {sceneId, turn};
}

/// Single-row-per-key store for the settings, the profile, the progress and
/// the ladder.
@DataClassName('MetaRow')
class Meta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ----------------------------------------------------------------- database

@DriftDatabase(tables: [Realms, Scenes, SceneResults, Reviews, Meta])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'kotolang'));

  /// Six is the first schema of the listening app as it now is. Everything
  /// before it belonged to a way of studying this app no longer has — decks
  /// of sentences, generated question formats, a debate gym — and none of it
  /// can be carried across, since a conversation in the old shape has no
  /// turns to play.
  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (mig) async {
          await mig.createAll();
          await _createIndexes();
        },
        onUpgrade: (mig, from, to) async {
          // Nothing from before survives, so rather than a chain of
          // alterations the old shape is dropped whole and the new one built
          // fresh. The learner is told what this costs before it happens.
          for (final name in _retired) {
            await customStatement('DROP TABLE IF EXISTS $name');
          }
          for (final t in allTables) {
            await customStatement('DROP TABLE IF EXISTS ${t.actualTableName}');
          }
          await mig.createAll();
          await _createIndexes();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          if (details.wasCreated || details.hadUpgrade) await _createIndexes();
        },
      );

  /// Tables from the study model this app no longer uses. Named here only so
  /// that a phone upgrading from it is left with nothing behind.
  static const _retired = [
    'items',
    'sentences',
    'questions',
    'srs_states',
    'question_stats',
    'histories',
    'batches',
    'chunks',
    'debates',
    'attempts',
    'captures',
    'failures',
  ];

  Future<void> _createIndexes() async {
    const statements = [
      // Every result is read for the record; the day's and the conversation's
      // are asked for directly. Reviews are looked up by what is due.
      'CREATE INDEX IF NOT EXISTS idx_scene_results_scene ON scene_results (scene_id)',
      'CREATE INDEX IF NOT EXISTS idx_scene_results_day ON scene_results (day)',
      'CREATE INDEX IF NOT EXISTS idx_reviews_due ON reviews (due_day)',
      'CREATE INDEX IF NOT EXISTS idx_scenes_realm ON scenes (realm_id)',
      'CREATE INDEX IF NOT EXISTS idx_scenes_situation ON scenes (situation)',
    ];
    for (final s in statements) {
      await customStatement(s);
    }
  }
}

// ------------------------------------------------------------- rows to domain

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

extension SceneRowX on SceneRow {
  sc.Scene toDomain() {
    final decoded = jsonDecode(turns);
    return sc.Scene(
      id: id,
      title: title,
      titleNative: titleNative,
      situation: situation,
      settingNative: settingNative,
      windowMs: windowMs,
      turns: [
        if (decoded is List)
          for (final t in decoded)
            if (t is Map) sc.Turn.fromJson(Map<String, dynamic>.from(t))
      ],
      source: sc.SceneSource.parse(source),
      realmId: realmId,
      createdAt: createdAt,
      disabled: disabled,
    );
  }
}

ScenesCompanion sceneToRow(sc.Scene s) => ScenesCompanion.insert(
      id: s.id,
      title: s.title,
      titleNative: Value(s.titleNative),
      situation: Value(s.situation),
      settingNative: Value(s.settingNative),
      windowMs: Value(s.windowMs),
      turns: jsonEncode([for (final t in s.turns) t.toJson()]),
      source: Value(s.source.name),
      realmId: Value(s.realmId),
      createdAt: s.createdAt,
      disabled: Value(s.disabled),
    );

extension TurnResultRowX on TurnResultRow {
  sc.TurnResult toDomain() => sc.TurnResult(
        sceneId: sceneId,
        turn: turn,
        correct: correct,
        missedSlot: missedSlot,
        inWindow: inWindow,
        review: review,
        day: day,
        at: at,
      );
}

SceneResultsCompanion turnResultToRow(sc.TurnResult r) => SceneResultsCompanion.insert(
      sceneId: r.sceneId,
      turn: r.turn,
      correct: r.correct,
      missedSlot: Value(r.missedSlot),
      inWindow: Value(r.inWindow),
      review: Value(r.review),
      day: r.day,
      at: r.at,
    );

extension ReviewRowX on ReviewRow {
  sc.ReviewItem toDomain() =>
      sc.ReviewItem(sceneId: sceneId, turn: turn, dueDay: dueDay, stage: stage);
}

/// Convenience for anything that needs a fresh id.
String newBatchId() => uid('batch');
