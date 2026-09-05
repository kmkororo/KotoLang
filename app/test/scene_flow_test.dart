/// The scene screen, driven by swipes against a real in-memory database:
/// hear, swipe the gist, swipe the reply, read why, move on; a review comes
/// first; the result pays and the miss books its review.
library;

import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kotolang/app.dart';
import 'package:kotolang/core/l10n/strings.dart';
import 'package:kotolang/core/speech.dart';
import 'package:kotolang/core/util.dart';
import 'package:kotolang/data/database.dart';
import 'package:kotolang/data/repository.dart';
import 'package:kotolang/domain/progress_service.dart';
import 'package:kotolang/domain/scene.dart';
import 'package:kotolang/features/scene_screen.dart';
import 'package:kotolang/features/tree_view.dart';

import 'repository_test.dart' show profileJson;
import 'scene_test.dart' show pack, scene;

Future<(AppDatabase, Repository, Scene)> pumpScene(
  WidgetTester tester, {
  List<SceneCard> reviews = const [],
  bool tutorial = false,
  SpeechService? speech,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final repo = Repository(db, rng: Random(42));
  await repo.saveUiLanguage('en');
  await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
  await repo.importScenes(pack([scene('Stay late')]), uiLanguage: 'en');
  final sc = (await repo.scenes()).single;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        treeMotionProvider.overrideWithValue(false),
        if (speech != null) speechProvider.overrideWithValue(speech),
      ],
      child: MaterialApp(home: SceneScreen(scene: sc, reviews: reviews, tutorial: tutorial)),
    ),
  );
  await tester.pumpAndSettle();
  return (db, repo, sc);
}

