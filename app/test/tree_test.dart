/// The tree is a record, not a decoration.
///
/// It is read from two numbers and no others: the questions answered and the
/// fields open. The ladder measures how hard the listening is and has no say
/// here — a reward that needs a five-axis ladder explained before it can be
/// read is not a reward.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kotolang/data/builtin_scenes.dart';
import 'package:kotolang/domain/scene.dart';
import 'package:kotolang/domain/tree.dart';

Scene make(String id, {bool builtin = false, String field = 'work', int turns = 2}) => Scene(
      id: id,
      title: id,
      situation: 'meetings',
      turns: [
        for (var i = 0; i < turns; i++)
          Turn(line: '$id line $i', replies: const [
            Reply(text: 'a', correct: true),
            Reply(text: 'b'),
            Reply(text: 'c'),
          ])
      ],
      source: builtin ? SceneSource.builtin : SceneSource.ai,
      realmId: builtin ? null : field,
      createdAt: 0,
    );

TurnResult answered(
  String sceneId,
  int turn, {
  bool correct = true,
  bool inWindow = true,
  bool review = false,
  String day = '2026-03-01',
}) =>
    TurnResult(
      sceneId: sceneId,
      turn: turn,
      correct: correct,
      inWindow: inWindow,
      review: review,
      day: day,
      at: turn,
    );

void main() {
  const today = '2026-03-01';

  test('nothing done is a seed', () {
    final t = treeFrom(today: today);
    expect(t.isSeed, isTrue);
    expect(t.branches, isEmpty);
    expect(t.stage, 0);
  });

  test('height and girth are the questions answered', () {
    final scenes = {for (final s in [make('a'), make('b')]) s.id: s};
    final one = treeFrom(today: today, results: [answered('a', 0)], scenes: scenes);
    expect(one.scenes, 1);
    expect(trunkGrowth(one.scenes), greaterThan(0));
    expect(one.stage, greaterThan(0));

    // A second question answered is taller than one, however many turns went
    // into the first.
    final busy = treeFrom(
        today: today,
        results: [for (var i = 0; i < 40; i++) answered('a', i % 2)],
        scenes: scenes);
    final broad = treeFrom(
        today: today,
        results: [answered('a', 0), answered('b', 0)],
        scenes: scenes);
    expect(busy.scenes, 1);
    expect(broad.scenes, 2);
    expect(trunkGrowth(broad.scenes), greaterThan(trunkGrowth(busy.scenes)));
  });

  test('the ground covered thickens the trunk as well', () {
    // The same questions, spread over more fields, carry a stouter bole.
    expect(trunkGirth(30, 6), greaterThan(trunkGirth(30, 1)));
    expect(trunkGirth(0, 6), 0, reason: 'nothing answered is no trunk');
  });

  test('the stages are cut fine enough to be felt', () {
    expect(treeStages, greaterThanOrEqualTo(20));
    final seen = <int>{};
    for (var reached = 0; reached <= treeNameAt.last; reached++) {
      seen.add(treeStage(reached));
    }
    expect(seen.length, greaterThanOrEqualTo(20));
    expect(treeStage(treeNameAt.last), treeStages - 1);
  });

  test('a bough for every field, samples below the learner own', () {
    final scenes = {
      for (final s in [
        make('own1', field: 'work'),
        make('own2', field: 'travel'),
        make('sample1', builtin: true),
      ])
        s.id: s
    };
    final t = treeFrom(
      today: today,
      scenes: scenes,
      fieldLabels: {'work': 'Work', 'travel': 'Travel'},
    );
    expect(t.branches.first.own, isFalse, reason: 'the samples grow low');
    expect(t.branches.where((b) => b.own), hasLength(2));
    expect(t.branches.firstWhere((b) => b.realmId == ownBranch('work')).label, 'Work');
  });

  test('only the learner own conversations flower, and only when kept up with', () {
    final scenes = {
      for (final s in [make('own1'), make('sample1', builtin: true)]) s.id: s
    };
    final t = treeFrom(
      today: today,
      scenes: scenes,
      results: [
        answered('own1', 0),
        answered('own1', 1, inWindow: false),
        answered('sample1', 0),
        answered('sample1', 1),
      ],
    );
    final own = t.branches.firstWhere((b) => b.own);
    final sample = t.branches.firstWhere((b) => !b.own);
    expect(own.flowers, 1, reason: 'the one answered while the window was open');
    expect(sample.flowers, 0, reason: 'the samples are there to be outgrown');
  });

  test('fruit is a conversation of their own with every turn right', () {
    final scenes = {for (final s in [make('own1', turns: 2)]) s.id: s};
    final half = treeFrom(today: today, scenes: scenes, results: [
      answered('own1', 0),
    ]);
    expect(half.fruit, 0, reason: 'not answered through yet');

    final whole = treeFrom(today: today, scenes: scenes, results: [
      answered('own1', 0),
      answered('own1', 1),
    ]);
    expect(whole.fruit, 1);

    final missed = treeFrom(today: today, scenes: scenes, results: [
      answered('own1', 0),
      answered('own1', 1, correct: false),
    ]);
    expect(missed.fruit, 0);
  });

  test('a bough goes pale when something is owed there and nothing was done today', () {
    final scenes = {for (final s in [make('own1')]) s.id: s};
    final due = [const ReviewItem(sceneId: 'own1', turn: 0, dueDay: today)];

    final cold = treeFrom(
        today: today,
        scenes: scenes,
        due: due,
        results: [answered('own1', 0, day: '2026-02-20')]);
    expect(cold.branches.single.thirsty, isTrue);

    final watered = treeFrom(
        today: today,
        scenes: scenes,
        due: due,
        results: [answered('own1', 0, day: today)]);
    expect(watered.branches.single.thirsty, isFalse);
  });

  test('every name the tree answers to is reachable, and only once', () {
    // The growing screen draws one row per name. Dividing the ladder into
    // six even parts to find them put two rows on the same name and skipped
    // another, because the names are not spaced evenly along it — so the
    // screen walks the ladder and asks. This is what it relies on.
    final seen = <int>[];
    for (var r = 0; r <= treeNameAt.last; r++) {
      final n = treeName(r);
      if (seen.isEmpty || seen.last != n) seen.add(n);
    }
    expect(seen, [for (var i = 0; i < treeNames; i++) i],
        reason: 'each name once, in order, from the seed to the last');
  });

  test('the samples alone come to a young tree', () {
    // Thirty questions is what the built-in conversations hold. They are meant
    // to carry the learner as far as a tree and no further: the crown and the
    // blossom are what their own conversations add.
    expect(builtinScenes('en').length, 30);
    expect(treeName(30), 6, reason: 'young tree');
    expect(treeName(29), lessThan(6), reason: 'and not before the last of them');
  });

  test('the same record always draws the same tree', () {
    final scenes = {for (final s in [make('a'), make('b', field: 'travel')]) s.id: s};
    final results = [answered('a', 0), answered('b', 0, correct: false)];
    List<String> shape() => [
          for (final b in treeFrom(
                  today: today, scenes: scenes, results: results)
              .branches)
            '${b.realmId}:${b.answers}:${b.flowers}'
        ];
    expect(shape(), shape());
  });
}
