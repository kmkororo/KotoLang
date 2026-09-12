/// The samples that ship with the app.
///
/// Nobody reviews these after they are written, and a broken one is invisible
/// on screen: a turn whose wrong replies give the answer away still looks
/// like a question and still records an answer. So the rules they were
/// written under are checked here, where the failure is loud.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:kotolang/data/builtin_scenes.dart';
import 'package:kotolang/data/scenes/base.dart';
import 'package:kotolang/domain/field.dart';
import 'package:kotolang/domain/scene.dart';

void main() {
  group('what ships', () {
    test('there are samples, and every field has some', () {
      expect(baseScenes, hasLength(30));
      for (final id in builtinFieldIds) {
        expect(baseScenes.where((s) => fieldOf(s) == id), isNotEmpty, reason: id);
      }
    });

    test('every id is its own, and stays its own', () {
      // Results and reviews are keyed by these. A renamed id is a learner's
      // record quietly detached from the thing it was about.
      final ids = baseScenes.map((s) => s.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final id in ids) {
        expect(id, startsWith('builtin_'), reason: id);
      }
      expect(kindOf('builtin_w1'), 'work');
      expect(kindOf('builtin_t1'), 'travel');
      expect(kindOf('nothing_like_it'), defaultFieldId);
    });

    test('they are marked as samples, so the tree knows not to flower', () {
      for (final s in baseScenes) {
        expect(s.isBuiltin, isTrue, reason: s.id);
      }
    });

    test('the lengths and the windows vary', () {
      // A set that is all the same length, at all the same speed, is a drill
      // rather than a set of conversations.
      expect(baseScenes.map((s) => s.turns.length).toSet().length,
          greaterThanOrEqualTo(3));
      expect(baseScenes.map((s) => s.windowMs).toSet().length,
          greaterThanOrEqualTo(3));
      for (final s in baseScenes) {
        expect(s.turns.length, inInclusiveRange(1, maxTurnsPerScene), reason: s.id);
        expect(s.windowMs, inInclusiveRange(minWindowMs, maxWindowMs), reason: s.id);
      }
    });
  });

  group('every turn', () {
    test('offers three replies, exactly one of which fits', () {
      for (final s in baseScenes) {
        for (var i = 0; i < s.turns.length; i++) {
          final t = s.turns[i];
          expect(t.replies, hasLength(repliesPerTurn), reason: '${s.id}#$i');
          expect(t.replies.where((r) => r.correct), hasLength(1),
              reason: '${s.id}#$i');
          for (final r in t.replies) {
            expect(r.text.trim(), isNotEmpty, reason: '${s.id}#$i');
          }
        }
      }
    });

    test('says the same thing again in different words', () {
      // The restate is what the learner gets when the moment passes. Repeating
      // the sentence would make it a second listen, which this does not give.
      for (final s in baseScenes) {
        for (var i = 0; i < s.turns.length; i++) {
          final t = s.turns[i];
          expect(t.restate.trim(), isNotEmpty, reason: '${s.id}#$i');
          expect(t.restate, isNot(t.line), reason: '${s.id}#$i');
        }
      }
    });

    test('does not leave the right reply sitting first', () {
      // They are authored right-first and moved by the id. If they were not
      // moved, the answer would be the first row every time.
      final first = baseScenes
          .expand((s) => s.turns)
          .where((t) => t.answer == 0)
          .length;
      final turns = baseScenes.fold(0, (n, s) => n + s.turns.length);
      expect(first, lessThan(turns), reason: 'nothing was moved at all');
      expect(first / turns, lessThan(0.6));
    });
  });

  group('a keyword turn', () {
    Iterable<({Scene scene, int i, Turn turn})> keywordTurns() sync* {
      for (final s in baseScenes) {
        for (var i = 0; i < s.turns.length; i++) {
          if (s.turns[i].type == TurnType.keyword) yield (scene: s, i: i, turn: s.turns[i]);
        }
      }
    }

    test('names both halves of the pair', () {
      for (final k in keywordTurns()) {
        expect(k.turn.keyWord.trim(), isNotEmpty, reason: '${k.scene.id}#${k.i}');
        expect(k.turn.confusable.trim(), isNotEmpty, reason: '${k.scene.id}#${k.i}');
        expect(k.turn.keyWord.toLowerCase(), isNot(k.turn.confusable.toLowerCase()),
            reason: '${k.scene.id}#${k.i}');
      }
    });

    test('puts the key word in the line and keeps its pair out of it', () {
      // A line naming both leaves nothing to mishear: anyone who caught the
      // sentence knows which is which, and the turn measures nothing.
      for (final k in keywordTurns()) {
        final line = k.turn.line.toLowerCase();
        final where = '${k.scene.id}#${k.i}';
        expect(line, contains(k.turn.keyWord.toLowerCase()), reason: where);
        expect(line, isNot(contains(k.turn.confusable.toLowerCase())), reason: where);
      }
    });
  });

  group('a polarity turn', () {
    test('turns on a word that reverses the line', () {
      const reversing = [
        'not', "n't", 'never', 'unless', 'without', 'hardly', 'no ',
      ];
      for (final s in baseScenes) {
        for (var i = 0; i < s.turns.length; i++) {
          final t = s.turns[i];
          if (t.type != TurnType.polarity) continue;
          final line = t.line.toLowerCase();
          expect(reversing.any(line.contains), isTrue,
              reason: '${s.id}#$i has no reversing word: ${t.line}');
        }
      }
    });
  });

  group('a multiFact turn', () {
    test('holds two facts, and each wrong reply drops exactly one of them', () {
      for (final s in baseScenes) {
        for (var i = 0; i < s.turns.length; i++) {
          final t = s.turns[i];
          if (t.type != TurnType.multiFact) continue;
          final where = '${s.id}#$i';
          expect(t.facts, hasLength(2), reason: where);
          final slots = t.facts.map((f) => f.slot).toSet();
          expect(slots, hasLength(2), reason: where);
          for (final f in t.facts) {
            expect(f.value.trim(), isNotEmpty, reason: where);
            expect(f.confusable.trim(), isNotEmpty, reason: where);
          }
          final missed = <String>[];
          for (final r in t.replies) {
            if (r.correct) {
              expect(r.missedSlot, isNull, reason: where);
              continue;
            }
            expect(r.missedSlot, isNotNull, reason: '$where: a wrong reply names no fact');
            expect(slots, contains(r.missedSlot), reason: where);
            missed.add(r.missedSlot!);
          }
          expect(missed.toSet(), hasLength(2),
              reason: '$where: both wrong replies drop the same fact');
        }
      }
    });
  });

  group('the languages', () {
    test('Japanese is on every conversation, and on every reply', () {
      for (final s in builtinScenes('ja')) {
        expect(s.titleNative.trim(), isNotEmpty, reason: s.id);
        expect(s.settingNative.trim(), isNotEmpty, reason: s.id);
        for (var i = 0; i < s.turns.length; i++) {
          final t = s.turns[i];
          expect(t.lineNative.trim(), isNotEmpty, reason: '${s.id}#$i');
          for (final r in t.replies) {
            expect(r.native.trim(), isNotEmpty, reason: '${s.id}#$i: ${r.text}');
          }
        }
      }
    });

    test('the translation stays on its own reply through the shuffle', () {
      // The overlay is written right-first; the English has already been
      // moved. If the two were not moved together, the right reply would
      // carry somebody else's Japanese and nobody would notice on screen.
      final ja = {for (final s in builtinScenes('ja')) s.id: s};
      final w1 = ja['builtin_w1']!.turns.first;
      expect(w1.replies[w1.answer].text, startsWith('Thursday'));
      expect(w1.replies[w1.answer].native, startsWith('木曜'));
    });

    test('a language nobody has translated still plays, in English', () {
      final hi = builtinScenes('hi');
      expect(hi, hasLength(baseScenes.length));
      expect(hi.first.turns.first.line, isNotEmpty);
      expect(hi.first.turns.first.replies, hasLength(repliesPerTurn));
      // Falling back is not the same as being broken: the label still reads.
      expect(hi.first.label, isNotEmpty);
    });

    test('switching language keeps the ids, so the record survives it', () {
      expect(builtinScenes('ja').map((s) => s.id).toList(),
          builtinScenes('hi').map((s) => s.id).toList());
    });
  });

  group('what the app asks of them', () {
    test('the titles are handed to the learner’s AI so it writes others', () {
      expect(builtinTopics(), hasLength(baseScenes.length));
      expect(builtinTopics(), contains('Moving a deadline'));
    });

    test('the walkthrough opens on a short one', () {
      final t = tutorialScene('ja');
      expect(t, isNotNull);
      expect(fieldOf(t!), 'work');
      expect(t.turns, hasLength(1),
          reason: 'the first thing anybody plays should end quickly');
    });

    test('chosen fields come first, and nothing is dropped', () {
      final all = builtinScenes('ja');
      final travelFirst = builtinScenes('ja', interests: const ['travel']);
      expect(travelFirst, hasLength(all.length));
      expect(travelFirst.map((s) => s.id).toSet(), all.map((s) => s.id).toSet());
      expect(fieldOf(travelFirst.first), 'travel');
    });
  });
}
