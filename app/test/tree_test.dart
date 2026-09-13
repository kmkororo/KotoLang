/// The tree is a record, not a decoration.
///
/// It is read from two numbers and no others: the questions answered and the
/// fields open. The ladder measures how hard the listening is and has no say
/// here — a reward that needs a five-axis ladder explained before it can be
/// read is not a reward.
library;

import 'package:flutter_test/flutter_test.dart';
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
  });

  test('the size is the questions answered, not the turns', () {
    final scenes = {for (final s in [make('a'), make('b')]) s.id: s};
    // Forty turns of one question is one question.
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
  });

  test('every level is bigger than the one before, by the same proportion', () {
    for (var l = 1; l < treeTopLevel; l++) {
      expect(treeSizeAt(l + 1.0), greaterThan(treeSizeAt(l.toDouble())));
    }
    final step = treeSizeAt(3) / treeSizeAt(2);
    expect(treeSizeAt(151) / treeSizeAt(150), closeTo(step, 1e-9));
    expect(treeSizeAt(treeTopLevel.toDouble()), closeTo(2.5 * worldRadius, 1e-6),
        reason: 'at the top the tree is two and a half worlds across');
  });

  test('the shape follows the name', () {
    // Maturity only ever goes up, and each name starts further along.
    var last = -1.0;
    for (var l = 1; l <= treeTopLevel; l++) {
      final m = treeMaturityAt(l.toDouble());
      expect(m, greaterThanOrEqualTo(last));
      last = m;
    }
    expect(treeMaturityAt(1), 0);
    expect(treeMaturityAt(treeTopLevel.toDouble()), 1);
    var entry = 1;
    for (var i = 0; i < treeLevelsPerName.length; i++) {
      final next = entry + treeLevelsPerName[i];
      expect(treeMaturityAt(next.toDouble()), greaterThan(treeMaturityAt(entry.toDouble())),
          reason: 'name ${i + 1} looks older than name $i');
      entry = next;
    }
  });

  test('the camera pulls back without a jump, and ends on the whole world', () {
    TreeView? prev;
    for (var x = 1.0; x <= treeTopLevel; x += 0.25) {
      final v = treeViewAt(x);
      expect(v.top, greaterThan(worldRadius), reason: 'the tree is in view');
      expect(v.bottom, lessThan(worldRadius), reason: 'so is the ground');
      if (prev != null) {
        expect(v.span, greaterThan(prev.span), reason: 'the view only widens');
        expect(v.toGlobe, greaterThanOrEqualTo(prev.toGlobe));
        expect(v.altitude, greaterThanOrEqualTo(prev.altitude));
        expect(v.span / prev.span, lessThan(1.1), reason: 'no sudden zoom at $x');
      }
      prev = v;
    }
    // Close up, the ground is a plain: the view is a sliver of the world.
    expect(treeViewAt(1).span, lessThan(worldRadius * 0.02));
    expect(treeViewAt(treeFullLevel.toDouble()).toGlobe, 0,
        reason: 'a full-grown tree still stands on a plain');
    final top = treeViewAt(treeTopLevel.toDouble());
    expect(top.toGlobe, 1);
    expect(top.bottom, lessThan(-worldRadius), reason: 'the whole world in view');
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
    // The growing screen draws one row per name, walking the questions and
    // asking which name each is, so this is what it relies on.
    final seen = <int>[];
    for (var q = 0; q <= treeLevelAt(treeFullLevel); q++) {
      final n = treeName(q);
      if (seen.isEmpty || seen.last != n) seen.add(n);
    }
    expect(seen, [for (var i = 0; i < treeNames; i++) i],
        reason: 'each name once, in order, from the seed to the last');
  });

  test('the first fortnight is a level every question or two', () {
    // What carries somebody through the beginning is not the tenth name a
    // year away; it is the tree answering to something new tonight.
    expect(treeLevelAt(2), lessThanOrEqualTo(2));
    expect(treeLevelAt(3), lessThanOrEqualTo(4));
    expect(treeLevelAt(5), lessThanOrEqualTo(10));
    expect(treeLevel(15), greaterThanOrEqualTo(6),
        reason: 'five or six level-ups in the first fifteen questions');
    // And they spread out without ever closing up again.
    // Rounding to whole questions can take a step off a gap, so this asks
    // that the gaps widen rather than that no two are ever equal.
    for (var l = 2; l < 300; l++) {
      expect(treeLevelAt(l + 1) - treeLevelAt(l),
          greaterThanOrEqualTo(treeLevelAt(l) - treeLevelAt(l - 1) - 1),
          reason: 'the gap to the next level does not close up');
    }
    expect(treeLevelAt(101) - treeLevelAt(100),
        greaterThan(treeLevelAt(11) - treeLevelAt(10)));
  });

  test('there are about two hundred things to be called', () {
    // Ten names with levels inside them. The last name never runs out, so
    // this is a floor rather than a total.
    final named = treeLevelsPerName.fold(0, (a, b) => a + b);
    expect(named + 130, greaterThanOrEqualTo(200));
    expect(treeRank(0), (name: 0, level: 1));
    expect(treeRank(1000000).name, treeNames - 1,
        reason: 'the last name holds everything past it');
    expect(treeRank(1000000).level, greaterThan(200));
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
