/// The growth tree: the first thing the app shows, and a picture of every
/// answer that has ever been given.
///
/// The tree itself is drawn rather than assembled from pictures. A real tree
/// forks over and over, its limbs curve, and its leaves are spread along the
/// branches rather than bunched on the ends; a trunk with a few stamped leaf
/// images on it reads as a diagram no matter how good the images are. Drawing
/// it also lets the shape follow the data — a learner with two areas and a
/// learner with seven cannot share a picture.
///
/// The things that hang on the tree — fruit, a bud, decorations, the ground —
/// stay as artwork, because those are fixed objects rather than structure.
library;

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show rootBundle;
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/util.dart';
import '../domain/scene.dart' show TurnType;
import '../domain/tree.dart';

/// The fixed objects the tree carries. Loaded once and held: they are a
/// handful of small files and the tree redraws on every answer.
class TreeArt {
  final ui.Image bud;
  final ui.Image fruit;
  final ui.Image sprout;
  const TreeArt({required this.bud, required this.fruit, required this.sprout});
}

Future<ui.Image> _load(String name) async {
  final data = await rootBundle.load('assets/tree/$name.png');
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  return (await codec.getNextFrame()).image;
}

final treeArtProvider = FutureProvider<TreeArt>((ref) async => TreeArt(
      bud: await _load('bud'),
      fruit: await _load('fruit'),
      sprout: await _load('sprout'),
    ));

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
    ladder: await ref.watch(ladderProvider.future),
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
    final art = ref.watch(treeArtProvider);
    final data = ref.watch(treeDataProvider);

    // Answering changes the tree, and the tree should be seen to notice.
    ref.listen(treeDataProvider, (_, _) => _breeze.stir());
    _apply();

    if (art.value == null || data.value == null) {
      return const SizedBox(height: 200);
    }

    final shape = data.value!.shape;
    final canvas = SizedBox(
      // Capped against the screen as well as the tree: on a short phone a
      // tall panel pushes the start button below the fold, which is the
      // one thing this screen must never do.
      height: widget.compact
          ? 140
          : min(150 + 130 * trunkGrowth(shape.reached), MediaQuery.sizeOf(context).height * 0.28),
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        // Grows into place rather than appearing at full size. Height is the
        // ladder: the trunk rises when a step is held, and the answers that
        // did not raise one go into the girth and the boughs instead.
        tween: Tween(begin: 0, end: trunkGrowth(shape.reached)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, grown, _) => CustomPaint(
          // The breeze repaints the painter directly rather than rebuilding
          // the widget: nothing above the canvas changes when the wind
          // blows, so nothing above the canvas needs to be built again.
          painter: _TreePainter(
            data: data.value!,
            art: art.value!,
            grown: grown,
            girth: trunkGirth(shape.answers),
            dark: theme.brightness == Brightness.dark,
            breeze: _breeze,
          ),
        ),
      ),
    );

    final stack = Stack(
      children: [
        // What gets shared is exactly what is on screen: the tree and the
        // line under it, on the page colour so the picture is not see-through.
        RepaintBoundary(
          key: _shot,
          child: ColoredBox(
            color: theme.colorScheme.surface,
            child: Padding(padding: const EdgeInsets.only(bottom: 4), child: canvas),
          ),
        ),
        if (!shape.isSeed && !widget.compact)
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: s.t('shareTree'),
              icon: Icon(Icons.ios_share, size: 20, color: theme.colorScheme.onSurfaceVariant),
              onPressed: _share,
            ),
          ),
      ],
    );
    return stack;
  }
}

/// A deterministic wobble in -1..1, seeded by position in the tree rather than
/// by a random number generator: the tree must not rearrange itself between
/// visits, or it is decoration rather than a record.
double _wobble(int seed) {
  final x = sin(seed * 12.9898) * 43758.5453;
  return (x - x.floorToDouble()) * 2 - 1;
}

/// A limb, kept so its leaves can be hung once all the wood is down.
typedef _Limb = ({Offset from, Offset ctrl, Offset to, int seed, bool tip, bool own});

class _TreePainter extends CustomPainter {
  final TreeData data;
  final TreeArt art;
  final double grown;

  /// Girth carries on past the point where height stops.
  final double girth;

