/// The conversation: read, listen, answer — on one screen that never scrolls.
///
/// A turn is three replies read first, then the line once, then a window to
/// answer in. Reading comes before the sound so that reading is not part of
/// the listening; the window closes so that answering is not something the
/// learner can take all evening over. Miss it and they say it again in other
/// words, which is what happens in a room, until the ladder takes that away
/// too.
///
/// Answering is one tap. What follows is a beat — right or wrong, and the
/// words in the learner's own language for as long as the ladder still gives
/// them — and then the next line starts over the end of it. Nothing here
/// needs a voice from the learner or a keyboard, and nothing here judges:
/// every turn carries one right index.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/l10n/strings.dart';
import '../core/speech.dart';
import '../domain/ladder.dart';
import '../domain/scene.dart';
import '../domain/tree.dart' show treeName;

/// One turn to answer, with the conversation it belongs to.
class SceneCard {
  final Scene scene;
  final int index;

  /// Owed from an earlier miss rather than part of today's conversation.
  final bool review;
  const SceneCard(this.scene, this.index, {this.review = false});

  Turn get turn => scene.turns[index];
}

/// What one run of the screen came to.
class SceneRunResult {
  final int right;
  final int answered;
  final List<LadderAxis> promoted;
  final bool again;
  const SceneRunResult({
    required this.right,
    required this.answered,
    this.promoted = const [],
    required this.again,
  });
}

/// Where a turn is. The replies are on screen from [reading] onward — only
/// what may be done with them changes.
enum _Phase {
  /// The replies are there to be read. Nothing has been said yet.
  reading,

  /// The line is being said. Too late to be reading, too early to answer.
  playing,

  /// The window is open.
  open,

  /// They are saying it again, in other words.
  restating,

  /// Answered, or the window closed on it.
  done,

  /// The conversation is over.
  result,
}

class SceneScreen extends ConsumerStatefulWidget {
  final Scene scene;

  /// Turns owed from earlier misses, taken before this conversation.
  final List<SceneCard> reviews;

  /// The walkthrough, which says what to do at each step the first time.
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

class _SceneScreenState extends ConsumerState<SceneScreen> with TickerProviderStateMixin {
  late final SpeechService _speech;
  late final List<SceneCard> _cards;
  late Ladder _ladder;

  int _index = 0;
  _Phase _phase = _Phase.reading;

  /// Which reply was taken, once one was.
  int? _picked;

  /// True while the answer given is the right one.
  bool _right = false;

  /// The line was said a second time before this was answered.
  bool _restated = false;

  int _rightCount = 0;
  bool _saving = false;

  /// Right answers in a row, carried in from earlier conversations.
  int _combo = 0;
  int _bestComboHere = 0;

  /// Steps of the ladder that went up during this run.
  final _promoted = <LadderAxis>[];


  /// The window, drained as a bar so the time left is felt rather than read.
  late final AnimationController _window;
  Timer? _beat;

  SceneCard get _card => _cards[_index];
  Turn get _turn => _card.turn;

  @override
  void initState() {
    super.initState();
    _speech = ref.read(speechProvider);
    _ladder = ref.read(ladderProvider).value ?? Ladder.empty;
    _cards = [
      ...widget.reviews,
      for (var i = 0; i < widget.scene.turns.length; i++) SceneCard(widget.scene, i),
    ];
    final stats = ref.read(skillStatsProvider).value;
    _combo = stats?.runs.combo ?? 0;
    _window = AnimationController(vsync: this, duration: Duration(milliseconds: _windowMs))
      ..addStatusListener((st) {
        if (st == AnimationStatus.completed && mounted) _windowClosed();
      });
  }

  @override
  void dispose() {
    _beat?.cancel();
    _window.dispose();
    _speech.stop();
    super.dispose();
  }

  // ------------------------------------------------------------- the ladder

  int get _windowMs => _card.scene.windowMs;
  double get _rate => speedAt(_ladder.currentOf(LadderAxis.speed));

  /// Whether a missed window is given a second chance. The two hardest steps
  /// of the replay axis take it away.
  bool get _restateAllowed =>
      _ladder.currentOf(LadderAxis.replay) < 2 && _turn.restate.isNotEmpty;

  /// How long the translation waits after an answer. The axis runs from at
  /// once to never, cut fine so no single step takes it all away.
  Duration? get _translationAfter {
    final step = _ladder.currentOf(LadderAxis.translation);
    if (step >= axisTop[LadderAxis.translation]!) return null;
    return Duration(milliseconds: step * 400);
  }

  // ------------------------------------------------------------- the run

