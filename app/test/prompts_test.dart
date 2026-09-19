/// The prompts the learner copies into their own AI.
///
/// These are the app's only contract with a machine it cannot call, test or
/// correct. Nothing here can check that an assistant obeys them — that is
/// what `docs/prompt_trial.md` is for — but it can check that the app never
/// ships a prompt with the rules missing, a language left unnamed, or a
/// number the learner did not ask for. Every one of those has happened.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kotolang/domain/prompts.dart';
import 'package:kotolang/domain/set_prompts.dart';

void main() {
  group('the sets prompt', () {
    String p0({String lang = 'ja'}) => setsPrompt(uiLanguage: lang, batch: 'b_test');

    test('carries the rule the whole exercise rests on', () {
      final p = p0();
      expect(p, contains('EXACTLY ONE OPTION FITS'));
      expect(p, contains('contradict a concrete fact'));
      expect(p, contains('If you cannot write the reason'));
      expect(p, contains('already answered'));
      // The two substitutions that stop invented colleagues and brands.
      expect(p, contains('People are roles, never names'));
      expect(p, contains('Tools are kinds, never products'));
    });

    test('asks for the shape the importer actually reads', () {
      final p = p0();
      expect(p, contains('"schema_version": "$setsSchemaVersion"'));
      expect(p, contains('"type": "replyPredict"'));
      expect(p, contains('"batch": "b_test"'));
      expect(p, contains('$setsPerReply sets'));
      expect(p, contains('50 to 60 words'));
      expect(p, contains('20 to 30 words'));
      for (final key in ['partnerName', 'paraphrase', 'stress', 'why', 'trap', 'predict',
        'response', 'keyword', 'polarity', 'multiFact']) {
        expect(p, contains(key), reason: key);
      }
      expect(p, contains('continue'), reason: 'a long reply can be split');
    });

    test('names the learner’s language, and never leaves it as a placeholder', () {
      expect(p0(), contains('Japanese'));
      expect(p0(lang: 'es'), contains('Spanish'));
      expect(p0(lang: 'es'), isNot(contains('Japanese')));
      expect(p0(lang: 'zz'), contains('English'),
          reason: 'an unknown code falls back rather than naming nothing');
    });

    test('asks for no difficulty at all', () {
      // The ladder is what makes a set hard. If the prompt also pitched the
      // sentences, two things would be moving one dial.
      final p = p0();
      for (final word in ['EASY', 'harder', 'Difficulty', 'difficulty']) {
        expect(p, isNot(contains(word)), reason: word);
      }
    });

    test('says nothing about the learner that it was not told', () {
      final bare = p0();
      expect(bare, isNot(contains('Age group')));
      expect(bare, isNot(contains('What they do')));
      expect(bare, isNot(contains('HOW THEY HAVE BEEN DOING')));
      expect(bare, isNot(contains('SITUATIONS THEY ALREADY HAVE')));
      expect(bare, isNot(contains('WHAT THEY RECENTLY MISHEARD')));

      final full = setsPrompt(
        uiLanguage: 'ja',
        batch: 'b',
        ageBand: 'in their thirties',
        roles: const ['software engineer'],
        priorities: const ['meetings'],
        field: 'English at work',
        existingTopics: const ['Moving a deadline'],
        tendencies: const ['misheard: "the handover is on Thursday"'],
        recent: (rightPct: 70, firstTimePct: 40, turns: 30),
      );
      expect(full, contains('in their thirties'));
      expect(full, contains('software engineer'));
      expect(full, contains('English at work'));
      expect(full, contains('Moving a deadline'));
      expect(full, contains('the handover is on Thursday'));
      expect(full, contains('70% right'));
      expect(full, contains('40% right on the first hearing'));
    });
  });

  group('the fix prompt', () {
    test('hands back each refused set with what is wrong, in the same batch', () {
      final p = setsFixPrompt(uiLanguage: 'ja', batch: 'b9', rejected: [
        (raw: {'scene': 'Broken one'}, reasons: ['reply.why is empty for wrong option 2']),
      ]);
      expect(p, contains('Broken one'));
      expect(p, contains('reply.why is empty for wrong option 2'));
      expect(p, contains('"batch": "b9"'));
      expect(p, contains('Japanese'));
    });
  });

  group('the feedback prompt', () {
    test('asks for prose to read, not JSON to import', () {
      final p = feedbackPrompt(
        uiLanguage: 'ja',
        field: 'English at work',
        level: 'B1',
        scenesDone: 3,
        rightPct: 60,
        firstTimePct: 25,
        misses: const [
          (topic: 'Moving a deadline', line: 'It is on Thursday.', slot: null),
          (topic: 'A visitor at three', line: 'The west exit at six.', slot: 'time'),
        ],
      );
      expect(p, contains('No JSON'));
      expect(p, contains('Japanese'), reason: 'the learner reads this, not a program');
      expect(p, contains('chose the right reply: 60%'));
      expect(p, contains('first hearing, inside the window: 25%'));
      expect(p, contains('missed: the line as a whole'));
      expect(p, contains('missed: time'));
    });

    test('a field with nothing answered says so rather than inventing a fault', () {
      final p = feedbackPrompt(
        uiLanguage: 'en',
        field: 'Travel',
        level: 'A2',
        scenesDone: 0,
        rightPct: 0,
        firstTimePct: 0,
        misses: const [],
      );
      expect(p, contains('(nothing missed)'));
      expect(p, contains('Do not invent mistakes'));
    });
  });
}
