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

/// What the tree is called: ten names, each with levels inside it — "sapling
/// Lv.3". Ten names alone is ten things to look forward to across a year of
/// work, and the ninth of them is a year away; a level inside the name is
/// something the next few questions can reach.
///
/// How many levels each of the first nine names holds. The tenth never runs
/// out: the great tree goes on gaining levels for as long as there are
/// questions, so there is no last one to arrive at.
const treeLevelsPerName = <int>[2, 3, 3, 4, 5, 7, 10, 14, 22];

/// How many names the tree answers to.
int get treeNames => treeLevelsPerName.length + 1;

/// Questions needed to reach global level [l], counting from one.
///
/// The shape of this is the whole point. The first levels come one or two
/// questions apart, so somebody who has just started sees the tree answer
/// almost every time they finish one; the gaps then widen without ever
/// closing, so the hundredth level is a long way off and the two hundredth is
/// further, and neither is the last.
int treeLevelAt(int l) => l <= 1 ? 0 : (0.5 * pow(l, 1.85)).ceil();

/// The level [scenes] questions have earned: one and upwards, for ever.
int treeLevel(int scenes) {
  if (scenes <= 0) return 1;
  final l = pow(scenes / 0.5, 1 / 1.85).floor();
  return l < 1 ? 1 : l;
}

/// The name, and which level of that name, for a global [level].
({int name, int level}) treeRankOfLevel(int level) {
  var l = level < 1 ? 1 : level;
  for (var i = 0; i < treeLevelsPerName.length; i++) {
    if (l <= treeLevelsPerName[i]) return (name: i, level: l);
    l -= treeLevelsPerName[i];
  }
  return (name: treeLevelsPerName.length, level: l);
}

/// The name, and which level of that name, for [scenes] questions answered.
({int name, int level}) treeRank(int scenes) => treeRankOfLevel(treeLevel(scenes));

/// The global level at which the last named tree begins, and the height of
/// the drawing is reached.
int get treeFullLevel =>
    treeLevelsPerName.fold(0, (a, b) => a + b) + 1;

/// The last level there is.
///
/// Growing stops somewhere, and this is a better somewhere than a number that
/// simply runs out: by here the ground under the tree has closed into a world
/// and the crown has gone round it. There is nothing left to be bigger than.
const treeTopLevel = 200;

/// Which name [scenes] questions answered has earned.
int treeName(int scenes) => treeRank(scenes).name;

// ---------------------------------------------------------------- the picture
//
// The tree is drawn on one rule: the ground was always a world, and what
// changes is how far away the camera is. There is one sphere of a fixed size
// and a tree standing on its pole. Close up the ground is a plain; as the
// tree grows the camera pulls back, the horizon bends, and at the last level
// the whole world is in view with the roots round it.
//
// Two things grow and they grow separately. Size is how big the tree is
// against the world, and it is what moves the camera. Maturity is what shape
// the tree has — a seedling is not a small old tree — and it is what the
// names are about.

/// The world's radius, in the units the tree is measured in.
const worldRadius = 100.0;

/// How big the tree is at [level], against a world of [worldRadius]: a
/// sprout half a unit high at the start, two and a half world radii at the
/// last level. Exponential, so every level is the same proportion bigger, and
/// taking a fractional level so the growth between two can be animated.
double treeSizeAt(double level) =>
    0.5 * pow(500, (level - 1) / (treeTopLevel - 1)).toDouble();

/// Maturity at the level each name begins, so the drawing and the name
/// agree: seed leaves for the sprout, a stem with leaves for the seedling, a
/// spindly sapling, a crown for the young tree, spreading from there.
const _maturityAt = <(int, double)>[
  (1, 0.00), (3, 0.05), (6, 0.10), (9, 0.16), (13, 0.24), (18, 0.32),
  (25, 0.42), (35, 0.54), (49, 0.66), (71, 0.78), (200, 1.00),
];

/// What shape the tree has at [level], from 0 (a sprout) to 1 (a great tree).
double treeMaturityAt(double level) {
  for (var i = 1; i < _maturityAt.length; i++) {
    final (l1, m1) = _maturityAt[i];
    final (l0, m0) = _maturityAt[i - 1];
    if (level <= l1) {
      final t = ((level - l0) / (l1 - l0)).clamp(0.0, 1.0);
      return m0 + (m1 - m0) * t;
    }
  }
  return 1;
}

double _smooth(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

/// Where the camera is for the tree at [level]: the band of the world, in
/// world units, that fills the height of the picture.
class TreeView {
  /// How big the tree is, in world units.
  final double size;

  /// The top and bottom of what is in view, in world units, measured up
  /// from the centre of the world.
  final double top;
  final double bottom;

  /// How far the camera has pulled back towards seeing the whole world,
  /// from 0 to 1. The ground is round all along; this is how much of it the
  /// frame takes in.
  final double toGlobe;

  /// How high up the camera is, from 0 to 1, for the colour of the sky.
  final double altitude;

  const TreeView({
    required this.size,
    required this.top,
    required this.bottom,
    required this.toGlobe,
    required this.altitude,
  });

  /// The height of the view, in world units.
  double get span => top - bottom;
}

TreeView treeViewAt(double level) {
  final h = treeSizeAt(level);
  final toGlobe = _smooth((log(h) - log(0.3 * worldRadius)) /
      (log(2.5 * worldRadius) - log(0.3 * worldRadius)));
  final top = worldRadius + h * 1.34;
  // Close up the ground sits a fifth of the way up; far out the whole world
  // is in the frame. Between them the camera moves continuously, which is
  // what makes the horizon bend a little at a time rather than all at once.
  final near = worldRadius - h * 0.36;
  final far = -worldRadius * 1.14;
  final bottom = near + (far - near) * toGlobe;
  final span = top - bottom;
  final altitude = _smooth((log(span) - log(2)) / (log(620) - log(2)));
  return TreeView(size: h, top: top, bottom: bottom, toGlobe: toGlobe, altitude: altitude);
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
