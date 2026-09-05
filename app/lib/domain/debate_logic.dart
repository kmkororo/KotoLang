/// The judgement the app makes on a train, without an AI in reach.
///
/// It cannot say whether a reply was good. What it can say, honestly, is
/// which model reply the learner's came closest to, which moves the strong
/// reply carries that theirs did not, and which tree is most worth opening
/// today. Everything deeper waits for the critique that comes back with the
/// next pack.
library;

import '../core/util.dart';
import 'debate.dart';

// ------------------------------------------------------------- assembling

/// The reply as text, from the chunks tapped in order and the slots filled in.
/// An unfilled slot is left as its marker, so the learner can see the gap.
String assemble(List<Chunk> picked, Map<String, String> slots) {
  final parts = <String>[];
  for (final c in picked) {
    var t = c.text;
    slots.forEach((k, v) {
      t = t.replaceAll('{$k}', v);
    });
    parts.add(t.trim());
  }
  return parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Slot names used across the chunks picked so far, in first-seen order.
List<String> slotsIn(List<Chunk> picked) {
  final out = <String>[];
  for (final c in picked) {
    for (final m in RegExp(r'\{(\w+)\}').allMatches(c.text)) {
      final k = m.group(1)!;
      if (!out.contains(k)) out.add(k);
    }
  }
  return out;
}

/// What the node's model replies would put in the slots — offered as taps so
/// the content can be chosen instead of typed, on a train.
List<String> slotSuggestions(DebateNode node) => uniqueBy(
      [
        for (final r in node.rebuttals)
          for (final v in r.slots.values) v
      ],
      (v) => normKey(v),
    );

// -------------------------------------------------------------- comparing

/// The model reply the learner's came nearest to.
///
/// Two things are compared and the moves count double: the exercise is about
/// the shape of an argument, and two replies that make the same moves in the
/// same order are the same reply to a listener even when the words differ.
/// Word overlap breaks ties, so a reply that borrowed the strong model's
/// content is not credited to the weak one by accident.
Rebuttal closestRebuttal(DebateNode node, String youSaid, List<Move> moves) {
  final saidWords = _words(youSaid);
  Rebuttal? best;
  var bestScore = -1.0;
  for (final r in node.rebuttals) {
    final score = 2 * _jaccard(moves.toSet(), r.moves.toSet()) +
        _jaccard(saidWords, _words(r.model));
    if (score > bestScore) {
      best = r;
      bestScore = score;
    }
  }
  return best ?? node.rebuttals.first;
}

/// The moves the strong reply makes that this one did not, and the ones it
/// did. The check is against the strong reply regardless of which one the
/// learner came closest to: the point is what a good answer here needed.
({List<Move> present, List<Move> missing}) structureCheck(
    DebateNode node, List<Move> moves) {
  final target = node.strongest?.moves ?? const <Move>[];
  final have = moves.toSet();
  return (
    present: [for (final m in target) if (have.contains(m)) m],
    missing: [for (final m in target) if (!have.contains(m)) m],
  );
}

Set<String> _words(String s) =>
    normKey(s).split(' ').where((w) => w.length > 2).toSet();

double _jaccard<T>(Set<T> a, Set<T> b) {
  if (a.isEmpty && b.isEmpty) return 0;
  final inter = a.intersection(b).length;
  return inter / (a.length + b.length - inter);
}

// --------------------------------------------------------------- choosing

/// Which tree to open now.
///
/// The one built for the nearest coming date first, because that is the
/// conversation the learner is actually about to have. Among the rest, the
/// one argued least recently, so a week's trees are all visited rather than
/// the first one worn out. Dates already past no longer pull ahead — the
/// meeting happened — but the tree stays useful as practice.
DebateTree? pickDebate(
  List<DebateTree> trees,
  List<Attempt> attempts, {
  required String today,
}) {
  final open = trees.where((t) => !t.disabled && t.nodes.isNotEmpty).toList();
  if (open.isEmpty) return null;

  final lastArgued = <String, int>{};
  for (final a in attempts) {
    lastArgued[a.debateId] = (lastArgued[a.debateId] ?? 0) > a.at
        ? lastArgued[a.debateId]!
        : a.at;
  }

  int daysAway(DebateTree t) {
    if (t.event == null) return 1 << 20;
    final d = daysBetween(today, t.event!);
    return d < 0 ? 1 << 19 : d; // past, but still ahead of "no date at all"
  }

  open.sort((a, b) {
    final byDate = daysAway(a).compareTo(daysAway(b));
    if (byDate != 0) return byDate;
    return (lastArgued[a.id] ?? 0).compareTo(lastArgued[b.id] ?? 0);
  });
  return open.first;
}

/// The failure kinds the app writes down on its own.
class FailureKind {
  static const weakPointMissed = 'weak_point_missed';
  static const claimMissed = 'claim_missed';
  static const reasonMissed = 'reason_missed';
  static const pressed = 'pressed';
  static String missingMove(Move m) => 'missing_move:${m.name}';
}
