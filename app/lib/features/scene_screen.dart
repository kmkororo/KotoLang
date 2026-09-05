/// The scene: listen, choose, grow.
///
/// One exchange is four short steps: hear the line with the words hidden,
/// choose the summary that says what was said, choose the reply that answers
/// it, read why. A scene is two exchanges; a review owed from an earlier miss
/// comes first. Above it all sit two figures — them and you — with the four
/// arrows of the scene between them, so it is always clear whose words these
/// are and how far along the exchange is. Nothing here needs a voice from the
/// learner or a keyboard, and nothing here judges: every question has one
/// right index.
library;

import 'dart:math';

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

  /// The row tapped but not yet confirmed.
  int? _pending;
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

  bool get _choosing => _phase == _Phase.listen || _phase == _Phase.reply;
  bool get _answered => _phase == _Phase.gistAnswer || _phase == _Phase.replyAnswer;

  void _select(int i) {
    if (!_choosing) return;
    _buzz(HapticFeedback.selectionClick);
    setState(() => _pending = i);
  }

  /// The confirm button: the tapped row becomes the answer.
  void _decide() {
    final i = _pending;
    if (i == null || !_choosing) return;
    final ok = i == (_phase == _Phase.listen ? _x.gist.answer : _x.reply.answer);
    _buzz(ok ? HapticFeedback.mediumImpact : HapticFeedback.heavyImpact);
    setState(() {
      _pending = null;
      if (_phase == _Phase.listen) {
        _gistPick = i;
        _revealed = true; // the words come out once the ear has been tested
        _phase = _Phase.gistAnswer;
      } else {
        _replyPick = i;
        _phase = _Phase.replyAnswer;
      }
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
        _pending = null;
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
            onTap: _answered && !_saving ? _advance : null,
            child: Column(
              children: [
                _topBar(theme),
                Expanded(
                  child: _phase == _Phase.result
                      ? _result(s, theme)
                      : ListView(
                          key: ValueKey('$_index/${_phase.name}'),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          children: [
                            _stage(s, theme),
                            const SizedBox(height: 12),
                            if (widget.tutorial) _guide(s, theme),
                            if (_card.review) _reviewTag(s, theme),
                            _lineCard(s, theme),
                            const SizedBox(height: 14),
                            ..._question(s, theme),
                            const SizedBox(height: 18),
                            Text(
                              _answered ? s.t('sceneTapNext') : s.t('sceneTapHint'),
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

  Widget _topBar(ThemeData theme) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
        child: Row(
          children: [
            IconButton(onPressed: _quit, icon: const Icon(Icons.close)),
            const Spacer(),
            if (_cards.length > 1)
              Text(
                '${_index + 1} / ${_cards.length}',
                style:
                    theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      );

  /// The two figures and the arrows between them. A scene is four arrows —
  /// their line, your reply, their line, your reply — and the one lit is the
  /// step being taken. A review card is a single exchange, so two arrows.
  Widget _stage(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    final arrows = _card.review ? 2 : widget.scene.exchanges.length * 2;
    final exchangeAt = _card.review ? 0 : _index - widget.reviews.length;
    final half = _phase == _Phase.listen || _phase == _Phase.gistAnswer ? 0 : 1;
    final now = exchangeAt * 2 + half;
    final otherOn = half == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _Figure(label: s.t('speakerOther'), other: true, lit: otherOn),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < arrows; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Icon(
                      i.isEven ? Icons.arrow_forward : Icons.arrow_back,
                      size: i == now ? 22 : 16,
                      color: i == now
                          ? (i.isEven ? _otherColor(theme) : scheme.primary)
                          : i < now
                              ? scheme.primary.withValues(alpha: 0.45)
                              : scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          _Figure(label: s.t('speakerYou'), other: false, lit: !otherOn),
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

  /// Their line: a bubble from the figure on the left. The second line of a
  /// scene says it follows the learner's own reply.
  Widget _lineCard(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    final showWords = _revealed || _phase != _Phase.listen;
    final followsReply = !_card.review && _card.exchange > 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Figure.small(other: true),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            color: scheme.surfaceContainerHigh,
            margin: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (followsReply)
                    Text(s.t('afterYourReply'),
                        style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                  Row(
                    children: [
                      if (_speech.available)
                        FilledButton.tonalIcon(
                          // The app theme gives FilledButton an infinite minimum
                          // width, which a Row cannot lay out.
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
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
                  const SizedBox(height: 6),
                  if (showWords) ...[
                    Text(_x.line, style: theme.textTheme.titleMedium),
                    if (_phase != _Phase.listen && _x.lineNative.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(_x.lineNative,
                          style:
                              theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ] else
                    Text('· · · · · ·',
                        style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// What was heard, carried into the reply question so the two halves read
  /// as one thought: "you heard this — so what do you say?"
  Widget _heard(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(s.t('heardBand', {'text': _x.gist.correct}),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onPrimaryContainer)),
          ),
        ],
      ),
    );
  }

  Widget _questionTitle(S s, ThemeData theme, String key) => Row(
        children: [
          _Figure.small(other: false),
          const SizedBox(width: 8),
          Text(s.t(key), style: theme.textTheme.titleSmall),
        ],
      );

  List<Widget> _question(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    switch (_phase) {
      case _Phase.listen:
      case _Phase.gistAnswer:
        final answered = _phase == _Phase.gistAnswer;
        return [
          _questionTitle(s, theme, 'sceneQ1'),
          const SizedBox(height: 8),
          for (var i = 0; i < _x.gist.options.length; i++)
            _Option(
              key: ValueKey('g$_index-$i'),
              text: _x.gist.options[i],
              state: !answered
                  ? (_pending == i ? _OptionState.selected : _OptionState.idle)
                  : i == _x.gist.answer
                      ? _OptionState.correct
                      : i == _gistPick
                          ? _OptionState.wrong
                          : _OptionState.dim,
              onTap: answered ? null : () => _select(i),
            ),
          if (!answered) _decideButton(s),
          if (answered) _verdict(s, theme, _gistPick == _x.gist.answer, gistSeeds),
        ];
      case _Phase.reply:
      case _Phase.replyAnswer:
        final answered = _phase == _Phase.replyAnswer;
        return [
          _heard(s, theme),
          _questionTitle(s, theme, 'sceneQ2'),
          const SizedBox(height: 8),
          for (var i = 0; i < _x.reply.options.length; i++) ...[
            _Option(
              key: ValueKey('r$_index-$i'),
              text: _x.reply.options[i].text,
              state: !answered
                  ? (_pending == i ? _OptionState.selected : _OptionState.idle)
                  : i == _x.reply.answer
                      ? _OptionState.correct
                      : i == _replyPick
                          ? _OptionState.wrong
                          : _OptionState.dim,
              onTap: answered ? null : () => _select(i),
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
          if (!answered) _decideButton(s),
          if (answered) _verdict(s, theme, _replyPick == _x.reply.answer, replySeeds),
        ];
      case _Phase.result:
        return const [];
    }
  }

  Widget _decideButton(S s) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: FilledButton(
          onPressed: _pending == null ? null : _decide,
          child: Text(s.t('sceneDecide')),
        ),
      );

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

/// The other side's colour: warm, against the app's own blue for "you", so
/// the two sides read apart at a glance in both themes.
Color _otherColor(ThemeData theme) =>
    theme.brightness == Brightness.dark ? const Color(0xFFD9A06C) : const Color(0xFFB9773A);

/// A person, faceless: them or you. No names, no titles — those would be
/// hints, and the scene is about listening.
class _Figure extends StatelessWidget {
  final String? label;
  final bool other;
  final bool lit;
  final double size;
  const _Figure({required this.label, required this.other, required this.lit}) : size = 40;
  const _Figure.small({required this.other})
      : label = null,
        lit = true,
        size = 26;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = other ? _otherColor(theme) : scheme.primary;
    final figure = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: lit ? 0.18 : 0.08),
        border: lit ? Border.all(color: color, width: 1.5) : null,
      ),
      child: Icon(Icons.person, size: size * 0.62, color: color.withValues(alpha: lit ? 1 : 0.5)),
    );
    if (label == null) return figure;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        figure,
        const SizedBox(height: 2),
        Text(label!,
            style: theme.textTheme.labelSmall?.copyWith(
                color: lit ? color : scheme.onSurfaceVariant,
                fontWeight: lit ? FontWeight.w700 : FontWeight.w400)),
      ],
    );
  }
}

// ----------------------------------------------------------------- options

enum _OptionState { idle, selected, correct, wrong, dim }

/// One choice: tap to select, confirm below. Two steps, so a knock on a
/// moving train does not answer for you.
class _Option extends StatelessWidget {
  final String text;
  final _OptionState state;
  final VoidCallback? onTap;
  const _Option({super.key, required this.text, required this.state, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, border, fg, width) = switch (state) {
      _OptionState.idle => (scheme.surface, scheme.outlineVariant, scheme.onSurface, 1.5),
      _OptionState.selected => (
          scheme.primaryContainer.withValues(alpha: 0.5),
          scheme.primary,
          scheme.onSurface,
          2.0
        ),
      _OptionState.correct => (scheme.primaryContainer, scheme.primary, scheme.onPrimaryContainer, 2.0),
      _OptionState.wrong => (scheme.errorContainer, scheme.error, scheme.onErrorContainer, 2.0),
      _OptionState.dim => (scheme.surface, scheme.outlineVariant, scheme.onSurfaceVariant, 1.5),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: width),
            ),
            child: Opacity(
              opacity: state == _OptionState.dim ? 0.55 : 1,
              child: Row(
                children: [
                  Expanded(child: Text(text, style: TextStyle(fontSize: 15, color: fg))),
                  if (state == _OptionState.selected)
                    Icon(Icons.radio_button_checked, color: scheme.primary),
                  if (state == _OptionState.idle && onTap != null)
                    Icon(Icons.radio_button_unchecked, color: scheme.outlineVariant),
                  if (state == _OptionState.correct) Icon(Icons.check_circle, color: scheme.primary),
                  if (state == _OptionState.wrong) Icon(Icons.cancel, color: scheme.error),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- launcher

/// Which scene to open now: one never done, drawn at random, before any that
/// has been; among those done, the one done longest ago. Built-ins and the
/// learner's own are treated alike here; who made a scene decides what
/// blooms, not when it comes up.
Scene? pickScene(List<Scene> scenes, List<SceneResult> results, {Random? rng}) {
  final open = scenes.where((s) => !s.disabled && s.exchanges.isNotEmpty).toList();
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

/// Opens today's scene, with any reviews owed in front of it, and the next
/// one if asked. Loops rather than recurses so a run of "next scene" does not
/// stack finished screens.
///
/// [all] is the set the caller wants to draw from — everything, one field,
/// one half of a field — so the caller decides what counts; this only
/// chooses among them.
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
