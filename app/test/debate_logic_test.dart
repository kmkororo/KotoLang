/// The judgement made on the train, without an AI: which model reply the
/// learner's came nearest to, what the strong reply had that theirs did not,
/// and which tree is worth opening today.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:kotolang/domain/debate.dart';
import 'package:kotolang/domain/debate_logic.dart';
import 'package:kotolang/domain/importer.dart' as imp;

import 'pack_test.dart' show debate, pack;

DebateTree tree({String topic = 'Pulling the date forward', String? event}) =>
    imp.normalisePack(jsonDecode(pack(debates: [debate(topic: topic, event: event)])))
        .debates
        .single;

Chunk chunk(String id, Move move, String text) =>
    Chunk(id: id, move: move, text: text, native: '');

Attempt attempt(String debateId, int at) => Attempt(
      id: 'att-$debateId-$at',
      debateId: debateId,
      nodeId: 'n1',
      youSaid: 'x',
      moves: const [],
      day: '2026-01-01',
      at: at,
    );

void main() {
  group('assembling', () {
    final picked = [
      chunk('c1', Move.concede, 'I take your point on {x}, but'),
      chunk('c2', Move.evidence, 'the numbers from {y} say otherwise: {x} is fine.'),
    ];

    test('slots are filled and the pieces joined with single spaces', () {
      expect(assemble(picked, {'x': 'headcount', 'y': 'March'}),
          'I take your point on headcount, but the numbers from March say otherwise: headcount is fine.');
    });

    test('an unfilled slot keeps its marker so the gap is visible', () {
      expect(assemble(picked, {'x': 'headcount'}), contains('{y}'));
    });

    test('slot names come out once each, in first-seen order', () {
      expect(slotsIn(picked), ['x', 'y']);
      expect(slotsIn(const []), isEmpty);
    });

    test('suggestions are what the model replies put in their slots, deduped', () {
      expect(slotSuggestions(tree().root), ['headcount']);
    });
  });

  group('comparing', () {
    final root = tree().root;

    test('the same moves in the same shape find the same reply', () {
      expect(closestRebuttal(root, 'anything', [Move.concede, Move.however, Move.evidence]).id,
          'r1a');
      expect(closestRebuttal(root, 'anything', [Move.however]).id, 'r1b');
      expect(closestRebuttal(root, 'anything', [Move.concede, Move.close]).id, 'r1c');
    });

    test('with no moves declared, borrowed words break the tie', () {
      expect(closestRebuttal(root, 'Model reply r1c', const []).id, 'r1c');
    });

    test('the structure check is against the strong reply, whichever was closest', () {
      final c = structureCheck(root, [Move.however]);
      expect(c.present, [Move.however]);
      expect(c.missing, [Move.concede, Move.evidence]);
      expect(structureCheck(root, [Move.concede, Move.however, Move.evidence]).missing, isEmpty);
    });
  });

  group('choosing', () {
    const today = '2026-03-10';

    test('nothing open means nothing to argue', () {
      expect(pickDebate(const [], const [], today: today), isNull);
      expect(pickDebate([tree().copyWith(disabled: true)], const [], today: today), isNull);
    });

    test('the nearest coming date comes first', () {
      final soon = tree(topic: 'soon', event: '2026-03-12');
      final later = tree(topic: 'later', event: '2026-04-01');
      final undated = tree(topic: 'undated');
      expect(pickDebate([undated, later, soon], const [], today: today)!.id, soon.id);
    });

    test('a date already past still beats no date at all', () {
      final past = tree(topic: 'past', event: '2026-03-01');
      final undated = tree(topic: 'undated');
      expect(pickDebate([undated, past], const [], today: today)!.id, past.id);
    });

    test('among equals, the one argued least recently', () {
      final a = tree(topic: 'a');
      final b = tree(topic: 'b');
      final c = tree(topic: 'c');
      final picked = pickDebate(
        [a, b, c],
        [attempt(a.id, 100), attempt(b.id, 500), attempt(b.id, 50), attempt(c.id, 300)],
        today: today,
      );
      expect(picked!.id, a.id);
    });

    test('a tree never argued comes before one that was', () {
      final a = tree(topic: 'a');
      final b = tree(topic: 'b');
      expect(pickDebate([a, b], [attempt(a.id, 1)], today: today)!.id, b.id);
    });
  });
}
