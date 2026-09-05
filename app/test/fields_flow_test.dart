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
    for (final id in builtinFieldIds) {
      await tester.scrollUntilVisible(find.text(s.t('interest_$id')), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(s.t('interest_$id')), findsOneWidget);
    }

    // The own scene was imported without a field, so it sits in the default.
    await tester.tap(find.text(s.t('interest_$defaultFieldId')));
    await tester.pumpAndSettle();
    expect(find.byType(FieldScreen), findsOneWidget);
    expect(find.text(s.t('sampleTag')), findsOneWidget);
    expect(find.text(s.t('fieldOwn')), findsOneWidget);
    expect(find.text('Stay late（日本語）'), findsOneWidget);
    expect(find.text(s.t('fieldStartSamples')), findsOneWidget);
    expect(find.text(s.t('fieldStartOwn')), findsOneWidget);

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

    await tester.scrollUntilVisible(find.text(s.t('interest_travel')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(s.t('interest_travel')));
    await tester.pumpAndSettle();
    expect(find.text(s.t('fieldOwnNone')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, s.t('makeOwnScenes')), findsOneWidget);

    await tester.tap(find.text(s.t('makeOwnScenes')));
    await tester.pumpAndSettle();
    expect(find.byType(ScenePackScreen), findsOneWidget);
    // Travel is already chosen on the scenes screen.
    final chip = tester.widget<ChoiceChip>(find.byKey(const ValueKey('field_travel')));
    expect(chip.selected, isTrue);
    expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('field_work'))).selected, isFalse);
  });

  testWidgets('adding a field asks for a name, charges Seeds and lists it', (tester) async {
    tall(tester);
    final (db, repo) = await pumpApp(tester, seed: (r) async {
      await seedLearner(r);
      await r.saveProgress((await r.loadProgress()).copyWith(seeds: realmUnlockCost + 5));
    });
    addTearDown(db.close);
    final s = S('en');

    await tester.scrollUntilVisible(find.textContaining(s.t('fieldAdd')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.textContaining(s.t('fieldAdd')));
    await tester.pumpAndSettle();
    expect(find.text(s.t('fieldAddBody', {'n': realmUnlockCost})), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Fishing');
    await tester.tap(find.text(s.t('confirmLabel')));
    await tester.pumpAndSettle();

    expect((await repo.loadProgress()).seeds, 5);
    expect(find.text('Fishing'), findsOneWidget);

    // Short of Seeds now: the next one is refused and nothing changes.
    await tester.tap(find.textContaining(s.t('fieldAdd')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Cooking');
    await tester.tap(find.text(s.t('confirmLabel')));
    await tester.pumpAndSettle();
    expect(find.text('Cooking'), findsNothing);
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
    expect(find.text(s.t('loadProfile')), findsOneWidget);
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
    // "You heard: …" sits above the reply question.
    expect(find.text(s.t('heardBand', {'text': sc.exchanges[0].gist.correct})), findsOneWidget);
    await choose(tester, sc.exchanges[0].reply.correct.text);
    await tester.tap(find.text(s.t('speakerYou')));
    await tester.pumpAndSettle();

    // The second line says it follows the learner's reply.
    expect(find.text(sc.exchanges[1].line), findsOneWidget);
    expect(find.text(s.t('afterYourReply')), findsOneWidget);
  });
}