  void _buzz(Future<void> Function() f) {
    if (ref.read(settingsProvider).haptics) f();
  }

  Future<void> _play() async {
    if (!mounted) return;
    setState(() => _phase = _Phase.playing);
    if (!_speech.available) {
      // No voice on this phone: the line is shown instead, and the window
      // opens straight away so the screen is still usable.
      _openWindow();
      return;
    }
    await _speech.speak(
      _turn.line,
      rate: _rate,
      voice: ref.read(settingsProvider).voicePerScene
          ? _speech.voiceFor(_card.scene.id.hashCode)
          : null,
    );
    if (!mounted || _phase != _Phase.playing) return;
    _openWindow();
  }

  void _openWindow() {
    setState(() => _phase = _Phase.open);
    _window
      ..duration = Duration(milliseconds: _windowMs)
      ..forward(from: 0);
  }

  /// The window closed with nothing chosen.
  Future<void> _windowClosed() async {
    if (_phase != _Phase.open) return;
    if (_restateAllowed && !_restated) {
      _restated = true;
      setState(() => _phase = _Phase.restating);
      _buzz(HapticFeedback.selectionClick);
      if (_speech.available) {
        await _speech.speak(_turn.restate, rate: _rate);
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 900));
      }
      if (!mounted || _phase != _Phase.restating) return;
      _openWindow();
      return;
    }
    // Out of chances. Counted as missed, and the conversation moves on.
    await _answer(null);
  }

  Future<void> _answer(int? i) async {
    if (_phase != _Phase.open && _phase != _Phase.reading) return;
    _window.stop();
    _speech.stop();
    final right = i != null && i == _turn.answer;
    _combo = right ? _combo + 1 : 0;
    if (_combo > _bestComboHere) _bestComboHere = _combo;
    if (right) _rightCount++;
    _buzz(right
        ? (_combo >= 5 ? HapticFeedback.heavyImpact : HapticFeedback.mediumImpact)
        : HapticFeedback.heavyImpact);

    setState(() {
      _picked = i;
      _right = right;
      _phase = _Phase.done;
    });

    final out = await ref.read(repositoryProvider).recordTurn(
          sceneId: _card.scene.id,
          turn: _card.index,
          correct: right,
          missedSlot: i == null ? null : _turn.replies[i].missedSlot,
          inWindow: right && !_restated,
          review: _card.review,
        );
    if (!mounted) return;
    _ladder = out.ladder;
    _promoted.addAll(out.promoted);

    // The next line starts over the end of this one rather than after it.
    _beat = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) _advance();
    });
  }

  void _advance() {
    _beat?.cancel();
    if (_index + 1 >= _cards.length) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _picked = null;
      _restated = false;
      _phase = _Phase.reading;
    });
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    await ref.read(repositoryProvider).completeScene();
    if (!mounted) return;
    ref.invalidate(ladderProvider);
    setState(() {
      _phase = _Phase.result;
      _saving = false;
    });
  }

  void _leave({required bool again}) => Navigator.pop(
        context,
        SceneRunResult(
          right: _rightCount,
          answered: _cards.length,
          promoted: _promoted,
          again: again,
        ),
      );

  Future<void> _quit() async {
    final s = ref.read(stringsProvider);
    if (_index == 0 && _phase == _Phase.reading) {
      _leave(again: false);
      return;
    }
    final ok = await confirm(
      context,
      title: s.t('quitTitle'),
      body: s.t('sceneQuitBody'),
      confirmLabel: s.t('quitConfirm'),
      cancelLabel: s.t('cancel'),
    );
    if (ok && mounted) _leave(again: false);
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    // Inside the conversation everything is English — the labels, the
    // verdict — so the head never switches language mid-turn. The guide and
    // the result, which are about the conversation rather than in it, keep
    // the interface language.
    final e = S('en');
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quit();
      },
      child: Scaffold(
        body: SafeArea(
          child: _phase == _Phase.result
              ? _result(s, theme)
              : Column(
                  children: [
                    _topBar(e, theme),
                    _dots(theme),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.tutorial) _guide(s, theme),
                            if (_card.review) _reviewTag(e, theme),
                            _them(e, theme),
                            const SizedBox(height: 12),
                            Expanded(child: _replies(e, theme)),
                          ],
                        ),
                      ),
                    ),
                    _bottom(e, theme),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _topBar(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          IconButton(onPressed: _quit, icon: const Icon(Icons.close)),
          const Spacer(),
          // The run: shown from two, and it grows on the spot.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: Tween(begin: 1.4, end: 1.0).animate(anim), child: child),
            child: _combo >= 2
                ? _Chip(
                    key: ValueKey('c$_combo'),
                    text: '✦ ${s.t('comboLabel', {'n': _combo})}',
                    color: scheme.primary)
                : const SizedBox.shrink(key: ValueKey('c0')),
          ),
        ],
      ),
    );
  }

  /// How far through the conversation this is. One dot per turn, the one
  /// being taken larger. The learner is never told how many are left — the
  /// dots say where they are, not how far there is to go.
  Widget _dots(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _cards.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _index ? 9 : 7,
              height: i == _index ? 9 : 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= _index ? scheme.primary : scheme.outlineVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _guide(S s, ThemeData theme) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          switch (_phase) {
            _Phase.reading => s.t('tutRead'),
            _Phase.playing || _Phase.restating => s.t('tutListen'),
            _Phase.open => s.t('tutReply'),
            _ => s.t('tutResult'),
          },
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
        ),
      );

  Widget _reviewTag(S s, ThemeData theme) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 14, color: theme.colorScheme.tertiary),
            const SizedBox(width: 6),
            Text(s.t('sceneReviewTag'),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.tertiary)),
          ],
        ),
      );

  /// Their side: the setting while nothing has been said, then the line once
  /// it has been answered. What was actually said is never shown before the
  /// answer — that is the whole exercise.
  Widget _them(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    final said = _phase == _Phase.done;
    final showing = said || !_speech.available;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: 2),
          child: Text(s.t('speakerOther'),
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.tertiary)),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Figure.small(other: true),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_card.scene.settingNative.isNotEmpty && !said)
                      Text(_card.scene.settingNative,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    if (showing) ...[
                      if (_card.scene.settingNative.isNotEmpty && !said)
                        const SizedBox(height: 6),
                      Text(_turn.line, style: theme.textTheme.titleSmall),
                    ] else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          _phase == _Phase.playing || _phase == _Phase.restating
                              ? '· · · · · ·'
                              : '',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    if (said) _native(theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The line in the learner's own language, once the ladder still allows it.
  /// At the top of that axis it never comes.
  Widget _native(ThemeData theme) {
    final wait = _translationAfter;
    if (wait == null || _turn.lineNative.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<void>(
      future: Future<void>.delayed(wait),
      builder: (context, snap) => AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: snap.connectionState == ConnectionState.done ? 1 : 0,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(_turn.lineNative,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
      ),
    );
  }

  Widget _replies(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    final live = _phase == _Phase.open;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Figure.small(other: false),
            const SizedBox(width: 8),
            Text(s.t('sceneQ2'), style: theme.textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _turn.replies.length; i++) ...[
          _Option(
            text: _turn.replies[i].text,
            sub: _phase == _Phase.done && _translationAfter != null
                ? _turn.replies[i].native
                : '',
            // Dimmed while the line is being said: reading is over by then.
            dim: _phase == _Phase.playing || _phase == _Phase.restating,
            right: _phase == _Phase.done && i == _turn.answer,
            wrong: _phase == _Phase.done && i == _picked && !_right,
            onTap: live ? () => _answer(i) : null,
          ),
          const SizedBox(height: 8),
        ],
        const Spacer(),
        // The window, draining. Only while it is open — a bar that is always
        // there would be one more thing to watch instead of listen to.
        SizedBox(
          height: 4,
          child: live
              ? AnimatedBuilder(
                  animation: _window,
                  builder: (context, _) => LinearProgressIndicator(
                    value: 1 - _window.value,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: scheme.primary,
                  ),
                )
              : null,
        ),
      ],
    );
  }

  Widget _bottom(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: switch (_phase) {
        _Phase.reading => FilledButton.icon(
            onPressed: _play,
            icon: const Icon(Icons.volume_up),
            label: Text(s.t('scenePlay')),
          ),
        _Phase.playing || _Phase.restating => Center(
            child: Text(
              s.t(_phase == _Phase.restating ? 'sceneAgain' : 'sceneListening'),
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        _Phase.open => Center(
            child: Text(s.t('sceneYourTurn'),
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary)),
          ),
        _ => _verdict(s, theme),
      },
    );
  }

  Widget _verdict(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    final missed = _picked == null;
    final bg = _right ? scheme.primaryContainer : scheme.errorContainer;
    final fg = _right ? scheme.onPrimaryContainer : scheme.onErrorContainer;
    return GestureDetector(
      // Moving on early is allowed, but nothing has to be pressed: the next
      // line comes over the end of this on its own.
      onTap: _advance,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(missed ? Icons.timer_off_outlined : (_right ? Icons.check : Icons.close),
                size: 18, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                missed
                    ? s.t('sceneWindowGone')
                    : (_right ? s.t('sceneCorrect') : s.t('sceneWrong')),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: fg, fontWeight: FontWeight.w700),
              ),
            ),
            if (_promoted.isNotEmpty)
              Text(s.t('ladderUp'),
                  style: theme.textTheme.labelSmall?.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }

  Widget _result(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    final stageUp =
        treeName(_ladder.reached) > treeName(_ladder.reached - _promoted.length);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: [
          Text('$_rightCount / ${_cards.length}', style: theme.textTheme.displaySmall),
          const SizedBox(height: 10),
          if (_bestComboHere >= 3)
            Text('✦ ${s.t('comboLabel', {'n': _bestComboHere})}',
                style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary)),
          const SizedBox(height: 18),
          if (_promoted.isNotEmpty) ...[
            Text(s.t('ladderUp'),
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              [for (final a in _promoted) s.t('axis_${a.name}')].join(' · '),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
          ],
          if (stageUp)
            Text(s.t('treeStageUp', {'name': s.t('treeStage${treeName(_ladder.reached)}')}),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          FilledButton(
            onPressed: () => _leave(again: true),
            child: Text(s.t('sceneNext')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _leave(again: false),
            child: Text(s.t('finishSession')),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ pieces

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w700)),
      );
}

/// Who is speaking, as a small figure. Two of them, facing each other.
class _Figure extends StatelessWidget {
  final bool other;
  final double size;
  const _Figure.small({required this.other}) : size = 24;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = other ? scheme.tertiary : scheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, size: size * 0.62, color: color),
    );
  }
}