/// Tap the option with this text, then Confirm: the two steps of an answer.
Future<void> choose(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, S('en').t('sceneDecide')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..physicalSize = const Size(800, 2000)
      ..devicePixelRatio = 1;
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  testWidgets('a scene: swipe the gist, swipe the reply, tap on, finish, get paid',
      (tester) async {
    final (db, repo, sc) = await pumpScene(tester);
    addTearDown(db.close);
    final s = S('en');

    // No voice under test, so the words are shown from the start.
    expect(find.text(s.t('sceneQ1')), findsOneWidget);
    expect(find.text(sc.exchanges[0].line), findsOneWidget);
    expect(find.text(s.t('sceneTapHint')), findsOneWidget);

    // The stage: them and you, with the four arrows of the scene between.
    expect(find.text(s.t('speakerOther')), findsOneWidget);
    expect(find.text(s.t('speakerYou')), findsOneWidget);

    // Confirm waits for a choice; a tap alone selects and does not answer.
    final decide = find.widgetWithText(FilledButton, s.t('sceneDecide'));
    expect(tester.widget<FilledButton>(decide).onPressed, isNull);
    await tester.tap(find.text(sc.exchanges[0].gist.correct));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(decide).onPressed, isNotNull);
    expect(find.text(s.t('sceneQ1')), findsOneWidget);
    expect(find.textContaining(s.t('sceneCorrect')), findsNothing);

    // Right gist.
    await choose(tester, sc.exchanges[0].gist.correct);
    expect(find.text('${s.t('sceneCorrect')} · +$gistSeeds'), findsOneWidget);
    // The translation waits behind a button.
    expect(find.text(sc.exchanges[0].lineNative), findsNothing);
    await tester.tap(find.byIcon(Icons.translate_outlined));
    await tester.pumpAndSettle();
    expect(find.text(sc.exchanges[0].lineNative), findsOneWidget);
    expect(find.text(s.t('sceneTapNext')), findsOneWidget);

    // Tap anywhere: on to the reply.
    await tester.tap(find.text(s.t('speakerYou')));
    await tester.pumpAndSettle();
    expect(find.text(s.t('sceneQ2')), findsOneWidget);

    // Wrong reply: red, the right one shown, every why on screen.
    final wrong = sc.exchanges[0].reply.options[(sc.exchanges[0].reply.answer + 1) % 3];
    await choose(tester, wrong.text);
    expect(find.text(s.t('sceneWrong')), findsOneWidget);
    // The panel explains the chosen reply; tapping another shows its reason.
    for (final o in sc.exchanges[0].reply.options) {
      await tester.tap(find.text(o.text));
      await tester.pumpAndSettle();
      expect(find.textContaining(o.why), findsOneWidget, reason: o.text);
    }

    // Written down at once, and the miss has booked its review.
    await tester.tap(find.text(s.t('speakerYou')));
    await tester.pumpAndSettle();
    final results = await repo.sceneResults();
    expect(results, hasLength(1));
    expect(results.single.gistOk, isTrue);
    expect(results.single.replyOk, isFalse);
    expect((await repo.reviews()).single.dueDay, addDays(today(), 1));

    // Second exchange, both right.
    expect(find.text(sc.exchanges[1].line), findsOneWidget);
    await choose(tester, sc.exchanges[1].gist.correct);
    await tester.tap(find.text(s.t('speakerYou')));
    await tester.pumpAndSettle();
    await choose(tester, sc.exchanges[1].reply.correct.text);
    await tester.tap(find.text(s.t('speakerYou')));
    await tester.pumpAndSettle();

    // The result: 3 of 4, the Seeds, the twig — and flowers, since this is
    // the learner's own scene.
    expect(find.text('3 / 4'), findsOneWidget);
    expect(find.text(s.t('sceneResultBreakdown', {'g': 2, 'r': 1, 'n': 2})), findsOneWidget);
    final seeds = 2 * gistSeeds + replySeeds + sceneCompleteSeeds;
    expect(find.text('+$seeds Seeds'), findsOneWidget);
    expect(find.textContaining(s.t('sceneFlowers', {'n': 1})), findsOneWidget);
    final progress = await repo.loadProgress();
    expect(progress.seeds, seeds);
    expect(progress.streak, 1);
  });

  testWidgets('a review owed comes first and is marked as one', (tester) async {
    late Scene owed;
    final db0 = AppDatabase(NativeDatabase.memory());
    final repo0 = Repository(db0, rng: Random(1));
    await repo0.importScenes(pack([scene('Owed')]), uiLanguage: 'en');
    owed = (await repo0.scenes()).single;
    await db0.close();

    final (db, repo, sc) =
        await pumpScene(tester, reviews: [SceneCard(owed, 1, review: true)]);
    addTearDown(db.close);
    final s = S('en');

    expect(find.text(s.t('sceneReviewTag')), findsOneWidget);
    expect(find.text(owed.exchanges[1].line), findsOneWidget);
    await choose(tester, owed.exchanges[1].gist.correct);
    await tester.tap(find.text(s.t('speakerYou')));
    await tester.pumpAndSettle();
    await choose(tester, owed.exchanges[1].reply.correct.text);
    await tester.tap(find.text(s.t('speakerYou')));
    await tester.pumpAndSettle();

    // Then today's scene, no tag.
    expect(find.text(s.t('sceneReviewTag')), findsNothing);
    expect(find.text(sc.exchanges[0].line), findsOneWidget);
    final r = (await repo.sceneResults()).single;
    expect(r.review, isTrue);
    expect(r.sceneId, owed.id);
  });

  testWidgets('the tutorial rides on each step', (tester) async {
    final (db, _, sc) = await pumpScene(tester, tutorial: true);
    addTearDown(db.close);
    final s = S('en');
    expect(find.text(s.t('tutListen')), findsOneWidget);
    await choose(tester, sc.exchanges[0].gist.correct);
    expect(find.text(s.t('tutNext')), findsOneWidget);
    await tester.tap(find.text(s.t('speakerYou')));
    await tester.pumpAndSettle();
    expect(find.text(s.t('tutReply')), findsOneWidget);
  });

  testWidgets('with a voice the words start hidden, and looking is a peek', (tester) async {
    final speech = _VoicedSpeech();
    final (db, repo, sc) = await pumpScene(tester, speech: speech);
    addTearDown(db.close);
    final s = S('en');

    // The line was spoken, not shown; the replay button sits in its row.
    expect(speech.spoken, [sc.exchanges[0].line]);
    expect(find.text(sc.exchanges[0].line), findsNothing);
    expect(find.text(s.t('debateReplay')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pumpAndSettle();
    expect(find.text(sc.exchanges[0].line), findsOneWidget);

    await choose(tester, sc.exchanges[0].gist.correct);
    await tester.tap(find.text(s.t('speakerYou')));
    await tester.pumpAndSettle();
    await choose(tester, sc.exchanges[0].reply.correct.text);
    await tester.tap(find.text(s.t('speakerYou')));
    await tester.pumpAndSettle();
    final r = (await repo.sceneResults()).single;
    expect(r.peeked, isTrue);
    expect(r.gistOk, isTrue);
  });

  test('the next scene is one never done, then the one done longest ago', () {
    Scene mk(String id) => Scene(
        id: id, topic: id, topicNative: '', exchanges: const [], createdAt: 0);
    Scene mkFull(String id) => Scene(
        id: id,
        topic: id,
        topicNative: '',
        exchanges: [
          Exchange(
              line: 'l', lineNative: '', gist: const Gist(options: ['a', 'b', 'c'], answer: 0),
              reply: const Reply(options: [
                ReplyOption(text: 'x'),
                ReplyOption(text: 'y'),
                ReplyOption(text: 'z')
              ], answer: 0))
        ],
        createdAt: 0);
    SceneResult done(String id, int at) => SceneResult(
        sceneId: id, exchange: 0, gistOk: true, replyOk: true, day: 'd', at: at);

    expect(pickScene([mk('empty')], const []), isNull);
    final a = mkFull('a'), b = mkFull('b'), c = mkFull('c');
    expect(pickScene([a, b, c], [done('a', 5), done('c', 9)])!.id, 'b');
    expect(pickScene([a, b, c], [done('a', 5), done('b', 7), done('c', 9)])!.id, 'a');
  });
}

/// A device with an English voice, without a platform: the screen takes the
/// listening path, which the plugin-less test runner otherwise never shows.
class _VoicedSpeech extends SpeechService {
  final spoken = <String>[];
  @override
  bool get available => true;
  @override
  Voice? voiceFor(int seed) => const Voice('en-test', 'en-US');
  @override
  Future<void> speak(String text, {double rate = 1.0, Voice? voice}) async => spoken.add(text);
  @override
  Future<void> stop() async {}
}
