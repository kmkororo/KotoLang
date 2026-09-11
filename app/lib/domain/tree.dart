/// The shape of the tree, derived entirely from what the learner has done.
///
/// **Height is the ladder, width is the ground covered.** A thousand answers
/// at the easiest setting do not make the tree taller; a step held at a speed
/// never heard before does. That is the whole of it, and it is why the tree
/// can be a reward without also being a measurement: the measuring is the
/// ladder's job, and the tree only shows it.
///
/// Nothing here is stored. The tree is a reading of the record, so it can
/// never drift out of step with the numbers, it survives a backup and restore
/// for free, and the same record always draws the same tree — one that
/// rearranged itself between visits would be a picture, not a record.
library;

import 'dart:math';

import 'field.dart';
import 'ladder.dart';
import 'scene.dart';

/// A bough is one field of the learner's life, on one of two sides: the
/// samples that came with the app grow low on the trunk and short; the
/// learner's own conversations grow above them and make the crown.
String ownBranch(String fieldId) => 'own:$fieldId';
String sampleBranch(String fieldId) => 'sample:$fieldId';

/// One field, drawn as one bough.
class Branch {
  /// `own:<field>` or `sample:<field>`.
  final String realmId;
  final String label;

  /// The learner's own conversations, as opposed to the samples.
  final bool own;

  /// Turns answered here. Sets the bough's length and thickness.
  final int answers;

  /// What kind of listening the work here was, which is where the bough
  /// forks.
  final Map<TurnType, int> twigs;

  /// Conversations here that have been answered through, and those still
  /// untouched.
  final int learned;
  final int growing;

  /// Replies caught while the window was still open, on the learner's own
  /// conversations. Only those bloom — the samples grow leaves and no more.
  final int flowers;

  /// The learner's own conversations with every turn right. One fruit each.
  final int fruit;

  /// Turns here are owed another look and nothing has been answered here
  /// today. The leaves go pale until one of them is done.
  final bool thirsty;

  const Branch({
    required this.realmId,
    required this.label,
    this.own = true,
    required this.answers,
    required this.twigs,
    this.growing = 0,
    this.learned = 0,
    this.flowers = 0,
    this.fruit = 0,
    this.thirsty = false,
  });
}

/// How finely the tree is cut. Many stages rather than a few, so that the
/// thing the learner is climbing shows a change often enough to be felt.
const treeStages = 24;

/// Which stage a ladder of [reached] steps has grown to. The whole ladder is
/// a little over fifty steps, so the tree changes shape every couple of them.
int treeStage(int reached) {
  if (reached <= 0) return 0;
  final step = (reached / (ladderSteps / (treeStages - 1))).floor() + 1;
  return step.clamp(1, treeStages - 1);
}

class TreeShape {
  /// Steps of the ladder ever reached. The height and girth of the trunk.
  final int reached;

  /// Turns answered, all told. Not what the tree is measured by — it is what
  /// the boughs are thickened by, since a field worked in often should look
  /// worked in.
  final int answers;

  /// Situations that have anything in them. The spread of the crown.
  final int situations;

  /// Samples first, then the learner's own; within each, by id, so a bough
  /// never moves between visits.
  final List<Branch> branches;

  /// Nothing done yet: the pot is shown instead of a tree.
  bool get isSeed => reached == 0 && answers == 0;

  int get flowers => branches.fold(0, (a, b) => a + b.flowers);
  int get fruit => branches.fold(0, (a, b) => a + b.fruit);
  int get stage => treeStage(reached);

  const TreeShape({
    required this.reached,
    required this.answers,
    this.situations = 0,
    required this.branches,
  });
}

/// How tall the trunk stands, from the ladder alone.
double trunkGrowth(int reached) {
  if (reached <= 0) return 0;
  return (reached / ladderSteps).clamp(0.0, 1.0);
}

/// How thick it is. Height comes from the ladder; girth from the work done at
/// it, so someone who climbs fast has a tall thin tree and someone who stays
/// and practises has a stout one.
double trunkGirth(int answers) {
  if (answers <= 0) return 0;
  final log10k = (log(answers + 1) / log(1001)).clamp(0.0, 1.0);
  return pow(log10k, 0.8).toDouble() * 1.6;
}

double branchGrowth(int answers, int busiest) {
  if (answers <= 0) return 0;
  final top = max(busiest, 1);
  return (0.45 + 0.55 * (log(answers + 1) / log(top + 1))).clamp(0.0, 1.0);
}

