/// What the record screen says, read off the answers themselves.
///
/// One thing is being measured now, not two: did the reply that fits get
/// chosen, and was it chosen while the conversation was still moving.
/// Nothing here is stored — every figure is a reading of the results, so a
/// restored backup shows the same numbers and no counter can drift from the
/// record.
library;

import '../core/util.dart';
import 'scene.dart';

/// A rate as a count over a base. `pct` is null while there is nothing to
/// divide, so the screen can say "—" rather than "0%".
class Rate {
  final int hit;
  final int of;
  const Rate(this.hit, this.of);
  int? get pct => of == 0 ? null : (hit * 100 / of).round();
}

/// How one span of answers went.
class SkillPair {
  /// Replies that fitted what was said.
  final Rate right;

  /// Of those, the ones given while the window was still open — without
  /// waiting to be told again. This is the figure that says whether the
  /// learner is keeping up rather than merely arriving.
  final Rate kept;

  const SkillPair({required this.right, required this.kept});

  static const empty = SkillPair(right: Rate(0, 0), kept: Rate(0, 0));
}

class SkillStats {
  /// Turns answered in total, conversations finished, and turns answered
  /// today.
  final int turns;
  final int scenes;
  final int today;

  final SkillPair all;
  final SkillPair week;

  /// Turns answered on each day, for the heat map.
  final Map<String, int> perDay;

  final Runs runs;

  /// How often each fact was the one dropped. A multiFact miss names what it
  /// lost, so the same weakness can be aimed at again.
  final Map<String, int> missedSlots;

  const SkillStats({
    required this.turns,
    required this.scenes,
    required this.today,
    required this.all,
    required this.week,
    required this.perDay,
    required this.runs,
    required this.missedSlots,
  });

  static const empty = SkillStats(
    turns: 0,
    scenes: 0,
    today: 0,
    all: SkillPair.empty,
    week: SkillPair.empty,
    perDay: {},
    runs: Runs.none,
    missedSlots: {},
  );
}

/// Streaks inside the answering itself: right in a row, and kept up in a row.
class Runs {
  final int combo;
  final int bestCombo;
  final int kept;
  final int bestKept;
  const Runs({this.combo = 0, this.bestCombo = 0, this.kept = 0, this.bestKept = 0});
  static const none = Runs();
}

Runs runsOf(List<TurnResult> results) {
  final ordered = [...results]..sort((a, b) => a.at.compareTo(b.at));
  var combo = 0, bestCombo = 0, kept = 0, bestKept = 0;
  for (final r in ordered) {
    combo = r.correct ? combo + 1 : 0;
    if (combo > bestCombo) bestCombo = combo;
    kept = r.correct && r.inWindow ? kept + 1 : 0;
    if (kept > bestKept) bestKept = kept;
  }
  return Runs(combo: combo, bestCombo: bestCombo, kept: kept, bestKept: bestKept);
}

SkillPair _pair(Iterable<TurnResult> rs) {
  final all = rs.toList();
  if (all.isEmpty) return SkillPair.empty;
  final right = all.where((r) => r.correct).toList();
  return SkillPair(
    right: Rate(right.length, all.length),
    kept: Rate(right.where((r) => r.inWindow).length, all.length),
  );
}

SkillStats skillStats(List<TurnResult> results, {required String today}) {
  if (results.isEmpty) return SkillStats.empty;
  final weekStart = addDays(today, -6);
  final perDay = <String, int>{};
  final missed = <String, int>{};
  for (final r in results) {
    perDay[r.day] = (perDay[r.day] ?? 0) + 1;
    final slot = r.missedSlot;
    if (!r.correct && slot != null && slot.isNotEmpty) {
      missed[slot] = (missed[slot] ?? 0) + 1;
    }
  }
  return SkillStats(
    turns: results.length,
    // A conversation is however many turns its author gave it, so finished
    // ones are counted by what was answered rather than divided out of the
    // total.
    scenes: {for (final r in results.where((r) => !r.review)) r.sceneId}.length,
    today: perDay[today] ?? 0,
    all: _pair(results),
    week: _pair(results.where((r) => r.day.compareTo(weekStart) >= 0)),
    perDay: perDay,
    runs: runsOf(results),
    missedSlots: missed,
  );
}

/// How the guesses about what comes next have gone: over everything, and
/// over the last seven days. Kept apart from the replies, because reading
/// where a conversation is going is a different thing from catching what was
/// said.
({Rate all, Rate week}) predictStats(List<TurnResult> predictions, {required String today}) {
  final weekStart = addDays(today, -6);
  Rate of(Iterable<TurnResult> rs) {
    final all = rs.toList();
    return Rate(all.where((r) => r.correct).length, all.length);
  }

  return (
    all: of(predictions),
    week: of(predictions.where((r) => r.day.compareTo(weekStart) >= 0)),
  );
}