  /// The wind. Read at paint time rather than copied in, because it is also
  /// what drives the repaint.
  final _Breeze breeze;
  double get phase => breeze.phase;
  double get gust => breeze.gust;

  /// Bark the colour of real bark disappears against a near-black screen.
  final bool dark;

  _TreePainter({
    required this.data,
    required this.art,
    required this.grown,
    required this.girth,
    required this.breeze,
    required this.dark,
  }) : super(repaint: breeze);

  static const _bark = Color(0xFF4A3226);
  static const _barkOnDark = Color(0xFF7A5540);

  /// A seedling is a green stem, not a thin trunk. Bark arrives gradually as
  /// the stem thickens: going straight from a sprout to a brown bole was the
  /// step that read as a swap rather than as growth.
  static const _stem = Color(0xFF4C8C3A);
  static const _stemOnDark = Color(0xFF6FA85C);

  /// Green at the start, fully barked a few hundred answers in. It used to
  /// finish inside fifty, which is a couple of days.
  double get _woodiness => ((data.shape.answers - 8) / 240).clamp(0.0, 1.0);

  Color get _stemColour => Color.lerp(dark ? _stemOnDark : _stem,
      dark ? _barkOnDark : _bark, _woodiness)!;

  // The lit side of the trunk. One band, not a gradient: enough to say where
  // the light is coming from without turning the drawing into a render.
  static const _barkLit = Color(0xFF6B4A37);
  static const _barkLitOnDark = Color(0xFF9A6E52);

  static const _leafShades = [
    Color(0xFF4E9B3F),
    Color(0xFF66B04C),
    Color(0xFF3D7F33),
  ];
  static const _dryShades = [
    Color(0xFFA9BC9C),
    Color(0xFFBECEB3),
    Color(0xFF93A788),
  ];

  /// A five-petalled flower, drawn rather than pasted: it has to sit on a
  /// twig end at any scale and read against both the light and the dark
  /// ground, which a fixed bitmap did not.
  void _flower(Canvas canvas, Offset at, double r) {
    final petal = Paint()
      ..color = dark ? const Color(0xFFE58AA0) : const Color(0xFFF4A7B9);
    final centre = Paint()
      ..color = dark ? const Color(0xFFFFE08A) : const Color(0xFFFFD25E);
    for (var i = 0; i < 5; i++) {
      final a = -pi / 2 + i * 2 * pi / 5;
      canvas.drawCircle(at + Offset(cos(a), sin(a)) * r, r * 0.62, petal);
    }
    canvas.drawCircle(at, r * 0.42, centre);
  }

