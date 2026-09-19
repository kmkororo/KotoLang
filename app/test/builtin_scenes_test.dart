/// The samples that ship with the app.
///
/// Nobody reviews these after they are written, and a broken one is invisible
/// on screen: a set whose wrong option has no reason still looks like a
/// question and still records an answer. So they are put through the same
/// checks a set from the learner's AI is, here, where the failure is loud.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:kotolang/data/builtin_scenes.dart';
import 'package:kotolang/data/sets/samples.dart';
import 'package:kotolang/domain/field.dart';
import 'package:kotolang/domain/set_import.dart';

/// A sample as the AI would have written it, in [lang].
Map<String, dynamic> asReply(SampleSet s, String lang) {
  final t = s.text[lang]!;
  return {
    'type': 'replyPredict',
    'scene': t.scene,
    'partnerName': t.partnerName,
    'partner': {
      'text': s.partner,
      'paraphrase': s.paraphrase,
      'native': t.partnerNative,
      'stress': s.partnerStress,
    },
    'reply': {
      'options': s.replies,
      'answer': 0,
      'why': ['', ...t.replyWhy],
      'trap': s.trap.name,
    },
    'predict': {
      'options': t.predict,
      'answer': 0,
      'why': ['', ...t.predictWhy],
    },
    'response': {'text': s.response, 'native': t.responseNative, 'stress': s.responseStress},
  };
}

void main() {
  group('what ships', () {
    test('there are samples, and every field has some', () {
      expect(sampleSets.length, greaterThanOrEqualTo(8));
      for (final id in builtinFieldIds) {
        expect(sampleSets.where((s) => s.field == id).length, greaterThanOrEqualTo(2),
            reason: id);
      }
    });

    test('every id is its own, and stays its own', () {
      // Results and reviews are keyed by these. A renamed id is a learner's
      // record quietly detached from the thing it was about.
      final ids = sampleSets.map((s) => s.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final id in ids) {
        expect(id, startsWith('sample_'), reason: id);
      }
      expect(kindOf('sample_work_room'), 'work');
      expect(kindOf('sample_travel_gate'), 'travel');
      expect(kindOf('nothing_like_it'), defaultFieldId);
    });

    test('they are samples, and they can be played', () {
      for (final s in builtinScenes('ja')) {
        expect(s.isBuiltin, isTrue, reason: s.id);
        expect(s.playable, isTrue, reason: s.id);
      }
    });

    test('the walkthrough has one to start with', () {
      expect(fieldOf(tutorialScene('ja')!), 'work');
    });
  });

  group('every sample', () {
    for (final lang in ['en', 'ja']) {
      test('passes the rules a set from the AI must pass ($lang)', () {
        for (final s in sampleSets) {
          expect(s.text[lang], isNotNull, reason: '${s.id} has no $lang');
          final r = checkSet(asReply(s, lang), uiLanguage: lang);
          expect(r.reasons, isEmpty, reason: '${s.id} ($lang): ${r.reasons}');
          expect(r.warnings, isEmpty, reason: '${s.id} ($lang): ${r.warnings}');
        }
      });
    }

    test('answers in twenty to thirty words, as the AI is asked to', () {
      for (final s in sampleSets) {
        expect(wordCount(s.response), inInclusiveRange(20, 30), reason: s.id);
      }
    });

    test('keeps each reason with its option when the options are moved', () {
      for (final sc in builtinScenes('ja')) {
        final set = sc.set!;
        final source = sampleSets.firstWhere((s) => s.id == sc.id);
        expect(set.reply.options[set.reply.answer], source.replies.first, reason: sc.id);
        expect(set.reply.why[set.reply.answer], isEmpty, reason: sc.id);
        expect(set.predict.options[set.predict.answer], source.text['ja']!.predict.first,
            reason: sc.id);
        expect(set.predict.why[set.predict.answer], isEmpty, reason: sc.id);
        for (var i = 0; i < 3; i++) {
          if (i != set.reply.answer) expect(set.reply.why[i], isNotEmpty, reason: sc.id);
          if (i != set.predict.answer) expect(set.predict.why[i], isNotEmpty, reason: sc.id);
        }
      }
    });

    test('is translated where there is a language to translate into', () {
      for (final sc in builtinScenes('ja')) {
        expect(sc.set!.partner.native, isNotEmpty, reason: sc.id);
        expect(sc.set!.response.native, isNotEmpty, reason: sc.id);
      }
      for (final sc in builtinScenes('en')) {
        expect(sc.set!.partner.native, isEmpty, reason: 'nothing to translate into');
      }
    });

    test('reads the English where a language has none of its own', () {
      final es = builtinScenes('es');
      final en = builtinScenes('en');
      expect(es.map((s) => s.label), en.map((s) => s.label));
      expect(es.first.set!.partner.native, isEmpty);
    });
  });
}
