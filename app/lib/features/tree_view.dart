/// The growth tree: the first thing the app shows, and a picture of every
/// answer that has ever been given.
///
/// It is drawn on one rule. The ground was always a world, and all that
/// changes is how far away the camera is: there is one sphere of a fixed
/// size, a tree standing on its pole, and a frame that pulls back as the tree
/// grows. Close up the ground is a plain; the horizon bends a little at a
/// time; at the last level the whole world is in view with the roots round
/// it. How big the tree is and what shape it has grow separately — see
/// [treeSizeAt] and [treeMaturityAt].
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data' show Float64List;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/l10n/strings.dart';
import '../core/util.dart';
import '../domain/tree.dart';

/// What the tree is called right now: the name and the level inside it.
///
/// One place rather than three, because it is shown on home, at the end of a
/// question, and on the growing screen, and a tree called one thing on one
/// screen and another on the next is not a name.
String rankName(S s, int scenes) {
  final r = treeRank(scenes);
  return s.t('treeRankLabel',
      {'name': s.t('treeStage${r.name}'), 'n': r.level});
}

/// Where [scenes] questions answered put the tree, between whole levels: the
/// level earned plus how far towards the next. So every question finished
/// makes the tree a little bigger, not only the ones that level up.
double treeLevelExact(int scenes) {
  final l = treeLevel(scenes);
  final from = treeLevelAt(l), to = treeLevelAt(l + 1);
  final part = to > from ? ((scenes - from) / (to - from)).clamp(0.0, 1.0) : 0.0;
  return min(treeTopLevel.toDouble(), l + part);
}

/// Everything the tree needs, gathered in one read.
class TreeData {
  final TreeShape shape;
  const TreeData({required this.shape});
}

final treeDataProvider = FutureProvider.autoDispose<TreeData>((ref) async {
  final repo = ref.watch(repositoryProvider);
  final t = today();
  final results = await ref.watch(sceneResultsProvider.future);
  final scenes = await ref.watch(allScenesProvider.future);
  final fields = await ref.watch(fieldsProvider.future);
  final shape = treeFrom(
    due: await repo.reviewsDue(day: t, limit: 99),
    today: t,
    results: results,
    scenes: {for (final sc in scenes) sc.id: sc},
    fieldLabels: {for (final f in fields) f.id: f.label},
  );
  return TreeData(shape: shape);
});

class TreePanel extends ConsumerStatefulWidget {
  /// No share button: the small tree on a field screen.
  final bool compact;
  const TreePanel({super.key, this.compact = false});

  @override
  ConsumerState<TreePanel> createState() => _TreePanelState();
}

