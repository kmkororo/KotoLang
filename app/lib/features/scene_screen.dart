/// The scene: listen, choose, grow — all by swiping.
///
/// One exchange is four short steps: hear the line with the words hidden,
/// swipe the summary that says what was said, swipe the reply that answers
/// it, read why. A scene is two exchanges; a review owed from an earlier miss
/// comes first. Nothing here needs a voice from the learner or a keyboard,
/// and nothing here judges: every question has one right index.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/l10n/strings.dart';
import '../core/speech.dart';
import '../domain/progress_service.dart';
import '../domain/scene.dart';

/// One exchange to answer, with the scene it belongs to.
class SceneCard {
  final Scene scene;
  final int exchange;

  /// Owed from an earlier miss rather than part of today's scene.
  final bool review;
  const SceneCard(this.scene, this.exchange, {this.review = false});

  Exchange get x => scene.exchanges[exchange];
}

/// What one run of the screen came to.
class SceneRunResult {
  final int gistRight;
  final int replyRight;
  final int answered;
  final int seeds;
  final bool again;
  const SceneRunResult({
    required this.gistRight,
    required this.replyRight,
    required this.answered,
    required this.seeds,
    required this.again,
  });
}

enum _Phase { listen, gistAnswer, reply, replyAnswer, result }

class SceneScreen extends ConsumerStatefulWidget {
  final Scene scene;

  /// Exchanges owed from earlier misses, asked before the scene.
  final List<SceneCard> reviews;

  /// First run: a short explanation rides on each step.
  final bool tutorial;

  const SceneScreen({
    super.key,
    required this.scene,
    this.reviews = const [],
    this.tutorial = false,
  });

  @override
  ConsumerState<SceneScreen> createState() => _SceneScreenState();
}

class _SceneScreenState extends ConsumerState<SceneScreen> {
  late final SpeechService _speech;
  late final List<SceneCard> _cards;
  int _index = 0;
  _Phase _phase = _Phase.listen;

  bool _revealed = false;
  bool _peeked = false;
  int? _gistPick;
  int? _replyPick;

  int _gistRight = 0;
  int _replyRight = 0;
  int _seedsEarned = 0;
  bool _saving = false;

  SceneCard get _card => _cards[_index];
  Exchange get _x => _card.x;

