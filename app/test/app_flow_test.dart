/// Drives the real widgets against a real (in-memory) database.
///
/// The domain and repository suites prove the rules; this one proves the app
/// a person actually touches: that the first screen is the language picker,
/// that the first run asks two things and ends on the way to the learner's
/// own AI, that home leads to today's scene, and that the tabs and the
/// language switch work.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:kotolang/app.dart';
import 'package:kotolang/core/l10n/strings.dart';
import 'package:kotolang/data/database.dart';
import 'package:kotolang/data/repository.dart';
import 'package:kotolang/domain/progress_service.dart';
import 'package:kotolang/features/first_run_screen.dart';
import 'package:kotolang/features/profile_screen.dart';
import 'package:kotolang/features/record_screen.dart';
import 'package:kotolang/features/scene_pack_screen.dart';
import 'package:kotolang/features/scene_screen.dart';
import 'package:kotolang/features/tree_view.dart';

import 'repository_test.dart' show profileJson;
import 'scene_test.dart' show pack, scene;

/// Pumps the app over a fresh in-memory database.
Future<(AppDatabase, Repository)> pumpApp(
  WidgetTester tester, {
  Future<void> Function(Repository repo)? seed,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final repo = Repository(db, rng: Random(42));
  if (seed != null) await seed(repo);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        // The tree sways in a loop on a real device. Held still here: a
        // repeating animation means `pumpAndSettle` never settles.
        treeMotionProvider.overrideWithValue(false),
      ],
      child: const KotoLangApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (db, repo);
}

