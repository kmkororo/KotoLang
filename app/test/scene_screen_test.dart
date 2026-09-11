/// The conversation screen, on the real widgets.
///
/// The point of this screen is that a conversation reads as one conversation:
/// each turn answered stays above the next, so the line being heard answers
/// something the learner themselves said. These check that what is kept above
/// is true — the words actually said, the reply actually chosen, and the one
/// that would have fitted.
///
/// There is no voice on the host, so these run the same way the screen runs
/// on a phone with no English voice installed: the line is shown rather than
/// said, and the window opens as soon as the button is pressed. That the line
/// stays hidden when there *is* a voice is a thing only a device can answer,
/// and `integration_test/device_test.dart` answers it.
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
import 'package:kotolang/domain/scene.dart';
import 'package:kotolang/features/scene_screen.dart';

import 'fixtures.dart' show pack, scene, turn;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final en = S('en');
  final ja = S('ja');

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// A turn whose replies say which turn they belong to, so a reply kept in
  /// the conversation above cannot be confused with one still on offer below.
  Map<String, dynamic> numbered(int n) => turn(
        line: 'Line number $n.',
        replies: [
          {'text': 'Right answer to $n.', 'correct': true},
          {'text': 'Wrong answer to $n.', 'correct': false},
          {'text': 'Other answer to $n.', 'correct': false},
        ],
        natives: ['$n への正解。', '$n への誤答。', '$n への別の答え。'],
      );

  Future<(Repository, Scene)> open(WidgetTester tester, {int turns = 2}) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = Repository(db, rng: Random(7));
    addTearDown(db.close);
    await repo.saveUiLanguage('ja');
    await repo.importScenes(
        pack([
          scene('Moving a deadline',
              turns: [for (var i = 0; i < turns; i++) numbered(i)])
        ]),
        uiLanguage: 'ja',
        field: 'work');
    final s = (await repo.scenes()).single;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          repositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(home: SceneScreen(scene: s)),
      ),
    );
    await tester.pump();
    return (repo, s);
  }

  /// Presses the button, then takes the reply at [i] while the window is open.
  Future<void> answer(WidgetTester tester, Turn t, int i) async {
    await tester.tap(find.text(en.t('scenePlay')));
    await tester.pump();
    await tester.tap(find.text(t.replies[i].text));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Taps the verdict, which moves on rather than waiting out the beat.
  Future<void> moveOn(WidgetTester tester, {bool right = true}) async {
    await tester.tap(find.text(en.t(right ? 'sceneCorrect' : 'sceneWrong')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the replies are readable before anything has been answered',
      (tester) async {
    tall(tester);
    final (_, s) = await open(tester, turns: 1);

    for (final r in s.turns.first.replies) {
      expect(find.text(r.text), findsOneWidget);
    }
    expect(find.text(s.settingNative), findsOneWidget,
        reason: 'the setting says where this is before a word is said');
  });

  testWidgets('the turn answered stays above the next one', (tester) async {
    tall(tester);
    final (_, s) = await open(tester);
    final first = s.turns[0];

    await answer(tester, first, first.answer);
    await moveOn(tester);

    // Their line, and the reply that went back, both still on screen.
    expect(find.text(first.line), findsOneWidget);
    expect(find.text(first.replies[first.answer].text), findsOneWidget);
    // The next line picks up that reply rather than opening cold.
    expect(find.text(ja.t('afterYourReply')), findsOneWidget);
    expect(find.text(s.settingNative), findsNothing,
        reason: 'the conversation above is the setting now');
    // And the next turn is the one on offer below.
    expect(find.text(s.turns[1].replies.first.text), findsOneWidget);
  });

  testWidgets('a turn gone wrong keeps both what was said and what fitted',
      (tester) async {
    tall(tester);
    final (_, s) = await open(tester);
    final first = s.turns[0];
    final wrong = (first.answer + 1) % first.replies.length;

    await answer(tester, first, wrong);
    await moveOn(tester, right: false);

    expect(find.text(first.replies[wrong].text), findsOneWidget,
        reason: 'what they chose is not rubbed out');
    expect(find.text(first.replies[first.answer].text), findsOneWidget,
        reason: 'and the conversation above still has to read as English '
            'that works');
  });

  testWidgets('what they heard is kept in their own language, on the band',
      (tester) async {
    tall(tester);
    final (_, s) = await open(tester);
    final first = s.turns[0];

    await answer(tester, first, first.answer);
    await moveOn(tester);

    expect(find.text(ja.t('heardBand', {'text': first.lineNative})),
        findsOneWidget);
  });

  testWidgets('the figures are named in the language of the interface',
      (tester) async {
    tall(tester);
    await open(tester, turns: 1);

    // A name on a figure is a label on the screen, so it follows the
    // interface; the question inside the conversation stays English.
    expect(find.text(ja.t('speakerOther')), findsOneWidget);
    expect(find.text(ja.t('speakerYou')), findsOneWidget);
    expect(find.text(en.t('sceneQ2')), findsOneWidget);
  });

  testWidgets('every turn answered is written down, and the run is counted',
      (tester) async {
    tall(tester);
    final (repo, s) = await open(tester);

    await answer(tester, s.turns[0], s.turns[0].answer);
    await moveOn(tester);
    await answer(tester, s.turns[1], s.turns[1].answer);
    await tester.pump(const Duration(milliseconds: 2400));

    final out = await repo.turnResults();
    expect(out, hasLength(2));
    expect(out.every((r) => r.correct), isTrue);
    expect(find.text('2 / 2'), findsOneWidget);
  });
}
