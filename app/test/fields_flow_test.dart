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
import 'package:kotolang/features/scene_pack_screen.dart';
import 'package:kotolang/features/scene_screen.dart';

import 'app_flow_test.dart' show pumpApp, seedLearner;
import 'repository_test.dart' show profileJson;
import 'scene_flow_test.dart' show pumpScene, choose;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('home lists the four fields; a field splits into samples and own',
      (tester) async {
    tall(tester);
    final (db, _) = await pumpApp(tester, seed: seedLearner);
    addTearDown(db.close);
    final s = S('en');

    expect(find.text(s.t('todayRandomNote')), findsOneWidget);
    // Two doors: the learner's own scenes by field, then the samples by field.
    expect(find.text(s.t('ownFieldsTitle')), findsOneWidget);
    await tester.scrollUntilVisible(find.text(s.t('samplesFieldsTitle')), 200,
        scrollable: find.byType(Scrollable).first);
    // The samples are folded away until asked for.
    expect(find.text(s.t('interest_travel')), findsNothing);
    await tester.tap(find.text(s.t('samplesFieldsTitle')));
    await tester.pumpAndSettle();
    for (final id in builtinFieldIds) {
      await tester.scrollUntilVisible(find.text(s.t('interest_$id')).last, 200,
          scrollable: find.byType(Scrollable).first);
    }
    // The own scene was imported without a field, so it sits in the default,
    // which therefore appears on both sides; the own side comes first.
    expect(find.text(s.t('interest_$defaultFieldId')), findsNWidgets(2));
    await tester.scrollUntilVisible(find.text(s.t('interest_$defaultFieldId')).first, -200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(s.t('interest_$defaultFieldId')).first);
    await tester.pumpAndSettle();
    expect(find.byType(FieldScreen), findsOneWidget);
    expect(find.text('Stay late（日本語）'), findsOneWidget);
    expect(find.text(s.t('fieldStartOwn')), findsOneWidget);
    expect(find.text(s.t('fieldStartSamples')), findsNothing);

    // Starting from the own half opens the own scene, not a sample.
    await tester.tap(find.text(s.t('fieldStartOwn')));
    await tester.pumpAndSettle();
    expect(find.byType(SceneScreen), findsOneWidget);
    expect(find.text(s.t('sceneReviewTag')), findsNothing);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(FieldScreen), findsOneWidget);
  });

  testWidgets('a field with no own scenes leads to making them for that field',
      (tester) async {
    tall(tester);
    final (db, _) = await pumpApp(tester, seed: seedLearner);
    addTearDown(db.close);
    final s = S('en');

    // A sample field opens on the samples alone, with no way to make scenes.
    await tester.scrollUntilVisible(find.text(s.t('samplesFieldsTitle')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(s.t('samplesFieldsTitle')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(s.t('interest_travel')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(s.t('interest_travel')));
    await tester.pumpAndSettle();
    expect(find.byType(FieldScreen), findsOneWidget);
    expect(find.text(s.t('fieldStartSamples')), findsOneWidget);
    expect(find.text(s.t('makeOwnScenes')), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Making scenes asks for the field with a dropdown, preset to the first
    // interest the learner named.
    await tester.scrollUntilVisible(find.text(s.t('nextScenesMake')).first, -200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(s.t('nextScenesMake')).first);
    await tester.pumpAndSettle();
    expect(find.byType(ScenePackScreen), findsOneWidget);
    final picker = tester.widget<DropdownButtonFormField<String>>(find.byKey(const ValueKey('fieldPicker')));
    // Only the learner's own fields are offered, never the samples' four.
    expect(picker.initialValue, isNotNull);
    expect(picker.initialValue, isNot(isIn(builtinFieldIds)));
    expect(find.text(s.t('privacyLine')), findsOneWidget);
  });

  testWidgets('opening an area from the profile costs Seeds and needs the balance',
      (tester) async {
    tall(tester);
    final (db, repo) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
      await r.saveSettings(
          const AppSettings(ageBand: '30s', interests: ['work'], tutorialDone: true));
      // Five areas: the first three open for free, two wait, priced.
      await r.importProfile(profileJson(['Nursing', 'Cycling', 'Gardening', 'Chess', 'Sailing']),
          uiLanguage: 'en');
      await r.saveProgress((await r.loadProgress()).copyWith(seeds: realmUnlockCost + 5));
    });
    addTearDown(db.close);
    final s = S('en');
    final lockedBefore = (await repo.realms()).where((r) => !r.unlocked).toList();
    expect(lockedBefore, hasLength(2));

    await tester.scrollUntilVisible(find.text(s.t('fieldAdd')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(s.t('fieldAdd')));
    await tester.pumpAndSettle();
    // The sheet lists the two closed areas, priced.
    for (final r in lockedBefore) {
      expect(find.text(r.label), findsOneWidget);
    }
    await tester.tap(find.text(lockedBefore.first.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.t('unlockButton')));
    await tester.pumpAndSettle();
    expect((await repo.loadProgress()).seeds, 5);
    expect((await repo.realms()).where((r) => !r.unlocked), hasLength(1));
    // An open field with no scenes is nothing yet: the scenes screen follows,
    // with the field already chosen.
    expect(find.byType(ScenePackScreen), findsOneWidget);
    final picker = tester.widget<DropdownButtonFormField<String>>(find.byKey(const ValueKey('fieldPicker')));
    expect(picker.initialValue, lockedBefore.first.id);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Short of Seeds now: the last one is refused and nothing changes.
    await tester.tap(find.text(s.t('fieldAdd')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(lockedBefore.last.label));
    await tester.pumpAndSettle();
    expect(find.text(s.t('unlockButton')), findsNothing);
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
    expect(find.text(s.t('copyPrompt')), findsOneWidget);
    expect(find.text(s.t('scenePasteButton')), findsOneWidget);
    expect(find.text(s.t('privacyLine')), findsOneWidget);
  });

  testWidgets('the scene screen shows whose words are whose, and carries the gist into the reply',
      (tester) async {
    final (db, _, sc) = await pumpScene(tester);
    addTearDown(db.close);
    final s = S('en');

    expect(find.text(s.t('speakerOther')), findsOneWidget);
    expect(find.text(s.t('speakerYou')), findsOneWidget);
    expect(find.text(s.t('afterYourReply')), findsNothing);

    await choose(tester, sc.exchanges[0].gist.correct);
    await tester.tap(find.text(s.t('speakerYou')));
    await tester.pumpAndSettle();
    // What was heard is folded to a mark, so the reply is not read off it;
    // a tap opens it.
    expect(find.text(s.t('heardOk')), findsOneWidget);
    expect(find.text(sc.exchanges[0].gist.correct), findsNothing);
    await tester.tap(find.text(s.t('heardOk')));
    await tester.pumpAndSettle();
    expect(find.text(sc.exchanges[0].gist.correct), findsOneWidget);
    await choose(tester, sc.exchanges[0].reply.correct.text);
    await tester.tap(find.text(s.t('speakerYou')));
    await tester.pumpAndSettle();

    // The second line says it follows the learner's reply.
    expect(find.text(sc.exchanges[1].line), findsOneWidget);
    expect(find.text(s.t('afterYourReply')), findsOneWidget);
  });
}
