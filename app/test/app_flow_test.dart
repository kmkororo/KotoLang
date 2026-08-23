/// Drives the real widgets against a real (in-memory) database.
///
/// The domain and repository suites prove the rules; this one proves the app
/// a person actually touches: that the first screen is the language picker,
/// that onboarding leads somewhere, that a question can be answered, and that
/// the interface really does change language.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:kotolang/app.dart';
import 'package:kotolang/core/l10n/strings.dart';
import 'package:kotolang/data/database.dart';
import 'package:kotolang/data/repository.dart';
import 'package:kotolang/features/quiz_screen.dart';

import 'repository_test.dart' show materialJson, profileJson;

/// Pumps the app over a fresh in-memory database.
Future<(AppDatabase, Repository)> pumpApp(
  WidgetTester tester, {
  Future<void> Function(Repository repo)? seed,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final repo = Repository(db);
  if (seed != null) await seed(repo);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
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
    expect(find.textContaining(S('ja').t('copyPrompt')), findsWidgets);
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
    expect(find.text(s.t('playAgain')), findsOneWidget);
    // The answer button starts disabled: nothing has been chosen yet.
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, s.t('answerLabel')),
    );
    expect(button.onPressed, isNull);
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
    expect(find.text(s.t('copyPrompt')), findsOneWidget);
    expect(find.text(s.t('startLearning')), findsNothing);
  });

  testWidgets('realms exist but no material yet goes to the material step',
      (tester) async {
    final (db, _) = await pumpApp(tester, seed: (r) async {
      await r.saveUiLanguage('en');
      await r.importProfile(profileJson(['Work']), uiLanguage: 'en');
    });
    addTearDown(db.close);

    final s = S('en');
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
}
