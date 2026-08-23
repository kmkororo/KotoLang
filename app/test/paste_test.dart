/// Covers the one step where the app is at the mercy of somebody else's UI:
/// getting a long AI reply out of a phone chat app and into the paste box.
///
/// Two things go wrong there, and neither is the learner's fault. The copy
/// arrives truncated, or it arrives in pieces with the selections overlapping.
/// Both have to end in stored material rather than in an error.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotolang/domain/importer.dart';
import 'package:kotolang/domain/prompts.dart';
import 'package:kotolang/domain/question_generator.dart';

/// A material reply of [n] sentences, shaped exactly like the prompt asks for.
String materialReply(int n) {
  final sentences = [
    for (var i = 0; i < n; i++)
      {
        'text': 'Please confirm the repair policy before review number $i.',
        'translation_native': 'Check the repair rules before review $i.',
        'level': 'B2',
        'context': 'review',
        'speech_act': 'request',
        'targets': ['repair policy'],
        'naturalness': 5,
        'paraphrase_en': 'Make sure the rules for repairs are checked first, $i.',
        'paraphrase_options_en': [
          'There is no need to check the rules for repairs, $i.',
          'The reviewer checks the rules for repairs themselves, $i.',
          'The rules for repairs were confirmed last time, $i.',
        ],
        'meaning_options_native': [
          'No need to check the repair rules $i.',
          'Someone else checks the repair rules $i.',
          'The repair rules were already checked $i.',
        ],
      }
  ];

  return jsonEncode({
    'schema_version': '1.0',
    'type': 'material',
    'native_language': 'English',
    'domain': {'name': 'Work', 'name_native': 'Work', 'importance': 5},
    'learning_items': [
      {
        'text': 'repair policy',
        'type': 'term',
        'meaning_native': 'the rules for repairs',
        'priority': 5,
        'confidence': 0.9,
        'distractors_native': ['wrong one', 'wrong two', 'wrong three'],
      }
    ],
    'sentences': sentences,
  });
}

