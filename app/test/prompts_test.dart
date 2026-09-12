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

void main() {
  group('the conversations prompt', () {
    test('carries the rule the whole exercise rests on', () {
      final p = scenesPrompt(uiLanguage: 'ja');
      // A reply that gives itself away turns listening practice into reading
      // practice, and nothing in the app can tell afterwards which it was.
      expect(p, contains('only the sound of the line may'));
      expect(p, contains('Hide the line.'));
      // The three tests that two trials of the prompt had to be rewritten for.
      expect(p, contains('The pair must sound alike'));
      expect(p, contains('The line must not contain the other word'));
      expect(p, contains('Swapping them must still make sense'));
      // And the two substitutions that stop invented colleagues and brands.
      expect(p, contains('People are roles, never names'));
      expect(p, contains('Tools are kinds, never products'));
    });

    test('asks for the shape the importer actually reads', () {
      final p = scenesPrompt(uiLanguage: 'ja', scenes: 5);
      expect(p, contains('"schema_version": "4.0"'));
      expect(p, contains('5 conversations'));
      expect(p, contains('1 to 5 turns'));
      for (final key in ['keyword', 'polarity', 'multiFact', 'windowMs']) {
        expect(p, contains(key), reason: key);
      }
      expect(p, contains('missedSlot'),
          reason: 'a wrong reply has to say which fact it dropped');
      expect(p, contains('Every line is a question'));
      expect(p, isNot(contains('restate')),
          reason: 'the same line is replayed now, so there is nothing to rephrase');
    });

    test('names the learner’s language, and never leaves it as a placeholder', () {
      expect(scenesPrompt(uiLanguage: 'ja'), contains('Japanese'));
      expect(scenesPrompt(uiLanguage: 'es'), contains('Spanish'));
      expect(scenesPrompt(uiLanguage: 'es'), isNot(contains('Japanese')));
      expect(scenesPrompt(uiLanguage: 'zz'), contains('English'),
          reason: 'an unknown code falls back rather than naming nothing');
    });

    test('asks for no difficulty at all', () {
      // The ladder is what makes a turn hard. If the prompt also pitched the
      // sentences, two things would be moving one dial and the tree would
      // grow on a claim nothing measured.
      final p = scenesPrompt(uiLanguage: 'ja');
      for (final word in ['EASY', 'harder', 'Difficulty', 'difficulty']) {
        expect(p, isNot(contains(word)), reason: word);
      }
    });

    test('says nothing about the learner that it was not told', () {
      final bare = scenesPrompt(uiLanguage: 'ja');
      expect(bare, isNot(contains('Age group')));
      expect(bare, isNot(contains('What they do')));
      expect(bare, isNot(contains('HOW THEY HAVE BEEN DOING')),
          reason: 'a first set has no results to report');
      expect(bare, isNot(contains('CONVERSATIONS THEY ALREADY HAVE')));
      expect(bare, isNot(contains('WHAT THEY KEEP MISHEARING')));

      final full = scenesPrompt(
        uiLanguage: 'ja',
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
      expect(full, contains('40% caught on the first hearing'));
    });

    test('the numbers it reports are the ones the app records', () {
      // Right, and right on one hearing inside the window. Not "gist" and
      // "reply" — two measures this app stopped keeping.
      final p = scenesPrompt(
          uiLanguage: 'ja', recent: (rightPct: 55, firstTimePct: 20, turns: 44));
      expect(p, contains('last 44 turns'));
      expect(p, isNot(contains('gist')));
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
