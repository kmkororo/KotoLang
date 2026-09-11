/// The importer: what arrives is checked turn by turn before it is kept.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotolang/domain/scene.dart';
import 'package:kotolang/domain/scene_import.dart';

Map<String, dynamic> turn({
  String type = 'keyword',
  String line = 'I will send it on Thursday.',
  List<Map<String, dynamic>>? replies,
  List<Map<String, dynamic>>? facts,
  Map<String, dynamic>? translations,
}) =>
    {
      'type': type,
      'line': line,
      'keyWord': 'Thursday',
      'confusable': 'Tuesday',
      'facts': ?facts,
      'replies': replies ??
          [
            {'text': 'Thursday it is.', 'correct': true},
            {'text': 'Tuesday, got it.', 'correct': false},
            {'text': 'Could it be sooner?', 'correct': false},
          ],
      'restate': 'It should reach you Thursday.',
      'translations': ?translations,
    };

Map<String, dynamic> pack(List<Map<String, dynamic>> scenes) => {
      'schema_version': '4.0',
      'type': 'scenes',
      'scenes': scenes,
    };

Map<String, dynamic> scene({
  String title = 'Moving a deadline',
  List<Map<String, dynamic>>? turns,
  int? windowMs,
}) =>
    {
      'title': title,
      'title_native': '締め切りをずらす',
      'situation': 'meetings',
      'setting_native': '午後のオフィスで。',
      'window_ms': ?windowMs,
      'turns': turns ?? [turn()],
    };

void main() {
  test('a conversation runs from one turn to five', () {
    for (final n in [1, 3, 5]) {
      final out = normaliseScenes(pack([
        scene(title: 'Talk $n', turns: [for (var i = 0; i < n; i++) turn()])
      ]));
      expect(out.rejected, isEmpty, reason: '$n turns');
      expect(out.scenes.single.turns, hasLength(n));
    }
    final tooMany = normaliseScenes(pack([
      scene(turns: [for (var i = 0; i < 6; i++) turn()])
    ]));
    expect(tooMany.scenes, isEmpty);
    expect(tooMany.rejected.single.reason, contains('at most'));
  });

  test('exactly one reply is right, or the turn is not a question', () {
    final none = normaliseScenes(pack([
      scene(turns: [
        turn(replies: [
          {'text': 'a', 'correct': false},
          {'text': 'b', 'correct': false},
          {'text': 'c', 'correct': false},
        ])
      ])
    ]));
    expect(none.rejected.single.reason, contains('no right reply'));

    final two = normaliseScenes(pack([
      scene(turns: [
        turn(replies: [
          {'text': 'a', 'correct': true},
          {'text': 'b', 'correct': true},
          {'text': 'c', 'correct': false},
        ])
      ])
    ]));
    expect(two.rejected.single.reason, contains('2 right replies'));
  });

  test('three replies, never two and never four', () {
    final short = normaliseScenes(pack([
      scene(turns: [
        turn(replies: [
          {'text': 'a', 'correct': true},
          {'text': 'b', 'correct': false},
        ])
      ])
    ]));
    expect(short.rejected.single.reason, contains('needs 3'));
  });

  test('the right reply does not stay first', () {
    // The AI writes it first every time; the order comes from the id, so it
    // lands somewhere else without being random.
    final moved = <int>{};
    for (final t in ['One', 'Two', 'Three', 'Four', 'Five', 'Six']) {
      final out = normaliseScenes(pack([scene(title: t)]));
      moved.add(out.scenes.single.turns.first.answer);
    }
    expect(moved.length, greaterThan(1), reason: 'the answer moves around');
  });

  test('the shuffle is the same every time', () {
    final a = normaliseScenes(pack([scene()])).scenes.single;
    final b = normaliseScenes(pack([scene()])).scenes.single;
    expect(a.turns.first.replies.map((r) => r.text),
        b.turns.first.replies.map((r) => r.text));
  });

  test('translations follow their own reply through the shuffle', () {
    final out = normaliseScenes(pack([
      scene(turns: [
        turn(translations: {
          'line': '木曜に送ります。',
          'replies': ['木曜ですね。', '火曜ですね。', 'もっと早くできますか？'],
        })
      ])
    ]));
    final t = out.scenes.single.turns.first;
    expect(t.lineNative, '木曜に送ります。');
    final right = t.replies[t.answer];
    expect(right.text, 'Thursday it is.');
    expect(right.native, '木曜ですね。');
  });

  test('a multiFact turn names two facts and points every miss at one', () {
    final good = normaliseScenes(pack([
      scene(turns: [
        turn(
          type: 'multiFact',
          facts: [
            {'slot': 'place', 'value': 'west exit', 'confusable': 'ticket gate'},
            {'slot': 'time', 'value': 'six', 'confusable': 'seven'},
          ],
          replies: [
            {'text': 'West exit at six.', 'correct': true},
            {'text': 'Ticket gate at six.', 'correct': false, 'missedSlot': 'place'},
            {'text': 'West exit at seven.', 'correct': false, 'missedSlot': 'time'},
          ],
        )
      ])
    ]));
    expect(good.rejected, isEmpty);
    expect(good.scenes.single.turns.first.facts, hasLength(2));

    final unnamed = normaliseScenes(pack([
      scene(turns: [
        turn(
          type: 'multiFact',
          facts: [
            {'slot': 'place', 'value': 'west exit'},
            {'slot': 'time', 'value': 'six'},
          ],
          replies: [
            {'text': 'West exit at six.', 'correct': true},
            {'text': 'Ticket gate at six.', 'correct': false},
            {'text': 'West exit at seven.', 'correct': false, 'missedSlot': 'time'},
          ],
        )
      ])
    ]));
    expect(unnamed.rejected.single.reason, contains('names no fact'));
  });

  test('the window is taken from the conversation, within reason', () {
    expect(normaliseScenes(pack([scene(windowMs: 2000)])).scenes.single.windowMs, 2000);
    expect(normaliseScenes(pack([scene()])).scenes.single.windowMs, defaultWindowMs);
    expect(normaliseScenes(pack([scene(windowMs: 99)])).scenes.single.windowMs, minWindowMs);
    expect(normaliseScenes(pack([scene(windowMs: 99999)])).scenes.single.windowMs, maxWindowMs);
  });

  test('two conversations with the same title still land apart', () {
    final out = normaliseScenes(pack([
      scene(turns: [turn(line: 'First one.')]),
      scene(turns: [turn(line: 'A different one.')]),
    ]));
    expect(out.scenes, hasLength(2));
    expect(out.scenes.first.id, isNot(out.scenes.last.id));
  });

  test('the same conversation twice is kept once', () {
    final out = normaliseScenes(pack([scene(), scene()]));
    expect(out.scenes, hasLength(1));
  });

  test('a conversation survives being written down and read back', () {
    final s = normaliseScenes(pack([
      scene(turns: [
        turn(type: 'polarity', translations: {
          'line': '早く終わらない限り行けません。',
          'replies': ['では早く終わったときだけですね。', '了解、会場で。', '午後にしますか？'],
        })
      ])
    ])).scenes.single;
    final back =
        Scene.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(back.id, s.id);
    expect(back.windowMs, s.windowMs);
    expect(back.turns.first.type, TurnType.polarity);
    expect(back.turns.first.restate, s.turns.first.restate);
    expect(back.turns.first.replies[back.turns.first.answer].text,
        s.turns.first.replies[s.turns.first.answer].text);
  });
}