class _TreePanelState extends ConsumerState<TreePanel>
    with WidgetsBindingObserver {
  /// The breeze. A loop, because a tree that is only ever still looks like a
  /// picture of a tree, and because the movement is the thing that says the
  /// screen is alive. It stops when the app is in the background, when the
  /// device asks for reduced motion, and under test — a loop that never
  /// stopped would burn battery behind a locked phone and hang every
  /// `pumpAndSettle` in the suite.
  final _breeze = _Breeze();

  /// The picture of the tree, as it stands, for the share sheet. Nothing but
  /// the image and one line of text leaves the phone, and only where the
  /// learner sends it.
  final _shot = GlobalKey();

  Future<void> _share() async {
    final s = ref.read(stringsProvider);
    final streak = ref.read(progressProvider).streak;
    final boundary = _shot.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    try {
      // The breeze repaints the tree every frame; a boundary mid-repaint
      // cannot be captured. Hold it still for two frames, then take the
      // picture, then let the wind back in.
      _breeze.stop();
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      await SharePlus.instance.share(ShareParams(
        text: s.t('shareTreeText', {'n': streak}),
        files: [
          XFile.fromData(bytes.buffer.asUint8List(),
              mimeType: 'image/png', name: 'kotolang_tree.png'),
        ],
      ));
    } catch (e) {
      // No share target, or a platform without the plugin (tests): nothing
      // to do but not crash.
      debugPrint('[KotoLang] share failed: $e');
    } finally {
      if (mounted) _apply();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _breeze.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _apply();
  }

  /// Whether the breeze should be blowing at all, given where the app is and
  /// what the device has asked for.
  void _apply() {
    final wanted = ref.read(treeMotionProvider) &&
        !MediaQuery.of(context).disableAnimations &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (wanted) {
      _breeze.start();
    } else {
      _breeze.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final data = ref.watch(treeDataProvider);

    // Answering changes the tree, and the tree should be seen to notice.
    ref.listen(treeDataProvider, (_, _) => _breeze.stir());
    _apply();

    final height = widget.compact
        ? 140.0
        // Capped against the screen: on a short phone a tall panel pushes
        // the start button below the fold, which is the one thing this
        // screen must never do.
        : min(250.0, MediaQuery.sizeOf(context).height * 0.28);

    if (data.value == null) return SizedBox(height: height);

    final shape = data.value!.shape;
    final level = treeLevelExact(shape.scenes);
    final canvas = SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: TweenAnimationBuilder<double>(
          // Grows into place rather than appearing at full size, and a
          // question finished is seen to add to it.
          tween: Tween(begin: max(1.0, level - 1.5), end: level),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, at, _) => CustomPaint(
            // The breeze repaints the painter directly rather than
            // rebuilding the widget: nothing above the canvas changes when
            // the wind blows, so nothing above it needs building again.
            painter: _WorldPainter(level: at, breeze: _breeze),
          ),
        ),
      ),
    );

    return Stack(
      children: [
        // What gets shared is exactly what is on screen.
        RepaintBoundary(
          key: _shot,
          child: ColoredBox(
            color: theme.colorScheme.surface,
            child: Padding(padding: const EdgeInsets.only(bottom: 4), child: canvas),
          ),
        ),
        if (!shape.isSeed && !widget.compact)
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              tooltip: s.t('shareTree'),
              icon: const Icon(Icons.ios_share, size: 20, color: Colors.white),
              onPressed: _share,
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ drawing

double _lerp(double a, double b, double t) => a + (b - a) * t;
double _ease(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

/// A deterministic wobble in -1..1, seeded by position in the tree rather than
/// by a random number generator: the tree must not rearrange itself between
/// visits, or it is decoration rather than a record.
double _wob(num seed) {
  final x = sin(seed * 12.9898) * 43758.5453;
  return (x - x.floorToDouble()) * 2 - 1;
}

Color _mix(List<int> a, List<int> b, double t) => Color.fromARGB(
    255,
    _lerp(a[0].toDouble(), b[0].toDouble(), t).round(),
    _lerp(a[1].toDouble(), b[1].toDouble(), t).round(),
    _lerp(a[2].toDouble(), b[2].toDouble(), t).round());

/// The picture at one level and one size, recorded once: the world behind,
/// the tree (which the breeze moves), and the cloud in front.
class _Scene {
  final ui.Picture back, tree, front;

  /// Where the foot of the tree is on the canvas, for the sway to pivot on.
  final Offset base;

  /// How far the breeze may lean the tree: young trees give more.
  final double give;

  _Scene(this.back, this.tree, this.front, this.base, this.give);
}

/// A handful of recent scenes. The home tree repaints the same one on every
/// breath of wind, and the growing screen scrolls back and forth over a few.
final _scenes = <(double, double, double), _Scene>{};

_Scene _sceneFor(double level, Size size) {
  final key = ((level * 1000).roundToDouble() / 1000, size.width, size.height);
  final hit = _scenes.remove(key);
  if (hit != null) return _scenes[key] = hit;
  final made = _compose(key.$1, size);
  _scenes[key] = made;
  while (_scenes.length > 24) {
    final old = _scenes.remove(_scenes.keys.first)!;
    old.back.dispose();
    old.tree.dispose();
    old.front.dispose();
  }
  return made;
}

_Scene _compose(double level, Size size) {
  final w = size.width, h = size.height;
  const r = worldRadius;
  final view = treeViewAt(level);
  final m = treeMaturityAt(level);
  final big = view.size;
  final scale = h / view.span;
  double X(double x) => w / 2 + x * scale;
  double Y(double y) => (view.top - y) * scale;
  final frame = Offset.zero & size;

  // ---- sky: day, then dusk, then space ----------------------------------
  final back = ui.PictureRecorder();
  final c = Canvas(back, frame);
  const day = [[111, 168, 220], [207, 230, 245]];
  const dusk = [[40, 52, 110], [214, 160, 150]];
  const night = [[6, 9, 26], [24, 34, 74]];
  final a = view.altitude;
  Color pick(int i) =>
      a < 0.5 ? _mix(day[i], dusk[i], a / 0.5) : _mix(dusk[i], night[i], (a - 0.5) / 0.5);
  c.drawRect(
      frame,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [pick(0), pick(1)]));
  if (a > 0.55) {
    final star = Paint()..color = Colors.white.withValues(alpha: 0.9 * (a - 0.55) / 0.45);
    for (var i = 0; i < 60; i++) {
      c.drawCircle(
          Offset((_wob(i * 31) * .5 + .5) * w, (_wob(i * 57 + 9) * .5 + .5) * h),
          (0.5 + (_wob(i * 13 + 3) * .5 + .5)) * max(w, h) / 400,
          star);
    }
  }

  // ---- the world --------------------------------------------------------
  final gx = X(0), gy = Y(0), gr = r * scale;
  // Half the width in view, in world units. While that is a sliver of the
  // world the ground is drawn as the arc in view, not as a disc a hundred
  // thousand pixels across, which the rasteriser cannot hold precisely.
  final half = w / 2 / scale;
  final near = half < r * 0.25;
  final ground = Path();
  if (near) {
    const n = 32;
    ground.moveTo(0, h + 10);
    for (var i = 0; i <= n; i++) {
      final x = -half * 1.1 + i / n * half * 2.2;
      ground.lineTo(X(x), Y(sqrt(r * r - x * x)));
    }
    ground.lineTo(w, h + 10);
    ground.close();
  } else {
    ground.addOval(Rect.fromCircle(center: Offset(gx, gy), radius: gr));
  }
  c.drawPath(ground, Paint()..color = const Color(0xFF2E7BC4));
  c.save();
  c.clipPath(ground);
  c.clipRect(frame);

  // The home continent, under the tree: everything above a wavy coast.
  final capY = r * cos(0.62);
  double coast(double x) => capY + r * (0.05 * sin(x / r * 7) + 0.03 * sin(x / r * 17 + 1));
  const land = Color(0xFF5C9A3E);
  if (Y(capY + r * 0.09) > h + 2) {
    // The coast is below the bottom of the frame: all the ground is land.
    c.drawRect(frame, Paint()..color = land);
  } else {
    final span = min(r * 1.2, half * 1.1);
    final cap = Path()
      ..moveTo(X(-span), -10)
      ..lineTo(X(span), -10);
    for (var i = 0; i <= 48; i++) {
      final x = span - i / 48 * span * 2;
      cap.lineTo(X(x), Y(coast(x)));
    }
    cap.close();
    c.drawPath(cap, Paint()..color = land);
  }

  // The other continents, laid out on the sphere so they foreshorten
  // towards the rim. Only once the camera is far enough out to see them.
  if (!near) {
    const continents = [
      (1.05, -0.9, 0.42), (1.25, 0.95, 0.38), (1.95, -0.35, 0.46),
      (2.40, 0.60, 0.30), (1.60, 0.10, 0.22),
    ];
    final paint = Paint()..color = const Color(0xFF4E8A34);
    List<double> cross(List<double> p, List<double> q) =>
        [p[1] * q[2] - p[2] * q[1], p[2] * q[0] - p[0] * q[2], p[0] * q[1] - p[1] * q[0]];
    for (var ci = 0; ci < continents.length; ci++) {
      final (u, v, cr) = continents[ci];
      final cen = [sin(u) * sin(v), cos(u), sin(u) * cos(v)];
      final ax = cen[1].abs() < 0.9 ? const [0.0, 1.0, 0.0] : const [1.0, 0.0, 0.0];
      var e1 = cross(cen, ax);
      final len = sqrt(e1[0] * e1[0] + e1[1] * e1[1] + e1[2] * e1[2]);
      e1 = [for (final x in e1) x / len];
      final e2 = cross(cen, e1);
      final p = Path();
      for (var i = 0; i <= 40; i++) {
        final th = i / 40 * pi * 2;
        final rr = cr * (1 + 0.14 * sin(th * 3 + ci * 1.7) + 0.08 * sin(th * 5 + ci * 2.3));
        final dx = cen[0] * cos(rr) + (e1[0] * cos(th) + e2[0] * sin(th)) * sin(rr);
        final dy = cen[1] * cos(rr) + (e1[1] * cos(th) + e2[1] * sin(th)) * sin(rr);
        if (i == 0) {
          p.moveTo(X(dx * r), Y(dy * r));
        } else {
          p.lineTo(X(dx * r), Y(dy * r));
        }
      }
      p.close();
      c.drawPath(p, paint);
    }
    // Night on the far side: one flat crescent, not a shaded ball.
    if (view.toGlobe > 0) {
      final dark = Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(Rect.fromCircle(center: Offset(gx, gy), radius: gr))
        ..addOval(Rect.fromCircle(
            center: Offset(gx - gr * 0.38, gy - gr * 0.32), radius: gr * 0.97));
      c.drawPath(dark, Paint()..color = Color.fromRGBO(6, 18, 44, 0.42 * view.toGlobe));
    }
  }
  c.restore();

  // ---- roots over the world ---------------------------------------------
  // They come on as the tree gets big against the world, not at a switch:
  // how far round they reach and how thick they are both follow its size.
  final reach = ((big - 0.25 * r) / (2.3 * r - 0.25 * r)).clamp(0.0, 1.0);
  final trunkW = big * _lerp(0.03, 0.11, _ease((m - 0.2) / 0.8));
  if (reach > 0 && !near) {
    c.save();
    c.clipPath(ground);
    final uMax = 0.10 + 2.75 * reach;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    void rootLine(double v0, double amp, double waves, double phase, double u0,
        double u1, double width, double alpha) {
      paint.color = Color.fromRGBO(160, 112, 70, alpha);
      Offset? prev;
      for (var i = 0; i <= 36; i++) {
        final t = i / 36, u = _lerp(u0, u1, t), v = v0 + amp * sin(u * waves + phase);
        final z = sin(u) * cos(v);
        final s = Offset(X(r * sin(u) * sin(v)), Y(r * cos(u)));
        if (prev != null && z > 0.02) {
          paint.strokeWidth = max(0.6, width * (1 - 0.7 * t) * scale);
          c.drawLine(prev, s, paint);
        }
        prev = s;
      }
    }

    for (var k = 0; k < 5; k++) {
      final v0 = (k - 2) * 0.55;
      rootLine(v0, 0.40, 2.1 + 0.3 * _wob(k * 11), _wob(k * 23) * pi, 0.01, uMax,
          trunkW * 0.42, 0.95);
      for (var j = 0; j < 3; j++) {
        final s0 = 0.5 + j * 0.7;
        if (s0 > uMax - 0.2) continue;
        rootLine(v0 + (j.isOdd ? -0.24 : 0.24), 0.2, 3.6, _wob(k * 31 + j) * pi, s0,
            min(uMax, s0 + 0.9), trunkW * 0.08, 0.85);
      }
    }
    for (var k = 0; k < 12; k++) {
      rootLine(-1.35 + k * 2.7 / 11, 0.24, 3.1 + 0.5 * _wob(k * 17), _wob(k * 41) * pi,
          0.01, uMax * 0.94, trunkW * 0.15, 0.85);
    }
    c.restore();
  }

  // ---- the tree -----------------------------------------------------------
  final treeRec = ui.PictureRecorder();
  final tc = Canvas(treeRec, frame);
  final leafPaths = [Path(), Path(), Path()];
  const leafColours = [Color(0xFF4E9B3F), Color(0xFF66B04C), Color(0xFF3E7A3A)];
  final bark = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = m < 0.2
        ? const Color(0xFF4C8C3A)
        : _mix(const [76, 140, 58], const [74, 50, 38], _ease((m - 0.2) / 0.25));
  // One leaf is an ellipse turned about its stalk end. The paths are built up
  // leaf by leaf and filled once per colour at the end.
  void leaf(double x, double y, double s, double ang, int i) {
    final len = s * scale;
    final cx = X(x), cy = Y(y);
    final ca = cos(-ang), sa = sin(-ang);
    final p = leafPaths[i.abs() % 3];
    const n = 12;
    for (var j = 0; j <= n; j++) {
      final th = j / n * 2 * pi;
      final ex = len * 0.5 + len * 0.55 * cos(th), ey = len * 0.26 * sin(th);
      final px = cx + ex * ca - ey * sa, py = cy + ex * sa + ey * ca;
      if (j == 0) {
        p.moveTo(px, py);
      } else {
        p.lineTo(px, py);
      }
    }
    p.close();
  }

  void stroke(double x0, double y0, double x1, double y1, double width) {
    bark.strokeWidth = max(0.8, width * scale);
    tc.drawLine(Offset(X(x0), Y(y0)), Offset(X(x1), Y(y1)), bark);
  }

  final flowers = <Offset>[];
  var flowerR = 0.0;
  const bx = 0.0, by = r;

  if (m < 0.06) {
    // A sprout: a short stem and two seed leaves.
    final sh = big * 0.55;
    stroke(bx, by, bx + big * 0.03, by + sh, big * 0.05);
    leaf(bx + big * 0.03, by + sh, big * 0.34, 0.35, 1);
    leaf(bx + big * 0.03, by + sh, big * 0.34, pi - 0.35, 2);
  } else if (m < 0.2) {
    // A seedling: one stem, true leaves up it by turns, no branches yet.
    final k = (m - 0.06) / 0.14;
    final sh = big * 0.92;
    final n = 2 + (k * 6).round();
    final lean = big * 0.05;
    for (var i = 0; i < 12; i++) {
      final t0 = i / 12, t1 = (i + 1) / 12;
      stroke(bx + lean * t0 * t0, by + sh * t0, bx + lean * t1 * t1, by + sh * t1,
          big * _lerp(0.05, 0.02, t0));
    }
    for (var i = 0; i < n; i++) {
      final t = 0.35 + 0.65 * (i / max(1, n - 1));
      leaf(bx + lean * t * t, by + sh * t, big * _lerp(0.30, 0.20, t),
          i.isOdd ? 0.55 : pi - 0.55, i);
    }
    leaf(bx + lean, by + sh, big * 0.18, pi / 2, 9);
  } else {
    // A tree. Everything below eases from sapling to great tree.
    final k = (m - 0.2) / 0.8;
    final trunkH = big * _lerp(0.62, 0.40, _ease(k));
    final primaries = _lerp(3, 9, k).round();
    final depth = _lerp(1, 5, _ease(k)).round();
    final spread = _lerp(0.38, 1.12, _ease(k));
    final primLen = big * _lerp(0.30, 0.52, _ease(k));
    final leafSize = big * _lerp(0.075, 0.022, _ease(k));
    final lean = big * 0.03;

    Offset trunkAt(double t) => Offset(bx + lean * sin(t * pi), by + trunkH * t);
    for (var i = 0; i < 16; i++) {
      final p0 = trunkAt(i / 16), p1 = trunkAt((i + 1) / 16);
      stroke(p0.dx, p0.dy, p1.dx, p1.dy, trunkW * (1 - 0.6 * (i / 16)));
    }
    // Buttress roots flaring into the ground once the trunk has weight.
    if (k > 0.35) {
      final fl = _ease((k - 0.35) / 0.4);
      for (final s in const [-1.0, -0.45, 0.5, 1.0]) {
        stroke(bx + s * trunkW * 0.3, by + trunkW * 0.5,
            bx + s * trunkW * (1.1 + 0.6 * fl), by - trunkW * 0.05, trunkW * 0.28 * fl);
      }
    }

    final tips = <(double, double, double, int)>[];
    // [ang] is measured from vertical, positive to the right.
    void branch(double x, double y, double ang, double len, double bw, int d, int seed) {
      final bend = 0.18 * _wob(seed * 7);
      final mx = x + sin(ang + bend * 0.5) * len * 0.5, my = y + cos(ang + bend * 0.5) * len * 0.5;
      final ex = x + sin(ang + bend) * len, ey = y + cos(ang + bend) * len;
      stroke(x, y, mx, my, bw);
      stroke(mx, my, ex, ey, bw * 0.7);
      if (d <= 0) {
        tips.add((ex, ey, ang + bend, seed));
        return;
      }
      // Forking part way along, fanning round the direction it was going,
      // and bending back towards the light so the crown stays a crown.
      final fx = x + sin(ang + bend * 0.7) * len * 0.62, fy = y + cos(ang + bend * 0.7) * len * 0.62;
      tips.add((ex, ey, ang + bend, seed + 1));
      final fan = _lerp(0.42, 0.55, k);
      final pull = ang.sign * 0.32 * 0.5;
      branch(fx, fy, (ang + bend) - fan + _wob(seed * 3) * 0.12 - pull, len * 0.70, bw * 0.62,
          d - 1, seed * 3 + 1);
      branch(fx, fy, (ang + bend) + fan + _wob(seed * 5) * 0.12 - pull, len * 0.66, bw * 0.58,
          d - 1, seed * 3 + 2);
    }

    for (var i = 0; i < primaries; i++) {
      final t = primaries == 1 ? 0.5 : i / (primaries - 1);
      final side = i.isOdd ? 1 : -1;
      final p = trunkAt(_lerp(_lerp(0.5, 0.30, k), 0.92, t));
      // Low branches spread widest, high ones stand up: a crown, not a fan.
      final ang = side * spread * _lerp(1.0, 0.32, t) + _wob(i * 19) * 0.12;
      final len = primLen * _lerp(1.0, 0.84, t) * (1 + _wob(i * 23) * 0.1);
      branch(p.dx, p.dy, ang, len, trunkW * _lerp(0.55, 0.30, t), depth, i * 10 + 3);
    }
    // The leader, carrying on up the middle.
    final top = trunkAt(1);
    branch(top.dx, top.dy, _wob(71) * 0.08, primLen * 0.92, trunkW * 0.40, depth, 777);

    for (final (x, y, ang, seed) in tips) {
      final count = k < 0.3 ? 3 : 5;
      for (var j = 0; j < count; j++) {
        final la = ang + (j - (count - 1) / 2) * 0.6 + _wob(seed * 13 + j) * 0.3;
        leaf(x, y, leafSize * (0.8 + 0.4 * (_wob(seed * 17 + j) * .5 + .5)), pi / 2 - la,
            seed + j);
      }
    }
    // Flowers scattered over the crown, never in one place.
    if (m > 0.55) {
      for (var i = 0; i < tips.length; i++) {
        final (x, y, _, seed) = tips[i];
        if (_wob(seed * 91 + i) > 0.86) flowers.add(Offset(X(x), Y(y)));
      }
      flowerR = max(1.2, leafSize * 0.45 * scale);
    }
  }
  for (var i = 0; i < 3; i++) {
    tc.drawPath(leafPaths[i], Paint()..color = leafColours[i]);
  }
  final bloom = Paint()..color = const Color(0xFFF2A7BA);
  for (final f in flowers) {
    tc.drawCircle(f, flowerR, bloom);
  }

  // ---- cloud, round the world once it is seen from far enough out -------
  final frontRec = ui.PictureRecorder();
  final fc = Canvas(frontRec, frame);
  if (view.toGlobe > 0.05 && !near) {
    final puff = Paint()..color = Colors.white.withValues(alpha: 0.30 * view.toGlobe);
    for (var i = 0; i < 7; i++) {
      final side = i.isOdd ? 1 : -1;
      final u = _lerp(0.9, 2.5, _wob(i * 29) * .5 + .5);
      final rr = r * 1.06;
      final x = side * rr * sin(u), y = rr * cos(u);
      final cw = r * (0.34 + 0.20 * (_wob(i * 7) * .5 + .5));
      for (var j = -1; j <= 1; j++) {
        fc.drawOval(
            Rect.fromCenter(
                center: Offset(X(x + j * cw * 0.35), Y(y + (j == 0 ? cw * 0.12 : 0))),
                width: 2 * cw * (j == 0 ? 0.46 : 0.36) * scale,
                height: 2 * cw * (j == 0 ? 0.13 : 0.10) * scale),
            puff);
      }
    }
  }

  return _Scene(back.endRecording(), treeRec.endRecording(), frontRec.endRecording(),
      Offset(X(bx), Y(by)), _lerp(0.035, 0.008, m));
}

class _WorldPainter extends CustomPainter {
  final double level;
  final _Breeze breeze;

  _WorldPainter({required this.level, required this.breeze}) : super(repaint: breeze);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.clipRect(Offset.zero & size);
    final scene = _sceneFor(level.clamp(1.0, treeTopLevel.toDouble()), size);
    canvas.drawPicture(scene.back);
    // The breeze leans the whole tree about its foot, a little: the roots and
    // the world stay where they are.
    final lean = scene.give * breeze.gust * sin(breeze.phase);
    if (lean == 0) {
      canvas.drawPicture(scene.tree);
    } else {
      canvas.save();
      canvas.translate(scene.base.dx, scene.base.dy);
      canvas.transform(Float64List.fromList(
          [1, 0, 0, 0, -lean, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]));
      canvas.translate(-scene.base.dx, -scene.base.dy);
      canvas.drawPicture(scene.tree);
      canvas.restore();
    }
    canvas.drawPicture(scene.front);
  }

  @override
  bool shouldRepaint(_WorldPainter old) => old.level != level || old.breeze != breeze;
}

/// Whether the tree is allowed to move. A provider rather than a constant so
/// the widget tests can hold it still: a loop that never ends means
/// `pumpAndSettle` never returns.
final treeMotionProvider = Provider<bool>((ref) => true);

/// The wind, as two numbers the painter reads: how far through the swing it
/// is, and how hard it is blowing.
///
/// Driven by a timer rather than a ticker, and deliberately not at the screen
/// refresh rate: a tree swaying at 24 frames a second looks exactly like one
/// swaying at 120.
class _Breeze extends ChangeNotifier {
  static const _tick = Duration(milliseconds: 42);

  /// The wind the tree sits in when nothing has happened.
  static const _rest = 0.42;

  double phase = 0;
  double gust = _rest;
  Timer? _timer;

  void start() {
    _timer ??= Timer.periodic(_tick, (_) {
      phase += 0.085;
      if (phase > 4 * pi) phase -= 4 * pi;
      // Settles back towards the resting breeze after a stir.
      gust += (_rest - gust) * 0.035;
      notifyListeners();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (gust != 0) {
      // Held still rather than frozen mid-sway, so a device asking for reduced
      // motion gets an upright tree instead of a leaning one.
      phase = 0;
      gust = 0;
      notifyListeners();
    }
  }

  /// A stronger stir, for the moment the tree grows.
  void stir() {
    gust = 1.6;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// A breeze that never blows. The still trees share one: it exists only
/// because the painter repaints off a notifier, and this one never notifies.
final _stillAir = _Breeze()..gust = 0;

/// The tree at one [level], drawn at a size of your choosing and held still.
///
/// For showing what the tree *becomes* rather than what it is: the growing
/// screen draws it at every level, so the thing being climbed towards is a
/// picture and not a promise.
class TreeStill extends StatelessWidget {
  final double level;
  final double height;
  const TreeStill({super.key, required this.level, required this.height});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: CustomPaint(painter: _WorldPainter(level: level, breeze: _stillAir)),
      );
}
