/// The shape of the growth tree, derived entirely from what the learner has
/// done: the exchanges argued, the answers given in the old sessions, and the
/// review schedule.
///
/// Nothing here is stored. The tree is a reading of the record, which means it
/// can never drift out of step with the numbers, it survives a backup and
/// restore for free, and the same record always draws the same tree — a tree
/// that rearranged itself between visits would be a picture, not a record.
library;

import 'dart:math';

import 'debate.dart';
import 'models.dart';
import 'srs.dart' as srs;

/// The three things a twig can stand for, in the order they sit on the bough:
/// a line caught whole, a reply that came nearest the strong model, and a
/// reply the learner reported using for real.
enum Twig { grasp, reply, claim }

/// Where an answer from the old question sessions sits. Listening formats
/// were about catching what was said; the rest were about producing it.
Twig twigFor(QuestionType t) => switch (t) {
      QuestionType.gist || QuestionType.reply || QuestionType.dictation => Twig.grasp,
      QuestionType.paraphrase ||
      QuestionType.register ||
      QuestionType.produce ||
      QuestionType.reorder =>
        Twig.reply,
    };

/// The bough exchanges land on when their tree names no area of study.
const debateBranchId = 'debate';

/// One area of study, drawn as one bough.
class Branch {
  final String realmId;
  final String label;

  /// Exchanges and answers in this area. Sets the bough's length and thickness.
  final int answers;

  /// What the work here amounted to, which is where the bough forks.
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
  /// Every exchange argued and every answer ever given. Sets the height and
  /// girth of the trunk.
  final int answers;

  /// Ordered by area id so a bough never moves between visits.
  final List<Branch> branches;

  /// Nothing done yet: the pot is shown instead of a tree.
  bool get isSeed => answers == 0;

  const TreeShape({required this.answers, required this.branches});
}

/// How far the tree has come, from 0 (nothing done) to 1 (as big as it
/// draws).
///
/// Logarithmic against a thousand, then raised to a power to flatten the
/// start. The plain log curve gave a third of the full height away inside
/// ten, so a learner who had seen two cotyledons on Monday had a tree by
/// Tuesday and then watched it barely move for a year. The seedling stage
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
  List<Attempt> attempts = const [],
  Map<String, DebateTree> trees = const {},
  Set<String> usedClaims = const {},
}) {
  final answersByRealm = <String, int>{};
  final twigsByRealm = <String, Map<Twig, int>>{};
  void add(String realmId, Twig twig, {bool counts = true}) {
    if (counts) answersByRealm[realmId] = (answersByRealm[realmId] ?? 0) + 1;
    final t = twigsByRealm.putIfAbsent(realmId, () => {for (final x in Twig.values) x: 0});
    t[twig] = t[twig]! + 1;
  }

  for (final h in history) {
    add(h.realmId, twigFor(h.type));
  }

  // An exchange is one unit of growth. It forks into a reply twig when the
  // reply came nearest the strong model and a grasp twig otherwise — the
  // strong/weak reading is on the attempt, the grasp reading lives in the
  // slips, so the attempt alone decides. A reply the learner reported using
  // for real adds a claim twig without counting as another exchange.
  final knownRealms = {for (final r in realms) r.id};
  for (final a in attempts) {
    final realm = trees[a.debateId]?.realmId;
    final id = realm != null && knownRealms.contains(realm) ? realm : debateBranchId;
    add(id, a.closestStrength == Strength.strong ? Twig.reply : Twig.grasp);
    if (usedClaims.contains(a.id)) add(id, Twig.claim, counts: false);
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
  // and nothing done here today. One exchange or answer puts the colour back.
  final touchedToday = {
    for (final h in history.where((h) => h.day == today)) h.realmId,
    for (final a in attempts.where((a) => a.day == today))
      trees[a.debateId]?.realmId ?? debateBranchId,
  };

  Branch branch(String id, String label) => Branch(
        realmId: id,
        label: label,
        answers: answersByRealm[id] ?? 0,
        twigs: twigsByRealm[id] ?? {for (final t in Twig.values) t: 0},
        growing: growing[id] ?? 0,
        learned: learned[id] ?? 0,
        thirsty: (overdue[id] ?? false) && !touchedToday.contains(id),
      );
  final branches = [
    for (final r in realms.where((x) => x.unlocked)) branch(r.id, r.label),
    // Exchanges whose tree named no area, or an area this phone does not
    // have. Labelled with a mark rather than a word so it needs no language.
    if ((answersByRealm[debateBranchId] ?? 0) > 0) branch(debateBranchId, '💬'),
  ]..sort((a, b) => a.realmId.compareTo(b.realmId));

  return TreeShape(answers: history.length + attempts.length, branches: branches);
}
