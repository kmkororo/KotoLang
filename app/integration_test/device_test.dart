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

import '../test/fixtures.dart' show pack, scene, turn;

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

  final en = S('en');

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

  testWidgets('the on-device database keeps a conversation and an answer',
      (tester) async {
    // The app's own file-backed database, not an in-memory one.
    final db = AppDatabase();
    final repo = Repository(db);
    addTearDown(db.close);
    await repo.factoryReset(keepLanguage: false);

    final out = await repo.importScenes(
        pack([
          scene('Moving a deadline'),
          scene('A visitor at three', turns: [turn(), turn(type: 'polarity')]),
        ]),
        uiLanguage: 'en',
        field: 'work');
    expect(out.ok, isTrue, reason: out.errors.join(', '));
    expect(out.scenes, 2);

    final stored = await repo.scenes();
    expect(stored, hasLength(2));
    expect(stored.map((s) => s.turns.length).toList()..sort(), [1, 2]);

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

  testWidgets('a conversation played on the device records a real answer',
      (tester) async {
    final db = AppDatabase();
    final repo = Repository(db);
    addTearDown(db.close);

    await repo.factoryReset(keepLanguage: false);
    await repo.saveUiLanguage('en');
    await repo.importScenes(pack([scene('Moving a deadline')]),
        uiLanguage: 'en', field: 'work');
    final s = (await repo.scenes()).single;
    final right = s.turns.first.replies[s.turns.first.answer].text;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: SceneScreen(scene: s)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // The replies are readable before anything is said — that is the point of
    // the screen, and it has to hold on a real device too.
    expect(find.text(right), findsOneWidget);
    expect(find.text(s.turns.first.line), findsNothing,
        reason: 'the line is never shown before it has been answered');

    await tester.tap(find.text(en.t('scenePlay')));

    // Speaking takes as long as the engine takes; the window opens after it.
    await waitFor(tester, find.text(en.t('sceneYourTurn')));
    await tester.tap(find.text(right));

    await waitFor(tester, find.text('1 / 1'));

    final result = (await repo.turnResults()).single;
    expect(result.sceneId, s.id);
    expect(result.correct, isTrue);
    expect(result.review, isFalse);

    await repo.factoryReset(keepLanguage: false);
  });
}