  @override
  void initState() {
    super.initState();
    _speech = ref.read(speechProvider);
    _cards = [
      ...widget.reviews,
      for (var i = 0; i < widget.scene.exchanges.length; i++) SceneCard(widget.scene, i),
    ];
    // Without a voice the words have to be on screen from the start; that is
    // not a peek, there was nothing else to hear.
    _revealed = !_speech.available;
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  void _play() {
    if (!mounted || !_speech.available) return;
    _speech.speak(
      _x.line,
      rate: ref.read(settingsProvider).rate,
      voice: _speech.voiceFor(_card.scene.id.hashCode),
    );
  }

  void _buzz(void Function() f) {
    if (ref.read(settingsProvider).haptics) f();
  }

  void _toggleReveal() {
    setState(() => _revealed = !_revealed);
    if (_revealed && _speech.available && _phase == _Phase.listen) _peeked = true;
  }

  // ------------------------------------------------------------- answering

  void _pickGist(int i) {
    if (_phase != _Phase.listen) return;
    final ok = i == _x.gist.answer;
    _buzz(ok ? HapticFeedback.mediumImpact : HapticFeedback.heavyImpact);
    setState(() {
      _gistPick = i;
      _revealed = true; // the words come out once the ear has been tested
      _phase = _Phase.gistAnswer;
    });
  }

  void _pickReply(int i) {
    if (_phase != _Phase.reply) return;
    final ok = i == _x.reply.answer;
    _buzz(ok ? HapticFeedback.mediumImpact : HapticFeedback.heavyImpact);
    setState(() {
      _replyPick = i;
      _phase = _Phase.replyAnswer;
    });
  }

  /// A tap anywhere moves on from an answer.
  Future<void> _advance() async {
    switch (_phase) {
      case _Phase.gistAnswer:
        setState(() => _phase = _Phase.reply);
      case _Phase.replyAnswer:
        await _settleExchange();
      default:
        break;
    }
  }

  Future<void> _settleExchange() async {
    if (_saving) return;
    final gistOk = _gistPick == _x.gist.answer;
    final replyOk = _replyPick == _x.reply.answer;
    setState(() => _saving = true);
    await ref.read(repositoryProvider).recordSceneExchange(
          sceneId: _card.scene.id,
          exchange: _card.exchange,
          gistOk: gistOk,
          replyOk: replyOk,
          peeked: _peeked,
          review: _card.review,
        );
    if (!mounted) return;
    _gistRight += gistOk ? 1 : 0;
    _replyRight += replyOk ? 1 : 0;

    if (_index + 1 < _cards.length) {
      setState(() {
        _saving = false;
        _index += 1;
        _phase = _Phase.listen;
        _gistPick = null;
        _replyPick = null;
        _revealed = !_speech.available;
        _peeked = false;
      });
      _play();
      return;
    }

    // The scene is finished: the day counts, the Seeds are paid.
    final res = await ref
        .read(repositoryProvider)
        .completeScene(gistRight: _gistRight, replyRight: _replyRight);
    if (!mounted) return;
    ref.read(progressProvider.notifier).state = res.progress;
    _speech.stop();
    setState(() {
      _saving = false;
      _seedsEarned = res.seeds;
      _phase = _Phase.result;
    });
  }

  Future<void> _quit() async {
    final s = ref.read(stringsProvider);
    if (_phase == _Phase.result || _index == 0 && _phase == _Phase.listen) {
      Navigator.pop(context);
      return;
    }
    final ok = await confirm(
      context,
      title: s.t('quitTitle'),
      body: s.t('sceneQuitBody'),
      confirmLabel: s.t('quitConfirm'),
      cancelLabel: s.t('cancel'),
      destructive: false,
    );
    if (ok && mounted) Navigator.pop(context);
  }

  void _finish(bool again) => Navigator.pop(
        context,
        SceneRunResult(
          gistRight: _gistRight,
          replyRight: _replyRight,
          answered: _cards.length,
          seeds: _seedsEarned,
          again: again,
        ),
      );

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final answering = _phase == _Phase.gistAnswer || _phase == _Phase.replyAnswer;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quit();
      },
      child: Scaffold(
        body: SafeArea(
          child: GestureDetector(
            // The whole screen is the "next" button after an answer: on a
            // train nobody wants to find a control.
            behavior: HitTestBehavior.opaque,
            onTap: answering && !_saving ? _advance : null,
            child: Column(
              children: [
                _topBar(theme),
                Expanded(
                  child: _phase == _Phase.result
                      ? _result(s, theme)
                      : ListView(
                          key: ValueKey('$_index/${_phase.name}'),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          children: [
                            if (widget.tutorial) _guide(s, theme),
                            if (_card.review) _reviewTag(s, theme),
                            _lineCard(s, theme),
                            const SizedBox(height: 16),
                            ..._question(s, theme),
                            const SizedBox(height: 18),
                            Text(
                              answering ? s.t('sceneTapNext') : s.t('sceneSwipeHint'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(ThemeData theme) {
    final mainCount = widget.scene.exchanges.length;
    final mainDone = (_index - widget.reviews.length).clamp(0, mainCount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(onPressed: _quit, icon: const Icon(Icons.close)),
          const Spacer(),
          // One dot per exchange of today's scene, filled as they are reached.
          for (var i = 0; i < mainCount; i++)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= mainDone && _index >= widget.reviews.length
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _reviewTag(S s, ThemeData theme) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Chip(
            label: Text(s.t('sceneReviewTag')),
            visualDensity: VisualDensity.compact,
          ),
        ),
      );

  Widget _guide(S s, ThemeData theme) {
    final key = switch (_phase) {
      _Phase.listen => 'tutListen',
      _Phase.gistAnswer || _Phase.replyAnswer => 'tutNext',
      _Phase.reply => 'tutReply',
      _Phase.result => 'tutResult',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(s.t(key),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onInverseSurface)),
    );
  }

  Widget _lineCard(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    final showWords = _revealed || _phase != _Phase.listen;
    return Card(
      color: scheme.surfaceContainerHigh,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_speech.available)
                  FilledButton.tonalIcon(
                    onPressed: _play,
                    icon: const Icon(Icons.volume_up),
                    label: Text(s.t('debateReplay')),
                  ),
                const Spacer(),
                if (_phase == _Phase.listen && _speech.available)
                  IconButton(
                    tooltip: s.t(_revealed ? 'debateHideText' : 'debateShowText'),
                    onPressed: _toggleReveal,
                    icon: Icon(_revealed ? Icons.visibility_off : Icons.visibility),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (showWords) ...[
              Text(_x.line, style: theme.textTheme.titleMedium),
              if (_phase != _Phase.listen && _x.lineNative.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(_x.lineNative,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ] else
              Text('· · · · · ·',
                  style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  List<Widget> _question(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    switch (_phase) {
      case _Phase.listen:
      case _Phase.gistAnswer:
        final answered = _phase == _Phase.gistAnswer;
        return [
          Text(s.t('sceneQ1'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (var i = 0; i < _x.gist.options.length; i++)
            _SwipeOption(
              key: ValueKey('g$_index-$i'),
              text: _x.gist.options[i],
              state: !answered
                  ? _OptionState.idle
                  : i == _x.gist.answer
                      ? _OptionState.correct
                      : i == _gistPick
                          ? _OptionState.wrong
                          : _OptionState.dim,
              onChosen: answered ? null : () => _pickGist(i),
            ),
          if (answered) _verdict(s, theme, _gistPick == _x.gist.answer, gistSeeds),
        ];
      case _Phase.reply:
      case _Phase.replyAnswer:
        final answered = _phase == _Phase.replyAnswer;
        return [
          Text(s.t('sceneQ2'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (var i = 0; i < _x.reply.options.length; i++) ...[
            _SwipeOption(
              key: ValueKey('r$_index-$i'),
              text: _x.reply.options[i].text,
              state: !answered
                  ? _OptionState.idle
                  : i == _x.reply.answer
                      ? _OptionState.correct
                      : i == _replyPick
                          ? _OptionState.wrong
                          : _OptionState.dim,
              onChosen: answered ? null : () => _pickReply(i),
            ),
            // Every reply gets its translation and its why once answered —
            // the wrong ones are where the learning is.
            if (answered)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
                child: Text(
                  [
                    if (_x.reply.options[i].native.isNotEmpty) _x.reply.options[i].native,
                    if (_x.reply.options[i].why.isNotEmpty) _x.reply.options[i].why,
                  ].join(' — '),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
          ],
          if (answered) _verdict(s, theme, _replyPick == _x.reply.answer, replySeeds),
        ];
      case _Phase.result:
        return const [];
    }
  }

  Widget _verdict(S s, ThemeData theme, bool ok, int seeds) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          ok
              ? '${s.t('sceneCorrect')} · +$seeds'
              : (_card.review ? s.t('sceneWrongAgain') : s.t('sceneWrong')),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: ok ? theme.colorScheme.primary : theme.colorScheme.error,
          ),
        ),
      );

  Widget _result(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    final total = _cards.length;
    final right = _gistRight + _replyRight;
    // The tree's reading of this scene: leaves for what was caught, flowers
    // for what was answered — and flowers only on the learner's own scenes.
    final bloom = !widget.scene.isBuiltin;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        if (widget.tutorial) _guide(s, theme),
        Text('$right / ${total * 2}',
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(s.t('sceneResultBreakdown', {'g': _gistRight, 'r': _replyRight, 'n': total}),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Text('+$_seedsEarned Seeds',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(color: scheme.primary)),
        const SizedBox(height: 16),
        Text(
          [
            s.t('sceneTwig'),
            if (_gistRight > 0) s.t('sceneLeaves', {'n': _gistRight}),
            if (bloom && _replyRight > 0) s.t('sceneFlowers', {'n': _replyRight}),
          ].join(' · '),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        if (widget.scene.isBuiltin) ...[
          const SizedBox(height: 6),
          Text(s.t('sceneSampleNote'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 32),
        FilledButton(onPressed: () => _finish(true), child: Text(s.t('sceneNext'))),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: () => _finish(false), child: Text(s.t('debateDone'))),
      ],
    );
  }
}

// ----------------------------------------------------------------- options

enum _OptionState { idle, correct, wrong, dim }

/// One choice, decided by a swipe to the right. A tap does nothing on
/// purpose: on a moving train a tap is what happens by accident, and a swipe
/// is what happens on purpose.
class _SwipeOption extends StatefulWidget {
  final String text;
  final _OptionState state;
  final VoidCallback? onChosen;
  const _SwipeOption({super.key, required this.text, required this.state, this.onChosen});

  @override
  State<_SwipeOption> createState() => _SwipeOptionState();
}

class _SwipeOptionState extends State<_SwipeOption> with SingleTickerProviderStateMixin {
  // Created in initState, not lazily: a `late final` controller first touched
  // in dispose() would be built while the tree is being torn down.
  late final AnimationController _ctl;
  double _dx = 0;
  bool _fired = false;

  /// How far the row has to travel, as a share of its width, to count.
  static const _threshold = 0.38;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _set(double v) {
    if (mounted) setState(() => _dx = v);
  }

  void _onUpdate(DragUpdateDetails d) {
    if (widget.onChosen == null || _fired) return;
    setState(() => _dx = (_dx + d.delta.dx).clamp(0.0, 1000.0));
  }

  void _onEnd(DragEndDetails d, double width) {
    if (widget.onChosen == null || _fired) return;
    final far = _dx > width * _threshold || d.primaryVelocity != null && d.primaryVelocity! > 900;
    if (far) {
      _fired = true;
      // Slide the rest of the way, then report. The answer lands as the row
      // finishes moving, which is what makes the swipe feel like sending.
      final start = _dx;
      final anim = Tween<double>(begin: start, end: width).animate(_ctl);
      void tick() => _set(anim.value);
      anim.addListener(tick);
      _ctl.forward(from: 0).whenComplete(() {
        anim.removeListener(tick);
        widget.onChosen?.call();
      });
    } else {
      final start = _dx;
      final anim = Tween<double>(begin: start, end: 0.0).animate(
          CurvedAnimation(parent: _ctl, curve: Curves.easeOut));
      void tick() => _set(anim.value);
      anim.addListener(tick);
      _ctl.forward(from: 0).whenComplete(() => anim.removeListener(tick));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, border, fg) = switch (widget.state) {
      _OptionState.idle => (scheme.surface, scheme.outlineVariant, scheme.onSurface),
      _OptionState.correct => (scheme.primaryContainer, scheme.primary, scheme.onPrimaryContainer),
      _OptionState.wrong => (scheme.errorContainer, scheme.error, scheme.onErrorContainer),
      _OptionState.dim => (scheme.surface, scheme.outlineVariant, scheme.onSurfaceVariant),
    };
    final live = widget.onChosen != null;

    return LayoutBuilder(builder: (context, box) {
      final width = box.maxWidth;
      final progress = (_dx / (width * _threshold)).clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: live ? _onUpdate : null,
          onHorizontalDragEnd: live ? (d) => _onEnd(d, width) : null,
          child: Stack(
            children: [
              // The track that shows through as the row slides: a hint of
              // where it is going, growing surer with the distance.
              if (live)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: scheme.primaryContainer.withValues(alpha: 0.35 + 0.65 * progress),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 18),
                    child: Icon(Icons.arrow_forward, color: scheme.primary),
                  ),
                ),
              Transform.translate(
                offset: Offset(_dx, 0),
                child: Opacity(
                  opacity: widget.state == _OptionState.dim ? 0.55 : 1,
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(widget.text, style: TextStyle(fontSize: 15, color: fg)),
                        ),
                        if (widget.state == _OptionState.correct)
                          Icon(Icons.check_circle, color: scheme.primary),
                        if (widget.state == _OptionState.wrong)
                          Icon(Icons.cancel, color: scheme.error),
                        if (live)
                          Icon(Icons.chevron_right, color: scheme.outlineVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ---------------------------------------------------------------- launcher

/// Which scene to open now: one never done before the rest, otherwise the
/// one done longest ago. Built-ins and the learner's own are treated alike
/// here; who made a scene decides what blooms, not when it comes up.
Scene? pickScene(List<Scene> scenes, List<SceneResult> results) {
  final open = scenes.where((s) => !s.disabled && s.exchanges.isNotEmpty).toList();
  if (open.isEmpty) return null;
  final last = <String, int>{};
  for (final r in results) {
    if (r.review) continue;
    last[r.sceneId] = r.at > (last[r.sceneId] ?? 0) ? r.at : (last[r.sceneId] ?? 0);
  }
  open.sort((a, b) => (last[a.id] ?? 0).compareTo(last[b.id] ?? 0));
  return open.first;
}

/// Opens today's scene, with any reviews owed in front of it, and the next
/// one if asked. Loops rather than recurses so a run of "next scene" does not
/// stack finished screens.
///
/// [all] is every scene the learner has — their own and the built-ins — so
/// the caller decides what counts; this only chooses among them.
Future<void> startScene(
  BuildContext context,
  WidgetRef ref, {
  required List<Scene> all,
  bool tutorial = false,
  VoidCallback? onDone,
}) async {
  final repo = ref.read(repositoryProvider);
  final s = ref.read(stringsProvider);
  final byId = {for (final x in all) x.id: x};
  while (true) {
    final results = await repo.sceneResults();
    final scene = pickScene(all, results);
    if (!context.mounted) return;
    if (scene == null) {
      showToast(context, s.t('sceneNoneYet'));
      return;
    }
    final reviews = [
      for (final r in await repo.reviewsDue())
        if (byId[r.sceneId] case final sc? when r.exchange < sc.exchanges.length)
          SceneCard(sc, r.exchange, review: true)
    ];
    if (!context.mounted) return;
    final run = await Navigator.push<SceneRunResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SceneScreen(scene: scene, reviews: reviews, tutorial: tutorial),
      ),
    );
    if (!context.mounted) return;
    onDone?.call();
    tutorial = false;
    if (run?.again != true) return;
  }
}
