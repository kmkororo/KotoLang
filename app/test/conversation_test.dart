/// The formats added to make the app useful for actually talking to someone.
///
/// The existing four all play the English first and ask the learner to
/// recognise or rebuild it. These three run the other way — say it from the
/// meaning, choose what to say back, choose how to say it — and the things
/// most likely to go wrong are the seams: material imported before these
/// fields existed must keep working, and a half-written block from an AI must
/// be refused rather than turned into an unanswerable question.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotolang/core/util.dart';
import 'package:kotolang/domain/importer.dart';
import 'package:kotolang/domain/models.dart';
import 'package:kotolang/domain/prompts.dart';
import 'package:kotolang/domain/question_generator.dart';
import 'package:kotolang/domain/srs.dart';

Sentence _sentence({
  String id = 's1',
  String text = 'Could we go over the repair policy before we sign?',
  String ja = 'サインの前に修理の方針を確認できますか。',
  String cue = '',
  String cueJa = '',
  List<String> replyDistractors = const [],
  String registerSituation = '',
  List<String> registerOptions = const [],
  List<String> registerWhy = const [],
  int registerCorrect = -1,
  String speechAct = 'request',
}) =>
    Sentence(
      id: id,
      text: text,
      normKeyValue: normKey(text),
      translationNative: ja,
      realmId: 'r1',
      context: 'review',
      speechAct: speechAct,
      cueEn: cue,
      cueTranslationNative: cueJa,
      replyDistractorsEn: replyDistractors,
      registerSituationNative: registerSituation,
      registerOptionsEn: registerOptions,
      registerWhyNative: registerWhy,
      registerCorrect: registerCorrect,
    );

const _cue = 'Everything looks fine — shall we sign it off?';
const _distractors = [
  'Yes, send it to the supplier tonight.',
  'I have not seen any of the drawings yet.',
  'The repair policy was withdrawn earlier this year.',
];
const _registerOptions = [
  'Could we go over the repair policy first?',
  'Go over the repair policy first.',
  'You need to go over the repair policy first.',
];
const _registerWhy = ['依頼の形', '命令形', '義務の押しつけ'];

