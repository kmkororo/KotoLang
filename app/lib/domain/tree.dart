/// The shape of the growth tree, derived entirely from the answer log and the
/// review schedule.
///
/// Nothing here is stored. The tree is a reading of what the learner has
/// already done, which means it can never drift out of step with the numbers,
/// it survives a backup and restore for free, and the same history always
/// draws the same tree — a tree that rearranged itself between visits would be
/// a picture, not a record.
library;

import 'dart:math';

import 'models.dart';
import 'srs.dart' as srs;

/// The three things a branch can be practising, in the order they sit on the
/// bough. Mirrors the home screen's format filter so the picture and the
/// control agree with each other.
enum Twig { listening, phrasing, speaking }

Twig twigFor(QuestionType t) => switch (t) {
      QuestionType.gist || QuestionType.reply || QuestionType.dictation =>
        Twig.listening,
      QuestionType.paraphrase || QuestionType.register => Twig.phrasing,
      QuestionType.produce || QuestionType.reorder => Twig.speaking,
    };

/// One area of study, drawn as one bough.
class Branch {
  final String realmId;
  final String label;

  /// Answers given in this area. Sets the bough's length and thickness.
  final int answers;

  /// Answers per format, which is where the bough forks.
  final Map<Twig, int> twigs;

  /// Expressions met but not yet learned, and those that have been.
  final int growing;
  final int learned;

  /// Reviews are waiting here and nothing has been answered here today. The
  /// leaves go pale until one question in this area is done.
  final bool thirsty;

  const Branch({
    required this.realmId,
    required this.label,
    required this.answers,
    required this.twigs,
    required this.growing,
    required this.learned,
    required this.thirsty,
  });
}

class TreeShape {
  /// Every answer ever given. Sets the height and girth of the trunk.
  final int answers;

  /// Ordered by area id so a bough never moves between visits.
  final List<Branch> branches;

  /// Nothing has been answered yet: the pot is shown instead of a tree.
  bool get isSeed => answers == 0;

  const TreeShape({required this.answers, required this.branches});
}

/// How far the tree has come, from 0 (nothing answered) to 1 (as big as it
/// draws).
///
/// Logarithmic against a thousand answers, then raised to a power to flatten
/// the start. The plain log curve gave a third of the full height away inside
/// ten answers, so a learner who had seen two cotyledons on Monday had a tree
/// by Tuesday and then watched it barely move for a year. The seedling stage
/// has to last long enough to be a stage.
double trunkGrowth(int answers) {
  if (answers <= 0) return 0;
  final log10k = (log(answers + 1) / log(1001)).clamp(0.0, 1.0);
  return pow(log10k, 2.1).toDouble();
}

/// Girth keeps creeping up past the point where height stops, so that someone
/// two years in still sees the tree answer to their work.
double trunkGirth(int answers) {
  if (answers <= 1000) return trunkGrowth(answers);
  return (1 + log(answers / 1000) / log(50)).clamp(1.0, 2.0);
}

/// Same curve, applied to one bough against the busiest bough. Relative rather
/// than absolute: the point of the picture is which areas have been fed and
/// which have been left, and that only shows as a comparison.
double branchGrowth(int answers, int busiest) {
  if (answers <= 0) return 0;
  final top = max(busiest, 1);
  return (0.45 + 0.55 * (log(answers + 1) / log(top + 1))).clamp(0.0, 1.0);
}

TreeShape treeFrom({
  required List<HistoryEntry> history,
  required List<Realm> realms,
  required List<LearningItem> items,
  required Map<String, SrsState> states,
  required String today,
}) {
  final byRealm = <String, List<HistoryEntry>>{};
  for (final h in history) {
    (byRealm[h.realmId] ??= []).add(h);
  }

  // Items are counted against every area they belong to. An expression that
  // serves two areas has genuinely been learned in both.
  final growing = <String, int>{};
  final learned = <String, int>{};
  final overdue = <String, bool>{};
  for (final i in items) {
    final st = states[i.id];
    if (st == null || !st.introduced) continue;
    final done = srs.isMastered(st);
    final due = srs.isDue(st, today);
    for (final r in i.realmIds) {
      if (done) {
        learned[r] = (learned[r] ?? 0) + 1;
      } else {
        growing[r] = (growing[r] ?? 0) + 1;
      }
      if (due) overdue[r] = true;
    }
  }

  // Reviews waiting is the normal state of a working schedule, so that alone
  // must not turn an area pale — it would be pale almost always, and a signal
  // that is always on is not a signal. What shows is neglect: reviews waiting
  // and nothing done here today. One answer puts the colour back.
  final touchedToday = {for (final h in history.where((h) => h.day == today)) h.realmId};

  final branches = <Branch>[];
  for (final r in realms.where((x) => x.unlocked)) {
    final rows = byRealm[r.id] ?? const <HistoryEntry>[];
    final counts = {for (final t in Twig.values) t: 0};
    for (final h in rows) {
      final t = twigFor(h.type);
      counts[t] = counts[t]! + 1;
    }
    branches.add(Branch(
      realmId: r.id,
      label: r.label,
      answers: rows.length,
      twigs: counts,
      growing: growing[r.id] ?? 0,
      learned: learned[r.id] ?? 0,
      thirsty: (overdue[r.id] ?? false) && !touchedToday.contains(r.id),
    ));
  }
  branches.sort((a, b) => a.realmId.compareTo(b.realmId));

  return TreeShape(answers: history.length, branches: branches);
}
