/// Everything the UI is allowed to ask for. Wraps the database and applies the
/// domain rules; no widget touches Drift or the scheduling maths directly.
library;

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../core/l10n/languages.dart';
import '../core/util.dart';
import '../domain/importer.dart' as imp;
import '../domain/models.dart';
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

class SessionSlot {
  final Question question;
  final String? itemId;
  final bool wasDue;
  const SessionSlot(this.question, this.itemId, this.wasDue);
}

class AnswerOutcome {
  final bool correct;
  final int xp;
  final StreakResult streak;
  final Progress progress;
  final SrsState? srsState;
  const AnswerOutcome(this.correct, this.xp, this.streak, this.progress, this.srsState);
}

class HomeCounts {
  final int due;
  final int fresh;
  final int total;
  final int questions;
  const HomeCounts(this.due, this.fresh, this.total, this.questions);
}

// --------------------------------------------------------------- repository

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
          )
        : prevRealm.copyWith(
            nameNative: prevRealm.nameNative.isNotEmpty
                ? prevRealm.nameNative
                : norm.realm.nameNative,
            contexts: prevRealm.contexts.isNotEmpty ? prevRealm.contexts : norm.realm.contexts,
            selected: true,
            hasMaterial: true,
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
    final t = today();

    final due = <String>{}, fresh = <String>{}, total = <String>{};
    for (final q in qs) {
      final key = q.itemId ?? 'sent:${q.sentenceId}';
      total.add(key);
      final st = q.itemId == null ? null : states[q.itemId];
      if (st != null && st.introduced) {
        if (srs.isDue(st, t)) due.add(key);
      } else {
        fresh.add(key);
      }
    }
    return HomeCounts(due.length, fresh.length, total.length, qs.length);
  }

  /// Builds a session. Read-only: nothing is recorded until an answer arrives.
  Future<List<SessionSlot>> buildSession({String? realmId, int count = 5}) async {
    final qs = await _usableQuestions(realmId);
    if (qs.isEmpty) return const [];

    final itemById = {for (final i in await items()) i.id: i};
    final realmById = {for (final r in await realms()) r.id: r};
    final states = {for (final s in await srsStates()) s.itemId: s};
    final recent = <String, int>{};
    final recentList = await _recentSentences();
    for (var i = 0; i < recentList.length; i++) {
      recent[recentList[i]] = i;
    }
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

      // Skip sentences served in the last few sessions; if everything is recent
      // fall back to the least recently used rather than refusing to ask.
      final unseen = candidates.where((q) => !recent.containsKey(q.sentenceId)).toList();
      if (unseen.isNotEmpty) {
        candidates = unseen;
      } else {
        candidates.sort((a, b) =>
            (recent[b.sentenceId] ?? 0).compareTo(recent[a.sentenceId] ?? 0));
        candidates = take(candidates, 3);
      }

      final chosen = sample(candidates, r);
      if (chosen == null) continue;

      usedSentences.add(chosen.sentenceId);
      picked.add(SessionSlot(chosen, g.itemId, g.due));
      lastType = chosen.type;
    }

    return picked;
  }

  /// Records one answer: schedule, per-question stats, history, streak and XP.
  /// The streak advances here rather than at session start, because a day counts
  /// only once a question has actually been answered.
  Future<AnswerOutcome> recordAnswer({
    required Question question,
    required bool correct,
    required bool wasDue,
    int boost = 1,
  }) async {
    final t = today();
    SrsState? updated;
    var firstCorrect = false;

    if (question.itemId != null) {
      final existing = await (db.select(db.srsStates)
            ..where((x) => x.itemId.equals(question.itemId!)))
          .getSingleOrNull();
      final state = existing?.toDomain() ?? SrsState.blank(question.itemId!);
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
    final gained = xpFor(question.type, correct, wasDue: wasDue, firstCorrect: firstCorrect) *
        (boost > 1 ? boost : 1);
    final next = streak.progress.copyWith(xpTotal: streak.progress.xpTotal + gained);
    await saveProgress(next);

    return AnswerOutcome(correct, gained, streak.result, next, updated);
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

  Future<void> deleteAllMaterial() async {
    await db.transaction(() async {
      await db.delete(db.questions).go();
      await db.delete(db.questionStats).go();
      await db.delete(db.sentences).go();
      await db.delete(db.items).go();
      await db.delete(db.srsStates).go();
      await (db.delete(db.batches)..where((t) => t.kind.equals('material'))).go();
      await db.update(db.realms).write(const RealmsCompanion(hasMaterial: Value(false)));
    });
    await _delMeta('recentSentences');
  }

  /// Keeps the material, forgets how far the learner got with it.
  Future<void> resetProgress() async {
    await db.transaction(() async {
      await db.delete(db.srsStates).go();
      await db.delete(db.questionStats).go();
      await db.delete(db.histories).go();
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
    });

    if (lang != null) await saveUiLanguage(lang);
    if (settings != null) await saveSettings(settings);
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
