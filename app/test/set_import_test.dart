/// The importer's checks on a set: the rules that keep exactly one option
/// right, and a reason on every one that is not.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kotolang/domain/scene.dart';
import 'package:kotolang/domain/set_import.dart';

import 'fixtures.dart' show scene;

List<String> reasonsOf(Map<String, dynamic> j, {String lang = 'ja'}) =>
    checkSet(j, uiLanguage: lang).reasons;

Map<String, dynamic> edit(Map<String, dynamic> j, String part, String key, Object? value) {
  final out = Map<String, dynamic>.from(j);
  out[part] = {...(j[part] as Map), key: value};
  return out;
}

void main() {
  test('a sound set passes, with nothing to say', () {
    final r = checkSet(scene('Good'), uiLanguage: 'ja');
    expect(r.reasons, isEmpty);
    expect(r.warnings, isEmpty);
    expect(r.set, isNotNull);
  });

  test('three options each, and an answer that is one of them', () {
    expect(reasonsOf(edit(scene('A'), 'reply', 'options', ['x', 'y'])),
        contains(startsWith('reply.options has 2')));
    expect(reasonsOf(edit(scene('A'), 'predict', 'answer', 3)),
        contains('predict.answer must be 0, 1 or 2'));
  });

  test('every wrong option carries its reason, and the right one none', () {
    expect(reasonsOf(edit(scene('A'), 'reply', 'why', ['', '', 'x'])),
        contains(startsWith('reply.why is empty for wrong option 2')));
    expect(reasonsOf(edit(scene('A'), 'predict', 'why', ['x', 'y', 'z'])),
        contains('predict.why must be empty for the right option'));
    expect(reasonsOf(edit(scene('A'), 'reply', 'why', ['', 'x'])),
        contains('reply.why has 2, needs 3'));
  });

  test('the first line is long enough to hold its facts, and not a speech', () {
    expect(reasonsOf(edit(scene('A'), 'partner', 'text', 'Too short to hold anything.')),
        contains(startsWith('partner.text has')));
    final speech = List.filled(95, 'word').join(' ');
    expect(reasonsOf(edit(scene('A'), 'partner', 'text', speech)),
        contains('partner.text has 95 words, at most $partnerMaxWords'));
  });

  test('the paraphrase is in other words', () {
    final j = scene('A');
    final same = edit(j, 'partner', 'paraphrase', (j['partner'] as Map)['text']);
    expect(reasonsOf(same), contains('partner.paraphrase is the same as partner.text'));
  });

  test('every stressed word is one that is said, however it is written', () {
    // Case, punctuation and hyphens are ignored; a word not there is not.
    final ok = edit(scene('A'), 'partner', 'stress', ['HANDOVER', 'Thursday,', 'second']);
    expect(reasonsOf(ok), isEmpty);
    final bad = edit(scene('A'), 'partner', 'stress', ['handover', 'friday']);
    expect(reasonsOf(bad), contains(contains('friday')));
    expect(isStressed({'check'}, 'double-check.'), isTrue);
    expect(isStressed({'double-check'}, 'Double-check'), isTrue);
    expect(isStressed({'check'}, 'cheque'), isFalse);
  });

  test('every fault is named at once, not one per trip', () {
    var j = edit(scene('A'), 'reply', 'why', ['', '', 'x']);
    j = edit(j, 'partner', 'stress', ['nowhere']);
    expect(reasonsOf(j), hasLength(2));
  });

  test('summaries in English for a learner reading another language are taken, and said',
      () {
    var j = edit(scene('A'), 'predict', 'options', ['Says thanks', 'Asks again', 'Says no']);
    j = edit(j, 'predict', 'why', ['', 'Already answered', 'Contradicts']);
    j = edit(j, 'reply', 'why', ['', 'Not Tuesday', 'Not tonight']);
    final r = checkSet(j, uiLanguage: 'ja');
    expect(r.reasons, isEmpty);
    expect(r.warnings, contains('english summaries'));
    expect(checkSet(j, uiLanguage: 'en').warnings, isEmpty);
  });

  test('the options are moved, and each reason goes with its own', () {
    final n = normaliseSets({
      'items': [for (var i = 0; i < 12; i++) scene('Set $i')]
    }, uiLanguage: 'ja');
    expect(n.sets, hasLength(12));
    final places = {for (final s in n.sets) s.set!.reply.answer};
    expect(places.length, greaterThan(1), reason: 'not always first');
    for (final s in n.sets) {
      final set = s.set!;
      expect(set.reply.options[set.reply.answer], startsWith('Thursday at three on'));
      expect(set.reply.why[set.reply.answer], isEmpty);
      expect(set.predict.why[set.predict.answer], isEmpty);
    }
  });

  test('a set twice in one reply is kept once', () {
    final n = normaliseSets({
      'items': [scene('Same'), scene('Same')]
    }, uiLanguage: 'ja');
    expect(n.sets, hasLength(1));
  });

  test('a set reads as one turn to everything that reads turns', () {
    final set = checkSet(scene('A'), uiLanguage: 'ja').set!;
    final t = set.asTurn;
    expect(t.line, set.partner.text);
    expect(t.replies[t.answer].text, set.reply.options[set.reply.answer]);
    expect(t.type, TurnType.keyword);
  });
}
