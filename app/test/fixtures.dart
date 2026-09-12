/// Conversations to test with, in the shape the AI is asked for.
///
/// Shared rather than repeated, because every suite that touches material
/// needs the same thing: a reply that would pass the importer, so what is
/// being tested is the app and not the fixture.
library;

import 'dart:convert';

import 'package:kotolang/data/repository.dart';
import 'package:kotolang/domain/ladder.dart';
import 'package:kotolang/domain/models.dart';
import 'package:kotolang/domain/scene.dart';

/// One turn. The right reply is written first, as the prompt asks; the
/// importer is what moves it.
Map<String, dynamic> turn({
  String type = 'keyword',
  String line = 'The handover is on Thursday, so I need the file the night before.',
  String keyWord = 'Thursday',
  String confusable = 'Tuesday',
  List<Map<String, dynamic>>? replies,
  List<Map<String, dynamic>>? facts,
  List<String>? natives,
}) =>
    {
      'type': type,
      'line': line,
      'keyWord': keyWord,
      'confusable': confusable,
      'facts': ?facts,
      'replies': replies ??
          [
            {'text': 'Thursday — ready the evening before.', 'correct': true},
            {'text': 'Got it, Tuesday. I will finish over the weekend.', 'correct': false},
            {'text': 'Any chance of another day? That week is full.', 'correct': false},
          ],
      'restate': 'It is the Thursday handover — the file has to be in the night before.',
      'translations': {
        'line': '引き継ぎは木曜なので、前の晩までにファイルが要ります。',
        'replies': natives ??
            const ['木曜ですね。前の晩までに用意します。', '火曜ですね。週末に仕上げます。', '別の日にできますか。'],
      },
    };

/// One conversation. [turns] defaults to a single keyword turn.
Map<String, dynamic> scene(
  String title, {
  List<Map<String, dynamic>>? turns,
  String situation = 'meetings',
  int? windowMs,
}) =>
    {
      'title': title,
      'title_native': '$title（日本語）',
      'situation': situation,
      'setting_native': '午後のオフィスで。',
      'window_ms': ?windowMs,
      'turns': turns ?? [turn(line: '$title — the handover is on Thursday.')],
    };

/// A whole reply, ready to paste.
String pack(List<Map<String, dynamic>> scenes) => jsonEncode({
      'schema_version': '4.0',
      'type': 'scenes',
      'native_language': 'Japanese',
      'scenes': scenes,
    });

/// One field of the learner's life, as the database holds it. Open and with
/// material by default, since that is the interesting state; the tests that
/// want a closed one say so.
Realm realm(String id, {bool unlocked = true}) => Realm(
      id: id,
      name: id,
      normKeyValue: id,
      confidence: 1,
      selected: true,
      hasMaterial: true,
      unlocked: unlocked,
    );

/// A conversation as a domain object, already past the importer. [builtin]
/// makes it one of the samples that ship with the app, which is the only
/// thing that tells the two kinds apart.
Scene builtScene(
  String title, {
  bool builtin = false,
  String? field,
  int turns = 1,
}) =>
    Scene(
      id: sceneId(title),
      title: title,
      titleNative: '$title（日本語）',
      situation: 'meetings',
      turns: [
        for (var i = 0; i < turns; i++)
          Turn(
            type: TurnType.keyword,
            line: '$title, line $i.',
            keyWord: 'Thursday',
            confusable: 'Tuesday',
            replies: const [
              Reply(text: 'Thursday it is.', correct: true),
              Reply(text: 'Tuesday, got it.'),
              Reply(text: 'Could it be sooner?'),
            ],
            restate: 'It reaches you Thursday.',
          ),
      ],
      source: builtin ? SceneSource.builtin : SceneSource.ai,
      realmId: field,
      createdAt: 0,
    );

/// Moves the ladder up by [steps], the way a learner would: by answering.
///
/// Every axis is at its own frontier at the start, so a clean run of
/// [ladderWindow] right answers lifts all five at once — which is exactly
/// what makes the total move in fives. Tests that only care that the ladder
/// reached far enough use this and say the number they need.
Future<void> climb(Repository repo, int steps) async {
  await repo.importScenes(pack([scene('Climbing')]), uiLanguage: 'en', field: 'work');
  final id = (await repo.scenes()).last.id;
  while ((await repo.loadLadder()).reached < steps) {
    final before = (await repo.loadLadder()).reached;
    for (var i = 0; i < ladderWindow; i++) {
      await repo.recordTurn(sceneId: id, turn: 0, correct: true);
    }
    if ((await repo.loadLadder()).reached == before) {
      throw StateError('the ladder stopped moving at $before');
    }
  }
}