void main() {
  group('rescuing a reply that was cut off', () {
    test('a whole reply needs no rescuing and is not marked as damaged', () {
      final res = extractJson(materialReply(6));
      expect(res.ok, isTrue);
      expect(res.repaired, isFalse);
    });

    test('a reply cut off mid-sentence still yields the sentences before it',
        () {
      final full = materialReply(12);
      // Chop three quarters of the way through: deep inside the array.
      final cut = full.substring(0, (full.length * 0.75).round());

      expect(() => jsonDecode(cut), throwsFormatException,
          reason: 'the fixture must really be broken JSON');

      final res = extractJson(cut);
      expect(res.ok, isTrue, reason: 'the salvage pass should have run');
      expect(res.repaired, isTrue);

      final norm = normaliseMaterial(res.data!);
      expect(norm.sentences.length, greaterThan(4));
      expect(norm.sentences.length, lessThan(12));
      expect(norm.realm.name, 'Work');

      // The last entry may have been mid-write when the text stopped, so its
      // option lists can be short. What must never be short is the sentence
      // itself: a half-written sentence would be taught as if it were real.
      for (final s in norm.sentences) {
        expect(s.text, endsWith('.'));
        expect(s.translationNative, isNotEmpty);
      }
      for (final s in norm.sentences.take(norm.sentences.length - 1)) {
        expect(s.paraphraseOptionsEn.length, 3);
        expect(s.meaningOptionsNative.length, 3);
      }
    });

    test('questions built from a rescued import are all well formed', () {
      final full = materialReply(12);
      final res = extractJson(full.substring(0, (full.length * 0.75).round()));
      final norm = normaliseMaterial(res.data!);

      final items = {for (final i in norm.items) i.id: i};
      final questions = generateForSentences(
          norm.sentences, items, norm.sentences, Random(7));

      final byId = {for (final s in norm.sentences) s.id: s};
      expect(questions, isNotEmpty);
      for (final q in questions) {
        expect(validateQuestion(q, byId), isEmpty,
            reason: '${q.type} built from a truncated reply');
      }
    });

    test('a cut inside a string value drops that entry rather than half of it',
        () {
      final full = materialReply(8);
      final at = full.indexOf('"paraphrase_en": "Make sure', full.length ~/ 2);
      final cut = full.substring(0, at + 40); // stops inside the string

      final res = extractJson(cut);
      expect(res.ok, isTrue);
      final norm = normaliseMaterial(res.data!);
      for (final s in norm.sentences) {
        expect(s.text, isNotEmpty);
        expect(s.translationNative, isNotEmpty);
      }
    });

    test('a cut before any sentence arrives is reported, not silently accepted',
        () {
      final full = materialReply(8);
      final cut = full.substring(0, full.indexOf('"sentences"'));
      final res = extractJson(cut);
      // Either unreadable or readable-but-invalid; what must not happen is a
      // confident success with nothing in it.
      if (res.ok) {
        expect(validate(res.data!).ok, isFalse);
      }
    });

    test('an unclosed code fence is still read', () {
      final res = extractJson('Sure, here you go:\n```json\n${materialReply(4)}');
      expect(res.ok, isTrue);
      expect(normaliseMaterial(res.data!).sentences.length, 4);
    });

    test('prose with no JSON at all fails cleanly', () {
      expect(extractJson('I cannot help with that.').ok, isFalse);
      expect(extractJson('').ok, isFalse);
      expect(extractJson(null).ok, isFalse);
      expect(repairJson('nothing here'), isNull);
    });
  });

  group('collecting a reply in pieces', () {
    test('two clean halves rejoin into the original', () {
      final full = materialReply(6);
      final mid = full.length ~/ 2;
      final joined = appendPiece(full.substring(0, mid), full.substring(mid));

      expect(extractJson(joined).ok, isTrue);
      expect(normaliseMaterial(extractJson(joined).data!).sentences.length, 6);
    });

    test('an overlapping second selection does not duplicate the overlap', () {
      final full = materialReply(6);
      final mid = full.length ~/ 2;
      // The second copy starts 300 characters early, as a careful person's
      // finger would.
      final joined =
          appendPiece(full.substring(0, mid), full.substring(mid - 300));

      expect(joined.length, full.length,
          reason: 'the repeated stretch should have been removed exactly once');
      expect(extractJson(joined).ok, isTrue);
      expect(normaliseMaterial(extractJson(joined).data!).sentences.length, 6);
    });

    test('pasting the same piece twice changes nothing', () {
      final full = materialReply(3);
      expect(appendPiece(full, full), full);
    });

    test('three pieces work as well as two', () {
      final full = materialReply(9);
      final a = full.substring(0, full.length ~/ 3);
      final b = full.substring(full.length ~/ 3, 2 * full.length ~/ 3);
      final c = full.substring(2 * full.length ~/ 3);

      final joined = appendPiece(appendPiece(a, b), c);
      expect(normaliseMaterial(extractJson(joined).data!).sentences.length, 9);
    });

    test('pieces are joined with nothing between them', () {
      // Deliberate: a piece may end inside a JSON string, where an inserted
      // newline would be illegal.
      expect(appendPiece('alpha', 'beta'), 'alphabeta');
      expect(appendPiece('alpha\n', '\nbeta'), 'alphabeta');
      expect(appendPiece('', 'beta'), 'beta');
      expect(appendPiece('alpha', ''), 'alpha');
    });

    test('a piece split inside a sentence survives the join', () {
      final full = materialReply(5);
      // Cut in the middle of a text value, then hand the halves over the way a
      // chat app would: with a stray newline at each edge.
      final at = full.indexOf('before review number 2') + 8;
      final joined =
          appendPiece('${full.substring(0, at)}\n', '\n${full.substring(at)}');

      final res = extractJson(joined);
      expect(res.ok, isTrue);
      expect(res.repaired, isFalse);
      expect(normaliseMaterial(res.data!).sentences.length, 5);
    });
  });

  group('the readout shown after each piece', () {
    test('reports what is actually readable so far', () {
      final p = previewImport(materialReply(7));
      expect(p.ok, isTrue);
      expect(p.type, 'material');
      expect(p.sentences, 7);
      expect(p.items, 1);
      expect(p.repaired, isFalse);
    });

    test('flags a truncated paste so the learner knows to add the rest', () {
      final full = materialReply(12);
      final p = previewImport(full.substring(0, (full.length * 0.7).round()));
      expect(p.repaired, isTrue);
      expect(p.sentences, greaterThan(0));
    });

    test('says nothing is readable when nothing is', () {
      expect(previewImport('hello').ok, isFalse);
      expect(previewImport('hello').sentences, 0);
    });

    test('counts areas for a profile reply', () {
      const profile = '{"schema_version":"1.0","type":"profile",'
          '"profile":{"english_level":"B2","roles":[],"learning_priorities":[]},'
          '"domains":[{"name":"Work","importance":5},{"name":"Cycling","importance":3}]}';
      final p = previewImport(profile);
      expect(p.type, 'profile');
      expect(p.realms, 2);
    });
  });

  group('request sizes', () {
    test('every size asks for less than one screenful of chat could hide', () {
      for (final b in BatchSize.values) {
        expect(b.sentences, lessThanOrEqualTo(30));
        expect(b.items, lessThan(b.sentences));
      }
      expect(BatchSize.small.sentences, lessThan(BatchSize.standard.sentences));
      expect(BatchSize.standard.sentences, lessThan(BatchSize.large.sentences));
    });

    test('an unknown or missing name falls back to standard', () {
      expect(BatchSize.byName(null), BatchSize.standard);
      expect(BatchSize.byName('nonsense'), BatchSize.standard);
      expect(BatchSize.byName('small'), BatchSize.small);
      expect(BatchSize.byName('large'), BatchSize.large);
    });

    test('the prompt states the exact counts and demands one code block', () {
      final p = materialPrompt(
        uiLanguage: 'ja',
        realmName: 'Work',
        batch: BatchSize.small,
        round: 3,
      );
      expect(p, contains('Exactly ${BatchSize.small.items}'));
      expect(p, contains('Exactly ${BatchSize.small.sentences}'));
      expect(p, contains('BATCH 3'));
      expect(p, contains('```json'));
      expect(p, contains('Do not stop half-way'));
    });
  });
}
