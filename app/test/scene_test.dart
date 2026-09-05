/// Scenes: the pasted reply is made sound, stored once, answered, reviewed
/// when missed, paid for when finished, and read back as the two skills.
library;

import 'dart:convert';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kotolang/core/util.dart';
import 'package:kotolang/data/database.dart';
import 'package:kotolang/data/repository.dart';
import 'package:kotolang/domain/importer.dart' as imp;
import 'package:kotolang/domain/progress_service.dart';
import 'package:kotolang/domain/prompts.dart' as pr;
import 'package:kotolang/domain/scene.dart';
import 'package:kotolang/domain/scene_import.dart';
import 'package:kotolang/domain/skills.dart';

import 'repository_test.dart' show profileJson;

// ------------------------------------------------------------------ fixtures

Map<String, dynamic> exchange(String stem, {Object gistAnswer = 1, Object replyAnswer = 0}) => {
      'line': 'Line $stem: could you stay an extra hour tonight?',
      'line_native': '$stem の台詞',
      'gist': {
        'options': ['$stem 明日早く来てほしい', '$stem 今夜1時間残ってほしい', '$stem 今夜は帰っていい'],
        'answer': gistAnswer,
      },
      'reply': {
        'options': [
          {'text': 'One hour is fine, $stem.', 'native': '1時間なら大丈夫', 'why': '正しく受けている'},
          {'text': 'Early tomorrow, right, $stem?', 'native': '明日早く？', 'why': '聞き違い'},
          {'text': 'See you tomorrow, $stem.', 'native': 'じゃあ明日', 'why': '聞き違い'},
        ],
        'answer': replyAnswer,
      },
    };

Map<String, dynamic> scene(String topic, {List<Map<String, dynamic>>? exchanges}) => {
      'topic': topic,
      'topic_native': '$topic（日本語）',
      'setting_native': '定時の少し前',
      'exchanges': exchanges ?? [exchange('$topic-1'), exchange('$topic-2')],
    };

String pack(List<Map<String, dynamic>> scenes) => jsonEncode({
      'schema_version': '3.0',
      'type': 'scenes',
      'native_language': 'Japanese',
      'scenes': scenes,
    });

