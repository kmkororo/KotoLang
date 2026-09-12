/// What the voice is handed, which is not quite what is on the page.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kotolang/core/speech.dart';

void main() {
  group('a question is said in one breath', () {
    test('commas inside a question are taken out', () {
      // A comma is a clause break to the engine, and the rise that makes a
      // question sound like one lands on the last clause only: with the
      // comma left in, the half in front of it came out flat and the learner
      // heard a statement with nothing to answer.
      expect(SpeechService.forSpeech('Is that just today, or all week?'),
          'Is that just today or all week?');
      expect(
          SpeechService.forSpeech(
              "The review call's moved back, does that still suit you?"),
          "The review call's moved back does that still suit you?");
    });

    test('a statement keeps its commas, where the pause is worth more', () {
      expect(SpeechService.forSpeech('Right, that works for me.'),
          'Right, that works for me.');
    });

    test('a question with no comma is left alone', () {
      expect(SpeechService.forSpeech('Does that still suit you?'),
          'Does that still suit you?');
    });

    test('the spacing round a comma does not survive it', () {
      expect(SpeechService.forSpeech('Now , or later?'), 'Now or later?');
      expect(SpeechService.forSpeech('Now,or later?'), 'Now or later?');
    });
  });
}
