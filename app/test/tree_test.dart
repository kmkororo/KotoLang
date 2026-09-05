/// The growth tree is a reading of the answer log, so these are the tests that
/// keep the picture honest: the same history must always draw the same tree,
/// and every part of it must correspond to something the learner actually did.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kotolang/core/util.dart';
import 'package:kotolang/domain/models.dart';
import 'package:kotolang/domain/tree.dart';

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

void main() {
  test('an empty history is a seed, not a tree', () {
    final t = treeFrom(
        history: const [],
        realms: [realm('a')],
        items: const [],
        states: const {},
        today: today());
    expect(t.isSeed, isTrue);
    expect(t.answers, 0);
  });

  test('one bough per unlocked area, always in the same order', () {
    final realms = [realm('c'), realm('a'), realm('b'), realm('z', unlocked: false)];
    final t = treeFrom(
        history: [answer('a', QuestionType.gist)],
        realms: realms,
        items: const [],
        states: const {},
        today: today());
    expect(t.branches.map((b) => b.realmId), ['a', 'b', 'c'],
        reason: 'a bough must not move between visits');
    expect(t.branches.any((b) => b.realmId == 'z'), isFalse,
        reason: 'a locked area has nothing growing on it');
  });

  test('answers land on the area and the format they were given in', () {
    final t = treeFrom(
      history: [
        answer('a', QuestionType.gist),
        answer('a', QuestionType.reply),
        answer('a', QuestionType.produce),
        answer('b', QuestionType.register),
      ],
      realms: [realm('a'), realm('b')],
      items: const [],
      states: const {},
      today: today(),
    );
    final a = t.branches.firstWhere((b) => b.realmId == 'a');
    expect(a.answers, 3);
    expect(a.twigs[Twig.grasp], 2);
    expect(a.twigs[Twig.reply], 1);
    expect(a.twigs[Twig.claim], 0);
    expect(t.answers, 4);
  });

  test('every question type hangs on exactly one twig', () {
    final seen = <QuestionType>{};
    for (final t in QuestionType.values) {
      expect(twigFor(t), isNotNull);
      seen.add(t);
    }
    expect(seen.length, QuestionType.values.length);
  });

  test('an area goes pale only when it is left alone with reviews waiting', () {
    final t = treeFrom(
      history: [answer('a', QuestionType.gist)],
      realms: [realm('a'), realm('b')],
      items: [
        LearningItem(
            id: 'i1',
            text: 'x',
            normKeyValue: 'x',
            type: 'term',
            meaningNative: 'y',
            priority: 3,
            confidence: 1,
            distractorsNative: const [],
            realmIds: const ['a']),
      ],
      states: {
        'i1': SrsState(
            itemId: 'i1', due: addDays(today(), -1), box: 2, introduced: true),
      },
      today: today(),
    );
    expect(t.branches.firstWhere((b) => b.realmId == 'a').thirsty, isFalse,
        reason: 'answered here today, so it has been watered');

    // The same library, but nothing done in that area today.
    final neglected = treeFrom(
      history: [answer('a', QuestionType.gist, day: addDays(today(), -3))],
      realms: [realm('a'), realm('b')],
      items: [
        LearningItem(
            id: 'i1',
            text: 'x',
            normKeyValue: 'x',
            type: 'term',
            meaningNative: 'y',
            priority: 3,
            confidence: 1,
            distractorsNative: const [],
            realmIds: const ['a']),
      ],
      states: {
        'i1': SrsState(
            itemId: 'i1', due: addDays(today(), -1), box: 2, introduced: true),
      },
      today: today(),
    );
    expect(neglected.branches.firstWhere((b) => b.realmId == 'a').thirsty, isTrue);
    expect(neglected.branches.firstWhere((b) => b.realmId == 'b').thirsty, isFalse);
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
      // Two curves have been wrong here. The first was referenced so far out
      // that one answer bought four tenths of the height. The second was a
      // plain log against a thousand, which still handed a third of it over
      // inside ten answers — cotyledons on Monday, a tree on Tuesday, then a
      // year of nothing. A sitting is a handful of answers, so the first
      // hundred of them have to still look like a plant.
      expect(trunkGrowth(1), lessThan(0.02));
      expect(trunkGrowth(10), lessThan(0.12));
      expect(trunkGrowth(50), lessThan(0.35));
      expect(trunkGrowth(100), lessThan(0.45));

      // And it must not stall either: by a few hundred it is plainly a tree.
      expect(trunkGrowth(250), greaterThan(0.50));
      expect(trunkGrowth(600), greaterThan(0.80));
    });

    test('girth keeps going after height has stopped', () {
      // Someone two years in still has to see the tree answer to their work,
      // and it cannot answer by getting taller for ever.
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
