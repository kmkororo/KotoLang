/// Runs on a real Android device or emulator.
///
/// The unit and widget suites run on the host and stub the platform away.
/// These are the questions only hardware can answer: does the installed
/// text-to-speech engine have an English voice and will it speak at every
/// rate the speed ladder asks for, does SQLite really open a file on the
/// device, and does a conversation played on a real screen put a real answer
/// in that file.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:kotolang/app.dart';
import 'package:kotolang/core/l10n/strings.dart';
import 'package:kotolang/core/speech.dart';
import 'package:kotolang/data/database.dart';
import 'package:kotolang/data/repository.dart';
import 'package:kotolang/domain/ladder.dart';
import 'package:kotolang/features/scene_screen.dart';

import '../test/fixtures.dart' show pack, scene;

/// Pumps in real time until [f] is on screen. `pumpAndSettle` cannot be used
/// here: the window is a running animation, so the screen never settles while
/// it is open.
Future<void> waitFor(
  WidgetTester tester,
  Finder f, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (f.evaluate().isNotEmpty) return;
  }
  fail('timed out waiting for: $f');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final ja = S('ja');

  testWidgets('the device speaks English, at every rate the ladder asks for',
      (tester) async {
    final speech = SpeechService();
    await speech.init();

    expect(speech.supported, isTrue,
        reason: 'the platform reported no text-to-speech at all');
    expect(speech.voices, isNotEmpty,
        reason: 'no English voice is installed on this device');
    debugPrint('TTS voices found: ${speech.voices.length}');
    debugPrint('chosen: ${speech.chosen?.name} (${speech.chosen?.locale})');

    // The bottom and the top of the speed axis. Whether sound leaves the
    // speaker cannot be asserted from here, but an engine that will not go
    // that fast surfaces as an exception — and the top of the ladder would
    // then be unreachable on this phone.
    for (final step in [0, axisTop[LadderAxis.speed]!]) {
      await speech.speak('Please confirm the handover before Thursday.',
          rate: speedAt(step));
      await tester.pump(const Duration(seconds: 1));
      await speech.stop();
    }
  });

  testWidgets('the engine says where it is, word by word, and when it has finished',
      (tester) async {
    final speech = SpeechService();
    await speech.init();
    const line = "Morning. Just so you know, the big meeting room on the fourth floor is "
        "closed today because they're fixing the air conditioning. Your two o'clock "
        'with the design team has moved to the small room on the second floor.';
    final words = SpeechService.tokens(line);
    final heard = <int>[];
    final at = <int>[];
    final start = DateTime.now();
    final done = await speech.say(line, onWord: (i) {
      heard.add(i);
      at.add(DateTime.now().difference(start).inMilliseconds);
    });
    final took = DateTime.now().difference(start).inMilliseconds;
    debugPrint('WORDS ${words.length} heard ${heard.length} in ${took}ms');
    debugPrint('WORD TIMES ${[for (var i = 0; i < heard.length; i++) '${words[heard[i]].word}@${at[i]}'].join(' ')}');
    expect(done, isTrue, reason: 'said to the end');
    expect(heard, isNotEmpty, reason: 'the engine reports no word boundaries');
    expect(heard.length, greaterThan(words.length * 0.8),
        reason: 'most words are reported');

    // Stopped part-way, it says so.
    final cut = speech.say(line);
    await tester.pump(const Duration(milliseconds: 800));
    await speech.stop();
    expect(await cut, isFalse, reason: 'a line cut short is not a line heard');

    final pair = speech.pair();
    debugPrint('VOICES partner=${pair.partner?.name} you=${pair.you?.name} '
        'pitch ${pair.partnerPitch}/${pair.youPitch}');
  });

  testWidgets('the on-device database keeps a conversation and an answer',
      (tester) async {
    // The app's own file-backed database, not an in-memory one.
    final db = AppDatabase();
    final repo = Repository(db);
    addTearDown(db.close);
    await repo.factoryReset(keepLanguage: false);

    final out = await repo.importScenes(
        pack([scene('Moving a deadline'), scene('A visitor at three')]),
        uiLanguage: 'en',
        field: 'work');
    expect(out.ok, isTrue, reason: out.errors.join(', '));
    expect(out.scenes, 2);

    final stored = await repo.scenes();
    expect(stored, hasLength(2));
    expect(stored.every((s) => s.playable), isTrue);

    final id = stored.first.id;
    await repo.recordTurn(sceneId: id, turn: 0, correct: true);

    // Read it back through a second repository on the same file: proves it
    // reached disk rather than a cache.
    final again = Repository(AppDatabase());
    addTearDown(() => again.db.close());
    expect((await again.turnResults()).single.sceneId, id);
    expect((await again.scenes()).map((s) => s.id), contains(id));

    await repo.factoryReset(keepLanguage: false);
  });

  testWidgets('a set played on the device hides the line while it is said',
      (tester) async {
    final db = AppDatabase();
    final repo = Repository(db);
    addTearDown(db.close);

    await repo.factoryReset(keepLanguage: false);
    await repo.saveUiLanguage('ja');
    await repo.importScenes(pack([scene('Moving a deadline')]),
        uiLanguage: 'ja', field: 'work');
    final s = (await repo.scenes()).single;
    final set = s.set!;
    final right = set.reply.options[set.reply.answer];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: SceneScreen(queue: [SetCard(s)])),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(ja.t('setListenButton')));
    await tester.pump(const Duration(milliseconds: 1500));

    // While they speak: no words on screen, and nothing to choose yet.
    expect(find.text(set.partner.text), findsNothing);
    expect(find.text(right), findsNothing);
    expect(find.text(ja.t('setSpeakingTitle', {'name': set.partnerName})), findsOneWidget);

    // The replies come only once the engine says the line is over.
    await waitFor(tester, find.text(ja.t('setReplyTitle')));
    await tester.tap(find.text(right));
    await waitFor(tester, find.text(ja.t('setSayButton')));
    expect(find.text(set.partner.text), findsOneWidget, reason: 'opened once answered');

    await tester.tap(find.text(ja.t('setSayButton')));
    await waitFor(tester, find.text(ja.t('setPredictTitle', {'name': set.partnerName})));
    await tester.tap(find.text(set.predict.options[set.predict.answer]));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, ja.t('setListenButton')));
    await waitFor(tester, find.text(ja.t('setPredictHit')));

    final result = (await repo.turnResults()).single;
    expect(result.correct, isTrue);
    expect(result.inWindow, isTrue);
    expect((await repo.predictResults()).single.correct, isTrue);

    await repo.factoryReset(keepLanguage: false);
  });
}
