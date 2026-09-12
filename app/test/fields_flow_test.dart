/// The field flow, on the real widgets: home lists the fields, a field
/// splits into samples and the learner's own, making scenes is asked per
/// field, a field can be added for Seeds, the profile has its own screen,
/// and the scene screen shows whose words are whose.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kotolang/core/l10n/strings.dart';
import 'package:kotolang/domain/field.dart';
import 'package:kotolang/domain/progress_service.dart';
import 'package:kotolang/features/field_screen.dart';
import 'package:kotolang/features/profile_screen.dart';
import 'package:kotolang/features/ai_screens.dart';
import 'package:kotolang/features/scene_screen.dart';
import 'package:kotolang/features/tree_view.dart';

import 'app_flow_test.dart' show pumpApp, seedLearner;
import 'repository_test.dart' show profileJson;
import 'fixtures.dart' show pack, scene;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('home puts the fields behind a picker, not on home itself',
      (tester) async {
    tall(tester);
    final (db, _) = await pumpApp(tester, seed: seedLearner);
    addTearDown(db.close);
    final s = S('en');

    expect(find.text(s.t('todayRandomNote')), findsOneWidget);
    // Two ways in, in one family: today's, and a field of their own. Neither
    // list is on home itself. The samples button is not here because there
    // are no samples yet — it comes back with them.
    expect(find.text(s.t('todayScene')), findsOneWidget);
    expect(find.text(s.t('homeFieldScenes')), findsOneWidget);
    expect(find.text(s.t('interest_travel')), findsNothing);

    // Their own picker leads to the field the imported scene landed in.
    await tester.tap(find.text(s.t('homeFieldScenes')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.t('interest_$defaultFieldId')));
    await tester.pumpAndSettle();
    expect(find.byType(FieldScreen), findsOneWidget);
    expect(find.text(s.t('feedbackButton')), findsOneWidget);

    // Starting from the own half opens the own scene, not a sample.
    await tester.tap(find.text(s.t('fieldStart')));
    await tester.pumpAndSettle();
    expect(find.byType(SceneScreen), findsOneWidget);
    expect(find.text(s.t('sceneReviewTag')), findsNothing);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(FieldScreen), findsOneWidget);
  });

  testWidgets('a field of their own asks for more conversations, and for feedback',
      (tester) async {
    tall(tester);
    final (db, _) = await pumpApp(tester, seed: (r) async {
      await seedLearner(r);
    });
    addTearDown(db.close);
    final s = S('en');

    // Another batch costs nothing, because nothing does; the way to it
    // leads to the prompt.
    await tester.tap(find.text(s.t('homeFieldScenes')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.t('interest_$defaultFieldId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.t('nextScenesMake')));
    await tester.pumpAndSettle();
    expect(find.byType(AiPromptScreen), findsOneWidget);
    final picker =
        tester.widget<DropdownButtonFormField<String>>(find.byKey(const ValueKey('fieldPicker')));
    // The field carries over from the screen it was opened from.
    expect(picker.initialValue, defaultFieldId);
    expect(find.text(s.t('privacyLine')), findsOneWidget);
  });

  testWidgets('the results go back to the AI only once there are enough of them',
      (tester) async {
    tall(tester);
    final (db, _) = await pumpApp(tester, seed: (r) async {
      await seedLearner(r, withScene: false);
      await r.importScenes(
          pack([for (var i = 0; i < feedbackAfter; i++) scene('Talk $i')]),
          uiLanguage: 'en');
    });
    addTearDown(db.close);
    final s = S('en');

    Future<void> openField() async {
      await tester.tap(find.text(s.t('homeFieldScenes')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.t('interest_$defaultFieldId')));
      await tester.pumpAndSettle();
    }

    // Nothing answered here yet: the button counts what is missing, and a
    // press explains rather than opens.
    await openField();
    expect(find.text('0 / $feedbackAfter'), findsOneWidget);
    await tester.tap(find.text(s.t('feedbackButton')));
    await tester.pumpAndSettle();
    expect(find.text(s.t('feedbackLockedTitle')), findsOneWidget);
    await tester.tap(find.text(s.t('close')));
    await tester.pumpAndSettle();
    expect(find.byType(AiPromptScreen), findsNothing);
  });

  testWidgets('a field of their own that is one of the built-in four keeps its name',
      (tester) async {
    // Conversations imported before fields existed sit in the default field,
    // which is one of the samples' four. Asking for more there must stay in
    // that field rather than silently moving to another.
    tall(tester);
    final (db, _) = await pumpApp(tester, seed: (r) async {
      await seedLearner(r);
    });
    addTearDown(db.close);
    final s = S('en');

    await tester.tap(find.text(s.t('homeFieldScenes')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.t('interest_$defaultFieldId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.t('nextScenesMake')));
    await tester.pumpAndSettle();
    final picker =
        tester.widget<DropdownButtonFormField<String>>(find.byKey(const ValueKey('fieldPicker')));
    expect(picker.initialValue, defaultFieldId);
  });

  testWidgets('with the field answered through, the results open on the prompt',
      (tester) async {
    tall(tester);
    final (db, repo) = await pumpApp(tester, seed: (r) async {
      await seedLearner(r, withScene: false);
      await r.importScenes(pack([for (var i = 0; i < feedbackAfter; i++) scene('Talk $i')]),
          uiLanguage: 'en');
      for (final sc in await r.scenes()) {
        await r.recordTurn(sceneId: sc.id, turn: 0, correct: true);
      }
    });
    addTearDown(db.close);
    final s = S('en');
    expect(await repo.scenes(), hasLength(feedbackAfter));

    await tester.tap(find.text(s.t('homeFieldScenes')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.t('interest_$defaultFieldId')));
    await tester.pumpAndSettle();
    // Every conversation here is answered, so the button is a button again.
    expect(find.text('$feedbackAfter / $feedbackAfter'), findsNothing);
    await tester.tap(find.text(s.t('feedbackButton')));
    await tester.pumpAndSettle();
    expect(find.text(s.t('feedbackLockedTitle')), findsNothing);
    expect(find.byType(AiPromptScreen), findsOneWidget);
    // One way: the prompt is copied, and no reply is asked for.
    expect(find.widgetWithText(FilledButton, s.t('copyPrompt')), findsOneWidget);
    expect(find.byKey(const ValueKey('fieldPicker')), findsNothing);
  });

  testWidgets('home scrolls back up from the bottom', (tester) async {
    // A phone-shaped viewport, so the list is longer than the screen and the
    // tree leaves it once the bottom is reached.
    tester.view.physicalSize = const Size(400, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final (db, _) = await pumpApp(tester, seed: seedLearner);
    addTearDown(db.close);
    final s = S('en');

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text(s.t('listenButton')), 200, scrollable: list);
    await tester.pumpAndSettle();
    // The tree stays mounted while it is off screen, so nothing above the
    // viewport changes height on the way back.
    expect(find.byType(TreePanel, skipOffstage: false), findsOneWidget);
    await tester.drag(list, const Offset(0, 400));
    await tester.pumpAndSettle();
    await tester.drag(list, const Offset(0, 400));
    await tester.pumpAndSettle();
    await tester.drag(list, const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('KotoLang'), findsOneWidget);
  });

  testWidgets('opening an area from the profile costs Seeds and needs the balance',
      (tester) async {
    tall(tester);
    final (db, repo) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
      await r.saveSettings(
          const AppSettings(ageBand: '30s', interests: ['work'], tutorialDone: true));
      // Five areas: three chosen to start with, two waiting on the ladder.
      await r.importProfile(profileJson(['Nursing', 'Cycling', 'Gardening', 'Chess', 'Sailing']),
          uiLanguage: 'en');
      await r.chooseFields([for (final x in (await r.realms()).take(3)) x.id]);
      await r.saveProgress(
          (await r.loadProgress()).copyWith(seeds: realmUnlockCost + 5));
    });
    addTearDown(db.close);
    final s = S('en');

    // Opening another field lives behind the picker for their own fields:
    // it is the only other thing that list can lead to.
    Future<void> openAddSheet() async {
      await tester.tap(find.text(s.t('homeFieldScenes')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.t('fieldAdd')));
      await tester.pumpAndSettle();
    }
    final lockedBefore = (await repo.realms()).where((r) => !r.unlocked).toList();
    expect(lockedBefore, hasLength(2));
    await openAddSheet();
    await tester.pumpAndSettle();
    // The sheet lists the two closed areas.
    for (final r in lockedBefore) {
      expect(find.text(r.label), findsOneWidget);
    }
    // Past the starting three it costs, so the popup says the number before
    // a single Seed is spent.
    await tester.tap(find.text(lockedBefore.first.label));
    await tester.pumpAndSettle();
    expect(find.text(s.t('lockedFieldTitle', {'realm': lockedBefore.first.label})),
        findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, s.t('seedsCost', {'n': realmUnlockCost})));
    await tester.pumpAndSettle();
    expect((await repo.loadProgress()).seeds, 5);
    expect((await repo.realms()).where((r) => !r.unlocked), hasLength(1));
    // An open field with no scenes is nothing yet: the scenes screen follows,
    // with the field already chosen.
    expect(find.byType(AiPromptScreen), findsOneWidget);
    final picker = tester.widget<DropdownButtonFormField<String>>(find.byKey(const ValueKey('fieldPicker')));
    expect(picker.initialValue, lockedBefore.first.id);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openAddSheet();
    await tester.tap(find.text(s.t('fieldAdd')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(lockedBefore.last.label));
    await tester.pumpAndSettle();
    // The balance is short now, so the second closed area gets a popup with
    // no button on it — only a way out.
    expect(find.text(s.t('lockedFieldTitle', {'realm': lockedBefore.last.label})), findsOneWidget);
    expect(find.widgetWithText(FilledButton, s.t('seedsCost', {'n': realmUnlockCost})),
        findsNothing);
    expect(find.text(s.t('close')), findsOneWidget);
    await tester.tap(find.text(s.t('close')));
    await tester.pumpAndSettle();
    expect((await repo.realms()).where((r) => !r.unlocked), hasLength(1));
    expect((await repo.loadProgress()).seeds, 5);
  });

  testWidgets('the profile screen shows the two answers and the AI profile', (tester) async {
    tall(tester);
    final (db, repo) = await pumpApp(tester, seed: seedLearner);
    addTearDown(db.close);
    final s = S('en');

    await tester.tap(find.text(s.t('settingsTitle')).last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(s.t('profileTitle')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(s.t('profileTitle')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);

    // The age is a chip that saves on tap.
    await tester.tap(find.text(s.t('age_40s')));
    await tester.pumpAndSettle();
    expect((await repo.loadSettings()).ageBand, '40s');

    // The AI profile is shown, with the way to remake it.
    expect(find.text(s.t('profileLevel')), findsOneWidget);
    expect(find.text(s.t('profileRemake')), findsOneWidget);
    expect(find.text(s.t('copyPrompt')), findsNothing);
    await tester.tap(find.text(s.t('profileRemake')));
    await tester.pumpAndSettle();
    // Remaking is the two-screen trip: the prompt first, the reply on the
    // next screen only.
    expect(find.byType(AiPromptScreen), findsOneWidget);
    expect(find.text(s.t('copyPrompt')), findsOneWidget);
    expect(find.text(s.t('scenePasteButton')), findsNothing);
    expect(find.text(s.t('privacyLine')), findsOneWidget);
  });
}
