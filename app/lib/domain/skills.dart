/// The two skills the app exists for, read off the exchange log.
///
/// Understanding: did the learner catch what the opponent said — claim,
/// reason, weak point — and by ear alone? Arguing back: did the reply come
/// nearest to the strong model, carry the strong reply's shape, and how did
/// the arguments end? Nothing here is stored; every figure is a reading of
/// attempts and the slips written down beside them, so a restored backup
/// shows the same numbers and no counter can drift from the record.
library;

import 'debate.dart';
import 'debate_logic.dart';

/// A rate as a count over a base. `pct` is null while there is nothing to
/// divide, so the screen can say "—" rather than "0%".
class Rate {
  final int hit;
  final int of;
  const Rate(this.hit, this.of);
  int? get pct => of == 0 ? null : (hit * 100 / of).round();
}

class SkillStats {
  /// Exchanges argued, in total and today.
  final int exchanges;
  final int today;

  // ---- understanding
  final Rate claim;
  final Rate reason;
  final Rate weakPoint;

  /// Exchanges where the line was caught with the words hidden.
  final Rate byEar;

  // ---- arguing back
  /// Replies that came nearest to the strong model.
  final Rate strong;

  /// Replies carrying every move of the strong model.
  final Rate fullShape;

  /// How many replies made each move, over all exchanges.
  final Map<Move, int> moves;

  /// How the arguments that reached a leaf ended.
  final Map<Outcome, int> outcomes;

  /// Calendar days with at least one exchange.
  final Set<String> days;

  const SkillStats({
    required this.exchanges,
    required this.today,
    required this.claim,
    required this.reason,
    required this.weakPoint,
    required this.byEar,
    required this.strong,
    required this.fullShape,
    required this.moves,
    required this.outcomes,
    required this.days,
  });

  static const empty = SkillStats(
    exchanges: 0,
    today: 0,
    claim: Rate(0, 0),
    reason: Rate(0, 0),
    weakPoint: Rate(0, 0),
    byEar: Rate(0, 0),
    strong: Rate(0, 0),
    fullShape: Rate(0, 0),
    moves: {},
    outcomes: {},
    days: {},
  );
}

/// A slip belongs to the exchange it was written beside: same tree, same
/// line, and within this many milliseconds of the attempt. The two are
/// written one after the other, so the gap is a few milliseconds in practice;
/// the window is wide only so a slow disk cannot separate them.
const _slipWindowMs = 15000;

SkillStats skillStats({
  required List<Attempt> attempts,
  required List<Failure> failures,
  required Map<String, DebateTree> trees,
  required String today,
}) {
  if (attempts.isEmpty) return SkillStats.empty;

  var claimHit = 0, reasonHit = 0, weakHit = 0, byEar = 0, strong = 0, shape = 0;
  final moves = <Move, int>{};
  final outcomes = <Outcome, int>{};
  final days = <String>{};
  var todayCount = 0;

  for (final a in attempts) {
    final kinds = <String>{
      for (final f in failures)
        if (f.debateId == a.debateId &&
            f.nodeId == a.nodeId &&
            (f.at - a.at).abs() <= _slipWindowMs)
          f.kind
    };
    if (!kinds.contains(FailureKind.claimMissed)) claimHit++;
    if (!kinds.contains(FailureKind.reasonMissed)) reasonHit++;
    if (!kinds.contains(FailureKind.weakPointMissed)) weakHit++;
    if (!kinds.contains(FailureKind.peeked)) byEar++;
    if (a.closestStrength == Strength.strong) strong++;
    if (!kinds.any((k) => k.startsWith('missing_move:'))) shape++;
    for (final m in a.moves) {
      moves[m] = (moves[m] ?? 0) + 1;
    }
    days.add(a.day);
    if (a.day == today) todayCount++;

    // The outcome is not stored on the attempt: it is what the tree says the
    // closest reply leads to, and only a leaf ends anything.
    final r = trees[a.debateId]
        ?.node(a.nodeId)
        ?.rebuttals
        .where((r) => r.id == a.closest)
        .firstOrNull;
    if (r != null && r.isLeaf) {
      final o = r.outcome ?? Outcome.forStrength(r.strength);
      outcomes[o] = (outcomes[o] ?? 0) + 1;
    }
  }

  final n = attempts.length;
  return SkillStats(
    exchanges: n,
    today: todayCount,
    claim: Rate(claimHit, n),
    reason: Rate(reasonHit, n),
    weakPoint: Rate(weakHit, n),
    byEar: Rate(byEar, n),
    strong: Rate(strong, n),
    fullShape: Rate(shape, n),
    moves: moves,
    outcomes: outcomes,
    days: days,
  );
}

/// Seeds for reporting that a reply was used in a real conversation. The
/// largest single payment in the app, because it is the only one for
/// something that happened outside it.
const claimUsedSeeds = 25;