/// Reads the tree off the record. [fieldLabels] names the fields in the
/// interface language; a field without a name shows its id.
TreeShape treeFrom({
  required Ladder ladder,
  required String today,
  List<TurnResult> results = const [],
  Map<String, Scene> scenes = const {},
  List<ReviewItem> due = const [],
  Map<String, String> fieldLabels = const {},
}) {
  final answersByBranch = <String, int>{};
  final twigsByBranch = <String, Map<TurnType, int>>{};
  final flowersByBranch = <String, int>{};
  final workedToday = <String>{};
  final touched = <String, Set<String>>{};

  String branchOf(Scene s) =>
      s.isBuiltin ? sampleBranch(fieldOf(s)) : ownBranch(fieldOf(s));

  for (final r in results) {
    final scene = scenes[r.sceneId];
    if (scene == null) continue;
    final key = branchOf(scene);
    answersByBranch[key] = (answersByBranch[key] ?? 0) + 1;
    touched.putIfAbsent(key, () => <String>{}).add(scene.id);
    if (r.day == today) workedToday.add(key);

    final kind = scene.turns.elementAtOrNull(r.turn)?.type ?? TurnType.keyword;
    final twigs = twigsByBranch.putIfAbsent(key, () => <TurnType, int>{});
    twigs[kind] = (twigs[kind] ?? 0) + 1;

    // A flower is a reply caught while the window was still open, and only on
    // the learner's own conversations: the samples are there to be outgrown.
    if (!scene.isBuiltin && r.correct && r.inWindow && !r.review) {
      flowersByBranch[key] = (flowersByBranch[key] ?? 0) + 1;
    }
  }

  // Fruit: one for each of the learner's own conversations whose every turn
  // was right, counting only the latest answer to each turn.
  final latest = <String, Map<int, bool>>{};
  for (final r in results) {
    if (r.review) continue;
    latest.putIfAbsent(r.sceneId, () => <int, bool>{})[r.turn] = r.correct;
  }
  final fruitByBranch = <String, int>{};
  for (final entry in latest.entries) {
    final scene = scenes[entry.key];
    if (scene == null || scene.isBuiltin || scene.turns.isEmpty) continue;
    if (entry.value.length < scene.turns.length) continue;
    if (entry.value.values.any((ok) => !ok)) continue;
    final key = branchOf(scene);
    fruitByBranch[key] = (fruitByBranch[key] ?? 0) + 1;
  }

  // Everything a field holds, so a bough can show what is still untouched.
  final heldByBranch = <String, Set<String>>{};
  final situations = <String>{};
  for (final s in scenes.values) {
    if (s.disabled) continue;
    heldByBranch.putIfAbsent(branchOf(s), () => <String>{}).add(s.id);
    if (s.situation.isNotEmpty) situations.add(s.situation);
  }

  final owedByBranch = <String>{};
  for (final d in due) {
    final scene = scenes[d.sceneId];
    if (scene != null) owedByBranch.add(branchOf(scene));
  }

  final keys = {...heldByBranch.keys, ...answersByBranch.keys}.toList()
    ..sort((a, b) {
      // Samples low, the learner's own above them; within each, by id, so a
      // bough never moves between visits.
      final sa = a.startsWith('sample:') ? 0 : 1;
      final sb = b.startsWith('sample:') ? 0 : 1;
      return sa != sb ? sa.compareTo(sb) : a.compareTo(b);
    });

  final branches = <Branch>[];
  for (final key in keys) {
    final own = !key.startsWith('sample:');
    final field = key.substring(key.indexOf(':') + 1);
    final held = heldByBranch[key] ?? const <String>{};
    final done = touched[key] ?? const <String>{};
    branches.add(Branch(
      realmId: key,
      label: fieldLabels[field] ?? field,
      own: own,
      answers: answersByBranch[key] ?? 0,
      twigs: twigsByBranch[key] ?? const {},
      learned: done.length,
      growing: held.length - done.where(held.contains).length,
      flowers: flowersByBranch[key] ?? 0,
      fruit: fruitByBranch[key] ?? 0,
      thirsty: owedByBranch.contains(key) && !workedToday.contains(key),
    ));
  }

  return TreeShape(
    reached: ladder.reached,
    answers: results.length,
    situations: situations.length,
    branches: branches,
  );
}
