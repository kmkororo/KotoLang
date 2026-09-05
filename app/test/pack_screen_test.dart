/// The pack screen: what is written down rides into the prompt, the tally
/// above the box advances one tree per paste, the critique-only trip is
/// offered only when a reply is waiting, and a critique that came back is
/// shown under the reply it was about.
library;

import 'dart:convert';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kotolang/app.dart';
import 'package:kotolang/core/l10n/strings.dart';
import 'package:kotolang/data/database.dart';
import 'package:kotolang/data/repository.dart';
import 'package:kotolang/domain/debate.dart';
import 'package:kotolang/features/pack_screen.dart';
import 'package:kotolang/features/tree_view.dart';

import 'pack_test.dart' show chunks, debate, pack;
import 'repository_test.dart' show profileJson;

Future<(AppDatabase, Repository)> pumpPack(
  WidgetTester tester, {
  String? initialText,
  Future<void> Function(Repository repo)? seed,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final repo = Repository(db, rng: Random(42));
  await repo.saveUiLanguage('en');
  await repo.importProfile(profileJson(['Work']), uiLanguage: 'en');
  if (seed != null) await seed(repo);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        treeMotionProvider.overrideWithValue(false),
      ],
      child: MaterialApp(home: PackScreen(initialText: initialText)),
    ),
  );
  await tester.pumpAndSettle();
  return (db, repo);
}

/// Records what the screen puts on the clipboard.
String? watchClipboard(WidgetTester tester) {
  String? copied;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
        _lastCopied = copied;
      }
      return null;
    },
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return copied;
}

String? _lastCopied;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _lastCopied = null;
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..physicalSize = const Size(800, 3200)
      ..devicePixelRatio = 1;
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  testWidgets('the tally advances one tree per paste', (tester) async {
    final (db, repo) = await pumpPack(tester,
        initialText: pack(chunksList: chunks(), debates: [debate()]));
    addTearDown(db.close);
    final s = S('en');

    expect(find.text(s.t('packProgress', {'n': 0, 'target': packTrees, 'm': 0})),
        findsOneWidget);
    expect(find.text(s.t('packChunksNeed')), findsOneWidget);

    await tester.tap(find.text(s.t('packTakeIn')));
    await tester.pumpAndSettle();

    expect(find.text(s.t('packImported', {'n': 1})), findsOneWidget);
    expect(find.text(s.t('packProgress', {'n': 1, 'target': packTrees, 'm': 0})),
        findsOneWidget);
    expect(find.text(s.t('packProgressNext')), findsOneWidget);
    expect(find.text(s.t('packChunksHave')), findsOneWidget);
    expect(await repo.debates(), hasLength(1));
  });

  testWidgets('what is written down rides into the prompt', (tester) async {
    final (db, repo) = await pumpPack(tester);
    addTearDown(db.close);
    watchClipboard(tester);
    final s = S('en');

    expect(find.text(s.t('captureEmpty')), findsOneWidget);
    await tester.tap(find.text(s.t('captureAdd')));
    await tester.pumpAndSettle();

    final fields = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(fields.at(0), 'Thursday review: the handover date');
    await tester.enterText(fields.at(1), 'Mika');
    await tester.tap(find.text(s.t('captureSave')));
    await tester.pumpAndSettle();

    expect(find.text('Thursday review: the handover date'), findsOneWidget);
    expect(find.text(s.t('packEvents', {'n': 1})), findsOneWidget);
    expect(await repo.captures(pendingOnly: true), hasLength(1));

    await tester.tap(find.text(s.t('copyPrompt')));
    await tester.pumpAndSettle();
    expect(_lastCopied, contains('Thursday review: the handover date'));
    expect(_lastCopied, contains('Mika'));

    // And it can be taken back.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text(s.t('captureEmpty')), findsOneWidget);
    expect(await repo.captures(pendingOnly: true), isEmpty);
  });

  testWidgets('critique only, now — not offered while nothing is waiting', (tester) async {
    final (db, _) = await pumpPack(tester, seed: (r) async {
      await r.importPack(pack(chunksList: chunks(), debates: [debate()]), uiLanguage: 'en');
    });
    addTearDown(db.close);
    final s = S('en');

    final button = find.widgetWithText(OutlinedButton, s.t('critiqueNow'));
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    expect(find.text(s.t('packAwaiting', {'n': 0})), findsOneWidget);
  });

  testWidgets('critique only, now — copies a prompt carrying the waiting reply',
      (tester) async {
    final (db, _) = await pumpPack(tester, seed: (r) async {
      await r.importPack(pack(chunksList: chunks(), debates: [debate()]), uiLanguage: 'en');
      final t = (await r.debates()).single;
      await r.recordAttempt(
          tree: t, node: t.root, youSaid: 'My waiting reply', moves: [Move.however]);
    });
    addTearDown(db.close);
    watchClipboard(tester);
    final s = S('en');

    expect(find.text(s.t('packAwaiting', {'n': 1})), findsOneWidget);
    final live = find.widgetWithText(OutlinedButton, s.t('critiqueNow'));
    expect(tester.widget<OutlinedButton>(live).onPressed, isNotNull);
    await tester.tap(live);
    await tester.pumpAndSettle();
    expect(find.text(s.t('critiqueNowCopied')), findsOneWidget);
    expect(_lastCopied, contains('My waiting reply'));
  });

  testWidgets('a critique that came back is shown under the reply it was about',
      (tester) async {
    final (db, _) = await pumpPack(tester, seed: (r) async {
      await r.importPack(pack(chunksList: chunks(), debates: [debate()]), uiLanguage: 'en');
      final t = (await r.debates()).single;
      final a = await r.recordAttempt(
          tree: t, node: t.root, youSaid: 'However, we can do it.', moves: [Move.however]);
      final critiques = jsonEncode({
        'schema_version': '2.0',
        'type': 'pack',
        'debates': [],
        'critiques': [
          {
            'attempt': a.id,
            'verdict_native': '反論はしたが、根拠がない。',
            'better': ['I take your point, but last quarter says otherwise.'],
            'watch_native': '「しかし」の後に数字を。',
          }
        ],
      });
      final out = await r.importPack(critiques, uiLanguage: 'en');
      expect(out.critiques, 1);
    });
    addTearDown(db.close);
    final s = S('en');

    expect(find.text(s.t('critiquesEmpty')), findsNothing);
    expect(find.text('However, we can do it.'), findsOneWidget);
    expect(find.text('反論はしたが、根拠がない。'), findsOneWidget);
    expect(find.textContaining('last quarter says otherwise'), findsOneWidget);
    expect(find.text('「しかし」の後に数字を。'), findsOneWidget);
    // Answered, so no longer counted as waiting.
    expect(find.text(s.t('packAwaiting', {'n': 0})), findsOneWidget);
  });
}
