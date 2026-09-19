/// Covers the one step where the app is at the mercy of somebody else's UI:
/// getting a reply out of a chat window and into the app.
///
/// Chat clients truncate, wrap replies in prose, fence them in code blocks,
/// and hand over half a selection at a time. None of that is the learner's
/// fault, so none of it may lose their material silently: what arrived whole
/// is kept, what was cut is rescued as far as the cut, and what cannot be
/// read at all is said so rather than quietly dropped.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotolang/domain/importer.dart';
import 'package:kotolang/domain/scene.dart';
import 'package:kotolang/domain/set_import.dart';

import 'fixtures.dart' show pack, scene;

/// A reply of [n] sets, shaped exactly as the prompt asks.
String scenesReply(int n) => pack([for (var i = 0; i < n; i++) scene('Moving a deadline $i')]);

List<Scene> normaliseScenes(Map<String, dynamic> data) =>
    normaliseSets(data, uiLanguage: 'ja').sets;

int scenesIn(String raw) {
  final ex = extractJson(raw);
  if (!ex.ok) return 0;
  return normaliseScenes(ex.data!).length;
}

void main() {
  group('rescuing a reply that was cut off', () {
    test('a whole reply needs no rescuing and is not marked as damaged', () {
      final ex = extractJson(scenesReply(3));
      expect(ex.ok, isTrue);
      expect(ex.repaired, isFalse);
      expect(normaliseScenes(ex.data!), hasLength(3));
    });

    test('a reply cut off mid-conversation still yields the ones before it', () {
      final whole = scenesReply(5);
      final cut = whole.substring(0, (whole.length * 0.6).round());
      final ex = extractJson(cut);
      expect(ex.ok, isTrue, reason: 'what arrived is worth keeping');
      expect(ex.repaired, isTrue, reason: 'and the learner is told it was cut');
      final kept = normaliseScenes(ex.data!).length;
      expect(kept, greaterThan(0));
      expect(kept, lessThan(5));
    });

    test('a cut inside a string drops that conversation, not half of one', () {
      final whole = scenesReply(4);
      final at = whole.indexOf('The handover has moved') + 12;
      final ex = extractJson(whole.substring(0, at));
      if (ex.ok) {
        for (final s in normaliseScenes(ex.data!)) {
          expect(s.set!.reply.options, hasLength(3));
          expect(s.set!.partner.text, isNotEmpty);
        }
      }
    });

    test('a cut before any conversation arrives is reported, not accepted', () {
      final whole = scenesReply(2);
      final ex = extractJson(whole.substring(0, whole.indexOf('"items"') + 12));
      expect(ex.ok && normaliseScenes(ex.data!).isNotEmpty, isFalse);
    });

    test('an unclosed code fence is still read', () {
      expect(scenesIn('```json\n${scenesReply(2)}'), 2);
    });

    test('prose wrapped around the reply is still read', () {
      expect(
        scenesIn('Sure! Here are your conversations:\n\n${scenesReply(2)}\n\nLet me know.'),
        2,
      );
    });

    test('prose with no JSON at all fails cleanly', () {
      final ex = extractJson('I am afraid I cannot help with that.');
      expect(ex.ok, isFalse);
      expect(ex.failure, isNotNull);
    });
  });

  group('collecting a reply in pieces', () {
    test('two clean halves rejoin into the original', () {
      final whole = scenesReply(4);
      final half = (whole.length / 2).round();
      final joined = appendPiece(whole.substring(0, half), whole.substring(half));
      expect(joined, whole);
      expect(scenesIn(joined), 4);
    });

    test('an overlapping second selection does not duplicate the overlap', () {
      final whole = scenesReply(4);
      final half = (whole.length / 2).round();
      // The learner's second selection starts before their first one ended.
      final joined = appendPiece(whole.substring(0, half), whole.substring(half - 200));
      expect(joined, whole);
    });

    test('pasting the same piece twice changes nothing', () {
      final whole = scenesReply(3);
      expect(appendPiece(whole, whole), whole);
    });

    test('three pieces work as well as two', () {
      final whole = scenesReply(5);
      final a = (whole.length / 3).round();
      final b = (whole.length * 2 / 3).round();
      var buffer = appendPiece('', whole.substring(0, a));
      buffer = appendPiece(buffer, whole.substring(a, b));
      buffer = appendPiece(buffer, whole.substring(b));
      expect(scenesIn(buffer), 5);
    });
  });

  group('the readout shown after each piece', () {
    test('says how many conversations can be read so far', () {
      final whole = scenesReply(4);
      final half = (whole.length / 2).round();
      final part = previewImport(whole.substring(0, half));
      expect(part.type, 'scenes');
      expect(part.scenes, lessThan(4));

      final all = previewImport(whole);
      expect(all.ok, isTrue);
      expect(all.scenes, 4);
      expect(all.repaired, isFalse);
    });

    test('a profile reply is recognised as one', () {
      final profile = jsonEncode({
        'schema_version': '1.0',
        'type': 'profile',
        'profile': {'english_level': 'B1'},
        'domains': [
          {'name': 'Code review', 'importance': 4},
          {'name': 'Meetings', 'importance': 3},
        ],
      });
      final p = previewImport(profile);
      expect(p.type, 'profile');
      expect(p.realms, 2);
    });

    test('nothing readable says so rather than showing a zero', () {
      expect(previewImport('hello').ok, isFalse);
      expect(previewImport('').ok, isFalse);
    });
  });
}