/// One reply, as a row that can be tapped.
class _Option extends StatelessWidget {
  final String text;
  final String sub;
  final bool dim;
  final bool right;
  final bool wrong;
  final VoidCallback? onTap;
  const _Option({
    required this.text,
    this.sub = '',
    this.dim = false,
    this.right = false,
    this.wrong = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final border = right
        ? scheme.primary
        : wrong
            ? scheme.error
            : scheme.outlineVariant;
    final fill = right
        ? scheme.primaryContainer.withValues(alpha: 0.5)
        : wrong
            ? scheme.errorContainer.withValues(alpha: 0.5)
            : Colors.transparent;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dim ? 0.45 : 1,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              border: Border.all(color: border, width: right || wrong ? 1.8 : 1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: theme.textTheme.bodyLarge),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(sub,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- launcher

/// Which conversation to open now: one never done, drawn at random, before
/// any that has been; among those done, the one done longest ago. Built-ins
/// and the learner's own are treated alike here; who wrote one decides what
/// blooms, not when it comes up.
Scene? pickScene(List<Scene> scenes, List<TurnResult> results, {Random? rng}) {
  final open = scenes.where((s) => !s.disabled && s.turns.isNotEmpty).toList();
  if (open.isEmpty) return null;
  final last = <String, int>{};
  for (final r in results) {
    if (r.review) continue;
    last[r.sceneId] = r.at > (last[r.sceneId] ?? 0) ? r.at : (last[r.sceneId] ?? 0);
  }
  final fresh = [for (final s in open) if (!last.containsKey(s.id)) s];
  if (fresh.isNotEmpty) return fresh[(rng ?? Random()).nextInt(fresh.length)];
  open.sort((a, b) => (last[a.id] ?? 0).compareTo(last[b.id] ?? 0));
  return open.first;
}

/// Opens today's conversation, with any turns owed in front of it, and the
/// next one if asked. Loops rather than recurses so a run of "next" does not
/// stack finished screens.
///
/// [all] is the set the caller wants to draw from — everything, one field,
/// one half of a field — so the caller decides what counts; this only chooses
/// among them.
Future<void> startScene(
  BuildContext context,
  WidgetRef ref, {
  required List<Scene> all,
  bool tutorial = false,
  VoidCallback? onDone,
}) async {
  final repo = ref.read(repositoryProvider);
  final s = ref.read(stringsProvider);
  final everything = await ref.read(allScenesProvider.future);
  final byId = {for (final x in everything) x.id: x, for (final x in all) x.id: x};
  if (!context.mounted) return;
  while (true) {
    final results = await repo.turnResults();
    final scene = pickScene(all, results);
    if (!context.mounted) return;
    if (scene == null) {
      showToast(context, s.t('sceneNoneYet'));
      return;
    }
    final reviews = [
      for (final r in await repo.reviewsDue())
        if (byId[r.sceneId] case final sc? when r.turn < sc.turns.length)
          SceneCard(sc, r.turn, review: true)
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
