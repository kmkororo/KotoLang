/// Everything the UI is allowed to ask for. Wraps the database and applies the
/// domain rules; no widget touches Drift or the scheduling maths directly.
library;

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../core/l10n/languages.dart';
import '../core/util.dart';
import '../domain/importer.dart' as imp;
import '../domain/debate.dart';
import '../domain/field.dart';
import '../domain/models.dart';
import '../domain/prompts.dart' as pr;
import '../domain/scene.dart';
import '../domain/scene_import.dart';
import '../domain/skills.dart';
import '../domain/progress_service.dart';
import '../domain/question_generator.dart' as qg;
import '../domain/srs.dart' as srs;
import 'database.dart';

// ------------------------------------------------------------------ results

class ImportOutcome {
  final bool ok;
  final List<String> errors;
  final int realms;
  final int newItems;
  final int linkedItems;
  final int newSentences;
  final int duplicateSentences;
  final int questions;
  final String? realmName;

  /// The reply stopped part-way and only what arrived before the cut was
  /// stored. Everything kept is genuine; there is simply more still missing.
  final bool partial;

  const ImportOutcome({
    required this.ok,
    this.errors = const [],
    this.realms = 0,
    this.newItems = 0,
    this.linkedItems = 0,
    this.newSentences = 0,
    this.duplicateSentences = 0,
    this.questions = 0,
    this.realmName,
    this.partial = false,
  });

  const ImportOutcome.failure(this.errors)
      : ok = false,
        realms = 0,
        newItems = 0,
        linkedItems = 0,
        newSentences = 0,
        duplicateSentences = 0,
        questions = 0,
        realmName = null,
        partial = false;
}

/// What came of importing a debate pack. Trees the importer could not make
/// sound are named, with the reason: the learner pasted them, and "3 of 4"
/// with no explanation would leave them wondering what they did wrong.
class PackOutcome {
  final bool ok;
  final List<String> errors;
  final int chunks;
  final int debates;
  final int critiques;

  /// Critiques for attempts this phone does not have â a pack pasted onto a
  /// different device, or attempts since deleted. Counted, not stored.
  final int unmatchedCritiques;
  final List<({String topic, String reason})> rejected;
  final bool partial;

  const PackOutcome({
    required this.ok,
    this.errors = const [],
    this.chunks = 0,
    this.debates = 0,
    this.critiques = 0,
    this.unmatchedCritiques = 0,
    this.rejected = const [],
    this.partial = false,
  });

  const PackOutcome.failure(this.errors)
      : ok = false,
        chunks = 0,
        debates = 0,
        critiques = 0,
        unmatchedCritiques = 0,
        rejected = const [],
        partial = false;
}

class SessionSlot {
  final Question question;
  final String? itemId;
  final bool wasDue;
  const SessionSlot(this.question, this.itemId, this.wasDue);
}

class AnswerOutcome {
  final bool correct;
  final int seeds;

  /// Set when this answer turned a struggling item around. The screen shows
  /// it; nothing else depends on it.
  final bool breakthrough;
  final StreakResult streak;
  final Progress progress;
  final SrsState? srsState;

  /// The stage this answer moved the item up to, when it moved one. Null when
  /// the item stayed where it was.
  final srs.MasteryStage? stageUp;

  /// This answer was the learner's first meeting with the expression. The
  /// reason to come back is what has not been met yet, so it is worth saying.
  final bool discovered;
  const AnswerOutcome(this.correct, this.seeds, this.streak, this.progress,
      this.srsState,
      {this.breakthrough = false, this.stageUp, this.discovered = false});
}

class HomeCounts {
  final int due;
  final int fresh;
  final int total;
  final int questions;

  /// Questions never served. `fresh` counts expressions the learner has not
  /// met; this counts the work actually left in the library, which is a much
  /// larger number â six expressions carry over a hundred questions between
  /// them. Both are shown, because meeting every expression and running out
  /// of things to answer are not the same event.
  final int unanswered;

  /// Distinct sentences available. A session prefers a fresh sentence for every
  /// slot and only doubles up once it has run out of them, so this is what
  /// decides whether a run feels varied or repetitive.
  final int sentences;
  const HomeCounts(this.due, this.fresh, this.total, this.questions,
      this.unanswered, this.sentences);
}

// --------------------------------------------------------------- repository

/// The nearest size the settings screen actually offers.
///
/// `sessionSizeAll` means "everything there is" rather than a number, so it is
/// only ever kept when it was stored deliberately â nothing snaps to it.
int _offeredSessionSize(int stored) {
  if (sessionSizes.contains(stored)) return stored;
  final numbered = sessionSizes.where((n) => n != sessionSizeAll).toList()
    ..sort();
  // Ties go to the shorter session. Someone whose stored size no longer exists
  // is better served by a run that ends early than by one that outstays.
  return numbered.reduce((a, b) =>
      (a - stored).abs() <= (b - stored).abs() ? a : b);
}


/// What came of importing a scenes reply. Scenes the importer could not make
/// sound are named, with the reason.
class SceneOutcome {
  final bool ok;
  final List<String> errors;
  final int scenes;
  final List<({String topic, String reason})> rejected;
  final bool partial;

  const SceneOutcome({
    required this.ok,
    this.errors = const [],
    this.scenes = 0,
    this.rejected = const [],
    this.partial = false,
  });

  const SceneOutcome.failure(this.errors)
      : ok = false,
        scenes = 0,
        rejected = const [],
        partial = false;
}

class Repository {
  final AppDatabase db;
  final Random? rng;

  Repository(this.db, {this.rng});

  /// How many recently served sentences stay out of rotation. Large enough that
  /// a sentence does not reappear next session, small enough that a modest
  /// library never runs dry.
  static const recentLimit = 45;

  // ------------------------------------------------------------- meta store

