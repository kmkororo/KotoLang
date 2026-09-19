/// Sets to test with, in the shape the AI is asked for.
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

/// What the other person says, long enough to pass and carrying its facts.
String partnerLine(String title) =>
    '$title. The handover has moved to Thursday at three, and it will be in the '
    'small room on the second floor instead of the usual one. Please bring the '
    'printed report, not the draft from last week, and send the slides to the '
    'whole team by noon so everyone has time to read them first.';

/// One set. The right option is written first, as the prompt asks; the
/// importer is what moves it.
Map<String, dynamic> scene(
  String title, {
  String? text,
  List<String>? replies,
  List<String>? replyWhy,
  int replyAnswer = 0,
  List<String>? predictWhy,
  List<String>? stress,
}) =>
    {
      'type': 'replyPredict',
      'scene': title,
      'partnerName': '同僚',
      'partner': {
        'text': text ?? partnerLine(title),
        'paraphrase': 'In other words, $title: Thursday at three, the small room on '
            'floor two, the printed report, and the slides to everyone before twelve.',
        'native': '$title。引き継ぎは木曜3時、2階の小部屋に変わりました。',
        'stress': stress ?? const ['handover', 'thursday', 'three', 'small', 'second', 'printed', 'noon'],
      },
      'reply': {
        'options': replies ??
            const [
              'Thursday at three on the second floor, with the printed report.',
              "Tuesday at three in the usual room, with last week's draft.",
              'Thursday at three, and I will send the slides tonight.',
            ],
        'answer': replyAnswer,
        'why': replyWhy ?? const ['', '火曜ではなく木曜。場所は2階の小部屋', 'スライドは今夜ではなく正午まで'],
        'trap': 'keyword',
      },
      'predict': {
        'options': const ['お礼を言って、2階で会おうと言う', 'いつなのかをもう一度聞く', '場所はいつもの部屋だと言い直す'],
        'answer': 0,
        'why': predictWhy ?? const ['', '木曜3時と、こちらがもう答えている', '2階の小部屋に変わったと言っている'],
      },
      'response': {
        'text': 'Thanks. See you on the second floor at three, and bring a pen as well.',
        'native': 'ありがとう。3時に2階で。ペンも持ってきてね。',
        'stress': const ['thanks', 'second', 'three'],
      },
    };

/// A whole reply, ready to paste.
String pack(List<Map<String, dynamic>> scenes, {String batch = ''}) => jsonEncode({
      'schema_version': '5.0',
      'type': 'replyPredict',
      if (batch.isNotEmpty) 'batch': batch,
      'native_language': 'Japanese',
      'items': scenes,
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

/// A set as a domain object, already past the importer. [builtin] makes it
/// one of the samples that ship with the app, which is the only thing that
/// tells the two kinds apart.
Scene builtScene(
  String title, {
  bool builtin = false,
  String? field,
}) =>
    Scene.ofSet(
      id: sceneId(title),
      label: title,
      set: ReplyPredict.fromJson(scene(title)),
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
