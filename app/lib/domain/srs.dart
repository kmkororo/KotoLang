/// Spaced repetition, ported from the web app's `srs.js`.
///
/// Scheduling is tracked per [LearningItem], not per question: the item is what
/// the learner is memorising, and the four formats are different ways of
/// probing the same knowledge.
///
/// Boxes and intervals:
///   box 0 -> due tomorrow   (new, or just failed)
///   box 1 -> +1 day
///   box 2 -> +3 days
///   box 3 -> +7 days
///   box 4 -> +16 days
///   box 5 -> +35 days
///
/// Recognition gate: an item cannot climb past box 3 on multiple choice alone.
/// Picking from four options is recognition; typing or rebuilding the phrase is
/// production. Without one correct production answer the item stays at box 3,
/// so "I only ever tapped the right button" never counts as mastered.
library;

import 'dart:math';

import '../core/util.dart';
import 'models.dart';

const srsIntervals = [1, 1, 3, 7, 16, 35];
const maxBox = 5;
const recognitionCap = 3;

/// How often each format should come round relative to the others. Comparing
/// attempts/weight means a heavier format needs proportionally more attempts
/// before the rotation moves on.
///
/// KotoLang is listening-first: understanding the main idea and choosing the
/// right response matter more than any other skill here, so `gist` and
/// `reply` lead by a wide margin rather than a narrow one. `produce` still
/// outweighs `reorder` for the same reason as before — it asks the same thing
/// without playing the sentence first, which makes it the harder and more
/// useful of the two.
const formatWeight = <QuestionType, double>{
  QuestionType.gist: 3.0,
  QuestionType.reply: 3.0,
  QuestionType.paraphrase: 1.6,
  QuestionType.produce: 1.2,
  QuestionType.dictation: 0.8,
  QuestionType.register: 0.6,
  QuestionType.reorder: 0.4,
};

bool isProduction(QuestionType t) => productionTypes.contains(t);

bool hasProductionEvidence(SrsState s) =>
    productionTypes.any((t) => s.statFor(t).ok > 0);

int intervalFor(int box) => srsIntervals[clampInt(box, 0, maxBox)];

/// Applies one answer and returns the updated state. The caller persists it.
SrsState applyAnswer(
  SrsState state,
  QuestionType type,
  bool correct, {
  String? sentenceId,
  String? at,
}) {
  final now = at ?? today();

  final formats = Map<QuestionType, FormatStat>.from(state.formats);
  formats[type] = state.statFor(type).plus(correct);

  var box = state.box;
  var lapses = state.lapses;
  var held = false;

  if (correct) {
    var next = min(box + 1, maxBox);
    // Recognition gate: hold at the cap until production is demonstrated.
    // The updated format tallies are used, so the answer that first proves
    // production immediately releases the gate.
    final proven = productionTypes.any((t) => (formats[t] ?? const FormatStat()).ok > 0);
    if (next > recognitionCap && !proven) {
      next = recognitionCap;
      held = true;
    }
    box = next;
  } else {
    // A miss on production is a real lapse. A miss on recognition says the item
    // is weaker than its box suggests, so drop it further than one step.
    lapses += 1;
    box = isProduction(type) ? 0 : max(0, min(box, 1) - 1);
  }

  return state.copyWith(
    box: box,
    due: addDays(now, intervalFor(box)),
    reps: state.reps + 1,
    lapses: lapses,
    lastResult: correct ? 'correct' : 'wrong',
    lastSeen: now,
    introduced: true,
    heldByGate: held,
    lastSentenceId: sentenceId ?? state.lastSentenceId,
    formats: formats,
  );
}

bool isDue(SrsState? s, [String? day]) {
  if (s == null || s.due.isEmpty) return false;
  return daysBetween(s.due, day ?? today()) >= 0;
}

/// An item counts as mastered only at the top box, which the gate makes
/// unreachable without production evidence.
bool isMastered(SrsState? s) => s != null && s.box >= maxBox;

({int n, int ok, int pct}) accuracy(SrsState s) {
  var n = 0, ok = 0;
  for (final t in QuestionType.values) {
    final f = s.statFor(t);
    n += f.n;
    ok += f.ok;
  }
  return (n: n, ok: ok, pct: percent(ok, n));
}

/// Which format to probe next.
///
/// A brand new item is chosen by weight, so every format stays reachable — a
/// purely deterministic choice once made reorder unreachable entirely. An item
/// in circulation goes to whichever format is furthest behind its weight.
QuestionType? preferredFormat(SrsState? state, List<QuestionType> available, [Random? rng]) {
  if (available.isEmpty) return null;

  // Shuffle first so formats tied on attempts are broken randomly; Dart's sort
  // is stable, so the shuffled order survives.
  final pool = shuffled(available, rng);

  if (state == null || !state.introduced) {
    return weightedPick(pool, (t) => formatWeight[t] ?? 1.0, rng);
  }

  // Once recognition is capped, push production formats explicitly.
  if (state.box >= recognitionCap && !hasProductionEvidence(state)) {
    final prod = pool.where(isProduction).toList();
    if (prod.isNotEmpty) return prod.first;
  }

  pool.sort((a, b) {
    final ra = state.statFor(a).n / (formatWeight[a] ?? 1.0);
    final rb = state.statFor(b).n / (formatWeight[b] ?? 1.0);
    return ra.compareTo(rb);
  });
  return pool.first;
}

/// Selection priority, highest first:
///   1. reviews that have come due
///   2. items currently being answered wrongly
///   3. material never studied yet
///   4. everything else, climbing only as it goes stale
///
/// Rank 3 above rank 4 is what keeps sessions varied. An item answered today is
/// not due again for at least a day; when such items outranked untouched
/// material the planner drilled the same handful forever and never introduced
/// the rest, which made every session feel like the same few sentences.
int priority(SrsState? state, LearningItem? item, Realm? realm, [String? day]) {
  final now = day ?? today();
  final imp = realm?.importance ?? 3;

  if (state != null && isDue(state, now)) {
    final overdue = daysBetween(state.due, now); // 0 = due today
    return 10000 + min(overdue, 60) * 10 + imp;
  }

  if (state != null && state.introduced) {
    final acc = accuracy(state);
    if (acc.n >= 2 && acc.pct < 60) return 5000 + (60 - acc.pct) * 10 + imp;
    final idle = state.lastSeen != null ? daysBetween(state.lastSeen!, now) : 0;
    return 100 + min(idle, 90) * 4 + imp;
  }

  return 500 + imp * 10 + (item?.priority ?? 3);
}

int dueCount(Iterable<SrsState> states, [String? day]) {
  final now = day ?? today();
  return states.where((s) => s.introduced && isDue(s, now)).length;
}
