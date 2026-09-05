/// The shape of the growth tree, derived entirely from what the learner has
/// done: the scenes answered, the answers given in the old sessions, and the
/// review schedule.
///
/// Nothing here is stored. The tree is a reading of the record, which means it
/// can never drift out of step with the numbers, it survives a backup and
/// restore for free, and the same record always draws the same tree — a tree
/// that rearranged itself between visits would be a picture, not a record.
library;

import 'dart:math';

import 'models.dart';
import 'scene.dart';
import 'srs.dart' as srs;

/// What a twig stands for, in the order they sit on the bough: a line caught
/// (the gist answered right) and a reply that answered what was said.
enum Twig { grasp, reply }

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

/// The boughs scenes land on when their scene names no area of study: the
/// learner's own scenes on one, the samples on another.
const ownBranchId = 'own';
const sampleBranchId = 'sample';

/// One area of study, drawn as one bough.
class Branch {
  final String realmId;
  final String label;

  /// Exchanges and answers in this area. Sets the bough's length and thickness.
  final int answers;

  /// What the work here amounted to, which is where the bough forks.
  final Map<Twig, int> twigs;

  /// Expressions met but not yet learned, and those that have been (the old
  /// material's review state).
  final int growing;
  final int learned;

  /// Replies answered right on the learner's own scenes. Only those bloom —
  /// the samples grow leaves and no more.
  final int flowers;

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
    this.flowers = 0,
    required this.thirsty,
  });
}

class TreeShape {
  /// Every exchange answered and every answer ever given. Sets the height and
  /// girth of the trunk.
  final int answers;

  /// Ordered by area id so a bough never moves between visits.
  final List<Branch> branches;

  /// Nothing done yet: the pot is shown instead of a tree.
  bool get isSeed => answers == 0;

  int get flowers => branches.fold(0, (a, b) => a + b.flowers);

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
  List<SceneResult> results = const [],
  Map<String, Scene> scenes = const {},
}) {
  final answersByRealm = <String, int>{};
  final twigsByRealm = <String, Map<Twig, int>>{};
  final flowersByRealm = <String, int>{};
  void add(String realmId, Twig? twig, {bool counts = true}) {
    if (counts) answersByRealm[realmId] = (answersByRealm[realmId] ?? 0) + 1;
    if (twig == null) return;
    final t = twigsByRealm.putIfAbsent(realmId, () => {for (final x in Twig.values) x: 0});
    t[twig] = t[twig]! + 1;
  }

  for (final h in history) {
    add(h.realmId, twigFor(h.type));
  }

  // An exchange is one unit of growth. It forks into a grasp twig when the
  // line was caught and a reply twig when the reply answered it; a review is
  // practice on an exchange already counted, so it adds no growth. Flowers
  // are replies on the learner's own scenes.
  final knownRealms = {for (final r in realms) r.id};
  String branchOf(SceneResult r) {
    final sc = scenes[r.sceneId];
    final realm = sc?.realmId;
    if (realm != null && knownRealms.contains(realm)) return realm;
    return (sc?.isBuiltin ?? false) ? sampleBranchId : ownBranchId;
  }

  for (final r in results) {
    if (r.review) continue;
    final id = branchOf(r);
    add(id, null);
    if (r.gistOk) add(id, Twig.grasp, counts: false);
    if (r.replyOk) {
      add(id, Twig.reply, counts: false);
      if (!(scenes[r.sceneId]?.isBuiltin ?? true)) {
        flowersByRealm[id] = (flowersByRealm[id] ?? 0) + 1;
      }
    }
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
    for (final r in results.where((r) => r.day == today)) branchOf(r),
  };

  Branch branch(String id, String label) => Branch(
        realmId: id,
        label: label,
        answers: answersByRealm[id] ?? 0,
        twigs: twigsByRealm[id] ?? {for (final t in Twig.values) t: 0},
        growing: growing[id] ?? 0,
        learned: learned[id] ?? 0,
        flowers: flowersByRealm[id] ?? 0,
        thirsty: (overdue[id] ?? false) && !touchedToday.contains(id),
      );
  final branches = [
    for (final r in realms.where((x) => x.unlocked)) branch(r.id, r.label),
    // Scenes that name no area. Labelled with a mark rather than a word so
    // they need no language.
    if ((answersByRealm[ownBranchId] ?? 0) > 0) branch(ownBranchId, '✦'),
    if ((answersByRealm[sampleBranchId] ?? 0) > 0) branch(sampleBranchId, '·'),
  ]..sort((a, b) => a.realmId.compareTo(b.realmId));

  final exchanges = results.where((r) => !r.review).length;
  return TreeShape(answers: history.length + exchanges, branches: branches);
}
