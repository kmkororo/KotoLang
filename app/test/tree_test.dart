/// The tree is a record, not a decoration: every bough is a field on one of
/// two sides, every leaf and flower and fruit comes from an answer, and the
/// shape never rearranges itself between visits.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:kotolang/core/util.dart';
import 'package:kotolang/domain/models.dart';
import 'package:kotolang/domain/scene.dart';
import 'package:kotolang/domain/tree.dart';

import 'scene_test.dart' show scene;

Realm realm(String id, {bool unlocked = true}) => Realm(
      id: id,
      name: id,
      nameNative: '',
      normKeyValue: id,
      importance: 3,
      confidence: 1,
      contexts: const [],
      selected: true,
      hasMaterial: true,
      unlocked: unlocked,
    );

HistoryEntry answer(String realmId, QuestionType type, {String? day}) =>
    HistoryEntry(
      day: day ?? today(),
      at: DateTime.now(),
      questionId: 'q',
      itemId: 'i',
      realmId: realmId,
      type: type,
      correct: true,
      wasDue: false,
    );

/// A scene in [field], the learner's own unless [builtin].
Scene mk(String topic, String field, {bool builtin = false}) => Scene.fromJson({
      ...scene(topic),
      if (builtin) 'id': 'builtin_$topic',
      'source': builtin ? 'builtin' : 'ai',
      'realm_id': field,
    });

SceneResult res(Scene sc, int exchange,
        {bool gist = true, bool reply = true, bool review = false, int at = 0}) =>
    SceneResult(
      sceneId: sc.id,
      exchange: exchange,
      gistOk: gist,
      replyOk: reply,
      peeked: false,
      review: review,
      day: today(),
      at: at,
    );

TreeShape grow(List<Scene> scenes, List<SceneResult> results) => treeFrom(
      history: const [],
      realms: const [],
      items: const [],
      states: const {},
      today: today(),
      results: results,
      scenes: {for (final s in scenes) s.id: s},
      fieldLabels: const {'work': '仕事', 'travel': '旅行'},
    );

void main() {
  test('an empty record is a seed, not a tree', () {
    final t = treeFrom(
        history: const [], realms: [realm('a')], items: const [], states: const {}, today: today());
    expect(t.isSeed, isTrue);
    expect(t.answers, 0);
    expect(t.branches, isEmpty, reason: 'nothing practised, nothing grown');
    expect(t.stage, 0);
  });

  test('a sample and an own scene in the same field grow on two different boughs', () {
    final sample = mk('Tip', 'travel', builtin: true);
    final own = mk('Trip', 'travel');
    final t = grow([sample, own], [res(sample, 0), res(sample, 1), res(own, 0)]);
    expect(t.branches.map((b) => b.realmId), [sampleBranch('travel'), ownBranch('travel')],
        reason: 'samples first, then the learner\'s own');
    expect(t.branches.first.own, isFalse);
    expect(t.branches.first.label, '旅行');
    expect(t.branches.first.answers, 2);
    expect(t.branches.last.answers, 1);
  });

  test('leaves for what was caught, flowers only on the learner\'s own', () {
    final sample = mk('Tip', 'travel', builtin: true);
    final own = mk('Trip', 'travel');
    final t = grow([sample, own], [
      res(sample, 0, gist: true, reply: true),
      res(own, 0, gist: true, reply: true),
      res(own, 1, gist: false, reply: true),
    ]);
    final s = t.branches.first, o = t.branches.last;
    expect(s.twigs[Twig.grasp], 1);
    expect(s.twigs[Twig.reply], 1);
    expect(s.flowers, 0, reason: 'samples never flower');
    expect(o.twigs[Twig.grasp], 1);
    expect(o.twigs[Twig.reply], 2);
    expect(o.flowers, 2);
    expect(t.flowers, 2);
  });

  test('a fruit for an own scene whose latest run was all right', () {
    final own = mk('Trip', 'travel');
    final sample = mk('Tip', 'travel', builtin: true);
    // First run: one miss. Second run: perfect. Latest wins.
    final t = grow([own, sample], [
      res(own, 0, gist: false, at: 1),
      res(own, 1, at: 2),
      res(own, 0, at: 3),
      res(own, 1, at: 4),
      res(sample, 0, at: 5),
      res(sample, 1, at: 6),
    ]);
    expect(t.fruit, 1);
    expect(t.branches.firstWhere((b) => b.own).fruit, 1);
    expect(t.branches.firstWhere((b) => !b.own).fruit, 0, reason: 'samples bear no fruit');

    // A perfect run that is later spoiled loses the fruit.
    final spoiled =
        grow([own], [res(own, 0, at: 1), res(own, 1, at: 2), res(own, 0, reply: false, at: 3)]);
    expect(spoiled.fruit, 0);
  });

  test('reviews practise a bough without growing it', () {
    final own = mk('Trip', 'work');
    final t = grow(
        [own], [res(own, 0), res(own, 1), res(own, 0, review: true), res(own, 1, review: true)]);
    expect(t.branches.single.answers, 2);
    expect(t.answers, 2);
    expect(t.scenes, 1);
  });

  test('the old question sessions still stand as own boughs, named by their area', () {
    final t = treeFrom(
      history: [answer('a', QuestionType.gist), answer('a', QuestionType.produce)],
      realms: [realm('a')],
      items: const [],
      states: const {},
      today: today(),
    );
    expect(t.branches.single.realmId, ownBranch('a'));
    expect(t.branches.single.twigs[Twig.grasp], 1);
    expect(t.branches.single.twigs[Twig.reply], 1);
  });

  test('the stages turn over at three, ten, thirty and eighty scenes', () {
    expect([0, 1, 3, 4, 10, 11, 30, 31, 80, 81].map(treeStage), [0, 1, 1, 2, 2, 3, 3, 4, 4, 5]);
    expect(treeStage(1000), treeStages - 1);
  });

  group('growth curves', () {
    test('the trunk grows with every early answer, and never runs off the top',
        () {
      expect(trunkGrowth(0), 0);
      var last = 0.0;
      for (final n in [1, 5, 20, 100, 400, 999]) {
        final g = trunkGrowth(n);
        expect(g, greaterThan(last), reason: 'no reward for the $n th answer');
        expect(g, lessThanOrEqualTo(1.0));
        last = g;
      }
      expect(trunkGrowth(100000), 1.0);
    });

    test('the seedling stage lasts long enough to be a stage', () {
      expect(trunkGrowth(1), lessThan(0.02));
      expect(trunkGrowth(10), lessThan(0.12));
      expect(trunkGrowth(50), lessThan(0.35));
      expect(trunkGrowth(100), lessThan(0.45));
      expect(trunkGrowth(250), greaterThan(0.50));
      expect(trunkGrowth(600), greaterThan(0.80));
    });

    test('girth keeps going after height has stopped', () {
      expect(trunkGirth(1000), closeTo(trunkGrowth(1000), 0.001));
      expect(trunkGirth(10000), greaterThan(trunkGirth(1000)));
      expect(trunkGirth(1000000), lessThanOrEqualTo(2.0));
    });

    test('a neglected area is visibly shorter than a busy one', () {
      expect(branchGrowth(2, 200), lessThan(branchGrowth(200, 200)));
      expect(branchGrowth(0, 200), 0);
    });
  });
}
