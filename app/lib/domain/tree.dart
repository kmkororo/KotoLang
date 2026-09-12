/// The shape of the tree, derived entirely from what the learner has done.
///
/// **Height and girth are the questions answered, width is the ground
/// covered.** Nothing else. The ladder measures how hard the listening is
/// and has no say in the drawing: a reward that needs the ladder explained
/// before it can be read is not a reward, and the ladder is a thing to feel
/// in the ear rather than to count on a trunk.
///
/// Nothing here is stored. The tree is a reading of the record, so it can
/// never drift out of step with the numbers, it survives a backup and restore
/// for free, and the same record always draws the same tree — one that
/// rearranged itself between visits would be a picture, not a record.
library;

import 'dart:math';

import 'field.dart';
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
/// work shows a change often enough to be felt.
const treeStages = 24;

/// Which stage [scenes] questions answered has grown to.
int treeStage(int scenes) {
  if (scenes <= 0) return 0;
  final step = (treeGrown(scenes) * (treeStages - 1)).ceil();
  return step.clamp(1, treeStages - 1);
}

/// The names the tree answers to, as the number of questions each is earned
/// at.
///
/// Close together at the bottom and further apart at the top, the way a tree
/// actually changes: a seedling looks different every week and an old tree
/// looks the same for years. Names spread evenly gave the opposite — one name
/// for the whole of the beginning, when there is least to show for the work
/// and a name is worth most, then several in a row near the top where the
/// picture barely moves.
///
/// The samples are thirty questions and they land exactly on "young tree":
/// the work that comes with the app is meant to carry the learner as far as a
/// tree, and leave the crown to the conversations their own AI writes.
const treeNameAt = <int>[0, 2, 4, 7, 12, 19, 30, 60, 120, 250];

/// How many names the tree answers to.
int get treeNames => treeNameAt.length;

/// Where the tree stands between nothing and full grown, for [scenes]
/// questions answered. A log curve: the first few questions move it plainly,
/// and after that it slows, which is both how a tree grows and the only way
/// a number with no ceiling can drive a drawing that has one.
double treeGrown(int scenes) {
  if (scenes <= 0) return 0;
  return (log(scenes + 1) / log(treeNameAt.last + 1)).clamp(0.0, 1.0);
}

/// Which name [scenes] questions answered has earned.
int treeName(int scenes) {
  var n = 0;
  for (var i = 0; i < treeNameAt.length; i++) {
    if (scenes >= treeNameAt[i]) n = i;
  }
  return n;
}

class TreeShape {
  /// Questions answered at least once. The height and girth of the trunk, and
  /// the name it answers to.
  final int scenes;

  /// Turns answered, all told. Finer than the questions, and what the boughs
  /// are lengthened by: a field worked in often should look worked in.
  final int answers;

  /// Situations that have anything in them. The spread of the crown.
  final int situations;

  /// Samples first, then the learner's own; within each, by id, so a bough
  /// never moves between visits.
  final List<Branch> branches;

  /// Nothing done yet: the pot is shown instead of a tree.
  bool get isSeed => scenes == 0 && answers == 0;

  int get flowers => branches.fold(0, (a, b) => a + b.flowers);
  int get fruit => branches.fold(0, (a, b) => a + b.fruit);
  int get stage => treeStage(scenes);

  /// One bough per field. The ground covered, which is the third thing the
  /// tree shows.
  int get fields => branches.length;

  const TreeShape({
    required this.scenes,
    required this.answers,
    this.situations = 0,
    required this.branches,
  });
}

/// How tall the trunk stands: the questions answered, and nothing else.
double trunkGrowth(int scenes) => treeGrown(scenes);

/// How thick it is. The questions answered again, and the ground covered with
/// them: a tree holding up six fields carries a stouter bole than one holding
/// up a single field, at the same number of questions.
double trunkGirth(int scenes, int fields) {
  if (scenes <= 0) return 0;
  final spread = 0.88 + 0.04 * fields.clamp(0, 6);
  return pow(treeGrown(scenes), 0.8).toDouble() * 1.6 * spread;
}

double branchGrowth(int answers, int busiest) {
  if (answers <= 0) return 0;
  final top = max(busiest, 1);
  return (0.45 + 0.55 * (log(answers + 1) / log(top + 1))).clamp(0.0, 1.0);
}

/// How far the boughs reach for the work that has gone into the tree, apart
/// from how they compare with one another.
///
/// [branchGrowth] only says which bough is longer than which: four fields
/// worked equally all came out at full reach, whether that was fifteen
/// answers each or five hundred. So a tree with sixty answers behind it wore
/// the crown of a tree with a thousand, and the rule the growing screen
/// states — that answering lengthens the boughs — was not true of the
/// drawing. This is the part that is true of it.
double branchReach(int answers) {
  if (answers <= 0) return 0;
  final log1k = (log(answers + 1) / log(1001)).clamp(0.0, 1.0);
  return pow(log1k, 1.4).toDouble();
}

/// Reads the tree off the record. [fieldLabels] names the fields in the
/// interface language; a field without a name shows its id.
TreeShape treeFrom({
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
    scenes: branches.fold(0, (a, b) => a + b.learned),
    answers: results.length,
    situations: situations.length,
    branches: branches,
  );
}