  /// The mound the tree stands in, drawn rather than pasted: a low ellipse of
  /// earth with a darker rim, in the app's own cartoon line. No grass — the
  /// leaves are the only green, and they belong to the tree.
  void _mound(Canvas canvas, Offset centre, double h) {
    final w = h * 3.4;
    final rect = Rect.fromCenter(center: centre, width: w, height: h);
    final rim = Paint()..color = dark ? const Color(0xFF3A2A1E) : const Color(0xFF4A3323);
    final earth = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark
            ? const [Color(0xFF8A5A36), Color(0xFF6E4629)]
            : const [Color(0xFFB07A48), Color(0xFF8F5E36)],
      ).createShader(rect);
    canvas.drawOval(rect, rim);
    canvas.drawOval(rect.deflate(h * 0.07), earth);
    // A lighter band across the top, the way the old picture had it.
    final band = Paint()..color = (dark ? const Color(0xFF9E6C43) : const Color(0xFFC08D5C)).withValues(alpha: 0.8);
    canvas.drawOval(
        Rect.fromCenter(center: centre.translate(-w * 0.06, -h * 0.12), width: w * 0.62, height: h * 0.30),
        band);
  }

  void _image(Canvas canvas, ui.Image img, Offset at, double height,
      {double opacity = 1, double angle = 0}) {
    final scale = height / img.height;
    final w = img.width * scale;
    final paint = Paint();
    if (opacity < 1) paint.color = Colors.white.withValues(alpha: opacity);
    canvas.save();
    if (angle != 0) {
      canvas.translate(at.dx, at.dy);
      canvas.rotate(angle);
      canvas.translate(-at.dx, -at.dy);
    }
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(at.dx - w / 2, at.dy - height / 2, w, height),
      paint,
    );
    canvas.restore();
  }

  Offset _at(Offset a, Offset c, Offset b, double t) {
    final u = 1 - t;
    return a * (u * u) + c * (2 * u * t) + b * (t * t);
  }

  /// The direction the curve is heading at [t].
  Offset _heading(Offset a, Offset c, Offset b, double t) {
    final d = _at(a, c, b, min(t + 0.02, 1)) - _at(a, c, b, max(t - 0.02, 0));
    final len = d.distance;
    return len == 0 ? const Offset(0, -1) : d / len;
  }

  /// A limb as a curved, tapering shape: sampled along its centre line and
  /// given a width that shrinks towards the tip. A straight line of constant
  /// width with round caps is a stick.
  Path _woodPath(Offset a, Offset c, Offset b, double w0, double w1) {
    const steps = 16;
    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final p = _at(a, c, b, t);
      final h = _heading(a, c, b, t);
      final n = Offset(-h.dy, h.dx);
      // Tapering fastest near the tip is what gives a branch its whip.
      final w = (w0 + (w1 - w0) * (t * t * 0.6 + t * 0.4)) / 2;
      left.add(p + n * w);
      right.add(p - n * w);
    }
    final path = Path()..moveTo(left.first.dx, left.first.dy);
    for (final p in left.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in right.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }
  /// Where the trunk meets the soil, widening as it goes down and putting out
  /// a couple of roots to either side. Everything below the soil line is
  /// covered afterwards by the near lip of the mound, so only the spread shows.
  /// The foot of the tree: a swelling where the trunk reaches the soil and a
  /// few roots splaying out of it into the ground.
  ///
  /// A trunk with parallel sides ends on the soil line in a straight cut and
  /// reads as a post pushed in. Roots crossing that line at an angle read as
  /// going into it, which is the whole trick. Everything below the line is
  /// covered afterwards by the near lip of the mound.
  void _roots(Canvas canvas, double x, double halfWidth, double soil,
      Paint wood) {
    final spread = halfWidth * (1.1 + 2.2 * _woodiness);
    // A seedling has no buttress at all; the swelling arrives with the bark.
    final crown = soil - 4 - 9 * _woodiness;
    final buried = soil + 11;

    canvas.drawPath(
      Path()
        ..moveTo(x - halfWidth, crown)
        ..quadraticBezierTo(
            x - halfWidth, soil - 2, x - halfWidth * (1 + _woodiness), buried)
        ..lineTo(x + halfWidth * (1 + _woodiness), buried)
        ..quadraticBezierTo(x + halfWidth, soil - 2, x + halfWidth, crown)
        ..close(),
      wood,
    );

    if (_woodiness < 0.3) return;
    for (final at in const [-1.0, -0.5, 0.55, 1.0]) {
      final from = Offset(x + halfWidth * at * 0.8, crown + 2);
      final to = Offset(x + spread * at, buried);
      canvas.drawPath(
        _woodPath(
          from,
          Offset((from.dx + to.dx) / 2 + spread * at * 0.35, soil - 1),
          to,
          halfWidth * 0.62,
          halfWidth * 0.16,
        ),
        wood,
      );
    }
  }

  /// One leaf: a pointed oval on a short stalk.
  Path _leaf(Offset stem, double angle, double len) {
    final dir = Offset(cos(angle), sin(angle));
    final n = Offset(-dir.dy, dir.dx);
    final base = stem + dir * (len * 0.16);
    final tip = stem + dir * len;
    final w = len * 0.31;
    return Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(base.dx + dir.dx * len * 0.4 + n.dx * w,
          base.dy + dir.dy * len * 0.4 + n.dy * w, tip.dx, tip.dy)
      ..quadraticBezierTo(base.dx + dir.dx * len * 0.4 - n.dx * w,
          base.dy + dir.dy * len * 0.4 - n.dy * w, base.dx, base.dy)
      ..close();
  }

  /// Leaves all the way along a limb, alternating sides, rather than a clump
  /// stuck on the end. This is the difference between a tree and a lollipop,
  /// and it is how a branch actually carries them.
  void _leaves(Canvas canvas, _Limb limb, double size, bool dry, double start) {
    final shades = dry ? _dryShades : _leafShades;
    const count = 11;
    for (var k = 0; k < count; k++) {
      final w = _wobble(limb.seed * 31 + k * 11);
      // Gaps. Foliage that covers a branch evenly reads as a pipe cleaner; a
      // real canopy comes in clumps with sky between them. A young tree keeps
      // nearly all of its leaves though — it has few enough already, and
      // thinning those reads as dying rather than as dappled.
      if (_wobble(limb.seed * 137 + k * 23) > 0.95 - 0.45 * grown) continue;

      // Bunched rather than spaced: the jitter is what makes the clumps.
      final t = (start + (1 - start) * (k / (count - 1)) + w * 0.06)
          .clamp(0.0, 1.0);
      final p = _at(limb.from, limb.ctrl, limb.to, t);
      final h = _heading(limb.from, limb.ctrl, limb.to, t);
      final along = atan2(h.dy, h.dx);
      final side = k.isEven ? 1.0 : -1.0;

      // Leaves point outward and forward, leaning further out nearer the tip.
      // The last term is the breeze: every leaf on its own phase, or the whole
      // tree waves like a single flag.
      final angle = along +
          side * (0.95 - 0.35 * t) +
          w * 0.22 +
          sin(phase + limb.seed * 0.7 + k * 0.9) * 0.16 * gust;
      final len = size * (0.72 + 0.42 * ((k % 3) / 2)) * (1 + w * 0.18);
      final stalk = p + Offset(cos(angle), sin(angle)) * (size * 0.10);
      canvas.drawPath(_leaf(stalk, angle, len),
          Paint()..color = _leafShade(shades, angle, limb.seed + k));
    }

    // A few at the very end, so a branch finishes in leaves, not in a point.
    for (var k = 0; k < 3; k++) {
      final h = _heading(limb.from, limb.ctrl, limb.to, 1);
      final angle = atan2(h.dy, h.dx) +
          (k - 1) * 0.55 +
          _wobble(limb.seed * 53 + k) * 0.2 +
          sin(phase + limb.seed * 0.7 + k) * 0.16 * gust;
      canvas.drawPath(_leaf(limb.to, angle, size * (0.85 + 0.2 * (k % 2))),
          Paint()..color = _leafShade(shades, angle, limb.seed + k + 1));
    }
  }

  /// Which green a leaf takes. The light comes from the upper left, so a leaf
  /// turned up towards it is paler and one hanging underneath is darker. This
  /// is the cheapest thing that stops a canopy looking like flat cut paper.
  Color _leafShade(List<Color> shades, double angle, int seed) {
    final up = -sin(angle) * 0.7 - cos(angle) * 0.3;
    if (up > 0.35) return shades[1];
    if (up < -0.35) return shades[2];
    return shades[seed % shades.length];
  }


  @override
  void paint(Canvas canvas, Size size) {
    final shape = data.shape;

    // Laid out once without drawing, so the extent is known before anything is
    // committed, then scaled to fit. The tree used to be clipped to the panel,
    // and a crown with a piece missing does not read as a big tree.
    final plan = _layout(shape, size);
    canvas.save();
    canvas.translate(plan.offset.dx, plan.offset.dy);
    canvas.scale(plan.scale);
    _draw(canvas, plan);
    canvas.restore();
  }

  /// Where the soil surface sits inside the ground picture, as a fraction of
  /// its height. Measured from the art itself: the mound is opaque from 16%
  /// of the way down, and everything above that is transparent sky. Planting
  /// the trunk on the middle of the picture left it standing on air.
  static const _soilTop = 0.16;

  /// How far above the soil the lowest leaf or bud is kept. Enough that the
  /// near lip of the mound, painted afterwards, cannot clip it.
  static const _clearance = 10.0;

  /// How many boughs a trunk of this height can carry. One to begin with,
  /// and one more at each of these fractions of full growth.
  /// The heights at which the trunk can carry another bough. The first three
  /// come almost at once — three fields are what everyone starts with, and a
  /// tree that would not show them is not showing the learner.
  static const _boughAt = <double>[0.00, 0.05, 0.16, 0.38, 0.60, 0.84];

  int _boughsAt(double grown) {
    var n = 1;
    for (final at in _boughAt) {
      if (grown >= at) n++;
    }
    return n;
  }

  /// How tall the ground picture is drawn. It widens a little with the trunk,
  /// so a full-grown tree is not standing on a seedling's patch of soil.
  double get _groundH => 44 + 9 * girth;

  /// Works out where every limb goes, and how much of the panel that needs.
  _Plan _layout(TreeShape shape, Size size) {
    final groundY = size.height - 22;
    final cx = size.width / 2;
    final headroom = groundY - 10;
    // The line the soil actually reaches at the centre of the mound.
    final soil = groundY - _groundH / 2 + _groundH * _soilTop;

    final plan = _Plan(groundY: groundY, cx: cx, soil: soil);
    if (shape.isSeed) return plan;

    // A young stem is short but not invisible, and grows from there. The
    // first term is the part that is buried, added back so that what shows
    // above the soil is the same at every size — without it a seedling stood
    // with its crown in the earth.
    final trunkH = 13 + headroom * (0.16 + 0.50 * grown);
    // The foot is buried: the mound's near lip is painted over it afterwards,
    // so the stem goes into the ground instead of resting on top of it.
    final base = Offset(cx + 3, soil + 13);
    final top = Offset(cx - 2, base.dy - trunkH);
    // Girth has to stay in proportion to the mound it grows out of: a trunk
    // wider than its own ground reads as a stump, not as an old tree. It also
    // has to start as a stem rather than as a thin trunk — a seedling with a
    // woody bole is the thing that made the early stages look wrong.
    final w0 = min(1.7 + 13 * girth, size.width * 0.075);
    // A crown wider than it is tall: the shape of a tree left to spread.
    final reach = headroom * (0.16 + 0.36 * grown);

    plan
      ..base = base
      ..top = top
      ..w0 = w0
      // The trunk leans and straightens rather than standing to attention.
      ..trunkCtrl = Offset(cx + w0 * 0.55, base.dy - trunkH * 0.45);

    // One bough per field, as many as the trunk is tall enough to carry.
    //
    // The count used to be simply the number of fields with anything in
    // them, which on the first day is four — four green boughs, each leafy
    // from the bottom, all the same height on a stem of thirty pixels. That
    // is not a seedling; that is a clump of grass, and it is what somebody
    // looking at it said. So the first few come cheap and the rest wait for
    // height: widening out is what opening a field does, and a tree still
    // cannot hold a bough where it has no wood.
    final branches = shape.branches.take(_boughsAt(grown)).toList();
    if (branches.isEmpty) return plan;


    final busiest =
        branches.map((b) => b.answers).fold<int>(0, (a, b) => a > b ? a : b);

    Offset onTrunk(double t) => _at(base, plan.trunkCtrl, top, t);
    double lengthOf(Branch b) =>
        reach * (0.58 + 0.42 * branchGrowth(b.answers, busiest));

    void limb(Offset from, double angle, double len, double wa, double wb,
        int depth, int seed, double leafSize, bool dry, bool own) {
      if (len < 4) return;
      final dir = Offset(cos(angle), sin(angle));
      final to = from + dir * len;
      // Branches sweep: they leave the trunk heading out and finish heading up.
      final ctrl = from +
          dir * (len * 0.55) +
          Offset(_wobble(seed * 7) * len * 0.08, -len * 0.30);
      final l = (from: from, ctrl: ctrl, to: to, seed: seed, tip: depth == 0, own: own);
      plan.wood.add((l, wa, wb));
      // Where a limb leaves its parent it swells. Without the collar the join
      // looks like one stick laid across another.
      plan.collars.add((from, wa * 0.62));

      if (depth == 0) {
        plan.leafy.add((l, leafSize, dry));
        return;
      }
      plan.leafy.add((l, leafSize * 0.85, dry));

      // Thickness is shared out rather than halved twice over: a parent limb
      // carries about as much wood as its children put together.
      final childW = wb * 0.76;
      final lean = _wobble(seed * 43) * 0.14;
      final at = _at(from, ctrl, to, 0.86);
      final head = _heading(from, ctrl, to, 0.86);
      for (var k = 0; k < 2; k++) {
        final side = k == 0 ? -1.0 : 1.0;
        limb(
          at,
          atan2(head.dy, head.dx) +
              side * (0.34 + _wobble(seed * 71 + k).abs() * 0.26) +
              lean,
          len * (k == 0 ? 0.66 : 0.60) * (1 + _wobble(seed * 89 + k) * 0.12),
          childW,
          childW * 0.58,
          depth - 1,
          seed * 3 + k + 1,
          leafSize * 0.92,
          dry,
          own,
        );
      }
    }

    // Two sides of one tree. The samples grow low on the trunk, short and
    // near-level, and stop at leaves; the learner's own scenes grow above
    // them and make the crown, where the flowers and fruit are.
    final low = [for (final b in branches) if (!b.own) b];
    final high = [for (final b in branches) if (b.own) b];

    void bough(Branch b, int i, int n, {required bool own}) {
      final spread = n == 1 ? 0.5 : i / (n - 1);
      final t = own ? (n == 1 ? 0.72 : 0.50 + 0.45 * spread) : (n == 1 ? 0.30 : 0.20 + 0.18 * spread);
      final side = i.isEven ? -1.0 : 1.0;
      final angle = -pi / 2 +
          0.08 +
          side * (own ? (1.02 - 0.44 * t + _wobble(i * 17) * 0.10) : (1.28 + _wobble(i * 19) * 0.06));
      final from = onTrunk(t);
      final width = (w0 * (1 - 0.55 * t)) * (own ? 0.66 : 0.48);
      final len = lengthOf(b) * (own ? 1.0 : 0.55);
      final seedBase = (own ? 1000 : 0) + i * 100;

      final live = TurnType.values.where((x) => (b.twigs[x] ?? 0) > 0).toList();
      if (live.isEmpty) {
        // Nothing caught here yet: a bare twig with a bud on the end.
        final dir = Offset(cos(angle), sin(angle));
        final to = from + dir * (len * 0.8);
        plan.wood.add((
          (
            from: from,
            ctrl: from + dir * (len * 0.4) + const Offset(0, -6),
            to: to,
            seed: seedBase,
            tip: true,
            own: own
          ),
          width * 0.7,
          width * 0.3
        ));
        plan.buds.add((to, angle + pi / 2));
        return;
      }

      // Every six turns the bough forks once more, up to three times: the
      // change is visible within a week rather than a season.
      final depth = min(3, b.answers ~/ 6);
      final leafSize = 10.5 + min(b.growing, 10) * 0.5;
      for (var j = 0; j < live.length; j++) {
        final off = live.length == 1 ? 0.0 : (j / (live.length - 1)) - 0.5;
        limb(
          from,
          angle + off * 0.52,
          len * (0.72 + 0.28 * branchGrowth(b.twigs[live[j]]!, busiest)),
          width,
          width * 0.42,
          depth,
          seedBase + j * 7 + 3,
          leafSize,
          b.thirsty,
          own,
        );
      }
    }

    for (var i = 0; i < low.length; i++) {
      bough(low[i], i, low.length, own: false);
    }
    for (var i = 0; i < high.length; i++) {
      bough(high[i], i, high.length, own: true);
    }

    // The leader: the trunk carries on above the boughs and ends in leaves.
    final totalGrowing = branches.fold<int>(0, (a, b) => a + b.growing);
    limb(top, -pi / 2 + 0.06, reach * 0.5, w0 * 0.5, w0 * 0.18, 1, 5,
        10.5 + min(totalGrowing, 10) * 0.5, branches.every((b) => b.thirsty), high.isNotEmpty);

    // Nothing that grows is allowed below the soil line.
    //
    // A bough low on the trunk, angled outward and down, can put its tip —
    // and the bud or the leaves on that tip — into the earth. The lip of the
    // mound is then painted over half of it, which reads as a plant sunk in
    // the ground rather than standing on it. Lifting the tip and its control
    // point together keeps the curve, so a bough that wanted to droop simply
    // levels out at the ground instead of going through it.
    Offset above(Offset p) =>
        p.dy > plan.soil - _clearance ? Offset(p.dx, plan.soil - _clearance) : p;
    _Limb lift(_Limb l) => (
          from: l.from,
          ctrl: above(l.ctrl),
          to: above(l.to),
          seed: l.seed,
          tip: l.tip,
          own: l.own,
        );
    for (var i = 0; i < plan.wood.length; i++) {
      final (l, wa, wb) = plan.wood[i];
      plan.wood[i] = (lift(l), wa, wb);
    }
    for (var i = 0; i < plan.leafy.length; i++) {
      final (l, size, dry) = plan.leafy[i];
      plan.leafy[i] = (lift(l), size, dry);
    }
    for (var i = 0; i < plan.buds.length; i++) {
      final (at, tilt) = plan.buds[i];
      plan.buds[i] = (above(at), tilt);
    }

    // What all of that needs, leaf tips included, against what there is.

    var minX = plan.base.dx, maxX = plan.base.dx;
    var minY = plan.top.dy, maxY = plan.groundY + _groundH / 2;
    for (final (l, leafSize, _) in plan.leafy) {
      for (final p in [l.from, l.ctrl, l.to]) {
        minX = min(minX, p.dx - leafSize * 1.6);
        maxX = max(maxX, p.dx + leafSize * 1.6);
        minY = min(minY, p.dy - leafSize * 1.6);
        maxY = max(maxY, p.dy + leafSize * 1.6);
      }
    }
    final needW = maxX - minX, needH = maxY - minY;
    plan.scale =
        min(1.0, min(size.width / max(needW, 1), size.height / max(needH, 1)));
    if (plan.scale < 1) {
      // Centred on what is actually there, with the ground kept on the floor
      // of the panel. Scaling about the middle instead would lift the trunk
      // off its own shadow.
      plan.offset = Offset(
        size.width / 2 - (minX + maxX) / 2 * plan.scale,
        size.height - 2 - maxY * plan.scale,
      );
    }
    return plan;
  }

  /// Paints what the layout worked out. Wood first, then everything that hangs
  /// on it, so a leaf is never cut in half by a branch drawn later.
  void _draw(Canvas canvas, _Plan plan) {
    final shape = data.shape;

    _mound(canvas, Offset(plan.cx, plan.groundY), _groundH);

    // Nothing answered yet: the seed art on its own, sitting in the soil.
    if (shape.isSeed) {
      _image(canvas, art.sprout, Offset(plan.cx, plan.soil - 14), 34);
      return;
    }

    // No cast shadow at the foot. One was tried and taken out again: the
    // trunk is already planted inside the mound, and an ellipse over the
    // painted ground read as a pale smear rather than as shade.

    final stem = _stemColour;
    final wood = Paint()..color = stem;
    // The lit band starts out the same colour as the stem, so a green seedling
    // has no bark highlight down it, and gains one as the bark arrives.
    final lit = Paint()
      ..color = Color.lerp(
          stem, dark ? _barkLitOnDark : _barkLit, _woodiness)!;

    // The trunk spreads where it reaches the soil. Without this the stem ends
    // on the straight line where the mound's near lip covers it, and the tree
    // reads as a post pushed into the ground rather than as something grown
    // out of it. A green seedling gets none of it — seedlings have no buttress.
    _roots(canvas, plan.base.dx, plan.w0 * 0.75, plan.soil, wood);

    canvas.drawPath(
        _woodPath(plan.base, plan.trunkCtrl, plan.top, plan.w0 * 1.5,
            plan.w0 * 0.5),
        wood);
    // Light from the upper left: a band down the lit side of the trunk, offset
    // and tapered in the same proportion as the trunk itself so it can never
    // slide out past the silhouette and cut a wedge out of it.
    canvas.drawPath(
        _woodPath(
            plan.base + Offset(-plan.w0 * 1.5 * 0.20, 0),
            plan.trunkCtrl + Offset(-plan.w0 * 1.0 * 0.20, 0),
            plan.top + Offset(-plan.w0 * 0.5 * 0.20, 0),
            plan.w0 * 1.5 * 0.30,
            plan.w0 * 0.5 * 0.30),
        lit);

    for (final (from, r) in plan.collars) {
      canvas.drawCircle(from, r, wood);
    }
    for (final (l, wa, wb) in plan.wood) {
      canvas.drawPath(_woodPath(l.from, l.ctrl, l.to, wa, wb), wood);
    }

    for (final (at, tilt) in plan.buds) {
      _image(canvas, art.bud, at, 14, angle: tilt);
    }

    for (final (l, leafSize, dry) in plan.leafy) {
      // A young stem carries leaves nearly all the way down; a grown branch
      // keeps its inner length bare, the way a real bough does.
      final inner = 0.55 * _woodiness;
      _leaves(canvas, l, leafSize, dry, l.tip ? 0.22 * _woodiness : inner);
    }

    // Fruit: one per expression learned outright, spread across the twig ends
    // rather than piled on the first branch.
    // Fruit: one per scene of the learner's own answered entirely right, on
    // the twig ends of their own boughs.
    final fruit = shape.fruit;
    final ends = [for (final (l, s, _) in plan.leafy) if (l.tip && l.own) (l, s)];
    if (fruit > 0 && ends.isNotEmpty) {
      final show = min(fruit, min(ends.length, 9));
      for (var k = 0; k < show; k++) {
        final (l, leafSize) = ends[(k * 7 + 1) % ends.length];
        _image(canvas, art.fruit, l.to + Offset(0, leafSize * 0.6), 15);
      }
    }

    // Flowers: one per reply answered on a scene of the learner's own. The
    // samples grow leaves but never flower — that is the difference the tree
    // shows between practising on what came with the app and on what the
    // learner's own AI wrote for them.
    final flowers = shape.flowers;
    if (flowers > 0 && ends.isNotEmpty) {
      final show = min(flowers, min(ends.length, 12));
      for (var k = 0; k < show; k++) {
        final (l, leafSize) = ends[(k * 5 + 3) % ends.length];
        _flower(canvas, l.to + Offset(_wobble(k * 13) * 4, -leafSize * 0.3),
            4.2 + (k % 3) * 0.6);
      }
    }


    // The near lip of the mound, painted over the roots. This is the only
    // depth in the picture and the one place it is needed: the roots have to
    // be seen going into the ground rather than stopping on top of it.
    //
    // Only as wide as the roots. It used to be repainted across the whole
    // panel, which buried everything that hung below the soil line — and on
    // a young tree that is the leaves, which sit barely above it.
    final lip = plan.w0 * 0.75 * (1.1 + 2.2 * _woodiness) * 1.35 + 10;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(plan.cx - lip, plan.soil + 2,
        plan.cx + lip, plan.groundY + _groundH));
    _mound(canvas, Offset(plan.cx, plan.groundY), _groundH);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TreePainter old) =>
      old.grown != grown ||
      old.girth != girth ||
      old.data != data ||
      old.dark != dark;
}

