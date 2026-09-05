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

import 'field.dart';
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

/// A bough is one field of the learner's life, on one of two sides: the
/// samples that came with the app grow low on the trunk and short; the
/// learner's own scenes grow above them and make the crown.
String ownBranch(String fieldId) => 'own:$fieldId';
String sampleBranch(String fieldId) => 'sample:$fieldId';

/// One field, drawn as one bough.
class Branch {
  /// `own:<field>` or `sample:<field>`; legacy areas of study keep `own:<realm>`.
  final String realmId;
  final String label;

  /// The learner's own scenes, as opposed to the samples.
  final bool own;

  /// Exchanges and answers here. Sets the bough's length and thickness.
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

  /// Scenes of the learner's own whose every answer is right, as of the
  /// latest run. One fruit each.
  final int fruit;

  /// Reviews are waiting here and nothing has been answered here today. The
  /// leaves go pale until one question in this area is done.
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

/// The named stages of the tree, by scenes finished: a seed, a sprout, a
/// seedling, a young tree, a tree, a great tree.
const treeStages = 6;

int treeStage(int scenes) {
  if (scenes <= 0) return 0;
  if (scenes <= 3) return 1;
  if (scenes <= 10) return 2;
  if (scenes <= 30) return 3;
  if (scenes <= 80) return 4;
  return 5;
}

class TreeShape {
  /// Every exchange answered and every answer ever given. Sets the height and
  /// girth of the trunk.
  final int answers;

  /// Scenes finished, which name the stage.
  final int scenes;

  /// Samples first, then the learner's own; within each, by id, so a bough
  /// never moves between visits.
  final List<Branch> branches;

  /// Nothing done yet: the pot is shown instead of a tree.
  bool get isSeed => answers == 0;

  int get flowers => branches.fold(0, (a, b) => a + b.flowers);
  int get fruit => branches.fold(0, (a, b) => a + b.fruit);
  int get stage => treeStage(scenes);

  const TreeShape({required this.answers, this.scenes = 0, required this.branches});
}

double trunkGrowth(int answers) {
  if (answers <= 0) return 0;
  final log10k = (log(answers + 1) / log(1001)).clamp(0.0, 1.0);
  return pow(log10k, 2.1).toDouble();
}

double trunkGirth(int answers) {
  if (answers <= 1000) return trunkGrowth(answers);
  return (1 + log(answers / 1000) / log(50)).clamp(1.0, 2.0);
}

double branchGrowth(int answers, int busiest) {
  if (answers <= 0) return 0;
  final top = max(busiest, 1);
  return (0.45 + 0.55 * (log(answers + 1) / log(top + 1))).clamp(0.0, 1.0);
}

/// Reads the tree off the record. [fieldLabels] names the fields in the
/// interface language; a field without a name shows its id.
TreeShape treeFrom({
  required List<HistoryEntry> history,
  required List<Realm> realms,
  required List<LearningItem> items,
  required Map<String, SrsState> states,
  required String today,
  List<SceneResult> results = const [],
  Map<String, Scene> scenes = const {},
  Map<String, String> fieldLabels = const {},
}) {
  final answersByBranch = <String, int>{};
  final twigsByBranch = <String, Map<Twig, int>>{};
  final flowersByBranch = <String, int>{};
  final fruitByBranch = <String, int>{};
  final labels = <String, String>{};
  final ownOf = <String, bool>{};

  void add(String id, Twig? twig, {bool counts = true}) {
    if (counts) answersByBranch[id] = (answersByBranch[id] ?? 0) + 1;
    if (twig == null) return;
    final t = twigsByBranch.putIfAbsent(id, () => {for (final x in Twig.values) x: 0});
    t[twig] = t[twig]! + 1;
  }

  // The old question sessions, by their area of study: the learner's own.
  final realmLabel = {for (final r in realms) r.id: r.label};
  for (final h in history) {
    final id = ownBranch(h.realmId);
    labels[id] = realmLabel[h.realmId] ?? h.realmId;
    ownOf[id] = true;
    add(id, twigFor(h.type));
  }

  // An exchange is one unit of growth. It forks into a grasp twig when the
  // line was caught and a reply twig when the reply answered it; a review is
  // practice on an exchange already counted, so it adds no growth. Flowers
  // are replies on the learner's own scenes.
  String branchOf(SceneResult r) {
    final sc = scenes[r.sceneId];
    final field = sc == null ? defaultFieldId : fieldOf(sc);
    final own = !(sc?.isBuiltin ?? false);
    final id = own ? ownBranch(field) : sampleBranch(field);
    labels[id] = fieldLabels[field] ?? realmLabel[field] ?? field;
    ownOf[id] = own;
    return id;
  }

  for (final r in results) {
    if (r.review) continue;
    final id = branchOf(r);
    add(id, null);
    if (r.gistOk) add(id, Twig.grasp, counts: false);
    if (r.replyOk) {
      add(id, Twig.reply, counts: false);
      if (ownOf[id]!) flowersByBranch[id] = (flowersByBranch[id] ?? 0) + 1;
    }
  }

  // A fruit for every scene of the learner's own whose latest run was all
  // right — both exchanges, both questions.
  final latest = <String, Map<int, SceneResult>>{};
  for (final r in results) {
    if (r.review) continue;
    final per = latest.putIfAbsent(r.sceneId, () => {});
    if ((per[r.exchange]?.at ?? -1) < r.at) per[r.exchange] = r;
  }
  for (final e in latest.entries) {
    final sc = scenes[e.key];
    if (sc == null || sc.isBuiltin) continue;
    if (e.value.length < sc.exchanges.length) continue;
    if (e.value.values.every((r) => r.gistOk && r.replyOk)) {
      final id = ownBranch(fieldOf(sc));
      fruitByBranch[id] = (fruitByBranch[id] ?? 0) + 1;
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
      final id = ownBranch(r);
      if (done) {
        learned[id] = (learned[id] ?? 0) + 1;
      } else {
        growing[id] = (growing[id] ?? 0) + 1;
      }
      if (due) overdue[id] = true;
    }
  }

  // Reviews waiting is the normal state of a working schedule, so that alone
  // must not turn an area pale — it would be pale almost always, and a signal
  // that is always on is not a signal. What shows is neglect: reviews waiting
  // and nothing done here today. One exchange or answer puts the colour back.
  final touchedToday = {
    for (final h in history.where((h) => h.day == today)) ownBranch(h.realmId),
    for (final r in results.where((r) => r.day == today)) branchOf(r),
  };

  final branches = [
    for (final id in answersByBranch.keys)
      Branch(
        realmId: id,
        label: labels[id] ?? id,
        own: ownOf[id] ?? true,
        answers: answersByBranch[id] ?? 0,
        twigs: twigsByBranch[id] ?? {for (final t in Twig.values) t: 0},
        growing: growing[id] ?? 0,
        learned: learned[id] ?? 0,
        flowers: flowersByBranch[id] ?? 0,
        fruit: fruitByBranch[id] ?? 0,
        thirsty: (overdue[id] ?? false) && !touchedToday.contains(id),
      ),
  ]..sort((a, b) {
      if (a.own != b.own) return a.own ? 1 : -1;
      return a.realmId.compareTo(b.realmId);
    });

  final exchanges = results.where((r) => !r.review).length;
  return TreeShape(
    answers: history.length + exchanges,
    scenes: exchanges ~/ exchangesPerScene,
    branches: branches,
  );
}
