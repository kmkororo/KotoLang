/// The train mode, driven by touch against a real in-memory database: home
/// offers the way in once a pack has arrived, an exchange runs hear → grasp
/// → reply → compare → branch, and what the learner said is kept for the
/// critique.
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
import 'package:kotolang/domain/debate.dart';
import 'package:kotolang/features/onboarding_screens.dart';
import 'package:kotolang/features/tree_view.dart';

import 'app_flow_test.dart' show pumpApp;
import 'pack_test.dart' show chunks, debate, pack;
import 'repository_test.dart' show materialJson, profileJson;

Future<void> seedLearner(Repository repo, {bool withPack = true}) async {
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
  if (withPack) {
    await repo.importPack(pack(chunksList: chunks(), debates: [debate()]), uiLanguage: 'en');
  }
}

/// Walks the grasp step with every answer right and lands on the reply step.
Future<void> graspAll(WidgetTester tester, S s, String nodeId) async {
  await tester.tap(find.text(s.t('debateGraspTitle')).last);
  await tester.pumpAndSettle();
  for (final answer in ['$nodeId の主張', '$nodeId の根拠', '$nodeId を確認せずに言っている']) {
    await tester.tap(find.text(answer));
    await tester.pumpAndSettle();
  }
  expect(find.text(s.t('debateGraspScore', {'n': 3})), findsOneWidget);
  await tester.tap(find.text(s.t('debateGraspNext')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Tall enough that every step fits without scrolling; the screens are
    // lists, and the test is about the flow rather than the scroll.
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..physicalSize = const Size(800, 2600)
      ..devicePixelRatio = 1;
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  testWidgets('home offers the argument only once an opponent has arrived',
      (tester) async {
    final (db, _) = await pumpApp(tester, seed: (r) => seedLearner(r, withPack: false));
    addTearDown(db.close);
    final s = S('en');
    expect(find.text(s.t('startLearning')), findsOneWidget);
    expect(find.text(s.t('debateButton')), findsNothing);
  });

  testWidgets('one exchange: hear, grasp, build a reply, see the models, branch',
      (tester) async {
    final (db, repo) = await pumpApp(tester, seed: seedLearner);
    addTearDown(db.close);
    final s = S('en');

    await tester.tap(find.text(s.t('debateButton')));
    await tester.pumpAndSettle();

    // No voice in a test, so the line is shown rather than hidden.
    expect(find.text(s.t('debateListenTitle')), findsOneWidget);
    expect(find.textContaining('Line n1:'), findsOneWidget);

    await graspAll(tester, s, 'n1');
    expect(find.text(s.t('debateAssembleTitle')), findsOneWidget);

    // Two pieces from the shelf, in order; the slot they share gets a tap.
    await tester.tap(find.text('I take your point on {x}, but'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('the numbers from {x} say otherwise:').last);
    await tester.pumpAndSettle();
    expect(find.text(s.t('debateSlotLabel', {'slot': 'x'})), findsOneWidget);
    await tester.tap(find.text('headcount'));
    await tester.pumpAndSettle();
    expect(
        find.text('I take your point on headcount, but the numbers from headcount say otherwise:'),
        findsOneWidget);

    // The pieces brought concede and evidence; "however" is declared by hand.
    await tester.tap(find.text(s.t('moveHowever')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.t('debateSend')));
    await tester.pumpAndSettle();

    // Nearest to the strong model, with nothing missing from its shape.
    expect(find.text(s.t('debateCompareTitle')), findsOneWidget);
    expect(find.text(s.t('debateClosest')), findsOneWidget);
    expect(find.text(s.t('debateStructureOk')), findsOneWidget);

    final attempts = await repo.attempts();
    expect(attempts, hasLength(1));
    expect(attempts.single.closest, 'r1a');
    expect(attempts.single.closestStrength, Strength.strong);
    expect(attempts.single.moves, [Move.concede, Move.however, Move.evidence]);
    expect(await repo.failures(), isEmpty);
    expect((await repo.loadProgress()).seeds, greaterThan(0));

    // The strong reply has a next line: the opponent answers.
    await tester.tap(find.text(s.t('debateContinue')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Line n2a:'), findsOneWidget);
  });

  testWidgets('conceding ends the argument and writes down what was missing',
      (tester) async {
    final (db, repo) = await pumpApp(tester, seed: seedLearner);
    addTearDown(db.close);
    final s = S('en');

    await tester.tap(find.text(s.t('debateButton')));
    await tester.pumpAndSettle();
    await graspAll(tester, s, 'n1');

    await tester.tap(find.text('I take your point on {x}, but'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.t('moveClose')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.t('debateSend')));
    await tester.pumpAndSettle();

    expect(find.text(s.t('debateStructureMissing',
            {'moves': '${s.t('moveHowever')}, ${s.t('moveEvidence')}'})),
        findsOneWidget);
    await tester.tap(find.text(s.t('debateFinish')));
    await tester.pumpAndSettle();
    expect(find.text(s.t('debateOutcomeConceded')), findsOneWidget);

    final kinds = (await repo.failures()).map((f) => f.kind).toSet();
    expect(kinds, {'missing_move:however', 'missing_move:evidence'});

    // Back home, the way in is still there for the next time.
    await tester.tap(find.text(s.t('debateDone')));
    await tester.pumpAndSettle();
    expect(find.text(s.t('debateButton')), findsOneWidget);
  });

  packViaMaterialBox();
  testWidgets('leaving mid-argument asks first and keeps what was said', (tester) async {
    final (db, repo) = await pumpApp(tester, seed: seedLearner);
    addTearDown(db.close);
    final s = S('en');

    await tester.tap(find.text(s.t('debateButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text(s.t('debateQuitBody')), findsOneWidget);
    await tester.tap(find.text(s.t('cancel')));
    await tester.pumpAndSettle();
    expect(find.text(s.t('debateListenTitle')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.t('quitConfirm')));
    await tester.pumpAndSettle();
    expect(find.text(s.t('startLearning')), findsOneWidget);
    expect(await repo.attempts(), isEmpty);
  });
}

// A pack shared into the material box is taken in as a pack: no Seeds
// charged, no realm asked for, and the opponent is there afterwards.
void packViaMaterialBox() {
  testWidgets('a pack pasted into the material box becomes an opponent, free of charge',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = Repository(db, rng: Random(42));
    addTearDown(db.close);
    await repo.saveUiLanguage('en');
    await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
    final before = (await repo.loadProgress()).seeds;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          repositoryProvider.overrideWithValue(repo),
          treeMotionProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          home: MaterialScreen(
              initialText: pack(chunksList: chunks(), debates: [debate()])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final s = S('en');
    await tester.tap(find.text(s.t('addQuestions')));
    await tester.pumpAndSettle();

    expect(find.text(s.t('packImported', {'n': 1})), findsOneWidget);
    expect(await repo.debates(), hasLength(1));
    expect(await repo.chunks(), hasLength(2));
    expect((await repo.loadProgress()).seeds, before);
  });
}