void main() {
  group('importer: scenes', () {
    test('a sound reply is recognised and counted', () {
      final p = imp.previewImport(pack([scene('Stay late'), scene('Move a meeting')]));
      expect(p.ok, isTrue);
      expect(p.type, 'scenes');
      expect(p.scenes, 2);
    });

    test('the type is inferred from the shape when the AI left it out', () {
      final raw = jsonEncode({'schema_version': '3.0', 'scenes': [scene('Stay late')]});
      expect(imp.validate(jsonDecode(raw)).type, 'scenes');
    });

    test('a scene needs exactly two exchanges', () {
      final n = normaliseScenes(jsonDecode(pack([
        scene('Short', exchanges: [exchange('a')]),
        scene('Fine'),
      ])));
      expect(n.scenes.map((s) => s.topic), ['Fine']);
      expect(n.rejected.single.reason, contains('needs 2'));
    });

    test('a question with an answer outside its three choices is refused', () {
      final n = normaliseScenes(jsonDecode(pack([
        scene('Bad', exchanges: [exchange('a', gistAnswer: 3), exchange('b')]),
      ])));
      expect(n.scenes, isEmpty);
      expect(n.rejected.single.reason, contains('gist'));
    });

    test('two identical choices are not three choices', () {
      final e = exchange('a');
      (e['gist'] as Map)['options'] = ['同じ', '同じ', '違う'];
      final n = normaliseScenes(jsonDecode(pack([scene('Dup', exchanges: [e, exchange('b')])])));
      expect(n.scenes, isEmpty);
    });

    test('a lettered answer is read as its index', () {
      final n = normaliseScenes(jsonDecode(pack([
        scene('Letters', exchanges: [exchange('a', gistAnswer: 'B', replyAnswer: 'A'), exchange('b')]),
      ])));
      // The positions are the app's to decide; the right text is what holds.
      expect(n.scenes.single.exchanges.first.gist.correct, 'a 今夜1時間残ってほしい');
      expect(n.scenes.single.exchanges.first.reply.correct.text, exchange('a')['reply']['options'][0]['text']);
    });

    test('ids come from the topic and first line: the same scene pasted twice is one', () {
      final n = normaliseScenes(jsonDecode(pack([scene('Stay late'), scene('Stay late')])));
      expect(n.scenes, hasLength(1));
      expect(n.scenes.single.id, sceneId('Stay late', n.scenes.single.exchanges.first.line));
      // Same topic name, different words: two scenes, not one overwriting the other.
      final twin = scene('Stay late', exchanges: [exchange('other'), exchange('more')]);
      final two = normaliseScenes(jsonDecode(pack([scene('Stay late'), twin])));
      expect(two.scenes, hasLength(2));
    });

    test('translated gists are kept beside the English, in the same order', () {
      final e = exchange('g');
      (e['gist'] as Map)['options'] = [
        {'text': 'Come early tomorrow', 'native': '明日早く'},
        {'text': 'Stay an hour tonight', 'native': '今夜1時間'},
        {'text': 'Go home now', 'native': '今帰る'},
      ];
      final n = normaliseScenes(jsonDecode(pack([scene('G', exchanges: [e, exchange('h')])])));
      final g = n.scenes.single.exchanges.first.gist;
      expect(g.correct, 'Stay an hour tonight');
      expect(g.nativeOf(g.answer), '今夜1時間');
      expect(g.natives, hasLength(3));
    });
  });

  group('prompt: scenes', () {
    test('carries the learner, the rules and the shape', () {
      final t = pr.scenesPrompt(
        uiLanguage: 'ja',
        level: 'A2',
        ageBand: 'in their twenties (student or early career)',
        roles: ['project manager'],
        existingTopics: ['Stay late'],
        recent: (gistPct: 82, replyPct: 61, exchanges: 14),
        tendencies: ['misheard: "could you stay an extra hour tonight?"'],
      );
      expect(t, contains('Native language: Japanese'));
      expect(t, contains('in their twenties'));
      expect(t, contains('- Stay late'));
      expect(t, contains('82% right'));
      expect(t, contains('misheard: "could you stay'));
      expect(t, contains('"schema_version": "3.1"'));
      expect(t, contains('exactly one right answer'));
      expect(t, contains('never a bare negation'));
      expect(t, contains('EASY.'));
    });

    test('the difficulty steps with the results', () {
      expect(pr.scenesPrompt(uiLanguage: 'en', difficulty: pr.SceneDifficulty.harder),
          contains('A STEP HARDER'));
      expect(pr.scenesPrompt(uiLanguage: 'en', difficulty: pr.SceneDifficulty.easier),
          contains('VERY EASY'));
    });
  });

  group('skills', () {
    SceneResult r(String day, {bool gist = true, bool reply = true, bool peeked = false}) =>
        SceneResult(
            sceneId: 's', exchange: 0, gistOk: gist, replyOk: reply, peeked: peeked, day: day, at: 0);

    test('rates over everything and over the week, by ear separately', () {
      final t = today();
      final s = skillStats([
        r(addDays(t, -10)),
        r(addDays(t, -10), gist: false),
        r(t, peeked: true),
        r(t, reply: false),
      ], today: t);
      expect(s.exchanges, 4);
      expect(s.all.gist.pct, 75);
      expect(s.all.reply.pct, 75);
      expect(s.all.byEar.pct, 50);
      expect(s.week.gist.pct, 100);
      expect(s.week.reply.pct, 50);
      expect(s.today, 2);
      expect(s.scenes, 2);
    });

    test('difficulty stays easy until there is enough to go on, then follows the week', () {
      final t = today();
      expect(difficultyFor(skillStats([r(t)], today: t)), 'easy');
      final high = skillStats([for (var i = 0; i < 10; i++) r(t)], today: t);
      expect(difficultyFor(high), 'harder');
      final low = skillStats([for (var i = 0; i < 10; i++) r(t, gist: false, reply: false)], today: t);
      expect(difficultyFor(low), 'easier');
    });
  });

  group('repository: scenes', () {
    late AppDatabase db;
    late Repository repo;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repo = Repository(db, rng: Random(1));
      await repo.saveUiLanguage('ja');
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'ja');
    });
    tearDown(() => db.close());

    test('a pasted reply is stored once, and the skipped ones are named', () async {
      final out = await repo.importScenes(
          pack([scene('Stay late'), scene('Broken', exchanges: [exchange('x')])]),
          uiLanguage: 'ja');
      expect(out.ok, isTrue);
      expect(out.scenes, 1);
      expect(out.rejected.single.topic, 'Broken');
      await repo.importScenes(pack([scene('Stay late')]), uiLanguage: 'ja');
      expect(await repo.scenes(), hasLength(1));
      expect((await repo.scenes()).single.source, SceneSource.ai);
    });

    test('a miss books a review for tomorrow; two right reviews clear it', () async {
      await repo.importScenes(pack([scene('Stay late')]), uiLanguage: 'ja');
      final id = (await repo.scenes()).single.id;
      final t = today();

      await repo.recordSceneExchange(sceneId: id, exchange: 0, gistOk: true, replyOk: false);
      var due = await repo.reviews();
      expect(due.single.dueDay, addDays(t, 1));
      expect(due.single.stage, 0);
      expect(await repo.reviewsDue(day: t), isEmpty);
      expect(await repo.reviewsDue(day: addDays(t, 1)), hasLength(1));

      // Right at the first look: on to the second gap.
      await repo.recordSceneExchange(
          sceneId: id, exchange: 0, gistOk: true, replyOk: true, review: true);
      due = await repo.reviews();
      expect(due.single.stage, 1);
      expect(due.single.dueDay, addDays(t, 3));

      // Wrong at the second look: back to tomorrow.
      await repo.recordSceneExchange(
          sceneId: id, exchange: 0, gistOk: false, replyOk: true, review: true);
      expect((await repo.reviews()).single.stage, 0);

      await repo.recordSceneExchange(sceneId: id, exchange: 0, gistOk: true, replyOk: true, review: true);
      await repo.recordSceneExchange(sceneId: id, exchange: 0, gistOk: true, replyOk: true, review: true);
      expect(await repo.reviews(), isEmpty);
      expect(await repo.sceneResults(), hasLength(5));
    });

    test('finishing a scene pays the Seeds and counts the day', () async {
      final before = await repo.loadProgress();
      final res = await repo.completeScene(gistRight: 2, replyRight: 1);
      expect(res.seeds, 2 * gistSeeds + replySeeds + sceneCompleteSeeds);
      expect(res.progress.seeds, before.seeds + res.seeds);
      expect(res.progress.streak, 1);
      expect(res.progress.lastStudyDay, today());
    });

    test('the prompt carries the topics already here and the recent misses', () async {
      await repo.importScenes(pack([scene('Stay late')]), uiLanguage: 'ja');
      final id = (await repo.scenes()).single.id;
      await repo.recordSceneExchange(sceneId: id, exchange: 1, gistOk: false, replyOk: true);
      final text = await repo.scenesPromptText(uiLanguage: 'ja', extraTopics: ['Tipping']);
      expect(text, contains('- Stay late'));
      expect(text, contains('- Tipping'));
      expect(text, contains('misheard: "Line Stay late-2'));
      expect(text, contains('Native language: Japanese'));
    });
  });
}