void main() {
  group('say it from the meaning', () {
    test('builds from nothing but a sentence and its reading', () {
      final q = buildProduce(_sentence(), const []);
      expect(q, isNotNull);
      expect(q!.type, QuestionType.produce);
      expect('${q.tokens.join(' ')}${q.finalPunct}', q.text);
      expect(q.translationNative, isNotEmpty);
      expect(validateQuestion(q, {'s1': _sentence()}), isEmpty);
    });

    test('is refused when there is no reading to prompt with', () {
      // The meaning is the entire question. Without it the card would be blank
      // and the learner would have nothing to work from.
      expect(buildProduce(_sentence(ja: ''), const []), isNull);
    });

    test('counts as production, so it can release the mastery gate', () {
      expect(productionTypes, contains(QuestionType.produce));

      var s = SrsState.blank('i');
      for (var i = 0; i < 8; i++) {
        s = applyAnswer(s, QuestionType.gist, true);
      }
      expect(s.box, recognitionCap, reason: 'recognition alone should cap');

      s = applyAnswer(s, QuestionType.produce, true);
      expect(hasProductionEvidence(s), isTrue);
      s = applyAnswer(s, QuestionType.gist, true);
      expect(s.box, greaterThan(recognitionCap));
    });

    test('its audio is withheld until the answer is in', () {
      // The whole difference from reorder. Playing the sentence first would
      // hand over the thing being asked for.
      expect(silentUntilAnswered, contains(QuestionType.produce));
      expect(silentUntilAnswered, isNot(contains(QuestionType.reorder)));
      expect(silentUntilAnswered, isNot(contains(QuestionType.dictation)));
    });
  });

  group('choosing what to say back', () {
    test('speaks the cue, not the answer', () {
      final q = buildReply(
        _sentence(cue: _cue, cueJa: 'これで承認しますか。', replyDistractors: _distractors),
        const [],
        Random(1),
      );
      expect(q, isNotNull);
      // Reading the reply aloud would give the question away entirely.
      expect(q!.spokenText, _cue);
      expect(q.spokenText, isNot(q.text));
      expect(q.cueTranslationNative, isNotEmpty);
    });

    test('offers four distinct replies, exactly one right', () {
      final q = buildReply(
        _sentence(cue: _cue, replyDistractors: _distractors),
        const [],
        Random(2),
      )!;
      expect(q.options.length, 4);
      expect(q.options[q.correct], q.answerText);
      expect(uniqueBy(q.options, normKey).length, 4);
      expect(validateQuestion(q, {'s1': _sentence(cue: _cue)}), isEmpty);
    });

    test('material with no cue simply yields no reply question', () {
      // The backward-compatibility guarantee: a library imported before these
      // fields existed keeps working, it just produces fewer formats.
      expect(buildReply(_sentence(), const [], Random(3)), isNull);
    });

    test('falls back to the area when the AI supplied no wrong replies', () {
      final pool = [
        _sentence(id: 'a', text: 'The analysis is still running on the cluster.'),
        _sentence(id: 'b', text: 'I will send the drawings over this afternoon.'),
        _sentence(id: 'c', text: 'We agreed to postpone that until next week.'),
      ];
      final q = buildReply(_sentence(cue: _cue), pool, Random(4));
      expect(q, isNotNull);
      expect(q!.options.length, 4);
      expect(q.options[q.correct], q.answerText);
    });

    test('gives up rather than build a question with too few options', () {
      expect(buildReply(_sentence(cue: _cue), const [], Random(5)), isNull);
    });

    test('is recognition, so it cannot release the mastery gate', () {
      // It is four options. Picking the right one is not evidence it could
      // have been produced.
      expect(productionTypes, isNot(contains(QuestionType.reply)));
      var s = SrsState.blank('i');
      for (var i = 0; i < 8; i++) {
        s = applyAnswer(s, QuestionType.reply, true);
      }
      expect(s.box, recognitionCap);
      expect(isMastered(s), isFalse);
    });
  });

  group('choosing how to say it', () {
    Sentence full() => _sentence(
          registerSituation: '初対面の取引先に頼むとき',
          registerOptions: _registerOptions,
          registerWhy: _registerWhy,
          registerCorrect: 0,
        );

    test('asks about the situation and carries the reason', () {
      final q = buildRegister(full(), Random(1));
      expect(q, isNotNull);
      expect(q!.translationNative, '初対面の取引先に頼むとき');
      expect(q.options.length, 3);
      expect(q.options[q.correct], _registerOptions[0]);
      // Without the reason the question is a coin toss nobody learns from.
      expect(q.note, '依頼の形');
      expect(validateQuestion(q, {'s1': full()}), isEmpty);
    });

    test('a block with no situation, too few variants or no answer is refused',
        () {
      expect(buildRegister(_sentence()), isNull);
      expect(
        buildRegister(_sentence(
            registerOptions: _registerOptions, registerCorrect: 0)),
        isNull,
        reason: 'no situation',
      );
      expect(
        buildRegister(_sentence(
            registerSituation: 'x',
            registerOptions: _registerOptions.take(2).toList(),
            registerCorrect: 0)),
        isNull,
        reason: 'too few variants',
      );
      expect(
        buildRegister(_sentence(
            registerSituation: 'x',
            registerOptions: _registerOptions,
            registerCorrect: 9)),
        isNull,
        reason: 'answer points past the end',
      );
      expect(
        buildRegister(_sentence(
            registerSituation: 'x',
            registerOptions: const ['same', 'same', 'other'],
            registerCorrect: 0)),
        isNull,
        reason: 'two identical variants',
      );
    });
  });

  group('reading the new fields out of an AI reply', () {
    Map<String, dynamic> reply({Object? register, String cue = _cue}) => {
          'schema_version': '1.0',
          'type': 'material',
          'native_language': 'Japanese',
          'domain': {'name': 'Work', 'importance': 5},
          'learning_items': const [
            {'text': 'repair policy', 'meaning_native': '修理の方針'}
          ],
          'sentences': [
            {
              'text': 'Could we go over the repair policy before we sign?',
              'translation_native': 'サインの前に確認できますか。',
              'targets': const ['repair policy'],
              'cue_en': cue,
              'cue_translation_native': 'これで承認しますか。',
              'reply_distractors_en': _distractors,
              'register': ?register,
            }
          ],
        };

    test('cue, distractors and register survive the parse', () {
      final m = normaliseMaterial(jsonDecode(jsonEncode(reply(register: {
        'situation_native': '初対面の取引先に頼むとき',
        'variants': [
          {'text': _registerOptions[0], 'fits': true, 'why_native': '依頼の形'},
          {'text': _registerOptions[1], 'fits': false, 'why_native': '命令形'},
          {'text': _registerOptions[2], 'fits': false, 'why_native': '押しつけ'},
        ],
      }))) as Map<String, dynamic>);

      final s = m.sentences.single;
      expect(s.cueEn, _cue);
      expect(s.cueTranslationNative, isNotEmpty);
      expect(s.replyDistractorsEn.length, 3);
      expect(s.registerSituationNative, '初対面の取引先に頼むとき');
      expect(s.registerCorrect, 0);
      expect(s.registerWhyNative.length, 3);
    });

    test('a cue that just repeats the sentence is dropped', () {
      final m = normaliseMaterial(jsonDecode(jsonEncode(reply(
        cue: 'Could we go over the repair policy before we sign?',
      ))) as Map<String, dynamic>);
      expect(m.sentences.single.cueEn, isEmpty,
          reason: 'it would read the answer aloud before asking for it');
    });

    test('a register block with no variant marked as fitting is dropped whole',
        () {
      final m = normaliseMaterial(jsonDecode(jsonEncode(reply(register: {
        'situation_native': 'x',
        'variants': [
          for (final t in _registerOptions) {'text': t, 'fits': false},
        ],
      }))) as Map<String, dynamic>);
      final s = m.sentences.single;
      expect(s.registerCorrect, -1);
      expect(s.registerOptionsEn, isEmpty);
      expect(s.registerSituationNative, isEmpty);
    });

    test('material that predates these fields parses to empty, not to junk',
        () {
      final bare = {
        'schema_version': '1.0',
        'type': 'material',
        'domain': {'name': 'Work'},
        'learning_items': const [],
        'sentences': const [
          {
            'text': 'Please confirm the repair policy before the review.',
            'translation_native': 'レビューの前に確認してください。',
          }
        ],
      };
      final s = normaliseMaterial(bare).sentences.single;
      expect(s.cueEn, isEmpty);
      expect(s.replyDistractorsEn, isEmpty);
      expect(s.registerCorrect, -1);

      // And the generator quietly builds only what it can.
      final qs = generateForSentences([s], const {}, [s], Random(1));
      final types = qs.map((q) => q.type).toSet();
      expect(types, isNot(contains(QuestionType.reply)));
      expect(types, isNot(contains(QuestionType.register)));
      expect(types, contains(QuestionType.produce));
    });
  });

  group('the prompt asks for what the formats need', () {
    test('it demands spoken turns and the conversation fields', () {
      final p = materialPrompt(uiLanguage: 'ja', realmName: 'Work');
      expect(p, contains('SPOKEN TURNS'));
      expect(p, contains('cue_en'));
      expect(p, contains('reply_distractors_en'));
      expect(p, contains('register'));
      expect(p, contains('why_native'));
    });

    test('batches shrank so the richer replies still fit in one copy', () {
      // Each sentence now carries roughly twice the JSON. Asking for the old
      // counts would put the answer back past what a phone can copy.
      for (final b in BatchSize.values) {
        expect(b.sentences, lessThanOrEqualTo(14));
        expect(b.items, lessThan(b.sentences));
      }
    });
  });
}
