/// The tree is a record, not a decoration.
///
/// The one rule worth defending: **height comes from the ladder, never from
/// how much has been answered.** A learner who answers a thousand at the
/// easiest setting has a stout tree, not a tall one — otherwise the tree
/// would be measuring, and measuring is the ladder's job.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kotolang/domain/ladder.dart';
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

Ladder climbed(int windows) {
  var l = Ladder.empty;
  for (var i = 0; i < windows * ladderWindow; i++) {
    l = l.record(true).ladder;
  }
  return l;
}

void main() {
  const today = '2026-03-01';

  test('nothing done is a seed', () {
    final t = treeFrom(ladder: Ladder.empty, today: today);
    expect(t.isSeed, isTrue);
    expect(t.branches, isEmpty);
    expect(t.stage, 0);
  });

  test('height is the ladder; answering alone never raises it', () {
    final scenes = {for (final s in [make('a'), make('b')]) s.id: s};
    final many = [
      for (var i = 0; i < 200; i++) answered('a', i % 2),
    ];
    final ground = treeFrom(
        ladder: Ladder.empty, today: today, results: many, scenes: scenes);
    expect(ground.reached, 0);
    expect(trunkGrowth(ground.reached), 0);
    expect(ground.stage, 0, reason: 'two hundred answers at the easiest setting');
    expect(trunkGirth(ground.answers), greaterThan(0),
        reason: 'but the work still thickens it');

    final tall = treeFrom(ladder: climbed(2), today: today, scenes: scenes);
    expect(tall.reached, greaterThan(0));
    expect(trunkGrowth(tall.reached), greaterThan(0));
    expect(tall.stage, greaterThan(0));
  });

  test('the stages are cut fine enough to be felt', () {
    expect(treeStages, greaterThanOrEqualTo(20));
    final seen = <int>{};
    for (var reached = 0; reached <= ladderSteps; reached++) {
      seen.add(treeStage(reached));
    }
    expect(seen.length, greaterThanOrEqualTo(20));
    expect(treeStage(ladderSteps), treeStages - 1);
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
      ladder: Ladder.empty,
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
      ladder: Ladder.empty,
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
    final half = treeFrom(ladder: Ladder.empty, today: today, scenes: scenes, results: [
      answered('own1', 0),
    ]);
    expect(half.fruit, 0, reason: 'not answered through yet');

    final whole = treeFrom(ladder: Ladder.empty, today: today, scenes: scenes, results: [
      answered('own1', 0),
      answered('own1', 1),
    ]);
    expect(whole.fruit, 1);

    final missed = treeFrom(ladder: Ladder.empty, today: today, scenes: scenes, results: [
      answered('own1', 0),
      answered('own1', 1, correct: false),
    ]);
    expect(missed.fruit, 0);
  });

  test('a bough goes pale when something is owed there and nothing was done today', () {
    final scenes = {for (final s in [make('own1')]) s.id: s};
    final due = [const ReviewItem(sceneId: 'own1', turn: 0, dueDay: today)];

    final cold = treeFrom(
        ladder: Ladder.empty,
        today: today,
        scenes: scenes,
        due: due,
        results: [answered('own1', 0, day: '2026-02-20')]);
    expect(cold.branches.single.thirsty, isTrue);

    final watered = treeFrom(
        ladder: Ladder.empty,
        today: today,
        scenes: scenes,
        due: due,
        results: [answered('own1', 0, day: today)]);
    expect(watered.branches.single.thirsty, isFalse);
  });

  test('the same record always draws the same tree', () {
    final scenes = {for (final s in [make('a'), make('b', field: 'travel')]) s.id: s};
    final results = [answered('a', 0), answered('b', 0, correct: false)];
    List<String> shape() => [
          for (final b in treeFrom(
                  ladder: climbed(1), today: today, scenes: scenes, results: results)
              .branches)
            '${b.realmId}:${b.answers}:${b.flowers}'
        ];
    expect(shape(), shape());
  });
}
