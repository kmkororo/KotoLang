/// The two skills the app exists for, read off the exchange results.
///
/// Understanding: did the learner catch what was said — and by ear alone?
/// Replying: did they pick the reply that answers what was actually said?
/// Nothing here is stored; every figure is a reading of the results, so a
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

/// The two skills over one span of results.
class SkillPair {
  final Rate gist;
  final Rate reply;

  /// Gist answered right with the words hidden.
  final Rate byEar;
  const SkillPair({required this.gist, required this.reply, required this.byEar});

  static const empty = SkillPair(gist: Rate(0, 0), reply: Rate(0, 0), byEar: Rate(0, 0));
}

class SkillStats {
  /// Exchanges answered in total, scenes finished (exchanges / 2, reviews
  /// excluded), and exchanges answered today.
  final int exchanges;
  final int scenes;
  final int today;

  final SkillPair all;
  final SkillPair week;

  /// Calendar days with at least one exchange, for the streak strip and the
  /// heatmap.
  final Map<String, int> perDay;

  /// The runs of right answers, now and at their longest.
  final Runs runs;

  const SkillStats({
    required this.exchanges,
    required this.scenes,
    required this.today,
    required this.all,
    required this.week,
    required this.perDay,
    this.runs = Runs.none,
  });

  static const empty = SkillStats(
    exchanges: 0,
    scenes: 0,
    today: 0,
    all: SkillPair.empty,
    week: SkillPair.empty,
    perDay: {},
  );

  Set<String> get days => perDay.keys.toSet();
}

SkillPair _pair(Iterable<SceneResult> rs) {
  var n = 0, gist = 0, reply = 0, ear = 0;
  for (final r in rs) {
    n++;
    if (r.gistOk) gist++;
    if (r.replyOk) reply++;
    if (r.gistOk && !r.peeked) ear++;
  }
  return SkillPair(gist: Rate(gist, n), reply: Rate(reply, n), byEar: Rate(ear, n));
}

/// Runs of right answers, read straight off the results: the run the learner
/// is on now and the longest ever. `combo` counts every answer (gist and
/// reply alike); `byEar` counts gists caught without looking at the words.
class Runs {
  final int combo;
  final int bestCombo;
  final int byEar;
  final int bestByEar;
  const Runs({this.combo = 0, this.bestCombo = 0, this.byEar = 0, this.bestByEar = 0});
  static const none = Runs();
}

Runs runsOf(List<SceneResult> results) {
  final ordered = [...results]..sort((a, b) => a.at.compareTo(b.at));
  var combo = 0, bestCombo = 0, ear = 0, bestEar = 0;
  for (final r in ordered) {
    for (final ok in [r.gistOk, r.replyOk]) {
      combo = ok ? combo + 1 : 0;
      if (combo > bestCombo) bestCombo = combo;
    }
    ear = r.gistOk && !r.peeked ? ear + 1 : 0;
    if (ear > bestEar) bestEar = ear;
  }
  return Runs(combo: combo, bestCombo: bestCombo, byEar: ear, bestByEar: bestEar);
}

SkillStats skillStats(List<SceneResult> results, {required String today}) {
  if (results.isEmpty) return SkillStats.empty;
  final weekStart = addDays(today, -6);
  final perDay = <String, int>{};
  for (final r in results) {
    perDay[r.day] = (perDay[r.day] ?? 0) + 1;
  }
  return SkillStats(
    exchanges: results.length,
    scenes: results.where((r) => !r.review).length ~/ exchangesPerScene,
    today: perDay[today] ?? 0,
    all: _pair(results),
    week: _pair(results.where((r) => r.day.compareTo(weekStart) >= 0)),
    perDay: perDay,
    runs: runsOf(results),
  );
}

/// What the next set of scenes should be pitched at, from the last week.
/// High and plenty of them: a step harder. Low: easier. Otherwise, and for
/// anyone new, easy — where everyone starts.
String difficultyFor(SkillStats s) {
  final w = s.week;
  if (w.gist.of < 8) return 'easy';
  final avg = ((w.gist.pct ?? 0) + (w.reply.pct ?? 0)) / 2;
  if (avg >= 85) return 'harder';
  if (avg < 50) return 'easier';
  return 'easy';
}