/// Where every part of one tree goes, worked out before anything is drawn.
class _Plan {
  final double groundY;
  final double cx;
  /// The line the soil surface reaches at the middle of the mound.
  final double soil;

  Offset base = Offset.zero;
  Offset top = Offset.zero;
  Offset trunkCtrl = Offset.zero;
  double w0 = 0;
  double scale = 1;
  Offset offset = Offset.zero;

  final List<(_Limb, double, double)> wood = [];
  final List<(Offset, double)> collars = [];
  final List<(_Limb, double, bool)> leafy = [];
  final List<(Offset, double)> buds = [];

  _Plan({required this.groundY, required this.cx, required this.soil});
}

/// Whether the tree is allowed to move. A provider rather than a constant so
/// the widget tests can hold it still: a loop that never ends means
/// `pumpAndSettle` never returns.
final treeMotionProvider = Provider<bool>((ref) => true);

/// The wind, as two numbers the painter reads: how far through the swing it
/// is, and how hard it is blowing.
///
/// Driven by a timer rather than a ticker, and deliberately not at the screen
/// refresh rate. Leaves rocking at 24 frames a second look exactly like leaves
/// rocking at 120, and this canvas redraws every leaf on the tree.
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
final _stillAir = _Breeze();

/// One tree, drawn at a size of your choosing and held still.
///
/// For showing what the tree *becomes* rather than what it is: the growing
/// screen draws the same tree at six heights, so the thing being climbed
/// towards is a picture and not a promise.
class TreeStill extends ConsumerWidget {
  final TreeShape shape;
  final double height;
  const TreeStill({super.key, required this.shape, required this.height});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final art = ref.watch(treeArtProvider).value;
    if (art == null) return SizedBox(height: height);
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _TreePainter(
          data: TreeData(shape: shape),
          art: art,
          grown: trunkGrowth(shape.reached),
          girth: trunkGirth(shape.answers),
          dark: Theme.of(context).brightness == Brightness.dark,
          breeze: _stillAir,
        ),
      ),
    );
  }
}