  Future<String?> _meta(String key) async {
    final row = await (db.select(db.meta)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _setMeta(String key, String value) =>
      db.into(db.meta).insertOnConflictUpdate(MetaCompanion.insert(key: key, value: value));

  Future<void> _delMeta(String key) =>
      (db.delete(db.meta)..where((t) => t.key.equals(key))).go();

  Future<AppSettings> loadSettings() async {
    final raw = await _meta('settings');
    if (raw == null) return const AppSettings();
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return AppSettings(
      voiceName: j['voiceName'] as String?,
      speechRate: (j['speechRate'] as num?)?.toDouble(),
      difficulty: (j['difficulty'] ?? 'hard') as String,
      inputMode: (j['inputMode'] ?? 'tap') as String,
      dailyGoal: (j['dailyGoal'] ?? 1) as int,
      theme: (j['theme'] ?? 'system') as String,
      batchSize: (j['batchSize'] ?? 'standard') as String,
      // A size bought under the old rules â sessions used to be lengthened ten
      // slots at a time, up to forty-five â is not one the settings screen can
      // offer any more. Snapped to the nearest size that is, because the
      // dropdown was showing "5" while the session still served twenty-five.
      sessionSize: _offeredSessionSize((j['sessionSize'] ?? baseSessionSize) as int),
      haptics: (j['haptics'] ?? true) as bool,
      ageBand: (j['ageBand'] ?? '') as String,
      interests: ((j['interests'] as List?) ?? const []).cast<String>(),
      tutorialDone: (j['tutorialDone'] ?? false) as bool,
      voicePerScene: (j['voicePerScene'] ?? true) as bool,
    );
  }

  Future<void> saveSettings(AppSettings s) => _setMeta(
      'settings',
      jsonEncode({
        'voiceName': s.voiceName,
        'speechRate': s.speechRate,
        'difficulty': s.difficulty,
        'inputMode': s.inputMode,
        'dailyGoal': s.dailyGoal,
        'theme': s.theme,
        'batchSize': s.batchSize,
        'sessionSize': s.sessionSize,
        'haptics': s.haptics,
        'ageBand': s.ageBand,
        'interests': s.interests,
        'tutorialDone': s.tutorialDone,
        'voicePerScene': s.voicePerScene,
      }));

  /// null until the learner has chosen one, which is what triggers the very
  /// first screen.
  Future<String?> loadUiLanguage() => _meta('uiLanguage');
  Future<void> saveUiLanguage(String code) => _setMeta('uiLanguage', code);

  Future<Progress> loadProgress() async {
    final raw = await _meta('progress');
    if (raw == null) return const Progress();
    return Progress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveProgress(Progress p) => _setMeta('progress', jsonEncode(p.toJson()));

  Future<UserProfile?> loadProfile() async {
    final raw = await _meta('profile');
    if (raw == null) return null;
    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _saveProfile(UserProfile p) => _setMeta('profile', jsonEncode(p.toJson()));

  Future<List<String>> _recentSentences() async {
    final raw = await _meta('recentSentences');
    if (raw == null) return const [];
    final d = jsonDecode(raw);
    return d is List ? d.cast<String>() : const [];
  }

  Future<void> _pushRecent(String sentenceId) async {
    final list = await _recentSentences();
    final next = [sentenceId, ...list.where((id) => id != sentenceId)];
    await _setMeta('recentSentences', jsonEncode(take(next, recentLimit)));
  }

  // ---------------------------------------------------------------- reading

  Future<List<Realm>> realms() async {
    final rows = await db.select(db.realms).get();
    final list = rows.map((r) => r.toDomain()).toList()
      ..sort((a, b) => b.importance.compareTo(a.importance));
    return list;
  }

  Future<List<LearningItem>> items() async =>
      (await db.select(db.items).get()).map((r) => r.toDomain()).toList();

  Future<List<Sentence>> sentences() async =>
      (await db.select(db.sentences).get()).map((r) => r.toDomain()).toList();

  Future<List<Question>> questions() async =>
      (await db.select(db.questions).get()).map((r) => r.toDomain()).toList();

  Future<List<SrsState>> srsStates() async =>
      (await db.select(db.srsStates).get()).map((r) => r.toDomain()).toList();

  Future<List<HistoryEntry>> history() async =>
      (await db.select(db.histories).get()).map((r) => r.toDomain()).toList();

  Future<({int realms, int items, int sentences, int questions})> counts() async {
    Future<int> n(TableInfo t) async =>
        (await db.customSelect('SELECT COUNT(*) AS c FROM ${t.actualTableName}').getSingle())
            .read<int>('c');
    return (
      realms: await n(db.realms),
      items: await n(db.items),
      sentences: await n(db.sentences),
      questions: await n(db.questions),
    );
  }

  // ------------------------------------------------------------ profile import

  Future<ImportOutcome> importProfile(String raw, {required String uiLanguage}) async {
    final ex = imp.extractJson(raw);
    if (!ex.ok) return ImportOutcome.failure([ex.failure == 'empty' ? 'empty' : 'parse']);

    final v = imp.validate(ex.data!);
    if (!v.ok) return ImportOutcome.failure(v.errors);
    if (v.type != 'profile') return const ImportOutcome.failure(['not a profile reply']);

    final norm = imp.normaliseProfile(ex.data!);
    final existing = {for (final r in await realms()) r.normKeyValue: r};

    final toWrite = norm.realms.map((r) {
      final prev = existing[r.normKeyValue];
      return prev == null
          ? r
          : prev.copyWith(
              nameNative: r.nameNative.isNotEmpty ? r.nameNative : prev.nameNative,
              importance: r.importance,
              confidence: r.confidence,
              contexts: r.contexts.isNotEmpty ? r.contexts : prev.contexts,
            );
    }).toList();

    await db.transaction(() async {
      for (final r in toWrite) {
        await db.into(db.realms).insertOnConflictUpdate(realmToRow(r));
      }
      await db.into(db.batches).insertOnConflictUpdate(BatchesCompanion.insert(
            id: newBatchId(),
            kind: 'profile',
            at: DateTime.now().millisecondsSinceEpoch,
            language: Value(uiLanguage),
            counts: Value(jsonEncode({'realms': toWrite.length})),
          ));
    });
    await _saveProfile(norm.profile);

    // The areas the AI read off the profile are the learner's fields. The
    // first few open for nothing; the rest wait, priced, in the field list.
    final all = await realms();
    final open = all.where((r) => r.unlocked).length;
    if (open < freeRealmSlots) {
      final free = [
        for (final r in all.where((r) => !r.unlocked).take(freeRealmSlots - open)) r.id
      ];
      await markRealmsUnlocked(free);
    }

    return ImportOutcome(ok: true, realms: toWrite.length, partial: ex.repaired);
  }

  // ----------------------------------------------------------- material import

  Future<ImportOutcome> importMaterial(String raw, {required String uiLanguage}) async {
    final ex = imp.extractJson(raw);
    if (!ex.ok) return ImportOutcome.failure([ex.failure == 'empty' ? 'empty' : 'parse']);

    final v = imp.validate(ex.data!);
    if (!v.ok) return ImportOutcome.failure(v.errors);
    if (v.type != 'material') return const ImportOutcome.failure(['not a material reply']);

    final norm = imp.normaliseMaterial(ex.data!);
    if (norm.sentences.isEmpty) return const ImportOutcome.failure(['no usable sentences']);

    final existingRealms = {for (final r in await realms()) r.normKeyValue: r};
    final allItems = await items();
    final allSentences = await sentences();

    // -- realm: reuse when the name already exists --
    //
    // `unlocked: true` unconditionally, in both branches: gating happens in
    // the UI *before* this method is ever called (the first three free
    // slots, `unlockRealm`, or `spendForNewRealm`), so material actually
    // landing here is itself the proof the realm was earned. Setting it here
    // rather than trusting each call site to have flipped it first is what
    // keeps "has material" and "unlocked" from ever disagreeing â the same
    // invariant the schema 3 migration's grandfathering rule relies on.
    final prevRealm = existingRealms[norm.realm.normKeyValue];
    final realm = prevRealm == null
        ? Realm(
            id: norm.realm.id,
            name: norm.realm.name,
            nameNative: norm.realm.nameNative,
            normKeyValue: norm.realm.normKeyValue,
            importance: norm.realm.importance,
            confidence: norm.realm.confidence,
            contexts: norm.realm.contexts,
            selected: true,
            hasMaterial: true,
            unlocked: true,
          )
        : prevRealm.copyWith(
            nameNative: prevRealm.nameNative.isNotEmpty
                ? prevRealm.nameNative
                : norm.realm.nameNative,
            contexts: prevRealm.contexts.isNotEmpty ? prevRealm.contexts : norm.realm.contexts,
            selected: true,
            hasMaterial: true,
            unlocked: true,
          );

    // -- learning items --
    // Identity is the normalised text. The same expression appearing in another
    // realm is linked rather than duplicated, so one concept keeps one schedule.
    final itemByKey = {for (final i in allItems) i.normKeyValue: i};
    final itemsToWrite = <LearningItem>[];
    var newItems = 0, linkedItems = 0;

    for (final it in norm.items) {
      final prev = itemByKey[it.normKeyValue];
      if (prev == null) {
        final rec = LearningItem(
          id: it.id,
          text: it.text,
          normKeyValue: it.normKeyValue,
          type: it.type,
          meaningNative: it.meaningNative,
          priority: it.priority,
          confidence: it.confidence,
          relatedTerms: it.relatedTerms,
          contexts: it.contexts,
          distractorsNative: it.distractorsNative,
          realmIds: [realm.id],
        );
        itemsToWrite.add(rec);
        itemByKey[it.normKeyValue] = rec;
        newItems++;
      } else {
        final ids = [...prev.realmIds];
        if (!ids.contains(realm.id)) {
          ids.add(realm.id);
          linkedItems++;
        }
        final merged = prev.copyWith(
          realmIds: ids,
          meaningNative: prev.meaningNative.isNotEmpty ? prev.meaningNative : it.meaningNative,
          distractorsNative:
              prev.distractorsNative.isNotEmpty ? prev.distractorsNative : it.distractorsNative,
          priority: max(prev.priority, it.priority),
        );
        itemsToWrite.add(merged);
        itemByKey[it.normKeyValue] = merged;
      }
    }

    // -- sentences --
    final sentenceKeys = {for (final s in allSentences) s.normKeyValue};
    final sentencesToWrite = <Sentence>[];
    var duplicates = 0;

    for (final s in norm.sentences) {
      if (sentenceKeys.contains(s.normKeyValue)) {
        duplicates++;
        continue;
      }
      // `targets` arrives as text; keep only those that resolve to a known item
      // AND actually occur in the sentence.
      final itemIds = <String>[];
      for (final t in s.itemIds) {
        final rec = itemByKey[normKey(t)];
        if (rec != null && containsPhrase(s.text, rec.text) && !itemIds.contains(rec.id)) {
          itemIds.add(rec.id);
        }
      }
      if (itemIds.isEmpty) {
        for (final rec in itemByKey.values) {
          if (rec.realmIds.contains(realm.id) && containsPhrase(s.text, rec.text)) {
            itemIds.add(rec.id);
            break;
          }
        }
      }

      sentencesToWrite.add(Sentence(
        id: s.id,
        text: s.text,
        normKeyValue: s.normKeyValue,
        translationNative: s.translationNative,
        level: s.level,
        context: s.context,
        speechAct: s.speechAct,
        naturalness: s.naturalness,
        realmId: realm.id,
        itemIds: itemIds,
        meaningOptionsNative: s.meaningOptionsNative,
        paraphraseEn: s.paraphraseEn,
        paraphraseOptionsEn: s.paraphraseOptionsEn,
        cueEn: s.cueEn,
        cueTranslationNative: s.cueTranslationNative,
        replyDistractorsEn: s.replyDistractorsEn,
        registerSituationNative: s.registerSituationNative,
        registerOptionsEn: s.registerOptionsEn,
        registerWhyNative: s.registerWhyNative,
        registerCorrect: s.registerCorrect,
      ));
      sentenceKeys.add(s.normKeyValue);
    }

    // -- questions, generated on device --
    final itemsById = {for (final i in itemByKey.values) i.id: i};
    for (final i in allItems) {
      itemsById.putIfAbsent(i.id, () => i);
    }
    final generated = qg.generateForSentences(
      sentencesToWrite,
      itemsById,
      [...allSentences, ...sentencesToWrite],
      rng,
    );

    await db.transaction(() async {
      await db.into(db.realms).insertOnConflictUpdate(realmToRow(realm));
      for (final i in itemsToWrite) {
        await db.into(db.items).insertOnConflictUpdate(itemToRow(i));
      }
      for (final s in sentencesToWrite) {
        await db.into(db.sentences).insertOnConflictUpdate(sentenceToRow(s));
      }
      for (final q in generated) {
        await db.into(db.questions).insertOnConflictUpdate(questionToRow(q));
      }
      await db.into(db.batches).insertOnConflictUpdate(BatchesCompanion.insert(
            id: newBatchId(),
            kind: 'material',
            realmId: Value(realm.id),
            at: DateTime.now().millisecondsSinceEpoch,
            language: Value(uiLanguage),
            counts: Value(jsonEncode({
              'items': newItems,
              'sentences': sentencesToWrite.length,
              'questions': generated.length,
            })),
          ));
    });

    // The area that was paid for has arrived, so the credit is used up and
    // the next new area is charged again.
    if (prevRealm == null) {
      final progress = await loadProgress();
      if (progress.realmCredits > 0) {
        await saveProgress(
            progress.copyWith(realmCredits: progress.realmCredits - 1));
      }
    }

    return ImportOutcome(
      ok: true,
      realmName: realm.label,
      newItems: newItems,
      linkedItems: linkedItems,
      newSentences: sentencesToWrite.length,
      duplicateSentences: duplicates,
      questions: generated.length,
      partial: ex.repaired,
    );
  }

  /// Optional quality pass: attaches scores, and can retire the weak sentences.
  Future<({int matched, int low})> importAudit(String raw) async {
    final ex = imp.extractJson(raw);
    if (!ex.ok) return (matched: 0, low: 0);
    final v = imp.validate(ex.data!);
    if (!v.ok || v.type != 'audit') return (matched: 0, low: 0);

    final byKey = {for (final e in imp.normaliseAudit(ex.data!)) e.normKeyValue: e};
    var matched = 0, low = 0;

    await db.transaction(() async {
      for (final s in await sentences()) {
        final a = byKey[s.normKeyValue];
        if (a == null) continue;
        matched++;
        if (a.score <= 2) low++;
        await (db.update(db.sentences)..where((t) => t.id.equals(s.id)))
            .write(SentencesCompanion(quality: Value(a.score)));
      }
    });
    return (matched: matched, low: low);
  }

  Future<int> disableLowQuality() async {
    final weak = await (db.select(db.sentences)
          ..where((t) => t.quality.isSmallerOrEqualValue(2) & t.disabled.equals(false)))
        .get();
    if (weak.isEmpty) return 0;
    await db.transaction(() async {
      for (final s in weak) {
        await (db.update(db.sentences)..where((t) => t.id.equals(s.id)))
            .write(const SentencesCompanion(disabled: Value(true)));
        await (db.update(db.questions)..where((t) => t.sentenceId.equals(s.id)))
            .write(const QuestionsCompanion(disabled: Value(true)));
      }
    });
    return weak.length;
  }

  // ----------------------------------------------------------------- session

  Future<List<Question>> _usableQuestions(String? realmId) async {
    final sentenceById = {for (final s in await sentences()) s.id: s};
    final all = await questions();
    return all.where((q) {
      if (q.disabled) return false;
      final s = sentenceById[q.sentenceId];
      if (s == null || s.disabled) return false;
      if (realmId != null && realmId != 'all' && q.realmId != realmId) return false;
      return true;
    }).toList();
  }

  Future<HomeCounts> homeCounts(String? realmId) async {
    final qs = await _usableQuestions(realmId);
    final states = {for (final s in await srsStates()) s.itemId: s};
    // A question with no row here, or a row saying nought, has never been put
    // in front of the learner.
    final served = {
      for (final row in await db.select(db.questionStats).get())
        if (row.n > 0) row.questionId
    };
    final t = today();

    final due = <String>{}, fresh = <String>{}, total = <String>{};
    var unanswered = 0;
    for (final q in qs) {
      final key = q.itemId ?? 'sent:${q.sentenceId}';
      total.add(key);
      if (!served.contains(q.id)) unanswered++;
      final st = q.itemId == null ? null : states[q.itemId];
      if (st != null && st.introduced) {
        if (srs.isDue(st, t)) due.add(key);
      } else {
        fresh.add(key);
      }
    }
    return HomeCounts(due.length, fresh.length, total.length, qs.length,
        unanswered, qs.map((q) => q.sentenceId).toSet().length);
  }

  /// Builds a session. Read-only: nothing is recorded until an answer arrives.
  ///
  /// Reviews that have come due lead, and everything else follows in an order
  /// weighted towards what has been asked least. The schedule is the point of
  /// the app, so it is never shuffled away â but beyond it the order is loose,
  /// because the same five questions in the same order every evening is what
  /// makes a library feel smaller than it is.
  Future<List<SessionSlot>> buildSession(
      {String? realmId, int count = 5, Set<QuestionType>? allow}) async {
    // ignore: parameter_assignments
    var qs = await _usableQuestions(realmId);
    // A format filter narrows the pool, but never empties it: someone who has
    // asked for listening only and has no listening questions left is better
    // served a session than a blank screen.
    if (allow != null) {
      final narrowed = qs.where((q) => allow.contains(q.type)).toList();
      if (narrowed.isNotEmpty) qs = narrowed;
    }
    if (qs.isEmpty) return const [];
    // Zero means everything the library can offer, which is what the longest
    // setting asks for.
    if (count <= 0) count = qs.length;

    final itemById = {for (final i in await items()) i.id: i};
    final realmById = {for (final r in await realms()) r.id: r};
    final states = {for (final s in await srsStates()) s.itemId: s};
    final recent = <String, int>{};
    final recentList = await _recentSentences();
    for (var i = 0; i < recentList.length; i++) {
      recent[recentList[i]] = i;
    }
    // How often each question has actually been served. The recency list only
    // remembers the last `recentLimit` sentences, so on a small library it
    // fills up and stops discriminating â this is what keeps the rotation
    // honest after that: least-asked first.
    final asked = {
      for (final row in await db.select(db.questionStats).get()) row.questionId: row.n
    };
    final t = today();

    // One slot per learning item, so a session probes breadth.
    final byItem = groupBy(qs, (Question q) => q.itemId ?? 'sent:${q.sentenceId}');

    final groups = byItem.entries.map((e) {
      final first = e.value.first;
      final state = first.itemId == null ? null : states[first.itemId];
      return (
        itemId: first.itemId,
        state: state,
        questions: e.value,
        due: state != null && state.introduced && srs.isDue(state, t),
        score: srs.priority(state, itemById[first.itemId], realmById[first.realmId], t),
      );
    }).toList();

    final r = rng ?? Random();
    groups.shuffle(r); // break ties randomly before the stable sort
    groups.sort((a, b) => b.score.compareTo(a.score));

    final picked = <SessionSlot>[];
    final usedSentences = <String>{};
    QuestionType? lastType;

    for (final g in groups) {
      if (picked.length >= count) break;

      // A sentence may carry several items; serving it twice in one session
      // would give the answer away.
      var fresh = g.questions.where((q) => !usedSentences.contains(q.sentenceId)).toList();
      if (fresh.isEmpty) continue;

      final available = uniqueBy(fresh.map((q) => q.type), (t) => t.name).toList();
      var wanted = srs.preferredFormat(g.state, available, r);
      if (wanted == lastType && available.length > 1) {
        final alt = available.where((t) => t != lastType).toList();
        wanted = srs.preferredFormat(g.state, alt, r) ?? wanted;
      }

      var candidates = fresh.where((q) => q.type == wanted).toList();
      if (candidates.isEmpty) candidates = fresh;

      // Meet the item through a different sentence than last time.
      final lastSentence = g.state?.lastSentenceId;
      if (lastSentence != null) {
        final varied = candidates.where((q) => q.sentenceId != lastSentence).toList();
        if (varied.isNotEmpty) candidates = varied;
      }

      candidates = _leastWorn(candidates, recent, asked);

      final chosen = sample(candidates, r);
      if (chosen == null) continue;

      usedSentences.add(chosen.sentenceId);
      picked.add(SessionSlot(chosen, g.itemId, g.due));
      lastType = chosen.type;
    }

    // A second helping. The first pass takes one question per learning item,
    // which is what makes a session broad â but it also caps the session at
    // however many items the library holds. On a small library that turned a
    // ten-question session into three, and the same few sentences came round
    // again and again.
    if (picked.length < count) {
      final takenIds = picked.map((p) => p.question.id).toSet();
      var pool = qs
          .where((q) => !takenIds.contains(q.id) && !usedSentences.contains(q.sentenceId))
          .toList();
      pool.shuffle(r);
      pool = _leastWorn(pool, recent, asked);

      for (final q in pool) {
        if (picked.length >= count) break;
        if (usedSentences.contains(q.sentenceId)) continue;
        final state = q.itemId == null ? null : states[q.itemId];
        usedSentences.add(q.sentenceId);
        picked.add(SessionSlot(
            q, q.itemId, state != null && state.introduced && srs.isDue(state, t)));
      }
    }

    // A third helping, once every sentence has been used once. The library is
    // finite and refilling it means a trip to an assistant, so a session that
    // stops early rather than asking a sentence again in a different format is
    // holding material back for no one's benefit. Kept strictly last: a
    // sentence met earlier in the same session makes its second question
    // easier, and that is a fair price only after the fresh ones are gone.
    if (picked.length < count) {
      final takenIds = picked.map((p) => p.question.id).toSet();
      final usedTypes = {
        for (final p in picked) '${p.question.sentenceId}|${p.question.type.name}'
      };
      var pool = qs
          .where((q) =>
              !takenIds.contains(q.id) &&
              !usedTypes.contains('${q.sentenceId}|${q.type.name}'))
          .toList();
      pool.shuffle(r);
      pool = _leastWorn(pool, recent, asked);

      for (final q in pool) {
        if (picked.length >= count) break;
        final state = q.itemId == null ? null : states[q.itemId];
        picked.add(SessionSlot(
            q, q.itemId, state != null && state.introduced && srs.isDue(state, t)));
      }
    }

    return picked;
  }

  /// The questions that have been shown least: unseen sentences first, and
  /// among those the ones asked fewest times. Falls back to the least recently
  /// seen rather than refusing to ask anything.
  List<Question> _leastWorn(
    List<Question> candidates,
    Map<String, int> recent,
    Map<String, int> asked,
  ) {
    if (candidates.length <= 1) return candidates;

    var pool = candidates.where((q) => !recent.containsKey(q.sentenceId)).toList();
    if (pool.isEmpty) {
      pool = [...candidates]..sort((a, b) =>
          (recent[b.sentenceId] ?? 0).compareTo(recent[a.sentenceId] ?? 0));
      pool = take(pool, 3);
    }

    // Among what is left, the ones asked fewest times â all of them, so the
    // caller still has something to pick at random from.
    final fewest = pool.map((q) => asked[q.id] ?? 0).reduce((a, b) => a < b ? a : b);
    return pool.where((q) => (asked[q.id] ?? 0) == fewest).toList();
  }

  /// Records one answer: schedule, per-question stats, history, streak and
  /// Seeds. The streak advances here rather than at session start, because a
  /// day counts only once a question has actually been answered.
  ///
  /// [bonusSeeds] is added on top of what the answer itself earns â the
  /// session's combo run. It is passed in rather than computed here because
  /// the run belongs to the session on screen, not to the stored record.
  Future<AnswerOutcome> recordAnswer({
    required Question question,
    required bool correct,
    required bool wasDue,
    int boost = 1,
    int bonusSeeds = 0,
  }) async {
    final t = today();
    SrsState? updated;
    SrsState? before;
    var firstCorrect = false;

    if (question.itemId != null) {
      final existing = await (db.select(db.srsStates)
            ..where((x) => x.itemId.equals(question.itemId!)))
          .getSingleOrNull();
      final state = existing?.toDomain() ?? SrsState.blank(question.itemId!);
      before = existing?.toDomain();
      firstCorrect = correct && srs.accuracy(state).ok == 0;
      updated = srs.applyAnswer(state, question.type, correct,
          sentenceId: question.sentenceId, at: t);
      await db.into(db.srsStates).insertOnConflictUpdate(srsToRow(updated));
    }

    final prevStat = await (db.select(db.questionStats)
          ..where((x) => x.questionId.equals(question.id)))
        .getSingleOrNull();
    await db.into(db.questionStats).insertOnConflictUpdate(QuestionStatsCompanion.insert(
          questionId: question.id,
          n: Value((prevStat?.n ?? 0) + 1),
          ok: Value((prevStat?.ok ?? 0) + (correct ? 1 : 0)),
          lastAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));

    await db.into(db.histories).insert(historyToRow(HistoryEntry(
          day: t,
          at: DateTime.now(),
          questionId: question.id,
          itemId: question.itemId,
          realmId: question.realmId,
          type: question.type,
          correct: correct,
          wasDue: wasDue,
        )));

    await _pushRecent(question.sentenceId);

    final progress = await loadProgress();
    final streak = registerStudyDay(progress, t);
    final gained =
        seedsFor(question.type, correct, wasDue: wasDue, firstCorrect: firstCorrect) *
            (boost > 1 ? boost : 1);
    // A study day advancing onto a multiple of `streakBonusEvery` pays a
    // milestone once â `registerStudyDay` already guarantees the streak
    // advances at most once per calendar day, so this cannot double-fire from
    // answering several questions on the same day.
    final milestone =
        streak.result.advanced && streak.result.to % streakBonusEvery == 0 ? streakBonus : 0;

    // The item that kept going wrong and finally stopped. Paid once, so a
    // later slip and recovery is not a second payday â and so nobody can
    // farm it by missing on purpose.
    final itemId = question.itemId;
    final broke = itemId != null &&
        !streak.progress.breakthroughs.contains(itemId) &&
        isBreakthrough(before, updated);
    final breakthrough = broke ? breakthroughBonus : 0;
    final next = streak.progress.copyWith(
      seeds: streak.progress.seeds + gained + milestone + bonusSeeds + breakthrough,
      breakthroughs: broke
          ? [...streak.progress.breakthroughs, itemId]
          : streak.progress.breakthroughs,
    );
    await saveProgress(next);

    // Growing a stage is its own reward â no Seeds attached, or it would
    // simply duplicate what the schedule already pays for.
    // First meeting: no schedule before this answer, or one that had never
    // introduced the item.
    final discovered = updated != null && !(before?.introduced ?? false);

    final grewTo = srs.stageFor(updated);
    final stageUp =
        grewTo.index > srs.stageFor(before).index ? grewTo : null;

    return AnswerOutcome(
        correct, gained + milestone + bonusSeeds + breakthrough, streak.result,
        next, updated,
        breakthrough: broke, stageUp: stageUp, discovered: discovered);
  }

  /// Called once, right after a session ends. Applies the flat
  /// session-length bonus, and â at most once a day â the "today's journey
  /// complete" bonus.
  ///
  /// Journey completeness is derived from the answer log rather than tracked
  /// separately: every realm that has material must have at least one
  /// history entry for today. That means it can never drift out of sync with
  /// what the learner actually did, and it costs nothing extra to compute â
  /// the same `history()` the stats screen already reads.
  Future<({Progress progress, int bonus, bool perfect})> finishSession(
      {required int answered, int missed = 0, int target = 0}) async {
    final progress = await loadProgress();
    final t = today();
    var bonus = sessionCompletionBonus(answered, target);

    // A whole session without a single miss. Judged here rather than on the
    // screen so the bonus cannot be claimed twice by returning to it.
    final perfect = isPerfectRun(answered: answered, missed: missed);
    if (perfect) bonus += perfectRunBonus;
    var journeyDay = progress.journeyBonusDay;

    if (progress.journeyBonusDay != t) {
      final withMaterial = (await realms()).where((r) => r.hasMaterial).toList();
      if (withMaterial.isNotEmpty) {
        final touchedToday =
            (await history()).where((h) => h.day == t).map((h) => h.realmId).toSet();
        if (withMaterial.every((r) => touchedToday.contains(r.id))) {
          bonus += journeyCompleteBonus;
          journeyDay = t;
        }
      }
    }

    final next = progress.copyWith(
      seeds: progress.seeds + bonus,
      journeyBonusDay: journeyDay,
    );
    await saveProgress(next);
    return (progress: next, bonus: bonus, perfect: perfect);
  }

  /// Spends `realmUnlockCost` to flip an existing (already-suggested but
  /// still locked) realm to usable. Returns false and spends nothing if the
  /// balance is short â the caller is expected to have already confirmed
  /// with the learner before calling this. An area that is already unlocked
  /// costs nothing: the confirmation is a dialog, and two of them could be
  /// stacked up by a double tap and then both confirmed.
  Future<bool> unlockRealm(String realmId) async {
    final row = await (db.select(db.realms)..where((t) => t.id.equals(realmId)))
        .getSingleOrNull();
    if (row == null) return false;
    if (row.unlocked) return true;

    final progress = await loadProgress();
    if (progress.seeds < realmUnlockCost) return false;

    await (db.update(db.realms)..where((t) => t.id.equals(realmId)))
        .write(const RealmsCompanion(unlocked: Value(true)));
    await saveProgress(progress.copyWith(seeds: progress.seeds - realmUnlockCost));
    return true;
  }

  /// Marks realms unlocked at no cost â used once, when the learner confirms
  /// their first three free areas at onboarding. Nothing beyond this point
  /// grants a free unlock; every later one goes through `unlockRealm` or
  /// `spendForNewRealm`.
  Future<void> markRealmsUnlocked(List<String> ids) async {
    if (ids.isEmpty) return;
    await (db.update(db.realms)..where((t) => t.id.isIn(ids)))
        .write(const RealmsCompanion(unlocked: Value(true)));
  }

  /// Spends `realmUnlockCost` for a realm that does not exist as a row yet â
  /// a genuinely new domain named through the "add a new area" AI prompt,
  /// rather than one the AI already suggested during profile import. The
  /// realm itself is created, already unlocked, by the `importMaterial` call
  /// that follows. Returns false and spends nothing if the balance is short.
  ///
  /// The purchase is held as a credit until that import arrives, because the
  /// gap between the two is long â the learner leaves for their AI and comes
  /// back â and copying the prompt again in the meantime must not be charged
  /// as a second area.
  Future<bool> spendForNewRealm() async {
    final progress = await loadProgress();
    if (progress.realmCredits > 0) return true;
    if (progress.seeds < realmUnlockCost) return false;
    await saveProgress(progress.copyWith(
      seeds: progress.seeds - realmUnlockCost,
      realmCredits: progress.realmCredits + 1,
    ));
    return true;
  }

  /// Whether adding material to [realmId] costs anything. The first batch in
  /// an area is free; every later one is charged, because that is the point
  /// at which the learner is genuinely buying more to study rather than
  /// making a newly opened area usable at all.
  /// Whether a further batch would be charged for, judged from the reply
  /// itself rather than from whichever area the picker happens to be showing.
  ///
  /// Those were two different things: the charge was decided by the dropdown
  /// while the material went wherever the JSON said, so pasting a Work batch
  /// while an empty area was selected imported it for nothing. Reading the
  /// reply closes that, and answering before the import means the learner is
  /// never told the price after they have already been to their assistant and
  /// back.
  Future<bool> materialWouldCost(String raw) async {
    final ex = imp.extractJson(raw);
    if (!ex.ok || ex.data == null) return false;
    final v = imp.validate(ex.data!);
    if (v.type != 'material') return false;
    final norm = imp.normaliseMaterial(ex.data!);
    final existing = await realms();
    final match = existing
        .where((r) => r.normKeyValue == norm.realm.normKeyValue)
        .firstOrNull;
    return match != null && match.hasMaterial;
  }

  /// Spends `extraMaterialCost` for a further batch in an area that already
  /// has material. Returns false and spends nothing if the balance is short.
  Future<bool> spendForExtraMaterial() async {
    final progress = await loadProgress();
    if (progress.seeds < extraMaterialCost) return false;
    await saveProgress(progress.copyWith(seeds: progress.seeds - extraMaterialCost));
    return true;
  }

  /// Buys one ornament and hangs it on the tree. Returns the progress actually
  /// stored, or null when the balance is short â in which case nothing is
  /// spent. Duplicates are allowed: several ribbons on one tree is a choice,
  /// not a mistake.
  Future<Progress?> spendForOrnament(String kind) async {
    if (!ornamentKinds.contains(kind)) return null;
    final progress = await loadProgress();
    if (progress.seeds < ornamentCost) return null;
    final next = progress.copyWith(
      seeds: progress.seeds - ornamentCost,
      ornaments: [...progress.ornaments, kind],
    );
    await saveProgress(next);
    return next;
  }

  // ------------------------------------------------------------- library ops

  Future<void> setItemDisabled(String itemId, bool disabled) async {
    await db.transaction(() async {
      await (db.update(db.items)..where((t) => t.id.equals(itemId)))
          .write(ItemsCompanion(disabled: Value(disabled)));
      await (db.update(db.questions)..where((t) => t.itemId.equals(itemId)))
          .write(QuestionsCompanion(disabled: Value(disabled)));
    });
  }

  Future<void> setSentenceDisabled(String sentenceId, bool disabled) async {
    await db.transaction(() async {
      await (db.update(db.sentences)..where((t) => t.id.equals(sentenceId)))
          .write(SentencesCompanion(disabled: Value(disabled)));
      await (db.update(db.questions)..where((t) => t.sentenceId.equals(sentenceId)))
          .write(QuestionsCompanion(disabled: Value(disabled)));
    });
  }

  /// Removes an expression with its questions and schedule. Sentences survive:
  /// they may carry other expressions worth keeping.
  Future<void> deleteItem(String itemId) async {
    await db.transaction(() async {
      await (db.delete(db.questions)..where((t) => t.itemId.equals(itemId))).go();
      await (db.delete(db.srsStates)..where((t) => t.itemId.equals(itemId))).go();
      await (db.delete(db.items)..where((t) => t.id.equals(itemId))).go();
    });
  }

  // ------------------------------------------------------------------ resets

  /// What deleting a realm would remove. Shown before anything is touched.
  Future<({int items, int sharedItems, int sentences, int questions, int srs})>
      planRealmDeletion(String realmId) async {
    final sents = (await sentences()).where((s) => s.realmId == realmId).toList();
    final sentIds = sents.map((s) => s.id).toSet();
    final qs = (await questions())
        .where((q) => q.realmId == realmId || sentIds.contains(q.sentenceId))
        .toList();
    final owned = (await items()).where((i) => i.realmIds.contains(realmId)).toList();
    final dead = owned.where((i) => i.realmIds.length <= 1).toList();
    final shared = owned.where((i) => i.realmIds.length > 1).toList();
    final deadIds = dead.map((i) => i.id).toSet();
    final states = (await srsStates()).where((s) => deadIds.contains(s.itemId)).length;
    return (
      items: dead.length,
      sharedItems: shared.length,
      sentences: sents.length,
      questions: qs.length,
      srs: states,
    );
  }

  /// removeRealm=false keeps the realm so fresh material can be pasted straight
  /// back in, which is the common case.
  Future<void> deleteRealmMaterial(String realmId, {bool removeRealm = false}) async {
    final sents = (await sentences()).where((s) => s.realmId == realmId).toList();
    final sentIds = sents.map((s) => s.id).toSet();
    final qs = (await questions())
        .where((q) => q.realmId == realmId || sentIds.contains(q.sentenceId))
        .toList();
    final owned = (await items()).where((i) => i.realmIds.contains(realmId)).toList();

    await db.transaction(() async {
      for (final q in qs) {
        await (db.delete(db.questions)..where((t) => t.id.equals(q.id))).go();
        await (db.delete(db.questionStats)..where((t) => t.questionId.equals(q.id))).go();
      }
      for (final s in sents) {
        await (db.delete(db.sentences)..where((t) => t.id.equals(s.id))).go();
      }
      for (final i in owned) {
        if (i.realmIds.length <= 1) {
          await (db.delete(db.items)..where((t) => t.id.equals(i.id))).go();
          await (db.delete(db.srsStates)..where((t) => t.itemId.equals(i.id))).go();
        } else {
          // Shared expressions survive; they just stop belonging to this realm.
          await db.into(db.items).insertOnConflictUpdate(itemToRow(
                i.copyWith(realmIds: i.realmIds.where((r) => r != realmId).toList()),
              ));
        }
      }
      await (db.delete(db.batches)..where((t) => t.realmId.equals(realmId))).go();

      if (removeRealm) {
        await (db.delete(db.realms)..where((t) => t.id.equals(realmId))).go();
      } else {
        await (db.update(db.realms)..where((t) => t.id.equals(realmId)))
            .write(const RealmsCompanion(hasMaterial: Value(false)));
      }
    });
  }

  /// Rebuilds every question from the sentences already stored, and returns
  /// how many there are afterwards.
  ///
  /// Questions are only built at import time, so a library imported before a
  /// format existed would never see it. This is what lets an existing learner
  /// pick up the new formats without re-importing anything.
  ///
  /// Safe to run repeatedly: `_questionId` is derived from the sentence and
  /// the type, so existing questions keep their ids and the answer history
  /// keyed to them survives. Only the option order is reshuffled, and the
  /// schedule lives on the learning item rather than the question, so nothing
  /// about the learner's progress moves.
  Future<int> regenerateQuestions() async {
    final all = await sentences();
    if (all.isEmpty) return 0;

    final itemsById = {for (final i in await items()) i.id: i};
    final generated = qg.generateForSentences(all, itemsById, all, rng);
    final keep = {for (final q in generated) q.id};

    // Anything a rebuild no longer produces is stale â a sentence edited into
    // a shape its old question no longer matches, say â and its statistics
    // describe a question that is gone.
    await db.transaction(() async {
      for (final q in generated) {
        await db.into(db.questions).insertOnConflictUpdate(questionToRow(q));
      }
      final stale = (await db.select(db.questions).get())
          .where((r) => !keep.contains(r.id))
          .map((r) => r.id)
          .toList();
      for (final id in stale) {
        await (db.delete(db.questions)..where((t) => t.id.equals(id))).go();
        await (db.delete(db.questionStats)..where((t) => t.questionId.equals(id))).go();
      }
    });

    return generated.length;
  }

  Future<void> deleteAllMaterial() async {
    await db.transaction(() async {
      await db.delete(db.questions).go();
      await db.delete(db.questionStats).go();
      await db.delete(db.sentences).go();
      await db.delete(db.items).go();
      await db.delete(db.srsStates).go();
      await (db.delete(db.batches)..where((t) => t.kind.equals('material'))).go();
      await db.update(db.realms).write(const RealmsCompanion(hasMaterial: Value(false)));
      // Debates and the chunk library are material too; the learner's own
      // captures and attempts are a record of what they did, and stay.
      await db.delete(db.debates).go();
      await db.delete(db.scenes).go();
      await db.delete(db.chunks).go();
    });
    await _delMeta('recentSentences');
  }

  /// Keeps the material, forgets how far the learner got with it.
  Future<void> resetProgress() async {
    await db.transaction(() async {
      await db.delete(db.srsStates).go();
      await db.delete(db.questionStats).go();
      await db.delete(db.histories).go();
      // What the learner said in debates, and where they slipped, is progress
      // in the same sense; the trees themselves are material and stay.
      await db.delete(db.attempts).go();
      await db.delete(db.sceneResults).go();
      await db.delete(db.reviews).go();
      await db.delete(db.failures).go();
    });
    await saveProgress(const Progress());
    await _delMeta('recentSentences');
  }

  /// Clears what the onboarding prompts produced. Streak, XP and history are a
  /// record of what the learner did, so they survive.
  Future<void> resetProfileAndRealms() async {
    await db.transaction(() async {
      await db.delete(db.questions).go();
      await db.delete(db.questionStats).go();
      await db.delete(db.sentences).go();
      await db.delete(db.items).go();
      await db.delete(db.srsStates).go();
      await db.delete(db.realms).go();
      await db.delete(db.batches).go();
      // The debates were built for the areas being cleared, and the attempts
      // and failures point into those debates. Captures are the learner's own
      // notes about their life, not about the material, so they stay.
      await db.delete(db.debates).go();
      await db.delete(db.scenes).go();
      await db.delete(db.chunks).go();
      await db.delete(db.attempts).go();
      await db.delete(db.sceneResults).go();
      await db.delete(db.reviews).go();
      await db.delete(db.failures).go();
    });
    await _delMeta('profile');
    await _delMeta('recentSentences');
  }

  /// Back to a first run. The interface language is kept unless [keepLanguage]
  /// is false, so the learner is not dropped into a language they cannot read.
  Future<void> factoryReset({bool keepLanguage = true, bool keepSettings = false}) async {
    final lang = keepLanguage ? await loadUiLanguage() : null;
    final settings = keepSettings ? await loadSettings() : null;

    await db.transaction(() async {
      await db.delete(db.questions).go();
      await db.delete(db.questionStats).go();
      await db.delete(db.sentences).go();
      await db.delete(db.items).go();
      await db.delete(db.srsStates).go();
      await db.delete(db.realms).go();
      await db.delete(db.histories).go();
      await db.delete(db.batches).go();
      await db.delete(db.meta).go();
      await db.delete(db.debates).go();
      await db.delete(db.scenes).go();
      await db.delete(db.chunks).go();
      await db.delete(db.attempts).go();
      await db.delete(db.sceneResults).go();
      await db.delete(db.reviews).go();
      await db.delete(db.captures).go();
      await db.delete(db.failures).go();
    });

    if (lang != null) await saveUiLanguage(lang);
    if (settings != null) await saveSettings(settings);
  }

  // -------------------------------------------------------------- debate gym

  Future<List<Chunk>> chunks() async =>
      (await db.select(db.chunks).get()).map((r) => r.toDomain()).toList();

  Future<List<DebateTree>> debates({bool includeDisabled = false}) async {
    final rows = await db.select(db.debates).get();
    return [
      for (final r in rows)
        if (includeDisabled || !r.disabled) r.toDomain()
    ];
  }

  Future<List<Attempt>> attempts({bool pendingOnly = false}) async {
    final rows = await (db.select(db.attempts)..orderBy([(t) => OrderingTerm.asc(t.at)])).get();
    return [
      for (final r in rows)
        if (!pendingOnly || r.critique == null) r.toDomain()
    ];
  }

  Future<List<Capture>> captures({bool pendingOnly = false}) async {
    final rows =
        await (db.select(db.captures)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
    return [
      for (final r in rows)
        if (!pendingOnly || r.consumedAt == null) r.toDomain()
    ];
  }

  Future<List<Failure>> failures({bool pendingOnly = false}) async {
    final rows = await (db.select(db.failures)..orderBy([(t) => OrderingTerm.asc(t.at)])).get();
    return [
      for (final r in rows)
        if (!pendingOnly || r.consumedAt == null) r.toDomain()
    ];
  }

  /// A line written down in twenty seconds: what is coming, or what could not
  /// be said. It becomes an event in the next pack prompt.
  Future<Capture> addCapture({required String note, String? date, String who = ''}) async {
    final text = clean(note);
    if (text.isEmpty) throw ArgumentError('a capture needs some words');
    final c = Capture(
      id: uid('cap'),
      noteNative: text,
      date: date != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ? date : null,
      who: clean(who),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await db.into(db.captures).insert(captureToRow(c));
    return c;
  }

  Future<void> deleteCapture(String id) =>
      (db.delete(db.captures)..where((t) => t.id.equals(id))).go();

  /// One reply the learner gave. Stored so the next pack can carry it out for
  /// critique. [closest] is the model rebuttal it was judged nearest to.
  Future<Attempt> recordAttempt({
    required DebateTree tree,
    required DebateNode node,
    required String youSaid,
    required List<Move> moves,
    Rebuttal? closest,
  }) async {
    final a = Attempt(
      id: uid('att'),
      debateId: tree.id,
      nodeId: node.id,
      youSaid: clean(youSaid),
      moves: moves,
      closest: closest?.id,
      closestStrength: closest?.strength,
      day: today(),
      at: DateTime.now().millisecondsSinceEpoch,
    );
    await db.into(db.attempts).insert(attemptToRow(a));
    return a;
  }

  /// Something that went wrong, written by the app. The AI reads these to aim
  /// the next pack's reinforcement.
  Future<Failure> recordFailure({
    required DebateTree tree,
    required DebateNode node,
    required String kind,
    String note = '',
  }) async {
    final f = Failure(
      id: uid('fail'),
      debateId: tree.id,
      nodeId: node.id,
      kind: kind,
      noteNative: clean(note),
      at: DateTime.now().millisecondsSinceEpoch,
    );
    await db.into(db.failures).insert(failureToRow(f));
    return f;
  }

  Future<void> setDebateDisabled(String id, bool disabled) => (db.update(db.debates)
        ..where((t) => t.id.equals(id)))
      .write(DebatesCompanion(disabled: Value(disabled)));

  /// One exchange settled: the reply stored for critique, the day counted as
  /// studied, the Seeds paid. Failures the exchange showed are written down
  /// here too, so the next pack can aim at them.
  ///
  /// Nothing is judged. [closest] is the model reply the learner's came
  /// nearest to, worked out on the phone; how much that is worth is decided
  /// in `progress_service.dart`, and what it *means* waits for the critique.
  Future<({Attempt attempt, Progress progress, int seeds})> recordExchange({
    required DebateTree tree,
    required DebateNode node,
    required String youSaid,
    required List<Move> moves,
    required Rebuttal closest,
    required bool graspedAll,
    required List<Move> missingMoves,
    required List<String> graspMisses,
    String? outcome,
  }) async {
    final attempt = await recordAttempt(
      tree: tree,
      node: node,
      youSaid: youSaid,
      moves: moves,
      closest: closest,
    );
    for (final kind in graspMisses) {
      await recordFailure(tree: tree, node: node, kind: kind);
    }
    for (final m in missingMoves) {
      await recordFailure(tree: tree, node: node, kind: 'missing_move:${m.name}');
    }
    if (outcome == 'pressed') {
      await recordFailure(tree: tree, node: node, kind: 'pressed');
    }

    final progress = await loadProgress();
    final streak = registerStudyDay(progress, today());
    final gained = exchangeSeeds(
          graspedAll: graspedAll,
          closestIsStrong: closest.strength == Strength.strong,
          structureComplete: missingMoves.isEmpty,
        ) +
        (outcome == null ? 0 : outcomeSeeds(outcome));
    final milestone =
        streak.result.advanced && streak.result.to % streakBonusEvery == 0 ? streakBonus : 0;
    final next = streak.progress.copyWith(seeds: streak.progress.seeds + gained + milestone);
    await saveProgress(next);
    return (attempt: attempt, progress: next, seeds: gained + milestone);
  }

  /// Imports one reply of a pack: chunks (usually only the first time), any
  /// debates, and critiques for attempts still waiting on one.
  ///
  /// Captures and failures are marked as carried out here, at the moment the
  /// material actually comes back â not when the prompt is copied, because a
  /// prompt copied and never pasted would otherwise lose them.
  Future<PackOutcome> importPack(String raw, {required String uiLanguage}) async {
    final ex = imp.extractJson(raw);
    if (!ex.ok) return PackOutcome.failure([ex.failure == 'empty' ? 'empty' : 'parse']);

    final v = imp.validate(ex.data!);
    if (!v.ok) return PackOutcome.failure(v.errors);
    if (v.type != 'pack') return const PackOutcome.failure(['not a pack reply']);

    final norm = imp.normalisePack(ex.data!);
    if (norm.chunks.isEmpty && norm.debates.isEmpty && norm.critiques.isEmpty) {
      return PackOutcome(
        ok: false,
        errors: const ['nothing usable in the pack'],
        rejected: norm.rejected,
        partial: ex.repaired,
      );
    }

    final pending = {for (final a in await attempts(pendingOnly: true)) a.id: a};
    var matched = 0, unmatched = 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction(() async {
      for (final c in norm.chunks) {
        await db.into(db.chunks).insertOnConflictUpdate(chunkToRow(c));
      }
      for (final t in norm.debates) {
        // A tree pasted twice lands on itself and comes back enabled: pasting
        // it again is the clearest way anyone could say they want it back.
        await db.into(db.debates).insertOnConflictUpdate(debateToRow(t));
      }
      for (final c in norm.critiques) {
        final a = pending[c.attemptId];
        if (a == null) {
          unmatched++;
          continue;
        }
        await db.update(db.attempts).replace(attemptToRow(a.withCritique(c)));
        matched++;
      }
      if (norm.debates.isNotEmpty) {
        await (db.update(db.captures)..where((t) => t.consumedAt.isNull()))
            .write(CapturesCompanion(consumedAt: Value(now)));
        await (db.update(db.failures)..where((t) => t.consumedAt.isNull()))
            .write(FailuresCompanion(consumedAt: Value(now)));
      }
      await db.into(db.batches).insertOnConflictUpdate(BatchesCompanion.insert(
            id: newBatchId(),
            kind: 'pack',
            at: now,
            language: Value(uiLanguage),
            promptVersion: const Value(pr.PromptVersions.pack),
            counts: Value(jsonEncode({
              'chunks': norm.chunks.length,
              'debates': norm.debates.length,
              'critiques': matched,
              'rejected': norm.rejected.length,
            })),
          ));
    });

    return PackOutcome(
      ok: true,
      chunks: norm.chunks.length,
      debates: norm.debates.length,
      critiques: matched,
      unmatchedCritiques: unmatched,
      rejected: norm.rejected,
      partial: ex.repaired,
    );
  }

  /// The attempts the AI is owed a critique on, in the shape the prompts take.
  Future<List<({String id, String topic, String line, String youSaid, List<String> moves})>>
      _attemptsForPrompt() async {
    final trees = {for (final t in await debates(includeDisabled: true)) t.id: t};
    return [
      for (final a in await attempts(pendingOnly: true))
        (
          id: a.id,
          topic: trees[a.debateId]?.topic ?? a.debateId,
          line: trees[a.debateId]?.node(a.nodeId)?.line ?? '',
          youSaid: a.youSaid,
          moves: [for (final m in a.moves) m.name],
        )
    ];
  }

  /// The weekly prompt, assembled from everything waiting on this phone.
  Future<String> packPromptText({required String uiLanguage, int debates = 3}) async {
    final profile = await loadProfile();
    final trees = {for (final t in await this.debates(includeDisabled: true)) t.id: t};
    final areas = [for (final r in await realms()) if (r.unlocked) r.label];
    return pr.packPrompt(
      uiLanguage: uiLanguage,
      level: profile?.englishLevel ?? 'B1',
      roles: profile?.roles ?? const [],
      priorities: profile?.learningPriorities ?? const [],
      areas: areas,
      existingTopics: [for (final t in trees.values) t.topic],
      events: [
        for (final c in await captures(pendingOnly: true))
          (date: c.date, note: c.noteNative, who: c.who)
      ],
      failures: [
        for (final f in await failures(pendingOnly: true))
          (
            topic: trees[f.debateId]?.topic ?? f.debateId,
            node: f.nodeId,
            kind: f.kind,
            note: f.noteNative,
          )
      ],
      attempts: await _attemptsForPrompt(),
      needChunks: (await chunks()).isEmpty,
      debates: debates,
    );
  }

  /// Critiques only, for the learner who cannot wait for the next pack.
  Future<String> critiquePromptText({required String uiLanguage}) async {
    final profile = await loadProfile();
    return pr.critiquePrompt(
      uiLanguage: uiLanguage,
      level: profile?.englishLevel ?? 'B1',
      attempts: await _attemptsForPrompt(),
    );
  }

  // ------------------------------------------------------------------ scenes
  //
  // Listen, choose, grow. Scenes the learner's own AI wrote live here; the
  // built-in ones ship with the app and are merged in above this layer, so
  // everything below is about the learner's own material and their results.

  Future<List<Scene>> scenes({bool includeDisabled = false}) async {
    final rows = await (db.select(db.scenes)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return [
      for (final r in rows)
        if (includeDisabled || !r.disabled) r.toDomain()
    ];
  }

  Future<void> setSceneDisabled(String id, bool disabled) => (db.update(db.scenes)
        ..where((t) => t.id.equals(id)))
      .write(ScenesCompanion(disabled: Value(disabled)));

  /// A scenes reply pasted in. Sound scenes are stored (a scene pasted twice
  /// lands on itself); the ones that could not be made sound are named with
  /// the reason, because the learner pasted them and "3 of 5" with no
  /// explanation would leave them wondering what they did wrong.
  /// [field] is the field the learner asked for these scenes; every scene in
  /// the reply lands there.
  Future<SceneOutcome> importScenes(String raw,
      {required String uiLanguage, String? field}) async {
    final ex = imp.extractJson(raw);
    if (!ex.ok) return SceneOutcome.failure([ex.failure == 'empty' ? 'empty' : 'parse']);

    final v = imp.validate(ex.data!);
    if (!v.ok) return SceneOutcome.failure(v.errors);
    if (v.type != 'scenes') return const SceneOutcome.failure(['not a scenes reply']);

    final norm = normaliseScenes(ex.data!);
    if (norm.scenes.isEmpty) {
      return SceneOutcome(
        ok: false,
        errors: const ['no usable scene'],
        rejected: norm.rejected,
        partial: ex.repaired,
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      for (final s in norm.scenes) {
        await db.into(db.scenes).insertOnConflictUpdate(
            sceneToRow(field == null ? s : s.copyWith(realmId: field)));
      }
      await db.into(db.batches).insertOnConflictUpdate(BatchesCompanion.insert(
            id: newBatchId(),
            kind: 'scenes',
            at: now,
            language: Value(uiLanguage),
            promptVersion: const Value(pr.PromptVersions.scenes),
            counts: Value(jsonEncode({
              'scenes': norm.scenes.length,
              'rejected': norm.rejected.length,
            })),
          ));
    });

    return SceneOutcome(
      ok: true,
      scenes: norm.scenes.length,
      rejected: norm.rejected,
      partial: ex.repaired,
    );
  }

  Future<List<SceneResult>> sceneResults() async {
    final rows =
        await (db.select(db.sceneResults)..orderBy([(t) => OrderingTerm.asc(t.at)])).get();
    return [for (final r in rows) r.toDomain()];
  }

  /// One exchange answered. Written down as it was, and a miss books its
  /// reviews: the next day first, then three days on. A review answered
  /// right moves to the next gap; answered wrong, it comes back tomorrow.
  Future<SceneResult> recordSceneExchange({
    required String sceneId,
    required int exchange,
    required bool gistOk,
    required bool replyOk,
    bool peeked = false,
    bool review = false,
  }) async {
    final day = today();
    final r = SceneResult(
      sceneId: sceneId,
      exchange: exchange,
      gistOk: gistOk,
      replyOk: replyOk,
      peeked: peeked,
      review: review,
      day: day,
      at: DateTime.now().millisecondsSinceEpoch,
    );
    await db.into(db.sceneResults).insert(sceneResultToRow(r));

    final key = (db.select(db.reviews)
      ..where((t) => t.sceneId.equals(sceneId) & t.exchange.equals(exchange)));
    final existing = await key.getSingleOrNull();
    final missed = !gistOk || !replyOk;

    if (missed) {
      // Back to the first gap — whether this was the first miss or a review
      // that did not stick.
      await db.into(db.reviews).insertOnConflictUpdate(ReviewsCompanion.insert(
            sceneId: sceneId,
            exchange: exchange,
            dueDay: addDays(day, reviewGaps[0]),
            stage: const Value(0),
          ));
    } else if (review && existing != null) {
      final next = existing.stage + 1;
      if (next >= reviewGaps.length) {
        await (db.delete(db.reviews)
              ..where((t) => t.sceneId.equals(sceneId) & t.exchange.equals(exchange)))
            .go();
      } else {
        await (db.update(db.reviews)
              ..where((t) => t.sceneId.equals(sceneId) & t.exchange.equals(exchange)))
            .write(ReviewsCompanion(dueDay: Value(addDays(day, reviewGaps[next])), stage: Value(next)));
      }
    }
    return r;
  }

  /// The exchanges owed another look today, oldest due first.
  Future<List<ReviewItem>> reviewsDue({String? day, int limit = 3}) async {
    final t = day ?? today();
    final rows = await (db.select(db.reviews)
          ..where((x) => x.dueDay.isSmallerOrEqualValue(t))
          ..orderBy([(x) => OrderingTerm.asc(x.dueDay)])
          ..limit(limit))
        .get();
    return [for (final r in rows) r.toDomain()];
  }

  Future<List<ReviewItem>> reviews() async {
    final rows = await db.select(db.reviews).get();
    return [for (final r in rows) r.toDomain()];
  }

  /// A scene finished: the day counted as studied, the Seeds paid. Finishing
  /// is what keeps the streak, however the questions went.
  Future<({Progress progress, int seeds})> completeScene({
    required int gistRight,
    required int replyRight,
  }) async {
    final progress = await loadProgress();
    final streak = registerStudyDay(progress, today());
    final gained = gistRight * gistSeeds + replyRight * replySeeds + sceneCompleteSeeds;
    final milestone =
        streak.result.advanced && streak.result.to % streakBonusEvery == 0 ? streakBonus : 0;
    final next = streak.progress.copyWith(seeds: streak.progress.seeds + gained + milestone);
    await saveProgress(next);
    return (progress: next, seeds: gained + milestone);
  }

  /// The prompt for the next five scenes, from everything this phone knows:
  /// the profile, the first-run answers, the topics already here (own and
  /// built-in, so nothing is written twice) and the last week's results.
  ///
  /// [lookup] resolves a scene id to its scene for the built-ins, which are
  /// not in the database; the mistakes are described by the line that was
  /// misheard, so the AI can aim at that kind of line.
  // ------------------------------------------------------------------ fields

  /// How many fields can still be opened for nothing: the first
  /// [freeRealmSlots] are free, whenever they are opened.
  Future<int> freeFieldSlotsLeft() async {
    final open = (await realms()).where((r) => r.unlocked).length;
    return (freeRealmSlots - open).clamp(0, freeRealmSlots);
  }

  /// Opens a field: free while free slots remain, for Seeds after that.
  /// Returns false, spending nothing, when the balance is short.
  Future<bool> openField(String realmId) async {
    final all = await realms();
    final row = all.where((r) => r.id == realmId).firstOrNull;
    if (row == null) return false;
    if (row.unlocked) return true;
    if (all.where((r) => r.unlocked).length < freeRealmSlots) {
      await markRealmsUnlocked([realmId]);
      return true;
    }
    return unlockRealm(realmId);
  }

  /// How a field is described to the AI, in English: the built-in four by
  /// their fixed description, a field the learner added by its name and the
  /// contexts the AI once attached to it.
  Future<String> fieldDescription(String fieldId) async {
    if (builtinFieldIds.contains(fieldId)) return interestDescription(fieldId);
    final realm = (await realms()).where((r) => r.id == fieldId).firstOrNull;
    if (realm == null) return fieldId;
    final contexts = realm.contexts.where((c) => c.trim().isNotEmpty).take(3).toList();
    return contexts.isEmpty ? realm.name : '${realm.name} (${contexts.join(', ')})';
  }

  /// Adds a field of the learner's own, paid for with Seeds at the same price
  /// as unlocking an area. Returns the field's realm, or null when the balance
  /// is short and nothing was spent. A name that matches an existing area
  /// unlocks that area instead of making a twin.
  Future<Realm?> addField(String label) async {
    final name = clean(label);
    if (name.isEmpty) return null;
    final key = normKey(name);
    final existing = (await realms()).where((r) => r.normKeyValue == key).firstOrNull;
    if (existing != null && existing.unlocked) return existing;

    final progress = await loadProgress();
    if (progress.seeds < realmUnlockCost) return null;
    final realm = existing?.copyWith(unlocked: true) ??
        Realm(
          id: slugId('realm', key),
          name: name,
          nameNative: name,
          normKeyValue: key,
          unlocked: true,
        );
    await db.transaction(() async {
      await db.into(db.realms).insertOnConflictUpdate(realmToRow(realm));
      await saveProgress(progress.copyWith(seeds: progress.seeds - realmUnlockCost));
    });
    return realm;
  }

  Future<String> scenesPromptText({
    required String uiLanguage,
    List<String> extraTopics = const [],
    Map<String, Scene> lookup = const {},
    int scenes = 5,
    String? field,
  }) async {
    final profile = await loadProfile();
    final settings = await loadSettings();
    final results = await sceneResults();
    final stats = skillStats(results, today: today());
    final own = await this.scenes(includeDisabled: true);
    final all = {for (final s in own) s.id: s, ...lookup};

    // The most recent misses, described by their lines. Gist misses are
    // mishearings; reply misses are the same thing one step later.
    final tendencies = <String>[];
    for (final r in results.reversed) {
      if (tendencies.length >= 6) break;
      if (r.gistOk && r.replyOk) continue;
      final line = all[r.sceneId]?.exchanges.elementAtOrNull(r.exchange)?.line;
      if (line == null) continue;
      tendencies.add(
          '${r.gistOk ? 'chose a reply to a misheard version of' : 'misheard'}: "$line"');
    }

    final areas = [for (final r in await realms()) if (r.unlocked) r.label];
    final week = stats.week;
    return pr.scenesPrompt(
      uiLanguage: uiLanguage,
      level: profile?.englishLevel ?? 'A2',
      ageBand: ageBandDescription(settings.ageBand),
      roles: profile?.roles ?? const [],
      priorities: uniqueBy(
        [...?profile?.learningPriorities, ...settings.interests.map(interestDescription)],
        normKey,
      ),
      areas: areas,
      field: field == null ? '' : await fieldDescription(field),
      existingTopics: uniqueBy([for (final s in own) s.topic, ...extraTopics], normKey),
      difficulty: switch (difficultyFor(stats)) {
        'harder' => pr.SceneDifficulty.harder,
        'easier' => pr.SceneDifficulty.easier,
        _ => pr.SceneDifficulty.easy,
      },
      recent: week.gist.of == 0
          ? null
          : (gistPct: week.gist.pct ?? 0, replyPct: week.reply.pct ?? 0, exchanges: week.gist.of),
      tendencies: tendencies,
      scenes: scenes,
    );
  }

  // ------------------------------------------------------------ export/import

  static const backupVersion = '1.0';

  Future<Map<String, dynamic>> exportAll() async {
    Future<List<Map<String, dynamic>>> dump(String table) async {
      final rows = await db.customSelect('SELECT * FROM $table').get();
      return rows.map((r) => r.data).toList();
    }

    return {
      'app': 'kotolang',
      'backup_version': backupVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'data': {
        for (final t in [
          'realms',
          'items',
          'sentences',
          'questions',
          'srs_states',
          'question_stats',
          'histories',
          'batches',
          'meta',
          'chunks',
          'debates',
          'attempts',
          'captures',
          'failures',
          'scenes',
          'scene_results',
          'reviews',
        ])
          t: await dump(t),
      },
    };
  }

  /// Merge restore: existing rows with the same key are overwritten, everything
  /// else is left alone. Never silently drops data the file does not mention.
  Future<int> restore(Map<String, dynamic> payload) async {
    if (payload['app'] != 'kotolang') {
      throw const FormatException('not a KotoLang backup');
    }
    final data = payload['data'];
    if (data is! Map) throw const FormatException('backup has no data');

    var restored = 0;
    await db.transaction(() async {
      for (final entry in data.entries) {
        final table = '${entry.key}';
        final rows = entry.value;
        if (rows is! List) continue;
        for (final row in rows) {
          if (row is! Map) continue;
          final cols = row.keys.map((k) => '"$k"').join(', ');
          final marks = List.filled(row.length, '?').join(', ');
          await db.customStatement(
            'INSERT OR REPLACE INTO $table ($cols) VALUES ($marks)',
            row.values.toList(),
          );
          restored++;
        }
      }
    });
    return restored;
  }

  // ------------------------------------------------------------- maintenance

  /// Recomputes hasMaterial from what is actually stored, rather than trusting
  /// a flag that could drift after a partial delete.
  Future<int> repairRealmFlags() async {
    final counts = <String, int>{};
    for (final s in await sentences()) {
      counts[s.realmId] = (counts[s.realmId] ?? 0) + 1;
    }
    var fixed = 0;
    for (final r in await realms()) {
      final should = (counts[r.id] ?? 0) > 0;
      if (r.hasMaterial != should) {
        await (db.update(db.realms)..where((t) => t.id.equals(r.id)))
            .write(RealmsCompanion(hasMaterial: Value(should)));
        fixed++;
      }
    }
    return fixed;
  }

  /// Language the most recent material import was generated in, so the settings
  /// screen can warn when it no longer matches the interface language.
  Future<String?> lastMaterialLanguage() async {
    final row = await (db.select(db.batches)
          ..where((t) => t.kind.equals('material'))
          ..orderBy([(t) => OrderingTerm.desc(t.at)])
          ..limit(1))
        .getSingleOrNull();
    final code = row?.language ?? '';
    return code.isEmpty ? null : code;
  }

  String languageLabel(String code) => languageFor(code).endonym;
}
