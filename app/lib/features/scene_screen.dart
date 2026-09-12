/// The conversation: read, listen, answer — on one screen that never scrolls.
///
/// A turn is three replies read first, then the line once, then a window to
/// answer in. Reading comes before the sound so that reading is not part of
/// the listening; the window closes so that answering is not something the
/// learner can take all evening over. Miss it and the same line comes again,
/// once, until the ladder takes that away too.
///
/// Answering is one tap, and then the screen waits. What it holds while it
/// waits is the only account of what went wrong the learner will get — the
/// line revealed, the word or the fact that went by them, and their own
/// language for as long as the ladder still gives it — so nothing moves on
/// until they press for the next one.
///
/// Nothing here needs a voice from the learner or a keyboard, and nothing
/// here judges: every turn carries one right index.
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
import '../domain/progress_service.dart';
import '../domain/scene.dart';
import '../domain/tree.dart' show treeLevel;
import 'tree_view.dart' show rankName, treeDataProvider;

/// A turn that has been answered, kept so it can stay in the conversation
/// above the one being taken. [picked] is null when the window closed on it.
class _Answered {
  final SceneCard card;
  final int? picked;
  final bool right;
  const _Answered(this.card, this.picked, this.right);
}

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

  /// The window closed and nothing was chosen. The clock is stopped: the
  /// replies are still there to be taken, and one press hears the line again.
  waiting,

  /// The line is coming again, once.
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

  /// The line was heard a second time before this was answered.
  bool _restated = false;

  /// The first window closed with nothing chosen. Kept apart from
  /// [_restated]: a learner can let the window go and then answer without
  /// asking to hear it again, and that is still not an answer inside the
  /// window.
  bool _windowGone = false;

  int _rightCount = 0;
  bool _saving = false;

  /// Right answers in a row, carried in from earlier conversations.
  int _combo = 0;
  int _bestComboHere = 0;

  /// Steps of the ladder that went up during this run.
  final _promoted = <LadderAxis>[];

  /// The turns already answered, oldest first. They stay on screen above the
  /// one being taken, so what has been said so far reads as one conversation
  /// rather than as a row of questions that happen to follow each other.
  final _thread = <_Answered>[];

  /// The thread is the only part that scrolls, and it is kept at the bottom:
  /// the line being answered is the one that has to be in front of them.
  final _scroll = ScrollController();

  /// What the turn just answered paid, and what the whole run has paid. The
  /// first drives the seed that flies to the counter; the second is what the
  /// counter reads while the screen is open.
  int _paid = 0;
  int _seedRun = 0;

  /// The window, drained as a bar so the time left is felt rather than read.
  late final AnimationController _window;

  /// The flight of the seeds from the reply that was taken to the counter.
  late final AnimationController _seedFlight;

  /// One grain per seed paid, up to [seedGrainCap]. Worked out at the moment
  /// of the answer, in the coordinates of the whole screen, because the reply
  /// they scatter from is whichever one was tapped.
  List<_Grain> _grains = const [];

  /// Where they all land.
  Offset? _seedTo;

  /// Questions answered before this one was opened, and whether this one is
  /// among them. The tree is read from the count of questions, so whether it
  /// has just been renamed is a question about that number and not about the
  /// ladder — which used to be asked of the ladder, back when the ladder was
  /// what made the tree grow.
  int _scenesBefore = 0;
  bool _firstTimeHere = false;

  final _bodyKey = GlobalKey();
  final _counterKey = GlobalKey();
  final _replyKeys = [for (var i = 0; i < repliesPerTurn; i++) GlobalKey()];
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
    _scenesBefore = ref.read(treeDataProvider).value?.shape.scenes ?? 0;
    _firstTimeHere = !(ref.read(sceneResultsProvider).value ?? const [])
        .any((r) => r.sceneId == widget.scene.id);
    _window = AnimationController(vsync: this, duration: Duration(milliseconds: _windowMs))
      ..addStatusListener((st) {
        if (st == AnimationStatus.completed && mounted) _windowClosed();
      });
    _seedFlight =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  }

  @override
  void dispose() {
    _beat?.cancel();
    _window.dispose();
    _seedFlight.dispose();
    _scroll.dispose();
    _speech.stop();
    super.dispose();
  }

  /// Works out where the seeds fly from and to.
  ///
  /// From the reply that was actually tapped, because that is the thing the
  /// learner just did; to the counter, because that is where they land. Both
  /// are read off the widgets rather than guessed, so the flight still points
  /// at the right row when the replies are different lengths or the list has
  /// been scrolled.
  ///
  /// One grain per seed, so twenty seeds is a handful and two is two â the
  /// size of what was earned is in the sight of it, not only in the number.
  /// Past [seedGrainCap] the handful stops growing and the number carries the
  /// rest; a hundred grains is a cloud, not a payment.
  void _aimSeeds(int? picked, int paid) {
    final body = _bodyKey.currentContext?.findRenderObject();
    final counter = _counterKey.currentContext?.findRenderObject();
    final reply = picked == null
        ? null
        : _replyKeys[picked].currentContext?.findRenderObject();
    if (body is! RenderBox || counter is! RenderBox || reply is! RenderBox) {
      _grains = const [];
      _seedTo = null;
      return;
    }
    Offset centreIn(RenderBox b) =>
        body.globalToLocal(b.localToGlobal(b.size.center(Offset.zero)));
    final start = centreIn(reply);
    _seedTo = centreIn(counter);

    // Seeded off the answer so a grain keeps its own path for the whole
    // flight rather than being rescattered on every frame.
    final rnd = Random(_index * 31 + (picked ?? 0) * 7 + paid);
    final n = min(paid, seedGrainCap);
    final w = reply.size.width * 0.38;
    final h = reply.size.height * 0.30;
    _grains = [
      for (var i = 0; i < n; i++)
        _Grain(
          // Scattered across the reply rather than stacked on its middle, so
          // they leave as a handful and not as one thing seen many times.
          from: start +
              Offset((rnd.nextDouble() * 2 - 1) * w, (rnd.nextDouble() * 2 - 1) * h),
          // Spread out along the way: the last to leave goes while the first
          // is already landing, which is what makes it a stream.
          delay: n == 1 ? 0 : (i / (n - 1)) * 0.42 + rnd.nextDouble() * 0.05,
          lift: 0.22 + rnd.nextDouble() * 0.30,
          sway: (rnd.nextDouble() * 2 - 1) * 40,
          size: 15 + rnd.nextDouble() * 9,
        ),
    ];
  }

  /// Keeps the newest turn in view. Called after the thread grows and after a
  /// line is revealed, both of which make it taller.

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  // ------------------------------------------------------------- the ladder

  /// How long there is to answer, stretched or shortened by the learner's
  /// own setting. One length for every turn: the gauge is marked in seed
  /// bands, and a mark that meant a different number of seconds from one turn
  /// to the next would be a mark nobody could learn.
  int get _windowMs =>
      (answerWindowMs * ref.read(settingsProvider).windowScale).round();
  double get _rate => speedAt(_ladder.currentOf(LadderAxis.speed));

  /// Whether a missed window is given a second hearing. The hardest steps of
  /// the replay axis take it away.
  bool get _replayAllowed => _ladder.currentOf(LadderAxis.replay) < 2;

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
  ///
  /// Nothing is spoken here. A voice that started on its own, saying a
  /// sentence the learner had just failed to catch, arrived while they were
  /// still working out what had happened — so the clock stops instead, and
  /// the second hearing waits for them to ask for it.
  Future<void> _windowClosed() async {
    if (_phase != _Phase.open) return;
    _windowGone = true;
    if (_replayAllowed && !_restated) {
      _buzz(HapticFeedback.selectionClick);
      setState(() => _phase = _Phase.waiting);
      return;
    }
    // No second hearing at this rung of the ladder. Counted as missed.
    await _answer(null);
  }

  /// The same line again, once, because they asked for it.
  Future<void> _replay() async {
    if (_phase != _Phase.waiting || _restated) return;
    _restated = true;
    setState(() => _phase = _Phase.restating);
    if (_speech.available) {
      await _speech.speak(_turn.line, rate: _rate);
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
    if (!mounted || _phase != _Phase.restating) return;
    _openWindow();
  }

  Future<void> _answer(int? i) async {
    if (_phase != _Phase.open &&
        _phase != _Phase.reading &&
        _phase != _Phase.waiting) {
      return;
    }
    // How much of the window was left, read before it is stopped. Speed is
    // what the seeds are for, so this is the number they are worked out from.
    final left = _phase == _Phase.open ? (1 - _window.value) : 0.0;
    // And whether the moment was caught at all, read here for the same
    // reason: by the time the answer is recorded the phase has moved on.
    final caught = _phase == _Phase.open && !_windowGone;
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
    // The line has just been revealed, so the bubble grew.
    _toBottom();

    final repo = ref.read(repositoryProvider);
    final out = await repo.recordTurn(
          sceneId: _card.scene.id,
          turn: _card.index,
          correct: right,
          missedSlot: i == null ? null : _turn.replies[i].missedSlot,
          // A fact about the clock, not about the answer. A wrong reply given
          // inside the window is exactly what the ladder's pass rate is there
          // to weigh; left out of the record, the buffer filled with nothing
          // but right answers and every window passed.
          inWindow: caught,
          review: _card.review,
          windowLeft: left,
        );
    if (!mounted) return;
    // All of this arrives after the await, so it needs its own setState: the
    // one above ran before the answer had been recorded. Without it the
    // counter kept its old total, the seed never flew, and a step of the
    // ladder went unmentioned — the screen was simply never told.
    setState(() {
      _ladder = out.ladder;
      _promoted.addAll(out.promoted);
      _paid = out.seeds;
      _seedRun += out.seeds;
    });
    if (out.seeds > 0) {
      ref.read(progressProvider.notifier).state = await repo.loadProgress();
      if (mounted) {
        _aimSeeds(i, out.seeds);
        _seedFlight.forward(from: 0);
      }
    }

    // Nothing moves on by itself. What is on screen now is the only
    // explanation of what went wrong that the learner will get, and reading
    // it takes as long as it takes.
  }

  void _advance() {
    _beat?.cancel();
    _paid = 0;
    // The turn just answered joins the conversation above, whether or not
    // there is another one after it: the result is read over the top of the
    // thread, and leaving early should not rub out what was said.
    _thread.add(_Answered(_card, _picked, _right));
    if (_index + 1 >= _cards.length) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _picked = null;
      _restated = false;
      _windowGone = false;
      _phase = _Phase.reading;
    });
    _toBottom();
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
    // What is said in the conversation stays English — the replies, the
    // verdict, the button — so the head is not switched mid-turn. What is
    // said *about* it keeps the interface language: the guide, the result,
    // and the two names beside the figures, which are labels on the screen
    // rather than anybody's words.
    final e = S('en');
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quit();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            key: _bodyKey,
            children: [
              _phase == _Phase.result
              ? _result(s, theme)
              : Column(
                  children: [
                    _topBar(e, theme),
                    // The conversation so far, and the line being answered at
                    // the foot of it. This is the only part that scrolls; the
                    // replies below must not be pushed off a small screen by
                    // a conversation that has been going a while.
                    //
                    // It grows upward from the bottom: the line being
                    // answered stays next to the replies it is answered
                    // with, rather than drifting to the top of an empty
                    // space on the first turn.
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) => SingleChildScrollView(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: ConstrainedBox(
                            // Clamped: on a short screen with a long verdict
                            // there is nothing left over, and a negative
                            // minimum is not a constraint Flutter accepts.
                            constraints: BoxConstraints(
                                minHeight: (box.maxHeight - 12).clamp(0.0, double.infinity)),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final past in _thread) ...[
                                  _pastTurn(s, theme, past),
                                  const SizedBox(height: 10),
                                ],
                                if (_card.review) _reviewTag(s, theme),
                                if (_windowGone && _phase != _Phase.done)
                                  _restateNote(s, theme),
                                _them(s, theme),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // The replies give way before the verdict does. On a small
                    // screen with three long replies and a verdict that names
                    // what went wrong, something has to; the replies are the
                    // part that can be scrolled without losing anything.
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.tutorial) _guide(s, theme),
                            _replies(s, e, theme),
                          ],
                        ),
                      ),
                    ),
                    _bottom(s, e, theme),
                  ],
                ),

              // The seeds, crossing the screen. They need a layer of their
              // own: they leave a reply near the bottom and land on a counter
              // in the corner, and nothing both of those sit inside is big
              // enough to fly them across.
              if (_seedTo != null && _grains.isNotEmpty)
                _SeedShower(grains: _grains, to: _seedTo!, flight: _seedFlight),
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
          // What this run has earned. It sits here because it is where the
          // seeds fly to, and a number that is flown at has to be somewhere
          // the eye can find without leaving the conversation.
          _SeedCounter(
            key: _counterKey,
            balance: ref.watch(progressProvider).seeds,
            paid: _paid,
            grains: _grains,
            flight: _seedFlight,
          ),
          const SizedBox(width: 10),
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

  /// A turn already answered, as the two things that were said: their line,
  /// and the reply that went back. Dimmed, because it is over.
  ///
  /// There were dots here once, one per turn. The thread says where they are
  /// better than a row of dots could, and says it with the conversation
  /// rather than beside it.
  Widget _pastTurn(S s, ThemeData theme, _Answered past) {
    final turn = past.card.turn;
    final chosen = past.picked;
    return Opacity(
      // Dimmed, because it is over — there, but not competing with the line
      // being answered for the eye.
      opacity: 0.62,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _speakerLabel(s, theme, other: true),
          _bubble(
            theme,
            other: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(turn.line, style: theme.textTheme.bodyMedium),
                // What they said, in the learner's own language. The band is
                // the "so this is what I heard" that the next line answers.
                // It follows the same rung as the translation itself: at the
                // top of that axis nobody gets it back by scrolling up.
                if (turn.lineNative.isNotEmpty && _translationAfter != null) ...[
                  const SizedBox(height: 6),
                  _heardBand(s, theme, turn.lineNative),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          _speakerLabel(s, theme, other: false),
          _bubble(
            theme,
            other: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // What they actually chose, when they chose anything.
                if (chosen != null)
                  _saidLine(theme, turn.replies[chosen].text, right: past.right),
                if (chosen == null)
                  _saidLine(theme, s.t('sceneWindowGone'), missed: true),
                // And the one that fitted, whenever that was not it, so the
                // conversation above still reads as English that works.
                if (!past.right) ...[
                  const SizedBox(height: 4),
                  _saidLine(theme, turn.replies[turn.answer].text, right: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One line inside a bubble, marked by how it went.
  Widget _saidLine(ThemeData theme, String text,
      {bool right = false, bool missed = false}) {
    final scheme = theme.colorScheme;
    final color = missed
        ? scheme.onSurfaceVariant
        : (right ? scheme.primary : scheme.error);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          missed
              ? Icons.timer_off_outlined
              : (right ? Icons.check : Icons.close),
          size: 14,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: missed ? color : null,
              fontStyle: missed ? FontStyle.italic : null,
            ),
          ),
        ),
      ],
    );
  }

  /// "You heard: …" — their own language, on the green.
  Widget _heardBand(S s, ThemeData theme, String text) {
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        s.t('heardBand', {'text': text}),
        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onPrimaryContainer),
      ),
    );
  }

  /// The name over a bubble. In the interface language: it names a figure on
  /// the screen, not something anybody said.
  Widget _speakerLabel(S s, ThemeData theme, {required bool other}) => Padding(
        padding: EdgeInsets.only(left: other ? 4 : 0, bottom: 2),
        child: Row(
          mainAxisAlignment:
              other ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            Text(
              s.t(other ? 'speakerOther' : 'speakerYou'),
              style: theme.textTheme.labelSmall?.copyWith(
                  color: other
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.primary),
            ),
          ],
        ),
      );

  /// A bubble, with the figure beside it on the side it belongs to.
  Widget _bubble(ThemeData theme, {required bool other, required Widget child}) {
    final scheme = theme.colorScheme;
    final body = Flexible(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
        decoration: BoxDecoration(
          color: other ? scheme.surfaceContainerHigh : scheme.primaryContainer
              .withValues(alpha: 0.28),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(other ? 4 : 16),
            topRight: Radius.circular(other ? 16 : 4),
            bottomLeft: const Radius.circular(16),
            bottomRight: const Radius.circular(16),
          ),
        ),
        child: child,
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: other
          ? [_Figure.small(other: true), const SizedBox(width: 8), body]
          : [body, const SizedBox(width: 8), _Figure.small(other: false)],
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

  /// Said when the window has closed on a turn and the line is about to come
  /// back in other words.
  ///
  /// It has to be said. What plays next is a *different* sentence, on purpose
  /// — repeating the first one would be a second listen, and a second listen
  /// is exactly what this practice does not give. But without a word of
  /// warning the learner hears an unfamiliar sentence and takes it for a new
  /// line they have already fallen behind on. It stays up through the second
  /// window, so it is still there to be read while they choose.
  Widget _restateNote(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.replay, size: 14, color: scheme.onTertiaryContainer),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                s.t('sceneRestateNote'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onTertiaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  /// The line being answered: the setting while nothing has been said, then
  /// the line itself once it has been answered. What was actually said is
  /// never shown before the answer — that is the whole exercise.
  ///
  /// Only the first turn carries the setting. After that the conversation
  /// above is the setting, and the line says instead that it is picking up
  /// what the learner just replied.
  Widget _them(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    final said = _phase == _Phase.done;
    final showing = said || !_speech.available;
    final opening = _thread.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _speakerLabel(s, theme, other: true),
        _bubble(
          theme,
          other: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!said && (!opening || _card.scene.settingNative.isNotEmpty)) ...[
                Text(
                  opening ? _card.scene.settingNative : s.t('afterYourReply'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
              ],
              if (showing)
                Text(_turn.line, style: theme.textTheme.titleSmall)
              else
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
              if (said) _native(s, theme),
            ],
          ),
        ),
      ],
    );
  }

  /// The line in the learner's own language, once the ladder still allows it.
  /// At the top of that axis it never comes.
  ///
  /// It arrives as the band it will keep: what appears the moment they answer
  /// is the same thing that stays above the next line, so nothing is
  /// re-styled under them as the conversation moves on.
  Widget _native(S s, ThemeData theme) {
    final wait = _translationAfter;
    if (wait == null || _turn.lineNative.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<void>(
      future: Future<void>.delayed(wait),
      builder: (context, snap) => AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: snap.connectionState == ConnectionState.done ? 1 : 0,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _heardBand(s, theme, _turn.lineNative),
        ),
      ),
    );
  }

  /// The three replies, fixed below the conversation. [s] names the figure,
  /// [e] asks the question — the label is about the screen, the question is
  /// part of the conversation.
  Widget _replies(S s, S e, ThemeData theme) {
    final scheme = theme.colorScheme;
    // Answerable while the window is open, and while it has closed and the
    // clock is stopped: letting the moment go is not the same as giving up.
    final live = _phase == _Phase.open || _phase == _Phase.waiting;
    final ticking = _phase == _Phase.open;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Figure.small(other: false),
            const SizedBox(width: 8),
            Text(e.t('sceneQ2'), style: theme.textTheme.titleSmall),
            const Spacer(),
            Text(s.t('speakerYou'),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 6),
        // The window, draining, marked off in the bands it pays in. Above the
        // replies rather than below them: the replies scroll on a short
        // screen, and a gauge that scrolls off is a gauge nobody uses. Only
        // while the window is open — a bar that is always there would be one
        // more thing to watch instead of listen to.
        SizedBox(
          height: 18,
          child: ticking
              ? AnimatedBuilder(
                  animation: _window,
                  builder: (context, _) => _WindowGauge(
                    left: 1 - _window.value,
                    dark: theme.brightness == Brightness.dark,
                    ground: scheme.surfaceContainerHighest,
                    ink: scheme.onSurfaceVariant,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < _turn.replies.length; i++) ...[
          _Option(
            key: _replyKeys[i],
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
      ],
    );
  }

  /// [s] is the interface language, [e] English. The verdict is part of the
  /// conversation and stays English; the account of what went wrong is about
  /// it, and is read in the learner's own language.
  Widget _bottom(S s, S e, ThemeData theme) {
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: switch (_phase) {
        _Phase.reading => FilledButton.icon(
            onPressed: _play,
            icon: const Icon(Icons.volume_up),
            label: Text(e.t('scenePlay')),
          ),
        _Phase.playing || _Phase.restating => Center(
            child: Text(
              e.t(_phase == _Phase.restating ? 'sceneAgain' : 'sceneListening'),
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        _Phase.open => Center(
            child: Text(e.t('sceneYourTurn'),
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary)),
          ),
        // The clock is stopped. Nothing happens until they ask for it.
        _Phase.waiting => FilledButton.icon(
            onPressed: _replay,
            icon: const Icon(Icons.replay),
            label: Text(s.t('sceneHearAgain')),
          ),
        _ => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _verdict(s, e, theme),
              const SizedBox(height: 8),
              // Nothing moves on by itself any more. What is above is the
              // only account of what went wrong that the learner gets, and
              // reading it takes as long as it takes.
              FilledButton(
                onPressed: _advance,
                child: Text(s.t('sceneNextButton')),
              ),
            ],
          ),
      },
    );
  }

  Widget _verdict(S s, S e, ThemeData theme) {
    final scheme = theme.colorScheme;
    final missed = _picked == null;
    final bg = _right ? scheme.primaryContainer : scheme.errorContainer;
    final fg = _right ? scheme.onPrimaryContainer : scheme.onErrorContainer;
    final slip = _whatWentWrong(s);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(missed ? Icons.timer_off_outlined : (_right ? Icons.check : Icons.close),
                  size: 18, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  missed
                      ? e.t('sceneWindowGone')
                      : (_right ? e.t('sceneCorrect') : e.t('sceneWrong')),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: fg, fontWeight: FontWeight.w700),
                ),
              ),
              if (_paid > 0)
                Text('+$_paid',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: fg, fontWeight: FontWeight.w800)),
              if (_promoted.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(s.t('ladderUp'),
                    style: theme.textTheme.labelSmall?.copyWith(color: fg)),
              ],

            ],
          ),
          // Which word, or which fact, went by them. Without this a learner
          // is told they were wrong and left to find where, in a line they
          // heard once.
          if (slip != null) ...[
            const SizedBox(height: 6),
            Text(slip, style: theme.textTheme.bodySmall?.copyWith(color: fg)),
          ],
        ],
      ),
    );
  }

  /// What went by them, in their own language, said as plainly as the turn
  /// allows.
  ///
  /// Everything here was already known and never shown: a `keyword` turn
  /// carries the pair it turns on, a `polarity` turn the word that reverses
  /// it, and a wrong reply on a `multiFact` turn names the fact it dropped.
  String? _whatWentWrong(S s) {
    if (_right) return null;
    final t = _turn;
    switch (t.type) {
      case TurnType.keyword:
        if (t.keyWord.isEmpty || t.confusable.isEmpty) return null;
        return s.t('slipKeyword', {'heard': t.confusable, 'said': t.keyWord});
      case TurnType.polarity:
        if (t.keyWord.isEmpty) return null;
        return s.t('slipPolarity', {'word': t.keyWord});
      case TurnType.multiFact:
        final picked = _picked;
        final slot = picked == null ? null : t.replies[picked].missedSlot;
        final fact = slot == null
            ? null
            : t.facts.where((f) => f.slot == slot).firstOrNull;
        if (fact == null) return null;
        return s.t('slipFact', {'slot': fact.slot, 'said': fact.value});
    }
  }

  /// The end of a conversation.
  ///
  /// It used to be a score and two buttons on an empty screen, which is a
  /// strange thing to be handed after a conversation. What is here now is
  /// what was just done: the whole exchange, readable from the top — it was
  /// on screen a moment ago and there is no reason to take it away — with the
  /// score, what it earned, and anything the ladder did above it.
  Widget _result(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    // Only a question never answered before adds to the count, so only one of
    // those can move the tree along. A level is worth saying as much as a
    // name: the levels are what make the first fortnight worth turning up
    // for, and they arrive every question or two at the start.
    final grownTo = _scenesBefore + (_firstTimeHere ? 1 : 0);
    final stageUp = treeLevel(grownTo) > treeLevel(_scenesBefore);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: [
              Row(
                children: [
                  Text('$_rightCount / ${_cards.length}',
                      style: theme.textTheme.displaySmall),
                  const Spacer(),
                  if (_seedRun > 0)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text('🌱 +$_seedRun',
                          style: theme.textTheme.titleMedium?.copyWith(
                              color: scheme.primary, fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
              if (_bestComboHere >= 3) ...[
                const SizedBox(height: 6),
                Text('✦ ${s.t('comboLabel', {'n': _bestComboHere})}',
                    style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary)),
              ],
              if (_promoted.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(s.t('ladderUp'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text([for (final a in _promoted) s.t('axis_${a.name}')].join(' · '),
                    style: theme.textTheme.bodyMedium),
              ],
              if (stageUp) ...[
                const SizedBox(height: 10),
                Text(
                    s.t('treeStageUp', {'name': rankName(s, grownTo)}),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 18),
              Text(s.t('sceneReadBack'),
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              // The conversation itself, from the top: every turn, with what
              // was said, what went back, and what would have fitted.
              for (final past in _thread) ...[
                _pastTurn(s, theme, past),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
        ),
      ],
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
    super.key,
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


/// The seeds earned in this run. It swells for a moment as one lands on it.
/// What they have, in the corner, with what the turn just paid arriving on
/// it.
///
/// The number is the balance rather than the run, because the balance is
/// what the seeds are for: a field costs five hundred of them, and a total
/// that resets every conversation never gets near one. It counts up with the
/// grains as they land, so the number is seen to be made of them.
class _SeedCounter extends StatelessWidget {
  /// The balance after the payment, which is what the grains are adding up
  /// to.
  final int balance;
  final int paid;
  final List<_Grain> grains;
  final Animation<double> flight;
  const _SeedCounter({
    super.key,
    required this.balance,
    required this.paid,
    required this.grains,
    required this.flight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: flight,
      builder: (context, _) {
        final t = flight.value;
        final flying = paid > 0 && t > 0 && t < 1;
        // The grains are the payment: what has landed is on the number, and
        // what is still in the air is not.
        final landed = flying ? _landed(grains, t) : 1.0;
        final shown = balance - paid + (paid * landed).round();
        // Each arrival swells it a little; together they read as one swell
        // that rises with the stream and settles after the last grain.
        final swell = flying ? sin(landed * pi) * 0.9 : 0.0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12 + 0.10 * swell),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🌱', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    '$shown',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13 + 4 * swell,
                    ),
                  ),
                ],
              ),
            ),
            // What this turn paid, beside the balance for as long as the
            // verdict is up: the number moved, and this is by how much.
            if (paid > 0) ...[
              const SizedBox(width: 4),
              Text(
                '+$paid',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// At most this many grains fly, however much was paid. Past it the handful
/// stops growing and the number carries the rest.
const seedGrainCap = 24;

/// How long one grain is in the air, as a share of the whole flight. The
/// grains start spread out over the rest of it, so the last leaves while the
/// first is already landing.
const _grainSpan = 0.53;

/// One seed on its way to the counter: where it left from, when it left, and
/// the arc it takes. Each grain keeps its own so the handful arrives as a
/// scatter rather than as one thing seen many times.
class _Grain {
  final Offset from;
  final double delay;
  final double lift;
  final double sway;
  final double size;
  const _Grain({
    required this.from,
    required this.delay,
    required this.lift,
    required this.sway,
    required this.size,
  });

  /// How far along its own flight this grain is, at [t] of the whole.
  double at(double t) => ((t - delay) / _grainSpan).clamp(0.0, 1.0);
}

/// How many of [grains] have landed by [t]. The counter counts up with them.
double _landed(List<_Grain> grains, double t) {
  if (grains.isEmpty) return 1;
  var n = 0;
  for (final g in grains) {
    if (g.at(t) >= 1) n++;
  }
  return n / grains.length;
}

class _SeedShower extends StatelessWidget {
  final List<_Grain> grains;
  final Offset to;
  final Animation<double> flight;
  const _SeedShower({required this.grains, required this.to, required this.flight});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: flight,
        builder: (context, _) {
          final t = flight.value;
          if (t <= 0 || t >= 1) return const SizedBox.shrink();
          final out = <Widget>[];
          for (final g in grains) {
            final p = g.at(t);
            if (p <= 0 || p >= 1) continue;
            final e = Curves.easeInOut.transform(p);
            // The control point: between the two, lifted by a share of the
            // distance there is to cover and pushed sideways, so no two
            // grains take quite the same line.
            final lift = (g.from - to).distance * g.lift;
            final ctrl = Offset(
                (g.from.dx + to.dx) / 2 + g.sway, min(g.from.dy, to.dy) - lift);
            final a = g.from + (ctrl - g.from) * e;
            final b = ctrl + (to - ctrl) * e;
            final at = a + (b - a) * e;
            // Shrinks as it goes, the way something thrown away from you
            // does, and fades only at the very end so it is seen to arrive.
            final size = g.size * (1 - 0.35 * e);
            final fade = 1 - ((p - 0.85) / 0.15).clamp(0.0, 1.0);
            out.add(Positioned(
              left: at.dx - size / 2,
              top: at.dy - size / 2,
              child: IgnorePointer(
                child: Opacity(
                  opacity: fade,
                  child: Text('🌱', style: TextStyle(fontSize: size)),
                ),
              ),
            ));
          }
          return out.isEmpty ? const SizedBox.shrink() : Stack(children: out);
        },
      );
}

/// The window, drawn as a bar marked off in the bands it pays in.
///
/// A bar that drains smoothly says how long is left and nothing else; the
/// marks say what the next second costs. The band the bar is still in gives
/// it its colour and its number, so the choice on offer — take another
/// moment, or answer now for ten more — is on the screen rather than in the
/// learner's head. The mark at the ladder's line is drawn heavier: above it
/// an answer counts towards the climb, below it only towards the balance.
class _WindowGauge extends StatelessWidget {
  /// How much of the window is left, 1 down to 0.
  final double left;
  final bool dark;
  final Color ground;
  final Color ink;
  const _WindowGauge({
    required this.left,
    required this.dark,
    required this.ground,
    required this.ink,
  });

  /// Fastest band first. Green while there is room, amber at the line the
  /// ladder draws, and the last band the colour of a moment nearly gone.
  static const _light = <Color>[
    Color(0xFF9E9E9E),
    Color(0xFFEF6C00),
    Color(0xFFF9A825),
    Color(0xFF7CB342),
    Color(0xFF2E7D32),
  ];
  static const _onDark = <Color>[
    Color(0xFF9E9E9E),
    Color(0xFFFFA726),
    Color(0xFFFFCA28),
    Color(0xFF9CCC65),
    Color(0xFF66BB6A),
  ];

  static Color colourOf(int band, bool dark) =>
      (dark ? _onDark : _light)[(band - 1).clamp(0, seedBands - 1)];

  @override
  Widget build(BuildContext context) {
    final band = seedBandOf(left);
    final colour = colourOf(band, dark);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SizedBox(
            height: 10,
            child: CustomPaint(
              painter: _GaugePainter(left: left, colour: colour, ground: ground, ink: ink),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // What answering now is worth. It steps rather than slides, because a
        // number that changes every frame cannot be aimed at.
        Text('🌱${seedFloor + (band - 1) * seedPerBand}',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: colour, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double left;
  final Color colour;
  final Color ground;
  final Color ink;
  const _GaugePainter(
      {required this.left, required this.colour, required this.ground, required this.ink});

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    final whole = RRect.fromRectAndRadius(Offset.zero & size, r);
    canvas.drawRRect(whole, Paint()..color = ground);

    if (left > 0) {
      canvas.save();
      canvas.clipRRect(whole);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width * left.clamp(0.0, 1.0), size.height),
        Paint()..color = colour,
      );
      canvas.restore();
    }

    // The marks, cut through both the filled part and the empty part so the
    // bands stay countable however much is left.
    for (var i = 1; i < seedBands; i++) {
      final x = size.width * i / seedBands;
      final onLadderLine = i == ladderBand - 1;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = ink.withValues(alpha: onLadderLine ? 0.85 : 0.35)
          ..strokeWidth = onLadderLine ? 2.4 : 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.left != left || old.colour != colour || old.ground != ground || old.ink != ink;
}
