/// Renders the growth tree at each stage and writes the pictures out.
///
/// Not an assertion suite: the tree is a drawing, and the only way to know
/// whether a drawing is right is to look at it. Growing one on real answers
/// would take months, so the shapes are built directly and painted through the
/// same widget the home screen uses.
///
/// Run with:
///   flutter test test/tree_phase_shot_test.dart
/// The PNGs land in build/tree_phases/.
library;

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:kotolang/app.dart';
import 'package:kotolang/data/database.dart';
import 'package:kotolang/domain/tree.dart';
import 'package:kotolang/features/tree_view.dart';

/// One area with a plausible spread of formats behind it.
Branch _branch(String id, String label, int answers,
    {int learned = 0, bool thirsty = false, bool bare = false, bool own = true}) {
  final listening = (answers * 0.5).round();
  return Branch(
    realmId: (own ? ownBranch : sampleBranch)(id),
    label: label,
    own: own,
    answers: answers,
    twigs: bare
        ? {for (final t in Twig.values) t: 0}
        : {
            Twig.grasp: listening,
            Twig.reply: answers - listening,
          },
    growing: (answers / 6).ceil(),
    fruit: learned,
    flowers: own ? (answers * 0.4).round() : 0,
    thirsty: thirsty,
  );
}

/// The stages, as somebody actually passes through them.
typedef _Phase = ({String name, TreeShape shape});

_Phase _phase(String name, TreeShape shape,
        {List<String> ornaments = const [], bool pest = false}) =>
    (name: name, shape: shape);

final _phases = <_Phase>[
  _phase('00_seed', const TreeShape(answers: 0, branches: [])),
  _phase('01_one', TreeShape(answers: 1, branches: [_branch('a', '仕事', 1)])),
  _phase('02_five', TreeShape(answers: 5, branches: [_branch('a', '仕事', 5, own: false)])),
  _phase('03_ten', TreeShape(answers: 10, branches: [_branch('a', '仕事', 6, own: false), _branch('a', '仕事', 4)])),
  _phase(
    '04_twenty_five',
    TreeShape(
        answers: 25,
        branches: [_branch('a', '仕事', 18), _branch('b', '旅行', 7)]),
  ),
  _phase(
    '05_fifty',
    TreeShape(
        answers: 50,
        branches: [_branch('a', '仕事', 34), _branch('b', '旅行', 16)]),
  ),
  _phase(
    '06_hundred',
    TreeShape(answers: 100, branches: [
      _branch('a', '仕事', 55, learned: 1),
      _branch('b', '旅行', 30),
      _branch('c', '料理', 15),
    ]),
  ),
  _phase(
    '07_two_fifty',
    TreeShape(answers: 250, branches: [
      _branch('a', '仕事', 120, learned: 4),
      _branch('b', '旅行', 80, learned: 2),
      _branch('c', '料理', 50),
    ]),
    ornaments: ['ribbon'],
  ),
  _phase(
    '08_six_hundred',
    TreeShape(answers: 600, branches: [
      _branch('a', '仕事', 240, learned: 9),
      _branch('b', '旅行', 160, learned: 5),
      _branch('c', '料理', 120, learned: 3),
      _branch('d', '健康', 80, learned: 2),
    ]),
    ornaments: ['ribbon', 'star'],
  ),
  _phase(
    '09_one_thousand',
    TreeShape(answers: 1000, branches: [
      _branch('a', '仕事', 400, learned: 14),
      _branch('b', '旅行', 260, learned: 8),
      _branch('c', '料理', 200, learned: 6),
      _branch('d', '健康', 140, learned: 4),
    ]),
    ornaments: ['ribbon', 'star', 'lantern'],
  ),
  _phase(
    '10_five_thousand',
    TreeShape(answers: 5000, branches: [
      _branch('a', '仕事', 1800, learned: 30),
      _branch('b', '旅行', 1400, learned: 22),
      _branch('c', '料理', 1000, learned: 16),
      _branch('d', '健康', 800, learned: 12),
    ]),
    ornaments: ['ribbon', 'star', 'lantern', 'bell'],
  ),
  // The states that are not about size at all.
  _phase(
    '11_neglected_area',
    TreeShape(answers: 200, branches: [
      _branch('a', '仕事', 120, learned: 5),
      _branch('b', '旅行', 60, thirsty: true),
      _branch('c', '料理', 20, thirsty: true),
    ]),
  ),
  _phase(
    '12_untouched_area',
    TreeShape(answers: 90, branches: [
      _branch('a', '仕事', 70, learned: 2),
      _branch('b', '旅行', 20),
      // Opened but never studied: a bare twig with a bud on the end.
      _branch('c', '料理', 0, bare: true),
    ]),
  ),
  _phase(
    // A streak on the line and nothing answered today: a bug turns up on the
    // tree until one question is done.
    '13_pest',
    TreeShape(answers: 150, branches: [
      _branch('a', '仕事', 90, learned: 3),
      _branch('b', '旅行', 60, learned: 1),
    ]),
    pest: true,
  ),
];

/// Decodes the tree art the way the app does, but from inside `runAsync` so
/// the image codec actually completes: a `FutureProvider` that decodes an
/// image starts its work during a pump, where the codec future never resolves,
/// and the panel then sits on its empty placeholder forever.
Future<TreeArt> _loadArt() async {
  Future<ui.Image> one(String name) async {
    final data = await rootBundle.load('assets/tree/$name.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  return TreeArt(
    bud: await one('bud'),
    fruit: await one('fruit'),
    sprout: await one('sprout'),
  );
}

Future<void> _write(String name, ui.Image image) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = Directory('build/tree_phases')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(
      bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final phase in _phases) {
    for (final dark in [false, true]) {
      final name = '${phase.name}${dark ? '_dark' : ''}';
      testWidgets('renders $name', (tester) async {
        // A tall viewport, so the panel is allowed to reach its full height
        // instead of being capped against a short screen.
        tester.view.physicalSize = const Size(720, 1800);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        // Exactly the height the home screen would give this panel. Clipping
        // to it drops the caption underneath, which has no glyphs in the test
        // font and would print as a row of tofu across every plate.
        final panelH = min(150 + 130 * trunkGrowth(phase.shape.answers), 252.0);

        final art = await tester.runAsync(_loadArt);

        // An in-memory database: the panel reads the interface language, and
        // the real one wants a file path that no test process has.
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              treeArtProvider.overrideWith((ref) => art!),
              // Held still: the picture has to be the same every run, and a
              // repeating breeze would never let `pumpAndSettle` return.
              treeMotionProvider.overrideWithValue(false),
              treeDataProvider.overrideWith((ref) async => TreeData(shape: phase.shape)),
            ],
            child: MaterialApp(
              theme: ThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light),
              home: Scaffold(
                backgroundColor: dark
                    ? const Color(0xFF14161A)
                    : const Color(0xFFF7F7FB),
                body: Center(
                  child: SizedBox(
                    width: 340,
                    height: panelH + 4,
                    // The boundary sits outside the clip: inside it, `toImage`
                    // captures the unclipped child and the crop does nothing.
                    child: const RepaintBoundary(
                      key: ValueKey('shot'),
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          maxHeight: 900,
                          child: TreePanel(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        // The art is decoded from real asset bytes, which needs turns of the
        // real event loop: a pumped-only test never lets the futures finish,
        // and the panel stays at its empty placeholder size.
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 80)));
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey("shot")));
        final image =
            await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
        await tester.runAsync(() => _write(name, image!));
        image!.dispose();
      });
    }
  }
}
