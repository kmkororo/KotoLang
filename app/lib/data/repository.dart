/// Everything the UI is allowed to ask for. Wraps the database and applies the
/// domain rules; no widget touches Drift or the scheduling maths directly.
library;

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../core/l10n/languages.dart';
import '../core/util.dart';
import '../domain/importer.dart' as imp;
import '../domain/field.dart';
import '../domain/models.dart';
import '../domain/prompts.dart' as pr;
import '../domain/scene.dart';
import '../domain/ladder.dart';
import '../domain/set_import.dart';
import '../domain/set_prompts.dart' as sp;
import '../domain/skills.dart';
import '../domain/progress_service.dart';
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
  final List<({String title, String reason})> rejected;
  final bool partial;

  /// What it cost, if anything. Nought for the first batch in a field.
  final int spent;

  /// Refused for want of Seeds, with the price. Told apart from a reply that
  /// would not parse, because there is nothing wrong with the reply and
  /// nothing to do about it but earn.
  final int shortOf;

  /// Taken, but worth a word — the summaries came back in English.
  final List<String> warnings;

  const SceneOutcome({
    required this.ok,
    this.errors = const [],
    this.scenes = 0,
    this.rejected = const [],
    this.partial = false,
    this.spent = 0,
    this.shortOf = 0,
    this.warnings = const [],
  });

  const SceneOutcome.failure(this.errors)
      : ok = false,
        scenes = 0,
        rejected = const [],
        partial = false,
        spent = 0,
        shortOf = 0,
        warnings = const [];

  /// Nothing wrong with the reply; there is just nothing to pay with.
  const SceneOutcome.tooDear(this.shortOf)
      : ok = false,
        errors = const ['too dear'],
        scenes = 0,
        rejected = const [],
        partial = false,
        spent = 0,
        warnings = const [];
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
      windowScale:
          offeredWindowScale(((j['windowScale'] ?? 1.0) as num).toDouble()),
      partnerVoice: (j['partnerVoice'] ?? '') as String,
      yourVoice: (j['yourVoice'] ?? '') as String,
      coachSeen: (j['coachSeen'] ?? false) as bool,
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
        'partnerVoice': s.partnerVoice,
        'yourVoice': s.yourVoice,
        'coachSeen': s.coachSeen,
        'haptics': s.haptics,
        'ageBand': s.ageBand,
        'interests': s.interests,
        'tutorialDone': s.tutorialDone,
        'voicePerScene': s.voicePerScene,
        'windowScale': s.windowScale,
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

  /// Where the learner stands on the five axes. Kept beside the progress
  /// rather than in a table of its own: it is read and written whole, and
  /// only ever one of them.
  Future<Ladder> loadLadder() async {
    final raw = await _meta('ladder');
    if (raw == null) return Ladder.empty;
    return Ladder.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveLadder(Ladder l) => _setMeta('ladder', jsonEncode(l.toJson()));

  Future<UserProfile?> loadProfile() async {
    final raw = await _meta('profile');
    if (raw == null) return null;
    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _saveProfile(UserProfile p) => _setMeta('profile', jsonEncode(p.toJson()));

  /// Opens fields outright, with nothing asked for them.
  Future<void> markRealmsUnlocked(List<String> ids) async {
    if (ids.isEmpty) return;
    await (db.update(db.realms)..where((t) => t.id.isIn(ids)))
        .write(const RealmsCompanion(unlocked: Value(true)));
  }

  // ---------------------------------------------------------------- reading

  Future<List<Realm>> realms() async {
    final rows = await db.select(db.realms).get();
    final list = rows.map((r) => r.toDomain()).toList()
      ..sort((a, b) => b.importance.compareTo(a.importance));
    return list;
  }

  /// How much there is, for the record screen and the resets.
  Future<({int realms, int scenes, int answered})> counts() async {
    Future<int> n(TableInfo t) async =>
        (await db.customSelect('SELECT COUNT(*) AS c FROM ${t.actualTableName}').getSingle())
            .read<int>('c');
    return (
      realms: await n(db.realms),
      scenes: await n(db.scenes),
      answered: await n(db.sceneResults),
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
    });
    await _saveProfile(norm.profile);

    // The areas the AI read off the profile are the learner's fields. None
    // opens by itself: the learner chooses the starting ones on the next
    // screen, through [chooseFields].

    return ImportOutcome(ok: true, realms: toWrite.length, partial: ex.repaired);
  }

  // ------------------------------------------------------------------ resets

  /// What clearing a field would take with it, said before anything is
  /// touched.
  Future<({int scenes, int answered})> planFieldClear(String realmId) async {
    final mine = [
      for (final s in await scenes(includeDisabled: true))
        if (fieldOf(s) == realmId) s.id
    ];
    final answered = (await turnResults()).where((r) => mine.contains(r.sceneId)).length;
    return (scenes: mine.length, answered: answered);
  }

  /// Clears one field: its conversations and the record of answering them.
  ///
  /// The conversations are what the field is. Leaving the answers behind
  /// would keep the record full and the tree grown with nothing standing
  /// under either of them.
  ///
  /// With [closeField] the field itself is shut rather than destroyed: the
  /// area came off the profile and stays on the list it came from, so it can
  /// be opened again. Deleting the row would put it out of reach for good.
  Future<void> clearField(String realmId, {bool closeField = false}) async {
    final mine = [
      for (final s in await scenes(includeDisabled: true))
        if (fieldOf(s) == realmId) s.id
    ];
    await db.transaction(() async {
      for (final id in mine) {
        await (db.delete(db.scenes)..where((t) => t.id.equals(id))).go();
        await (db.delete(db.sceneResults)..where((t) => t.sceneId.equals(id))).go();
        await (db.delete(db.reviews)..where((t) => t.sceneId.equals(id))).go();
      }
      await (db.update(db.realms)..where((t) => t.id.equals(realmId))).write(
        RealmsCompanion(
          hasMaterial: const Value(false),
          unlocked: Value(!closeField),
        ),
      );
    });
  }

  /// Every conversation, and the answers that were about them.
  Future<void> clearEveryField() async {
    await db.transaction(() async {
      await db.delete(db.scenes).go();
      await db.delete(db.sceneResults).go();
      await db.delete(db.reviews).go();
      await db.update(db.realms).write(const RealmsCompanion(hasMaterial: Value(false)));
    });
  }

  /// Keeps the conversations, forgets how they were answered — and with them
  /// the ladder, since a step is a claim about answers that no longer exist.
  Future<void> forgetAnswers() async {
    await db.transaction(() async {
      await db.delete(db.sceneResults).go();
      await db.delete(db.reviews).go();
    });
    // The streak counted days of answering that are gone, and the ladder was
    // a claim about those same answers. The fields stay open: the ladder that
    // opened them is being forgotten too, and shutting a field the learner is
    // in the middle of would be a punishment for tidying up.
    await saveProgress(const Progress());
    await saveLadder(Ladder.empty);
  }

  /// Clears what the profile produced: the fields, the conversations written
  /// for them, and the answers about those.
  Future<void> resetProfileAndFields() async {
    await db.transaction(() async {
      await db.delete(db.realms).go();
      await db.delete(db.scenes).go();
      await db.delete(db.sceneResults).go();
      await db.delete(db.reviews).go();
    });
    await _delMeta('profile');
    // Every field is gone, so the ones that open for nothing are owed again,
    // and the streak counted days of answering that are gone with them. The
    // ladder measured those same answers.
    await saveProgress(const Progress());
    await saveLadder(Ladder.empty);
  }

  /// Back to a first run. The interface language is kept unless
  /// [keepLanguage] is false, so nobody is dropped into a language they
  /// cannot read.
  Future<void> factoryReset({bool keepLanguage = true}) async {
    final lang = keepLanguage ? await loadUiLanguage() : null;
    await db.transaction(() async {
      await db.delete(db.realms).go();
      await db.delete(db.scenes).go();
      await db.delete(db.sceneResults).go();
      await db.delete(db.reviews).go();
      await db.delete(db.meta).go();
    });
    if (lang != null) await saveUiLanguage(lang);
  }

  // ------------------------------------------------------------------ scenes
  //
  // Read the replies, hear the line once, answer inside the window. The
  // conversations the learner's own AI wrote live here; the built-in ones
  // ship with the app and are merged in above this layer, so everything
  // below is about their own material and their own answers.

  Future<List<Scene>> scenes({bool includeDisabled = false}) async {
    final rows = await (db.select(db.scenes)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return [
      for (final r in rows)
        if (includeDisabled || !r.disabled) r.toDomain()
    ];
  }

  Future<void> setSceneDisabled(String id, bool disabled) =>
      (db.update(db.scenes)..where((t) => t.id.equals(id)))
          .write(ScenesCompanion(disabled: Value(disabled)));

  /// A reply pasted in. Sound conversations are stored — one pasted twice
  /// lands on itself — and the ones that could not be made sound are named
  /// with the reason, because the learner pasted them and "3 of 5" with no
  /// explanation would leave them wondering what they did wrong.
  ///
  /// [field] is the field they asked for; every conversation in the reply
  /// lands there. [situation] is the finer unit inside it, when the reply was
  /// asked for by situation rather than by field.
  Future<SceneOutcome> importScenes(String raw,
      {required String uiLanguage, String? field, String? situation}) async {
    final ex = imp.extractJson(raw);
    if (!ex.ok) return SceneOutcome.failure([ex.failure == 'empty' ? 'empty' : 'parse']);

    // Sets are the only questions there are now. A reply in the conversation
    // shape of before is told apart from one that is not a reply at all, so
    // the learner knows the prompt they used is out of date.
    if (!isSetsReply(ex.data!)) {
      final v = imp.validate(ex.data!);
      return SceneOutcome.failure([v.type == 'scenes' ? 'old format' : 'not a scenes reply']);
    }

    final norm = normaliseSets(ex.data!, uiLanguage: uiLanguage);
    final batch = clean(ex.data!['batch']);
    final rejected = [
      for (final r in norm.rejected) (title: r.title, reason: r.reasons.join('; '))
    ];

    // What was refused is kept, with why, so it can be handed back to the AI
    // to be mended. A reply that is all sound clears it.
    if (norm.rejected.isEmpty) {
      await _delMeta('pendingFix');
    } else {
      await _setMeta(
          'pendingFix',
          jsonEncode({
            'field': field,
            'batch': batch,
            'items': [
              for (final r in norm.rejected) {'raw': r.raw, 'reasons': r.reasons}
            ],
          }));
    }

    if (norm.sets.isEmpty) {
      return SceneOutcome(
        ok: false,
        errors: const ['no usable scene'],
        rejected: rejected,
        partial: ex.repaired,
        warnings: norm.warnings,
      );
    }

    // Paid for once per batch, here rather than on the screen that asks for
    // it, so a reply arriving through the share sheet is charged the same as
    // one pasted in. The rest of a batch — after "continue", or mended — is
    // the same batch and costs nothing more. The first batch in a field is
    // free: a field with nothing in it is not yet a field.
    final paid = await _paidBatches();
    final again = batch.isNotEmpty && paid.contains(batch);
    final cost = again ? 0 : await sceneAddCostFor(field);
    if (cost > 0 && !await spendSeeds(cost)) {
      return SceneOutcome.tooDear(cost - (await loadProgress()).seeds);
    }
    if (batch.isNotEmpty && !again) {
      await _setMeta('paidBatches', jsonEncode([...paid.take(49), batch]));
    }

    await db.transaction(() async {
      for (final s in norm.sets) {
        await db.into(db.scenes).insertOnConflictUpdate(sceneToRow(
              s.copyWith(realmId: field, situation: situation),
            ));
      }
    });

    return SceneOutcome(
      ok: true,
      scenes: norm.sets.length,
      rejected: rejected,
      partial: ex.repaired,
      spent: cost,
      warnings: norm.warnings,
    );
  }

  Future<List<String>> _paidBatches() async {
    final raw = await _meta('paidBatches');
    if (raw == null) return const [];
    final list = jsonDecode(raw);
    return list is List ? [for (final b in list) '$b'] : const [];
  }

  /// The batch a prompt for [field] belongs to: the same one until a reply to
  /// it has been paid for, so the prompt copied and the prompt shown beside
  /// the paste box agree, and a new one after.
  Future<String> _batchFor(String? field) async {
    final key = 'batch:${field ?? ''}';
    final current = await _meta(key);
    if (current != null && !(await _paidBatches()).contains(current)) return current;
    final id = uid('b');
    await _setMeta(key, id);
    return id;
  }

  /// The sets last refused, if any are waiting to be mended.
  Future<({String? field, int count})> pendingFix() async {
    final raw = await _meta('pendingFix');
    if (raw == null) return (field: null, count: 0);
    final j = jsonDecode(raw) as Map;
    return (field: j['field'] as String?, count: (j['items'] as List? ?? const []).length);
  }

  /// The prompt that asks the AI to mend what was refused.
  Future<String?> fixPromptText({required String uiLanguage}) async {
    final raw = await _meta('pendingFix');
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map;
    final items = [
      for (final i in (j['items'] as List? ?? const []))
        if (i is Map)
          (
            raw: Map<String, dynamic>.from(i['raw'] as Map),
            reasons: [for (final r in (i['reasons'] as List? ?? const [])) '$r'],
          )
    ];
    if (items.isEmpty) return null;
    return sp.setsFixPrompt(
        uiLanguage: uiLanguage, batch: '${j['batch'] ?? ''}', rejected: items);
  }

  Future<List<TurnResult>> turnResults() async {
    final rows = await (db.select(db.sceneResults)
          ..where((t) => t.turn.isBiggerOrEqualValue(0))
          ..orderBy([(t) => OrderingTerm.asc(t.at)]))
        .get();
    return [for (final r in rows) r.toDomain()];
  }

  /// Every prediction made, oldest first. Kept beside the replies but never
  /// among them: a guess about what comes next is not an answer, and the
  /// ladder, the combo and the record of replies do not count it.
  Future<List<TurnResult>> predictResults() async {
    final rows = await (db.select(db.sceneResults)
          ..where((t) => t.turn.equals(predictTurn))
          ..orderBy([(t) => OrderingTerm.asc(t.at)]))
        .get();
    return [for (final r in rows) r.toDomain()];
  }

  /// A prediction settled: written down, and paid for when it came true. A
  /// review pays nothing, as a reply on review does not.
  Future<int> recordPrediction(
      {required String sceneId, required bool hit, bool review = false}) async {
    await db.into(db.sceneResults).insert(turnResultToRow(TurnResult(
          sceneId: sceneId,
          turn: predictTurn,
          correct: hit,
          review: review,
          day: today(),
          at: DateTime.now().millisecondsSinceEpoch,
        )));
    if (!hit || review) return 0;
    final p = await loadProgress();
    await saveProgress(p.copyWith(seeds: p.seeds + predictSeeds));
    return predictSeeds;
  }

  /// One turn answered. Written down as it was, and a miss books its reviews:
  /// the next day first, then three days on. A review answered right moves to
  /// the next gap; answered wrong, it comes back tomorrow.
  ///
  /// The ladder is moved here too, since this is the only place an answer
  /// exists. What comes back says which axes went up, so the screen can say
  /// so while the learner is still looking at it.
  Future<({TurnResult result, Ladder ladder, List<LadderAxis> promoted, int seeds})>
      recordTurn({
    required String sceneId,
    required int turn,
    required bool correct,
    String? missedSlot,
    bool inWindow = true,
    bool review = false,
    double windowLeft = 0,
  }) async {
    final day = today();
    final r = TurnResult(
      sceneId: sceneId,
      turn: turn,
      correct: correct,
      missedSlot: missedSlot,
      inWindow: inWindow,
      review: review,
      day: day,
      at: DateTime.now().millisecondsSinceEpoch,
    );
    await db.into(db.sceneResults).insert(turnResultToRow(r));

    final key = (db.select(db.reviews)
      ..where((t) => t.sceneId.equals(sceneId) & t.turn.equals(turn)));
    final existing = await key.getSingleOrNull();

    if (!correct) {
      // Back to the first gap — whether this was the first miss or a review
      // that did not stick.
      await db.into(db.reviews).insertOnConflictUpdate(ReviewsCompanion.insert(
            sceneId: sceneId,
            turn: turn,
            dueDay: addDays(day, reviewGaps[0]),
            stage: const Value(0),
          ));
    } else if (review && existing != null) {
      final next = existing.stage + 1;
      if (next >= reviewGaps.length) {
        await (db.delete(db.reviews)
              ..where((t) => t.sceneId.equals(sceneId) & t.turn.equals(turn)))
            .go();
      } else {
        await (db.update(db.reviews)
              ..where((t) => t.sceneId.equals(sceneId) & t.turn.equals(turn)))
            .write(ReviewsCompanion(
                dueDay: Value(addDays(day, reviewGaps[next])), stage: Value(next)));
      }
    }

    // A review is a second look at something already answered, so it says
    // nothing new about whether this setting can be held, and it is not paid
    // for either: the seeds were paid the first time.
    if (review) {
      final held = await loadLadder();
      return (result: r, ladder: held, promoted: const <LadderAxis>[], seeds: 0);
    }

    // Clean means inside the window, on one hearing. The seeds pay in full
    // only for those; the ladder asks for one thing more, that the answer
    // came fast enough to say something about the ear.
    final moved = (await loadLadder())
        .record(correct, clean: countsToLadder(inWindow: inWindow, windowLeft: windowLeft));
    await saveLadder(moved.ladder);

    final paid = seedsForTurn(correct: correct, clean: inWindow, windowLeft: windowLeft);
    if (paid > 0) {
      final p = await loadProgress();
      await saveProgress(p.copyWith(seeds: p.seeds + paid));
    }
    return (result: r, ladder: moved.ladder, promoted: moved.promoted, seeds: paid);
  }

  /// The turns owed another look today, oldest due first.
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

  /// The results in one of the learner's own fields, as coaching to ask their
  /// AI for. One way: what comes back is prose to read, not material to
  /// import, so nothing here expects a reply.
  Future<String> feedbackPromptText({
    required String uiLanguage,
    required String fieldId,
    required String fieldLabel,
  }) async {
    final profile = await loadProfile();
    final own = await scenes(includeDisabled: true);
    final inField = {for (final s in splitField(own, fieldId).own) s.id: s};
    final results = [
      for (final r in await turnResults()) if (inField.containsKey(r.sceneId)) r
    ];

    var right = 0;
    var firstTime = 0;
    final misses = <({String topic, String line, String? slot})>[];
    for (final r in results) {
      if (r.correct) right++;
      // In the window and right means it was got on one hearing, with no
      // second saying: the only measure here that is about listening rather
      // than about choosing.
      if (r.correct && r.inWindow) firstTime++;
      if (r.correct) continue;
      if (misses.length >= 12) continue;
      final sc = inField[r.sceneId];
      final t = sc?.turns.elementAtOrNull(r.turn);
      if (sc == null || t == null) continue;
      // A named slot says which fact went by them. Nothing named means the
      // line as a whole, or that the window closed with nothing chosen.
      misses.add((topic: sc.label, line: t.line, slot: r.missedSlot));
    }

    final n = results.length;
    return pr.feedbackPrompt(
      uiLanguage: uiLanguage,
      field: fieldLabel,
      level: profile?.englishLevel ?? 'A2',
      scenesDone: {for (final r in results) if (!r.review) r.sceneId}.length,
      rightPct: n == 0 ? 0 : (right * 100 / n).round(),
      firstTimePct: n == 0 ? 0 : (firstTime * 100 / n).round(),
      misses: misses,
    );
  }

  /// A conversation finished: the day counted as studied. Finishing is what
  /// keeps the streak, however the turns went.
  Future<Progress> completeScene() async {
    final streak = registerStudyDay(await loadProgress(), today());
    await saveProgress(streak.progress);
    return streak.progress;
  }

  // ------------------------------------------------------------------ fields

  /// How many fields can still be opened for nothing: the three the learner
  /// chooses at the end of the first run. Read off the fields themselves as
  /// well as the tally, so deleting a field hands its opening back and a
  /// tally that drifted comes right on its own.
  Future<int> fieldOpeningsLeft() async {
    final open = (await realms()).where((r) => r.unlocked).length;
    return (freeRealmSlots - open).clamp(0, freeRealmSlots);
  }

  /// The starting fields, chosen by the learner at the end of the first run.
  Future<void> chooseFields(List<String> realmIds) async {
    if (realmIds.isEmpty) return;
    await markRealmsUnlocked(realmIds);
  }

  /// Opens a field: free while one of the starting three is still owed, for
  /// Seeds after that. Returns false and spends nothing when the balance is
  /// short.
  Future<bool> openField(String realmId) async {
    final all = await realms();
    final row = all.where((r) => r.id == realmId).firstOrNull;
    if (row == null) return false;
    if (row.unlocked) return true;
    if (await fieldOpeningsLeft() <= 0 && !await spendSeeds(realmUnlockCost)) {
      return false;
    }
    await markRealmsUnlocked([realmId]);
    return true;
  }

  /// Takes Seeds off the balance. False when there are not enough, and then
  /// nothing is taken.
  Future<bool> spendSeeds(int n) async {
    if (n <= 0) return true;
    final p = await loadProgress();
    if (p.seeds < n) return false;
    await saveProgress(p.copyWith(seeds: p.seeds - n));
    return true;
  }

  /// What the next batch of conversations costs for this field: nothing the
  /// first time, [sceneAddCost] once the field already has some. Asked before
  /// the reply is taken, since afterwards the field always has some.
  Future<int> sceneAddCostFor(String? fieldId) async {
    if (fieldId == null) return 0;
    final own = await scenes(includeDisabled: true);
    return splitField(own, fieldId).own.any((s) => s.set != null) ? sceneAddCost : 0;
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

  /// Adds a field of the learner's own, at the same price as opening one the
  /// profile named: a field the learner types is still a field. A name that
  /// matches an area already there opens that one instead of making a twin.
  Future<Realm?> addField(String label) async {
    final name = clean(label);
    if (name.isEmpty) return null;
    final key = normKey(name);
    final existing = (await realms()).where((r) => r.normKeyValue == key).firstOrNull;
    if (existing != null && existing.unlocked) return existing;
    if (await fieldOpeningsLeft() <= 0 && !await spendSeeds(realmUnlockCost)) {
      return null;
    }

    final realm = existing?.copyWith(unlocked: true) ??
        Realm(
          id: slugId('realm', key),
          name: name,
          nameNative: name,
          normKeyValue: key,
          unlocked: true,
        );
    await db.into(db.realms).insertOnConflictUpdate(realmToRow(realm));
    return realm;
  }

  Future<String> scenesPromptText({
    required String uiLanguage,
    List<String> extraTopics = const [],
    Map<String, Scene> lookup = const {},
    String? field,
  }) async {
    final profile = await loadProfile();
    final settings = await loadSettings();
    final results = await turnResults();
    final stats = skillStats(results, today: today());
    final own = await scenes(includeDisabled: true);
    final all = {for (final s in own) s.id: s, ...lookup};
    // The most recent misses, described by the line that was misheard, so the
    // next set can aim at that kind of line.
    // mishearings; reply misses are the same thing one step later.
    final tendencies = <String>[];
    for (final r in results.reversed) {
      if (tendencies.length >= 6) break;
      if (r.correct) continue;
      final line = all[r.sceneId]?.turns.elementAtOrNull(r.turn)?.line;
      if (line == null) continue;
      final slot = r.missedSlot;
      tendencies.add(slot == null || slot.isEmpty
          ? 'misheard: "$line"'
          : 'lost the $slot in: "$line"');
    }

    final areas = [for (final r in await realms()) if (r.unlocked) r.label];
    final week = stats.week;
    return sp.setsPrompt(
      uiLanguage: uiLanguage,
      batch: await _batchFor(field),
      level: profile?.englishLevel ?? 'A2',
      ageBand: ageBandDescription(settings.ageBand),
      roles: profile?.roles ?? const [],
      priorities: uniqueBy(
        [...?profile?.learningPriorities, ...settings.interests.map(interestDescription)],
        normKey,
      ),
      areas: areas,
      field: field == null ? '' : await fieldDescription(field),
      existingTopics: uniqueBy([for (final s in own) s.title, ...extraTopics], normKey),
      // No difficulty goes with this. How hard a turn is belongs to the
      // ladder, which moves it by speed, noise, accent and what it takes
      // away; asking the AI to pitch the sentences as well would put two
      // hands on one dial.
      recent: week.right.of == 0
          ? null
          : (
              rightPct: week.right.pct ?? 0,
              firstTimePct: week.kept.pct ?? 0,
              turns: week.right.of,
            ),
      tendencies: tendencies,
    );
  }

  // ------------------------------------------------------------ export/import

  /// Two is the first backup of the rebuilt app. A file from before it names
  /// tables this app no longer has and conversations it cannot play, so it is
  /// refused rather than half-restored.
  static const backupVersion = 2;

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
        for (final t in ['realms', 'scenes', 'scene_results', 'reviews', 'meta'])
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
    // A backup taken before the rebuild describes tables this app no longer
    // has, and conversations in a shape it cannot play. Restoring it row by
    // row would half-fill the new database with nothing playable in it.
    //
    // The old files wrote the version as the string "1.0", so it is read
    // loosely: a field this app cannot make a number of is older than any
    // version it can read, which is the same answer either way.
    final stamp = payload['backup_version'];
    final version = stamp is num
        ? stamp.toInt()
        : int.tryParse('$stamp'.split('.').first) ?? 0;
    if (version < backupVersion) {
      throw const FormatException('backup is from before the rebuild');
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

  /// Recomputes hasMaterial from what is actually stored, rather than
  /// trusting a flag that could drift after a partial delete.
  Future<int> repairRealmFlags() async {
    final counts = <String, int>{};
    for (final s in await scenes(includeDisabled: true)) {
      final id = s.realmId;
      if (id == null) continue;
      counts[id] = (counts[id] ?? 0) + 1;
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

  String languageLabel(String code) => languageFor(code).endonym;
}
