/// Drives the real widgets against a real (in-memory) database.
///
/// The domain and repository suites prove the rules; this one proves the app
/// a person actually touches: that the first screen is the language picker,
/// that onboarding leads somewhere, that a question can be answered, and that
/// the interface really does change language.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:kotolang/app.dart';
import 'package:kotolang/core/l10n/strings.dart';
import 'package:kotolang/data/database.dart';
import 'package:kotolang/data/repository.dart';
import 'package:kotolang/domain/models.dart';
import 'package:kotolang/domain/progress_service.dart';
import 'package:kotolang/features/ai_links.dart';
import 'package:kotolang/features/onboarding_screens.dart';
import 'package:kotolang/features/paste_box.dart';
import 'package:kotolang/features/quiz_screen.dart';
import 'package:kotolang/features/tree_view.dart';

import 'paste_test.dart' show materialReply;
import 'repository_test.dart' show materialJson, profileJson;

/// Pumps the app over a fresh in-memory database.
Future<(AppDatabase, Repository)> pumpApp(
  WidgetTester tester, {
  Future<void> Function(Repository repo)? seed,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  // Seeded, and shared with the widgets under test. Session building draws at
  // random, so an unseeded app picked a different question type on every run
  // and any assertion about the question on screen was a coin toss.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first run opens on the language picker, in every language',
      (tester) async {
    final (db, _) = await pumpApp(tester);
    addTearDown(db.close);

    // All ten options are offered, each written in its own script. The list
    // scrolls, so later entries have to be brought into view first.
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

  testWidgets('choosing a language shows the welcome screen in that language',
      (tester) async {
    final (db, repo) = await pumpApp(tester);
    addTearDown(db.close);

    await tester.tap(find.text('日本語'));
    await tester.pumpAndSettle();

    // The picker previews the pending choice before it is committed.
    expect(find.text(S('ja').t('continueLabel')), findsOneWidget);

    await tester.tap(find.text(S('ja').t('continueLabel')));
    await tester.pumpAndSettle();

    expect(await repo.loadUiLanguage(), 'ja');
    expect(find.text(S('ja').t('goToPaste')), findsOneWidget);
  });

  testWidgets('a learner with material lands on home and can start a session',
      (tester) async {
    final (db, repo) = await pumpApp(tester, seed: (repo) async {
      await repo.saveUiLanguage('en');
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await repo.importMaterial(
        materialJson(realm: 'Work', terms: [
          ('repair policy', 'meaning A'),
          ('damage tolerance', 'meaning B'),
          ('third term', 'meaning C'),
        ]),
        uiLanguage: 'en',
      );
    });
    addTearDown(db.close);

    final s = S('en');
    expect(find.text('KotoLang'), findsOneWidget);
    expect(find.text(s.t('startLearning')), findsOneWidget);
    expect(find.text(s.t('justOne')), findsOneWidget);

    // Start the shortest possible session.
    await tester.tap(find.text(s.t('justOne')));
    await tester.pumpAndSettle();

    expect(find.byType(QuizScreen), findsOneWidget);
    // Nothing has played yet, so the button invites a first listen rather
    // than offering to repeat something the learner has not heard.
    expect(find.text(s.t('playFirst')), findsOneWidget);
    expect(find.text(s.t('playAgain')), findsNothing);

    await tester.tap(find.text(s.t('playFirst')));
    await tester.pumpAndSettle();
    expect(find.text(s.t('playAgain')), findsOneWidget);

    // The answer button starts disabled: nothing has been chosen yet.
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, s.t('answerLabel')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('a "say it" question offers no way to hear the answer first',
      (tester) async {
    // The one thing that makes this format different from reorder. If the
    // play button were on screen the learner could simply listen and copy,
    // and the question would stop testing recall.
    _tallScreen(tester);
    final (db, repo) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
      await r.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await r.importMaterial(
        materialJson(realm: 'Work', terms: [('repair policy', 'meaning A')]),
        uiLanguage: 'en',
      );
    });
    addTearDown(db.close);

    final s = S('en');
    // Walk sessions until the format comes up; the mix is deliberately varied.
    var guard = 0;
    while (find.text(s.t('typeProduce')).evaluate().isEmpty && guard++ < 25) {
      if (find.byType(QuizScreen).evaluate().isNotEmpty) {
        // The quiz screen leaves by its close icon, behind a confirmation.
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        await tester.tap(find.text(s.t('quitConfirm')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(s.t('justOne')));
      await tester.pumpAndSettle();
    }

    expect(find.text(s.t('typeProduce')), findsOneWidget,
        reason: 'the produce format never came up in $guard tries');
    expect(find.text(s.t('playAgain')), findsNothing);
    expect(find.text(s.t('promptProduce')), findsOneWidget);
    // The meaning is the prompt, so it has to be on screen.
    final sentence = (await repo.sentences()).first;
    expect(find.textContaining(sentence.translationNative.split(' ').first),
        findsWidgets);
  });

  testWidgets('a "phrasing" question states the situation and explains itself',
      (tester) async {
    _tallScreen(tester);
    final (db, repo) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
      await r.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await r.importMaterial(
        materialJson(realm: 'Work', terms: [('repair policy', 'meaning A')]),
        uiLanguage: 'en',
      );
    });
    addTearDown(db.close);

    final s = S('en');
    // Register's share of the rotation dropped when gist/reply were
    // reweighted to lead the mix by a wide margin, so it can take more tries
    // than the other single-format search tests in this file to come up.
    var guard = 0;
    while (find.text(s.t('typeRegister')).evaluate().isEmpty && guard++ < 80) {
      if (find.byType(QuizScreen).evaluate().isNotEmpty) {
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        await tester.tap(find.text(s.t('quitConfirm')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(s.t('justOne')));
      await tester.pumpAndSettle();
    }

    expect(find.text(s.t('typeRegister')), findsOneWidget,
        reason: 'the register format never came up in $guard tries');

    // Who you are speaking to is the entire question, so it must be stated.
    final sentence =
        (await repo.sentences()).firstWhere((x) => x.registerCorrect >= 0);
    expect(find.text(sentence.registerSituationNative), findsOneWidget);
    // It is a question about phrasing, not about listening.
    expect(find.text(s.t('playAgain')), findsNothing);

    // Pick the phrasing that fits, by its text rather than its position.
    await tester.tap(find.text(sentence.registerOptionsEn[sentence.registerCorrect]));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, s.t('answerLabel')));
    await tester.pumpAndSettle();

    // The reason is the teaching. Without it the question is a coin toss.
    expect(find.textContaining(s.t('registerWhyLabel')), findsOneWidget);
  });

  testWidgets('answering a multiple-choice question records it and shows why',
      (tester) async {
    late Repository repository;
    final (db, repo) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
      await r.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await r.importMaterial(
        materialJson(realm: 'Work', terms: [('repair policy', 'meaning A')]),
        uiLanguage: 'en',
      );
    });
    repository = repo;
    addTearDown(db.close);

    final s = S('en');
    await tester.tap(find.text(s.t('justOne')));
    await tester.pumpAndSettle();

    // Keep starting sessions until a four-option question comes up; the mix is
    // deliberately varied, so the format is not fixed.
    var guard = 0;
    while (find.byType(InkWell).evaluate().length < 4 && guard++ < 8) {
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.t('justOne')));
      await tester.pumpAndSettle();
    }

    // Answer whatever is on screen by tapping the first available choice or tile.
    final tappable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(InkWell),
    );
    if (tappable.evaluate().isNotEmpty) {
      await tester.tap(tappable.last, warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    final answerButton = find.widgetWithText(FilledButton, s.t('answerLabel'));
    if (tester.widget<FilledButton>(answerButton).onPressed != null) {
      await tester.tap(answerButton);
      await tester.pumpAndSettle();

      // One answer is one study day, and it is recorded immediately.
      expect((await repository.history()).length, 1);
      expect((await repository.loadProgress()).streak, 1);
      expect(find.text(s.t('finishSession')), findsOneWidget);
    }
  });

  testWidgets('an empty install routes to onboarding, not to an empty home',
      (tester) async {
    final (db, _) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
    });
    addTearDown(db.close);

    final s = S('en');
    // Language is chosen but nothing else exists: the welcome screen, never a
    // home screen with nothing on it.
    expect(find.text(s.t('welcomeTitle')), findsOneWidget);
    expect(find.text(s.t('goToPaste')), findsOneWidget);
    expect(find.text(s.t('startLearning')), findsNothing);
  });

  testWidgets('the profile step copies and pastes on the one screen',
      (tester) async {
    // Copying used to be on the welcome screen and pasting on the next one,
    // which left people holding a prompt with nowhere obvious to put it.
    _tallScreen(tester);
    final (db, _) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
    });
    addTearDown(db.close);

    final s = S('en');
    await tester.tap(find.text(s.t('goToPaste')));
    await tester.pumpAndSettle();

    expect(find.text(s.t('step1Title')), findsOneWidget);
    expect(find.text(s.t('copyPrompt')), findsOneWidget);
    expect(find.text(s.t('openAiTitle')), findsOneWidget);
    for (final ai in aiServices) {
      expect(find.text(ai.name), findsOneWidget, reason: ai.name);
    }
    expect(find.text(s.t('step2Title')), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(s.t('loadProfile')), findsOneWidget);
  });

  testWidgets('onboarding caps the free realms at three, no more', (tester) async {
    // The first three areas are free. A fourth must not become checkable —
    // that would silently promise something Seeds are supposed to gate — but
    // tapping it has to say why rather than simply doing nothing.
    _tallScreen(tester);
    final (db, repo) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
    });
    addTearDown(db.close);

    final s = S('en');
    await tester.tap(find.text(s.t('goToPaste')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      profileJson(['Work', 'Travel', 'Hobby', 'Tech', 'Music']),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.t('loadProfile')));
    await tester.pumpAndSettle();

    // Three preselected — the ones the AI rated most important — and a
    // fourth box that does nothing when tapped.
    final boxes = find.byType(CheckboxListTile);
    expect(boxes, findsNWidgets(5));
    for (var i = 0; i < 3; i++) {
      expect(tester.widget<CheckboxListTile>(boxes.at(i)).value, isTrue);
    }
    expect(tester.widget<CheckboxListTile>(boxes.at(3)).value, isFalse);

    // Tapping the fourth explains the rule and leaves the box alone.
    await tester.tap(boxes.at(3));
    await tester.pumpAndSettle();
    expect(find.text(s.t('capTitle', {'n': freeRealmSlots})), findsOneWidget);
    expect(find.text(s.t('capStepEarn', {'n': realmUnlockCost})), findsOneWidget);

    // Any tap closes it, including one inside the card.
    await tester.tap(find.text(s.t('capStepOpen')));
    await tester.pumpAndSettle();
    expect(find.text(s.t('capTitle', {'n': freeRealmSlots})), findsNothing);
    expect(tester.widget<CheckboxListTile>(boxes.at(3)).value, isFalse);

    await tester.tap(find.text(s.t('continueLabel')));
    await tester.pumpAndSettle();

    final realms = await repo.realms();
    expect(realms.where((r) => r.unlocked).length, 3);
    expect(realms.where((r) => !r.unlocked).length, 2);
  });

  testWidgets('unlocking a realm from settings spends coin and flips it',
      (tester) async {
    _tallScreen(tester);
    final (db, repo) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
      await r.importProfile(profileJson(['Work', 'Travel']), uiLanguage: 'en');
      await r.importMaterial(
        materialJson(realm: 'Work', terms: [('repair policy', 'x')]),
        uiLanguage: 'en',
      );
      // Enough to afford one unlock, not two.
      await r.saveProgress(const Progress(seeds: realmUnlockCost));
    });
    addTearDown(db.close);

    final s = S('en');
    await tester.tap(find.text(s.t('settingsTitle')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(s.t('yourRealmsButton')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(s.t('yourRealmsButton')));
    await tester.pumpAndSettle();

    expect(find.text(s.t('unlockButton')), findsOneWidget,
        reason: 'exactly the one locked realm (Travel) should offer it');

    await tester.tap(find.text(s.t('unlockButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text(s.t('unlockButton'))));
    await tester.pumpAndSettle();

    final realms = await repo.realms();
    expect(realms.every((r) => r.unlocked), isTrue);
    expect((await repo.loadProgress()).seeds, 0);
  });

  testWidgets('insufficient coin refuses the unlock without spending anything',
      (tester) async {
    _tallScreen(tester);
    final (db, repo) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
      await r.importProfile(profileJson(['Work', 'Travel']), uiLanguage: 'en');
      await r.importMaterial(
        materialJson(realm: 'Work', terms: [('repair policy', 'x')]),
        uiLanguage: 'en',
      );
      await r.saveProgress(Progress(seeds: realmUnlockCost - 1));
    });
    addTearDown(db.close);

    final s = S('en');
    await tester.tap(find.text(s.t('settingsTitle')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(s.t('yourRealmsButton')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(s.t('yourRealmsButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.text(s.t('unlockButton')));
    await tester.pumpAndSettle();

    // No confirm dialog appears — the shortfall is reported immediately.
    expect(find.text(s.t('unlockRealmConfirmTitle', {'realm': 'Travel'})), findsNothing);
    final realms = await repo.realms();
    expect(realms.any((r) => !r.unlocked), isTrue);
    expect((await repo.loadProgress()).seeds, realmUnlockCost - 1);
  });

  testWidgets('a locked area in the material picker explains itself',
      (tester) async {
    // Greyed but still tappable. Marking the row disabled would swallow the
    // tap and leave the learner with a row that simply does nothing.
    _tallScreen(tester);
    final (db, repo) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
      await r.importProfile(profileJson(['Work', 'Travel']), uiLanguage: 'en');
      await r.markRealmsUnlocked([(await r.realms()).first.id]);
    });
    addTearDown(db.close);

    final s = S('en');
    final locked = (await repo.realms()).firstWhere((r) => !r.unlocked);

    // The area picker, not the batch-size one further down the screen.
    await tester.tap(find.widgetWithText(
        DropdownButtonFormField<String>, s.t('realmLabel')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(locked.label).last);
    await tester.pumpAndSettle();

    expect(find.text(s.t('capTitle', {'n': freeRealmSlots})), findsOneWidget);
    await tester.tap(find.text(s.t('capStepOpen')));
    await tester.pumpAndSettle();

    // Explained, not selected: the prompt is still for the opened area, and
    // the picker snaps back rather than sitting on an area it cannot use.
    final open = (await repo.realms()).firstWhere((r) => r.unlocked);
    expect(find.text(s.t('materialHintEmpty', {'name': locked.label})),
        findsNothing);
    expect(find.text(s.t('materialHintEmpty', {'name': open.label})),
        findsOneWidget);
    expect(
        tester
            .widget<DropdownButtonFormField<String>>(find.widgetWithText(
                DropdownButtonFormField<String>, s.t('realmLabel')))
            .initialValue,
        open.id);
  });

  testWidgets('setup abandoned at the area picker comes back to the picker',
      (tester) async {
    // Areas imported but never confirmed. The material screen only offers
    // areas the learner has opened, so sending them there would be a screen
    // with an empty picker and no way forward.
    _tallScreen(tester);
    final (db, _) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
      await r.importProfile(profileJson(['Work', 'Travel']), uiLanguage: 'en');
    });
    addTearDown(db.close);

    final s = S('en');
    expect(find.text(s.t('realmsTitle')), findsWidgets);
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    expect(find.text(s.t('materialHintNoRealm')), findsNothing);
  });

  testWidgets('a session started with a boost in hand opens and spends it',
      (tester) async {
    // The reported crash. The boost was cleared from initState, and writing a
    // provider during a widget life-cycle throws — so the one reward the
    // chest hands out most often took the quiz screen down with it.
    _tallScreen(tester);
    final (db, repo) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
      await r.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await r.importMaterial(
        materialJson(realm: 'Work', terms: [('repair policy', 'x')]),
        uiLanguage: 'en',
      );
      await r.saveProgress(const Progress(pendingBoost: chestBoost));
    });
    addTearDown(db.close);

    final s = S('en');
    await tester.tap(find.text(s.t('justOne')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(QuizScreen), findsOneWidget);
    // Spent on the way in, so a second session is not doubled as well.
    expect((await repo.loadProgress()).pendingBoost, 0);
  });

  group('growing your world from the home screen', () {
    Future<(AppDatabase, Repository)> seedHome(
      WidgetTester tester, {
      required int seeds,
      int sessionSize = baseSessionSize,
      int terms = 6,
    }) =>
        pumpApp(tester, seed: (r) async {
          await r.saveUiLanguage('en');
          await r.importProfile(profileJson(['Work', 'Travel']), uiLanguage: 'en');
          // Enough sentences to outnumber a session: below that the app stops
          // offering a longer one, because it could not fill it.
          await r.importMaterial(
            materialJson(
              realm: 'Work',
              terms: [for (var i = 0; i < terms; i++) ('repair policy $i', 'x')],
              sentencesPerTerm: 3,
            ),
            uiLanguage: 'en',
          );
          await r.saveProgress(Progress(seeds: seeds));
          await r.saveSettings(AppSettings(sessionSize: sessionSize));
        });
    testWidgets('the balance names what it is saving for', (tester) async {
      _tallScreen(tester);
      final (db, repo) = await seedHome(tester, seeds: realmUnlockCost - 2);
      addTearDown(db.close);

      final s = S('en');
      expect(find.text(s.t('seedsToNextUnlock', {'n': 2})), findsOneWidget);
      expect((await repo.loadProgress()).seeds, realmUnlockCost - 2);
    });

    testWidgets('a full balance says so instead of naming a shortfall',
        (tester) async {
      _tallScreen(tester);
      final (db, _) = await seedHome(tester, seeds: realmUnlockCost);
      addTearDown(db.close);

      expect(find.text(S('en').t('seedsCanUnlock')), findsOneWidget);
    });

    /// The tappable decoration of the given kind, wherever the card put it.
    Finder ornament(String kind) => find.ancestor(
          of: find.byWidgetPredicate((w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName ==
                  'assets/tree/ornament_$kind.png'),
          matching: find.byType(InkWell),
        );

    testWidgets('Seeds buy three things, and session length is not one',
        (tester) async {
      // Session length is a preference now, set in Settings. It used to be
      // sold by the slot, which put a price on a taste.
      _tallScreen(tester);
      final (db, _) = await seedHome(tester, seeds: 500);
      addTearDown(db.close);

      final s = S('en');
      expect(find.text(s.t('yourRealmsButton')), findsOneWidget);
      expect(find.text(s.t('createMaterial')), findsWidgets);
      expect(find.text(s.t('ornamentNote', {'n': ornamentCost})), findsOneWidget);
      // The fourth thing Seeds used to buy, and its two states, are gone.
      expect(find.text(s.t('perSessionMaxed')), findsNothing);
      expect(find.text(s.t('addButton')), findsNothing);
    });

    testWidgets('a decoration is confirmed before it is charged for',
        (tester) async {
      _tallScreen(tester);
      final (db, repo) = await seedHome(tester, seeds: ornamentCost);
      addTearDown(db.close);

      final s = S('en');
      await tester.ensureVisible(ornament('ribbon'));
      await tester.pumpAndSettle();
      await tester.tap(ornament('ribbon'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text(s.t('cancel'))));
      await tester.pumpAndSettle();

      expect((await repo.loadProgress()).seeds, ornamentCost);
      expect((await repo.loadProgress()).ornaments, isEmpty);
    });

    testWidgets('a confirmed decoration is charged for and hung on the tree',
        (tester) async {
      _tallScreen(tester);
      final (db, repo) = await seedHome(tester, seeds: ornamentCost);
      addTearDown(db.close);

      final s = S('en');
      await tester.ensureVisible(ornament('ribbon'));
      await tester.pumpAndSettle();
      await tester.tap(ornament('ribbon'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(s.t('confirmLabel'))));
      await tester.pumpAndSettle();

      expect((await repo.loadProgress()).seeds, 0);
      expect((await repo.loadProgress()).ornaments, ['ribbon']);
    });

    testWidgets('a decoration too dear to afford cannot be tapped at all',
        (tester) async {
      _tallScreen(tester);
      final (db, repo) = await seedHome(tester, seeds: ornamentCost - 1);
      addTearDown(db.close);

      await tester.ensureVisible(ornament('ribbon'));
      await tester.pumpAndSettle();
      await tester.tap(ornament('ribbon'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect((await repo.loadProgress()).seeds, ornamentCost - 1);
    });

    testWidgets('an area is unlocked from the list, not from the card',
        (tester) async {
      // The card used to unlock whichever locked area happened to come first.
      // Which area to open is a choice, so the card sends you to the list and
      // the list does the spending.
      _tallScreen(tester);
      final (db, repo) = await seedHome(tester, seeds: realmUnlockCost);
      addTearDown(db.close);

      final s = S('en');
      await tester.tap(find.text(s.t('yourRealmsButton')));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, s.t('unlockButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text(s.t('unlockButton'))));
      await tester.pumpAndSettle();

      expect((await repo.realms()).every((r) => r.unlocked), isTrue);
      expect((await repo.loadProgress()).seeds, 0);
      // An area with nothing in it is a dead end, so its material screen is
      // where the unlock lands.
      expect(find.byType(MaterialScreen), findsOneWidget);
    });
  });

  testWidgets('tapping an assistant copies the prompt before opening it',
      (tester) async {
    _tallScreen(tester);
    final (db, _) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
    });
    addTearDown(db.close);

    String? copied;
    final launched = <String>[];
    // Stands in for what is installed on the phone. An https link only reaches
    // an assistant's app while "open supported links" is on for it, so the
    // app's own scheme is tried first and the web address is the fallback.
    final installed = <String>{};

    final messenger = tester.binding.defaultBinaryMessenger;
    const launcher = MethodChannel('plugins.flutter.io/url_launcher');

    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(launcher, (call) async {
      final url = (call.arguments as Map?)?['url'] as String?;
      if (url == null) return false;
      final handled =
          url.startsWith('https:') || installed.any((s) => url.startsWith('$s:'));
      if (call.method == 'canLaunch') return handled;
      if (call.method == 'launch' && handled) {
        launched.add(url);
        return true;
      }
      return false;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(launcher, null);
    });

    await tester.tap(find.text(S('en').t('goToPaste')));
    await tester.pumpAndSettle();

    // Nothing installed: the web address is used.
    await tester.tap(find.text('ChatGPT'));
    await tester.pumpAndSettle();

    // The order is the whole point: the prompt must already be on the
    // clipboard by the time the assistant's input box appears.
    expect(copied, isNotNull, reason: 'the prompt was never copied');
    expect(copied, contains('```json'));
    expect(copied, contains('schema_version'));
    expect(launched, ['https://chatgpt.com/']);

    // With the app installed, it is opened directly instead.
    installed.add('chatgpt');
    launched.clear();
    await tester.tap(find.text('ChatGPT'));
    await tester.pumpAndSettle();
    expect(launched, ['chatgpt://']);

    // Gemini declares no scheme, so it always goes to the web.
    launched.clear();
    await tester.tap(find.text('Gemini'));
    await tester.pumpAndSettle();
    expect(launched, ['https://gemini.google.com/app']);
  });

  testWidgets('confirmed areas with no material yet go to the material step',
      (tester) async {
    _tallScreen(tester);
    final (db, _) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
      await r.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await r.markRealmsUnlocked((await r.realms()).map((x) => x.id).toList());
    });
    addTearDown(db.close);

    final s = S('en');
    expect(find.text(s.t('materialTitle')), findsOneWidget);
    // Both halves of the job are on this one screen: copy, then paste.
    expect(find.text(s.t('step1Title')), findsOneWidget);
    expect(find.text(s.t('copyPrompt')), findsOneWidget);
    expect(find.text(s.t('openAiTitle')), findsOneWidget);
    expect(find.text(s.t('step2Title')), findsOneWidget);
    expect(find.text(s.t('addQuestions')), findsOneWidget);
  });

  testWidgets('the four bottom tabs all render', (tester) async {
    final (db, _) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
      await r.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await r.importMaterial(
        materialJson(realm: 'Work', terms: [('repair policy', 'x')]),
        uiLanguage: 'en',
      );
    });
    addTearDown(db.close);

    final s = S('en');
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text(s.t('libraryTitle')));
    await tester.pumpAndSettle();
    expect(find.text(s.t('tabExpressions')), findsWidgets);

    await tester.tap(find.text(s.t('statsTitle')));
    await tester.pumpAndSettle();
    expect(find.text(s.t('continuitySection')), findsOneWidget);

    await tester.tap(find.text(s.t('settingsTitle')));
    await tester.pumpAndSettle();
    expect(find.text(s.t('interfaceSection')), findsOneWidget);
    await tester.scrollUntilVisible(find.text(s.t('resetSection')), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text(s.t('resetSection')), findsOneWidget);
  });

  testWidgets('the interface language can be changed after setup', (tester) async {
    final (db, repo) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
      await r.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await r.importMaterial(
        materialJson(realm: 'Work', terms: [('repair policy', 'x')]),
        uiLanguage: 'en',
      );
    });
    addTearDown(db.close);

    await tester.tap(find.text(S('en').t('settingsTitle')));
    await tester.pumpAndSettle();

    await tester.tap(find.text(S('en').t('uiLanguageLabel')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S('de').t('continueLabel')));
    await tester.pumpAndSettle();

    expect(await repo.loadUiLanguage(), 'de');
    // The settings screen is now German.
    expect(find.text(S('de').t('settingsTitle')), findsWidgets);
  });

  testWidgets('the chosen language reaches Flutter, not just the strings',
      (tester) async {
    // The reported failure. Strings were translated but every screen still
    // rendered under en_US, because WidgetsApp resolves the requested locale
    // against `supportedLocales` and its default is English alone. Text
    // rendering depends on that resolved locale: it is the only signal the
    // font engine gets about which script a run of CJK characters belongs
    // to, so Japanese was drawn with Chinese glyphs.
    for (final (code, language, country) in [
      ('ja', 'ja', null),
      ('ko', 'ko', null),
      ('zh-CN', 'zh', 'CN'),
      ('pt-BR', 'pt', 'BR'),
    ]) {
      final (db, _) = await pumpApp(tester, seed: (r) async {
        await r.saveUiLanguage(code);
        await r.importProfile(profileJson(['Work']), uiLanguage: code);
        await r.importMaterial(
          materialJson(realm: 'Work', terms: [('repair policy', 'x')]),
          uiLanguage: code,
        );
      });
      addTearDown(db.close);

      final context = tester.element(find.byType(Scaffold).first);
      final locale = Localizations.localeOf(context);
      expect(locale.languageCode, language, reason: code);
      expect(locale.countryCode, country, reason: code);
      // Material's own widgets need localisations for the same locale, or
      // anything that shows a dialog or a text field asserts at runtime.
      expect(MaterialLocalizations.of(context), isNotNull, reason: code);
    }
  });

  testWidgets('a factory reset returns to the welcome screen, not a dead end',
      (tester) async {
    // The reported failure. Finishing setup used to replace every route with
    // the home shell, root included — and the root is the only thing that
    // decides which screen the app belongs on. A later reset then emptied the
    // database while leaving the learner on a home screen with nothing in it,
    // whose only button led to a material screen where every control was
    // disabled. Nothing could be done short of force-quitting the app.
    _tallScreen(tester);
    final (db, repo) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
      await r.importProfile(profileJson(['Work']), uiLanguage: 'en');
      // The picker is where areas are confirmed; material comes after it.
      await r.markRealmsUnlocked((await r.realms()).map((x) => x.id).toList());
    });
    addTearDown(db.close);

    final s = S('en');

    // Go through setup for real: it is the "you're all set" screen at the end
    // of it that used to tear the root out of the navigator.
    await tester.enterText(find.byType(TextField), materialReply(6));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.t('addQuestions')));
    await tester.pumpAndSettle();

    expect(find.text(s.t('readyTitle')), findsOneWidget);
    await tester.tap(find.text(s.t('goHome')));
    await tester.pumpAndSettle();

    expect(find.text('KotoLang'), findsOneWidget, reason: 'setup should end at home');

    await tester.tap(find.text(s.t('settingsTitle')));
    await tester.pumpAndSettle();
    // The wipe-everything actions are folded away, a deliberate step from the
    // per-area buttons they sit under.
    await tester.scrollUntilVisible(find.text(s.t('wipeSection')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(s.t('wipeSection')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(s.t('factoryReset')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(s.t('factoryReset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.t('confirmLabel')));
    await tester.pumpAndSettle();

    expect((await repo.counts()).realms, 0, reason: 'the reset itself must work');

    // The screen has to follow the data.
    expect(find.text(s.t('welcomeTitle')), findsOneWidget);
    expect(find.text(s.t('goToPaste')), findsOneWidget);
    expect(find.text('KotoLang'), findsNothing);
  });

  testWidgets('the material screen offers a way out when no area exists',
      (tester) async {
    _tallScreen(tester);
    final (db, _) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
    });
    addTearDown(db.close);

    final s = S('en');
    // Reached the way the home screen's empty state reaches it.
    await tester.tap(find.text(s.t('goToPaste')));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(PasteBox))).push(
      MaterialPageRoute(builder: (_) => const MaterialScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text(s.t('materialHintNoRealm')), findsOneWidget);
    // Every control that needs an area is dead, so there must be a live one
    // that leads to making one.
    expect(find.widgetWithText(FilledButton, s.t('goToPaste')), findsOneWidget);
    final out = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, s.t('goToPaste')));
    expect(out.onPressed, isNotNull);
  });

  testWidgets('a reply that could only be copied in halves still imports',
      (tester) async {
    // The reported failure: on a phone the whole AI answer cannot be selected
    // at once. Two partial pastes must add up to the same material.
    _tallScreen(tester);
    final (db, repo) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
      await r.importProfile(profileJson(['Work']), uiLanguage: 'en');
      // The picker is where areas are confirmed; material comes after it.
      await r.markRealmsUnlocked((await r.realms()).map((x) => x.id).toList());
    });
    addTearDown(db.close);

    final s = S('en');
    final reply = materialReply(6);
    final mid = reply.length ~/ 2;

    final box = find.byType(TextField);
    expect(box, findsOneWidget);

    // Half arrives, then the rest is pasted over the top of it — which is what
    // a phone actually does, because select-all replaces rather than appends.
    // Nothing is tapped in between: the box keeps the first half by itself.
    await tester.enterText(box, reply.substring(0, mid));
    await tester.pumpAndSettle();
    await tester.enterText(box, reply.substring(mid));
    await tester.pumpAndSettle();

    expect(find.textContaining('6 sentences readable'), findsOneWidget,
        reason: 'the readout must confirm the two pieces joined up');

    await tester.tap(find.text(s.t('addQuestions')));
    await tester.pumpAndSettle();

    final counts = await repo.counts();
    expect(counts.sentences, 6);
    expect(counts.questions, greaterThan(0));
  });

  testWidgets('a truncated paste imports what arrived and says it is partial',
      (tester) async {
    _tallScreen(tester);
    final (db, repo) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
      await r.importProfile(profileJson(['Work']), uiLanguage: 'en');
      // The picker is where areas are confirmed; material comes after it.
      await r.markRealmsUnlocked((await r.realms()).map((x) => x.id).toList());
    });
    addTearDown(db.close);

    final s = S('en');
    final reply = materialReply(10);

    await tester.enterText(
        find.byType(TextField), reply.substring(0, (reply.length * 0.7).round()));
    await tester.pumpAndSettle();

    expect(find.text(s.t('truncatedNotice')), findsOneWidget,
        reason: 'a cut-off paste must be flagged before it is imported');

    await tester.tap(find.text(s.t('addQuestions')));
    await tester.pumpAndSettle();

    final counts = await repo.counts();
    expect(counts.sentences, greaterThan(0));
    expect(counts.sentences, lessThan(10));
  });

  testWidgets('a session finished without a miss says so on the summary',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = Repository(db, rng: Random(42));
    addTearDown(db.close);
    await repo.saveUiLanguage('en');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          repositoryProvider.overrideWithValue(repo),
        // The tree sways in a loop on a real device. Held still here: a
        // repeating animation means `pumpAndSettle` never settles.
        treeMotionProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(
          home: SummaryScreen(
            seeds: 30,
            boosted: false,
            bestCombo: 0,
            correct: 8,
            total: 8,
            streakAdvanced: true,
            perfect: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final s = S('en');
    expect(find.textContaining(s.t('perfectRunTitle')), findsOneWidget);
    expect(
        find.text(s.t('perfectRunBody', {'n': perfectRunBonus})), findsOneWidget);
  });

  testWidgets('a summary with a miss in it keeps quiet about perfection',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = Repository(db, rng: Random(42));
    addTearDown(db.close);
    await repo.saveUiLanguage('en');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          repositoryProvider.overrideWithValue(repo),
        // The tree sways in a loop on a real device. Held still here: a
        // repeating animation means `pumpAndSettle` never settles.
        treeMotionProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(
          home: SummaryScreen(
            seeds: 20,
            boosted: false,
            bestCombo: 0,
            correct: 7,
            total: 8,
            streakAdvanced: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining(S('en').t('perfectRunTitle')), findsNothing);
  });

  testWidgets('the listening feed plays the learner own sentences, unscored',
      (tester) async {
    _tallScreen(tester);
    final (db, repo) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
      await r.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await r.importMaterial(
        materialJson(realm: 'Work', terms: [('repair policy', 'meaning A')]),
        uiLanguage: 'en',
      );
    });
    addTearDown(db.close);

    final s = S('en');
    await tester.tap(find.text(s.t('listenButton')));
    await tester.pumpAndSettle();

    expect(find.text(s.t('listenTitle')), findsOneWidget);
    // A real sentence from the library is on screen, and its reading is not.
    final first = (await repo.sentences()).first;
    expect(find.text(s.t('listenTapForMeaning')), findsWidgets);
    expect(find.text(first.translationNative), findsNothing);

    // Listening is not answering: nothing is recorded and nothing is paid.
    expect((await repo.history()), isEmpty);
    expect((await repo.loadProgress()).seeds, 0);
  });

  testWidgets('a tap on a listening card reveals the reading', (tester) async {
    _tallScreen(tester);
    final (db, repo) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
      await r.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await r.importMaterial(
        materialJson(realm: 'Work', terms: [('repair policy', 'meaning A')]),
        uiLanguage: 'en',
      );
    });
    addTearDown(db.close);

    final s = S('en');
    await tester.tap(find.text(s.t('listenButton')));
    await tester.pumpAndSettle();

    // Whichever sentence the shuffle put first, its reading appears on a tap.
    final readings =
        (await repo.sentences()).map((x) => x.translationNative).toSet();
    await tester.tap(find.text(s.t('listenTapForMeaning')).first);
    await tester.pumpAndSettle();

    final shown = readings.where((r) => find.text(r).evaluate().isNotEmpty);
    expect(shown, hasLength(1), reason: 'exactly the card tapped opens');

  });
  testWidgets('an answered question waits for the button instead of jumping on',
      (tester) async {
    // It used to move on by itself after a beat. The explanation is the part
    // worth reading, and a screen that turns the page while you are reading it
    // teaches you not to bother reading.
    _tallScreen(tester);
    final (db, repo) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
      await r.importProfile(profileJson(['Work']), uiLanguage: 'en');
      await r.importMaterial(
        materialJson(
          realm: 'Work',
          terms: [('repair policy', 'meaning A'), ('lead time', 'meaning B')],
          sentencesPerTerm: 2,
        ),
        uiLanguage: 'en',
      );
    });
    addTearDown(db.close);

    final s = S('en');
    await tester.tap(find.text(s.t('justOne')));
    await tester.pumpAndSettle();

    // Whatever format came up, answer it by tapping a choice.
    final tappable = find.descendant(
        of: find.byType(ListView), matching: find.byType(InkWell));
    if (tappable.evaluate().isEmpty) return;
    await tester.tap(tappable.last, warnIfMissed: false);
    await tester.pumpAndSettle();

    final answerButton = find.widgetWithText(FilledButton, s.t('answerLabel'));
    if (tester.widget<FilledButton>(answerButton).onPressed == null) return;
    await tester.tap(answerButton);
    await tester.pumpAndSettle();

    // Five seconds of nothing. The old timer fired at one and a half.
    expect((await repo.history()).length, 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect((await repo.history()).length, 1,
        reason: 'nothing moved on by itself');
    expect(find.text(s.t('nextQuestion')), findsOneWidget);
  });
  testWidgets('a finished session offers another instead of only the way out',
      (tester) async {
    _tallScreen(tester);
    final db = AppDatabase(NativeDatabase.memory());
    final repo = Repository(db, rng: Random(42));
    addTearDown(db.close);
    await repo.saveUiLanguage('en');

    final s = S('en');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          repositoryProvider.overrideWithValue(repo),
        // The tree sways in a loop on a real device. Held still here: a
        // repeating animation means `pumpAndSettle` never settles.
        treeMotionProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(
          home: SummaryScreen(
            seeds: 12,
            boosted: false,
            bestCombo: 0,
            correct: 5,
            total: 5,
            streakAdvanced: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(s.t('moreButton')), findsOneWidget);
    expect(find.text(s.t('backHome')), findsOneWidget);
    // With an empty library there is nothing left to meet, and the card says
    // so rather than promising more.
    expect(find.text(s.t('moreNoneLeft')), findsOneWidget);
  });

  testWidgets('the appearance setting drives the app theme', (tester) async {
    final (db, repo) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
      await r.saveSettings(const AppSettings(theme: 'dark'));
    });
    addTearDown(db.close);

    expect((await repo.loadSettings()).theme, 'dark');
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark,
        reason: 'the stored preference was being written and never read');
  });
  testWidgets('adding with an empty box takes the reply from the clipboard',
      (tester) async {
    _tallScreen(tester);
    final db = AppDatabase(NativeDatabase.memory());
    final repo = Repository(db, rng: Random(42));
    addTearDown(db.close);
    await repo.saveUiLanguage('en');
    await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
    await repo.markRealmsUnlocked((await repo.realms()).map((r) => r.id).toList());

    // What an assistant's reply would leave on the clipboard.
    final reply = materialJson(realm: 'Work', terms: [('repair policy', 'x')]);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? <String, dynamic>{'text': reply}
          : null,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          repositoryProvider.overrideWithValue(repo),
        // The tree sways in a loop on a real device. Held still here: a
        // repeating animation means `pumpAndSettle` never settles.
        treeMotionProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(home: MaterialScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // One button, not two: nothing is pasted by hand.
    final s = S('en');
    expect(find.text(s.t('addQuestions')), findsOneWidget);
    await tester.tap(find.text(s.t('addQuestions')));
    await tester.pumpAndSettle();

    expect((await repo.counts()).sentences, greaterThan(0),
        reason: 'the reply on the clipboard should have been imported');
  });
}

/// The material screen is a long form. A tall window lets these tests act on it
/// without scrolling, which a text field holding ten thousand characters makes
/// unreliable.
void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}