/// A learner past the first run, with one scene of their own.
Future<void> seedLearner(Repository repo, {bool withScene = true}) async {
  await repo.saveUiLanguage('en');
  await repo.saveSettings(
      const AppSettings(ageBand: '30s', interests: ['work'], tutorialDone: true));
  await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
  if (withScene) await repo.importScenes(pack([scene('Stay late')]), uiLanguage: 'en');
}

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first run opens on the language picker, in every language',
      (tester) async {
    final (db, _) = await pumpApp(tester);
    addTearDown(db.close);

    const endonyms = [
      '日本語', 'English', 'Español', 'Português (Brasil)', 'Français',
      'Deutsch', '한국어', '简体中文', 'हिन्दी', 'Bahasa Indonesia',
    ];
    for (final name in endonyms) {
      await tester.scrollUntilVisible(find.text(name), 120,
          scrollable: find.byType(Scrollable).last);
      expect(find.text(name), findsOneWidget, reason: name);
    }
  });

  testWidgets('choosing a language leads to the two first-run questions', (tester) async {
    final (db, _) = await pumpApp(tester);
    addTearDown(db.close);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S('en').t('continueLabel')));
    await tester.pumpAndSettle();

    final s = S('en');
    expect(find.byType(FirstRunScreen), findsOneWidget);
    expect(find.text(s.t('firstRunTitle')), findsOneWidget);
    for (final band in ageBands) {
      expect(find.text(s.t('age_${band.replaceAll('+', 'plus')}')), findsOneWidget);
    }
    for (final kind in interestKinds) {
      expect(find.text(s.t('interest_$kind')), findsOneWidget);
    }
  });

  testWidgets("the first run keeps the answers and ends pointing at the learner's own AI",
      (tester) async {
    _tallScreen(tester);
    final (db, repo) = await pumpApp(tester, seed: (r) => r.saveUiLanguage('en'));
    addTearDown(db.close);
    final s = S('en');

    // Continue waits for an age.
    final go = find.widgetWithText(FilledButton, s.t('continueLabel'));
    expect(tester.widget<FilledButton>(go).onPressed, isNull);
    await tester.tap(find.text(s.t('age_20s')));
    await tester.tap(find.text(s.t('interest_travel')));
    await tester.pumpAndSettle();
    await tester.tap(go);
    await tester.pumpAndSettle();

    final settings = await repo.loadSettings();
    expect(settings.ageBand, '20s');
    expect(settings.interests, ['travel']);

    // The sample scene, with the guide on it. Leaving it early still leads on.
    expect(find.byType(SceneScreen), findsOneWidget);
    expect(find.text(s.t('tutListen')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // The sprout: the main button is the way to the learner's own AI.
    expect(find.text(s.t('sproutTitle')), findsOneWidget);
    expect(find.text(s.t('sproutSample')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, s.t('makeOwnScenes')), findsOneWidget);
    await tester.tap(find.text(s.t('laterSamples')));
    await tester.pumpAndSettle();

    // Home, on the samples, with the way to the real thing always in view.
    expect((await repo.loadSettings()).tutorialDone, isTrue);
    expect(find.text(s.t('todaySceneSample')), findsOneWidget);
    expect(find.text(s.t('ownScenesCardTitle')), findsOneWidget);
    expect(find.text(s.t('axisEmpty')), findsOneWidget);
  });

  testWidgets('a learner with a scene lands on home and can start it', (tester) async {
    _tallScreen(tester);
    final (db, repo) = await pumpApp(tester, seed: seedLearner);
    addTearDown(db.close);
    final s = S('en');

    expect(find.text('KotoLang'), findsOneWidget);
    expect(find.text(s.t('todayScene')), findsOneWidget);
    // Own scenes are here, so the samples-only card is not.
    expect(find.text(s.t('ownScenesCardTitle')), findsNothing);

    await tester.tap(find.text(s.t('todayScene')));
    await tester.pumpAndSettle();
    expect(find.byType(SceneScreen), findsOneWidget);
    expect(find.text(s.t('sceneQ1')), findsOneWidget);

    // Leaving before anything was answered needs no confirmation.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(SceneScreen), findsNothing);
    expect(await repo.sceneResults(), isEmpty);
  });

  testWidgets('with only the samples, home leads to making the first own scenes',
      (tester) async {
    _tallScreen(tester);
    final (db, _) = await pumpApp(tester, seed: (r) => seedLearner(r, withScene: false));
    addTearDown(db.close);
    final s = S('en');

    // The samples are there to play, and the card to the learner's own AI
    // stays up until an own scene arrives.
    expect(find.text(s.t('todaySceneSample')), findsOneWidget);
    await tester.tap(find.text(s.t('makeOwnScenes')));
    await tester.pumpAndSettle();
    expect(find.byType(ScenePackScreen), findsOneWidget);
    expect(find.text(s.t('firstSceneMake')), findsOneWidget);
    // The profile is there, so the prompt is ready to copy.
    final copy = find.widgetWithText(FilledButton, s.t('copyPrompt'));
    expect(tester.widget<FilledButton>(copy).onPressed, isNotNull);
    expect(find.text(s.t('scenePackNeedProfile')), findsNothing);
  });

  testWidgets('the scenes screen asks for a profile first when there is none',
      (tester) async {
    _tallScreen(tester);
    final (db, _) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
      await r.saveSettings(const AppSettings(ageBand: '20s', tutorialDone: true));
    });
    addTearDown(db.close);
    final s = S('en');

    await tester.tap(find.text(s.t('makeOwnScenes')));
    await tester.pumpAndSettle();
    expect(find.text(s.t('scenePackNeedProfile')), findsOneWidget);
    final copy = find.widgetWithText(FilledButton, s.t('copyPrompt'));
    expect(tester.widget<FilledButton>(copy).onPressed, isNull);

    await tester.tap(find.text(s.t('scenePackProfileButton')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('the three bottom tabs all render', (tester) async {
    _tallScreen(tester);
    final (db, _) = await pumpApp(tester, seed: seedLearner);
    addTearDown(db.close);
    final s = S('en');

    await tester.tap(find.text(s.t('recordTab')).last);
    await tester.pumpAndSettle();
    expect(find.byType(RecordScreen), findsOneWidget);
    expect(find.text(s.t('skillUnderstand')), findsOneWidget);
    expect(find.text(s.t('sceneListTitle')), findsOneWidget);
    // The own scene and the samples are listed together, samples marked.
    await tester.scrollUntilVisible(find.text('Stay late（日本語）'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Stay late（日本語）'), findsOneWidget);
    expect(find.text(s.t('sampleTag')), findsWidgets);

    await tester.tap(find.text(s.t('settingsTitle')).last);
    await tester.pumpAndSettle();
    expect(find.text(s.t('interfaceSection')), findsOneWidget);
  });

  testWidgets('the interface language can be changed after setup', (tester) async {
    _tallScreen(tester);
    final (db, repo) = await pumpApp(tester, seed: seedLearner);
    addTearDown(db.close);

    await tester.tap(find.text(S('en').t('settingsTitle')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(S('en').t('uiLanguageLabel')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日本語'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S('ja').t('continueLabel')));
    await tester.pumpAndSettle();

    expect(await repo.loadUiLanguage(), 'ja');
    expect(find.text(S('ja').t('settingsTitle')), findsWidgets);
  });

  testWidgets('a decoration is confirmed, charged for and hung on the tree', (tester) async {
    _tallScreen(tester);
    final (db, repo) = await pumpApp(tester, seed: (r) async {
      await seedLearner(r);
      await r.saveProgress((await r.loadProgress()).copyWith(seeds: ornamentCost));
    });
    addTearDown(db.close);
    final s = S('en');

    await tester.tap(find.text(s.t('recordTab')).last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(s.t('ornamentNote', {'n': ornamentCost})), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byWidgetPredicate(
        (w) => w is Image && '${w.image}'.contains('ornament_ribbon')));
    await tester.pumpAndSettle();
    expect(find.text(s.t('ornamentConfirmTitle')), findsOneWidget);
    await tester.tap(find.text(s.t('confirmLabel')));
    await tester.pumpAndSettle();

    final progress = await repo.loadProgress();
    expect(progress.seeds, 0);
    expect(progress.ornaments, ['ribbon']);
  });
}
