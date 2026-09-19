/// The set screen, on the real widgets.
///
/// One set: hear it, reply, hear the right reply said back, guess what comes
/// next, hear it. These check what the learner is shown at each point — the
/// replies only after the line, the line opened only after the reply, every
/// wrong option with its reason — and that what is written down is what
/// happened.
///
/// There is no voice on the host, so these run the way the screen runs on a
/// phone with no English voice installed: the line is shown rather than said,
/// and the window opens as soon as the button is pressed. That the line stays
/// hidden while it is being said is a thing only a device can answer.
library;

import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kotolang/app.dart';
import 'package:kotolang/core/l10n/strings.dart';
import 'package:kotolang/data/database.dart';
import 'package:kotolang/data/repository.dart';
import 'package:kotolang/domain/progress_service.dart';
import 'package:kotolang/domain/scene.dart';
import 'package:kotolang/features/scene_screen.dart';

import 'fixtures.dart' show pack, scene;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ja = S('ja');

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<(Repository, Scene)> open(WidgetTester tester, {bool coach = false}) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = Repository(db, rng: Random(7));
    addTearDown(db.close);
    await repo.saveUiLanguage('ja');
    await repo.importScenes(pack([scene('Moving a deadline')]), uiLanguage: 'ja', field: 'work');
    final s = (await repo.scenes()).single;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          repositoryProvider.overrideWithValue(repo),
          // The notes for a first question are tested on their own below.
          settingsProvider.overrideWith((ref) => AppSettings(coachSeen: !coach)),
        ],
        child: MaterialApp(home: SceneScreen(queue: [SetCard(s)])),
      ),
    );
    await tester.pump();
    return (repo, s);
  }

  Future<void> listen(WidgetTester tester) async {
    await tester.tap(find.text(ja.t('setListenButton')));
    await tester.pump();
  }

  Future<void> reply(WidgetTester tester, Scene s, int i) async {
    await tester.tap(find.text(s.set!.reply.options[i]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// From an answered reply to the guess being asked for: the right reply is
  /// said back first.
  Future<void> sayIt(WidgetTester tester) async {
    await tester.tap(find.text(ja.t('setSayButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('the replies appear only once the line has been said', (tester) async {
    tall(tester);
    final (_, s) = await open(tester);
    for (final o in s.set!.reply.options) {
      expect(find.text(o), findsNothing, reason: 'nothing to read before hearing');
    }
    await listen(tester);
    for (final o in s.set!.reply.options) {
      expect(find.text(o), findsOneWidget);
    }
    expect(find.text(ja.t('setReplyTitle')), findsOneWidget);
  });

  testWidgets('a right reply opens the line, and says why the others were wrong',
      (tester) async {
    tall(tester);
    final (repo, s) = await open(tester);
    final set = s.set!;
    await listen(tester);
    await reply(tester, s, set.reply.answer);

    expect(find.text(ja.t('setRight')), findsOneWidget);
    expect(find.text(set.partner.text), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      if (i == set.reply.answer) continue;
      expect(find.text(set.reply.why[i]), findsOneWidget, reason: 'reason for option $i');
    }
    final r = (await repo.turnResults()).single;
    expect(r.correct, isTrue);
    expect(r.inWindow, isTrue);
    expect((await repo.loadProgress()).seeds, greaterThanOrEqualTo(seedFloor));
  });

  testWidgets('a wrong reply is marked, pays nothing, and comes back tomorrow',
      (tester) async {
    tall(tester);
    final (repo, s) = await open(tester);
    final set = s.set!;
    final wrong = (set.reply.answer + 1) % 3;
    final before = (await repo.loadProgress()).seeds;
    await listen(tester);
    await reply(tester, s, wrong);

    expect(find.text(ja.t('setWrong')), findsOneWidget);
    expect(find.text(set.reply.why[wrong]), findsOneWidget);
    expect((await repo.loadProgress()).seeds, before);
    expect(await repo.reviews(), hasLength(1));
  });

  testWidgets('the right reply is said back, and a guess is put down and settled',
      (tester) async {
    tall(tester);
    final (repo, s) = await open(tester);
    final set = s.set!;
    await listen(tester);
    await reply(tester, s, set.reply.answer);
    await sayIt(tester);

    expect(find.text(ja.t('setPredictTitle')), findsOneWidget);
    // Nothing to hear until a guess is down.
    final button = find.widgetWithText(FilledButton, ja.t('setCheckButton'));
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.tap(find.text(set.predict.options[set.predict.answer]));
    await tester.pump();
    expect(find.text(ja.t('setTentTag')), findsOneWidget, reason: 'put down, not given');
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);

    final before = (await repo.loadProgress()).seeds;
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(set.response.text), findsOneWidget);
    expect(find.text(ja.t('setPredictHit')), findsOneWidget);
    expect(await repo.predictResults(), hasLength(1));
    expect(await repo.turnResults(), hasLength(1), reason: 'the guess is not a reply');
    expect((await repo.loadProgress()).seeds, before + predictSeeds);
  });

  testWidgets('a window that closes gives the line again, once, in other words',
      (tester) async {
    tall(tester);
    final (repo, s) = await open(tester);
    await listen(tester);
    await tester.pump(const Duration(milliseconds: answerWindowMs + 100));
    await tester.pump();

    // No voice, so it goes straight back to the window, with the other words
    // on screen.
    expect(find.text(s.set!.paraphrase), findsOneWidget);
    expect(find.text(ja.t('setHearAgain')), findsNothing, reason: 'only once');

    await tester.pump(const Duration(milliseconds: answerWindowMs + 100));
    await tester.pump();
    expect(find.text(ja.t('setTimeUp')), findsOneWidget);
    final r = (await repo.turnResults()).single;
    expect(r.correct, isFalse);
  });

  testWidgets('a right reply after the second hearing pays the least', (tester) async {
    tall(tester);
    final (repo, s) = await open(tester);
    await listen(tester);
    await tester.tap(find.text(ja.t('setHearAgain')));
    await tester.pump();
    final before = (await repo.loadProgress()).seeds;
    await reply(tester, s, s.set!.reply.answer);
    expect(find.text(ja.t('setFloorPill')), findsOneWidget);
    expect((await repo.loadProgress()).seeds, before + seedFloor);
    expect((await repo.turnResults()).single.inWindow, isFalse);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a line cut off starts again, and nothing is counted', (tester) async {
    tall(tester);
    final (repo, s) = await open(tester);
    await listen(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text(ja.t('setPausedTitle')), findsOneWidget);
    expect(await repo.turnResults(), isEmpty);
    await tester.pump(const Duration(milliseconds: answerWindowMs + 100));
    expect(await repo.turnResults(), isEmpty, reason: 'the clock stopped');

    await tester.tap(find.text(ja.t('setResume')));
    await tester.pump();
    expect(find.text(ja.t('setReplyTitle')), findsOneWidget);
    await reply(tester, s, s.set!.reply.answer);
    expect((await repo.turnResults()).single.inWindow, isTrue,
        reason: 'the cut was not a second hearing');
  });

  testWidgets('the run ends on what the replies and the guesses came to',
      (tester) async {
    tall(tester);
    final (_, s) = await open(tester);
    final set = s.set!;
    await listen(tester);
    await reply(tester, s, set.reply.answer);
    await sayIt(tester);
    await tester.tap(find.text(set.predict.options[(set.predict.answer + 1) % 3]));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, ja.t('setCheckButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(ja.t('setPredictMiss')), findsOneWidget);

    await tester.tap(find.text(ja.t('setToSummary')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(ja.t('setSumReply')), findsOneWidget);
    expect(find.text('1／0（0）'), findsOneWidget);
    expect(find.text('0／1'), findsOneWidget);
    expect(find.text(ja.t('setAgain')), findsOneWidget);
  });
  testWidgets('the first question explains each step once, and holds the clock',
      (tester) async {
    tall(tester);
    final (repo, s) = await open(tester, coach: true);
    final set = s.set!;

    expect(find.text(ja.t('setCoachListenTitle')), findsOneWidget);
    await tester.tap(find.text(ja.t('setListenButton')));
    await tester.pump();
    expect(find.text(ja.t('setCoachListenTitle')), findsOneWidget,
        reason: 'nothing under the note can be pressed until it is read');
    await tester.tap(find.text(ja.t('setCoachOk')));
    await tester.pump();

    await tester.tap(find.text(ja.t('setListenButton')));
    await tester.pump();
    expect(find.text(ja.t('setCoachReplyTitle')), findsOneWidget);
    // The window does not run while the reply is being explained.
    await tester.pump(const Duration(milliseconds: answerWindowMs + 500));
    expect(await repo.turnResults(), isEmpty);
    await tester.tap(find.text(ja.t('setCoachOk')));
    await tester.pump();

    await tester.tap(find.text(set.reply.options[set.reply.answer]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(ja.t('setCoachResultTitle')), findsOneWidget);
    await tester.tap(find.text(ja.t('setCoachOk')));
    await tester.pump();

    await tester.tap(find.text(ja.t('setSayButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text(ja.t('setCoachPredictTitle')), findsOneWidget);
    expect(find.text(ja.t('setNextLine')), findsOneWidget, reason: 'the blank for their line');
    await tester.tap(find.text(ja.t('setCoachOk')));
    await tester.pump();
    expect((await repo.loadSettings()).coachSeen, isTrue, reason: 'shown once, not again');
  });
}
