/// One set at a time: hear it, reply, guess what comes back, hear that.
///
/// The other person speaks first, at length, and nothing of what they say is
/// on screen. The three replies only appear once they have finished, so the
/// hearing is over before any reading starts; then there is a window to
/// answer in. Once answered, what they said is opened, and every wrong reply
/// shows the fact it got wrong — so a miss is explained by the line itself,
/// not by a verdict.
///
/// The right reply is then said, in the learner's own voice. Before the other
/// person answers it, the learner puts down a guess about what they will say,
/// from three summaries in their own language, and the answer settles it.
///
/// A line cut short — headphones pulled out, the sound taken by a call — is
/// not a line missed. The set stops, and starts that line again from the top
/// when asked; the clock, the ladder and the seeds never see it.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/feel.dart';
import '../core/l10n/strings.dart';
import '../core/speech.dart';
import '../domain/ladder.dart';
import '../domain/progress_service.dart';
import '../domain/scene.dart';
import '../domain/tree.dart' show treeLevel;
import 'tree_view.dart' show rankName, treeDataProvider;

/// One set to take, and whether it is owed from an earlier miss.
class SetCard {
  final Scene scene;
  final bool review;
  const SetCard(this.scene, {this.review = false});

  ReplyPredict get set => scene.set!;
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

enum _Step {
  /// Nothing said yet; one press starts it.
  ready,

  /// They are speaking. Nothing to read and nothing to press.
  listening,

  /// They have finished; a breath before the replies appear.
  gap,

  /// The window is open.
  replying,

  /// The sound was cut off. Waiting to start the line again.
  paused,

  /// Answered. What they said is open, and why each wrong reply was wrong.
  replied,

  /// The right reply, said in the learner's voice.
  saying,

  /// A guess is being put down.
  predicting,

  /// Their answer is being said.
  responding,

  /// Their answer is open and the guess settled.
  predicted,

  /// The run is over.
  summary,
}

/// The breath between their last word and the replies appearing.
const _gapAfterLine = Duration(milliseconds: 600);

class SceneScreen extends ConsumerStatefulWidget {
  /// The sets to take, owed ones first.
  final List<SetCard> queue;

  const SceneScreen({super.key, required this.queue});

  @override
  ConsumerState<SceneScreen> createState() => _SceneScreenState();
}

class _SceneScreenState extends ConsumerState<SceneScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final SpeechService _speech;
  late final Feel _feel;
  late final AudioGuard _guard;
  StreamSubscription<String>? _cuts;
  late Ladder _ladder;
  late ({Voice? partner, Voice? you, double partnerPitch, double youPitch}) _voices;

  int _index = 0;
  _Step _step = _Step.ready;

  /// The one second hearing, in other words, has been used on this set.
  bool _restated = false;

  int? _picked;
  bool _right = false;

  /// The guess put down, before it is settled.
  int? _tent;
  bool _hit = false;

  /// The words being said, and which of them is being said now.
  List<({String word, bool stressed})> _beats = const [];
  int _beat = -1;

  /// What the last answer paid, and the whole run.
  int _paid = 0;
  int _seedRun = 0;

  int _replyRight = 0;
  int _replyWrong = 0;
  int _replyRestated = 0;
  int _predictHit = 0;
  int _predictMiss = 0;
  final _promoted = <LadderAxis>[];

  /// Questions answered before the run, and how many of the run's are new —
  /// the tree grows by those.
  int _scenesBefore = 0;
  Set<String> _doneBefore = const {};
  int _firstTimes = 0;

  late final AnimationController _window;
  late final AnimationController _seedFlight;
  List<_Grain> _grains = const [];
  Offset? _seedTo;

  final _bodyKey = GlobalKey();
  final _counterKey = GlobalKey();
  final _optionKeys = [for (var i = 0; i < repliesPerTurn; i++) GlobalKey()];
  final _chat = ScrollController();

  /// The first question ever taken explains each step once, over the step
  /// itself. [_coaching] is whether this is that question; [_coached] the
  /// steps already explained.
  bool _coaching = false;
  final _coached = <String>{};

  /// The note for the step on screen, if one is still owed.
  String? get _coach {
    if (!_coaching) return null;
    final k = switch (_step) {
      _Step.ready => 'Listen',
      _Step.replying => 'Reply',
      _Step.replied => 'Result',
      _Step.predicting => 'Predict',
      _ => null,
    };
    return k == null || _coached.contains(k) ? null : k;
  }

  void _coachDone() {
    final k = _coach;
    if (k == null) return;
    setState(() => _coached.add(k));
    // The window was held while the reply was being explained.
    if (k == 'Reply' && _step == _Step.replying) _window.forward(from: 0);
    if (_coached.length == 4) _coachSeen();
  }

  /// The notes are shown once: all four read, they are done. Left part-way,
  /// the next question starts them again.
  void _coachSeen() {
    if (!_coaching) return;
    _coaching = false;
    updateSettings(ref, ref.read(settingsProvider).copyWith(coachSeen: true));
  }

  SetCard get _card => widget.queue[_index];
  ReplyPredict get _set => _card.set;

  int get _windowMs => (answerWindowMs * ref.read(settingsProvider).windowScale).round();
  double get _rate => speedAt(_ladder.currentOf(LadderAxis.speed));

  /// Whether a missed window gets the second hearing. The hardest steps of
  /// the replay axis take it away.
  bool get _replayAllowed => _ladder.currentOf(LadderAxis.replay) < 2;

  /// How long the translation waits after an answer; null at the top of the
  /// axis, where it never comes.
  Duration? get _translationAfter {
    final step = _ladder.currentOf(LadderAxis.translation);
    if (step >= axisTop[LadderAxis.translation]!) return null;
    return Duration(milliseconds: step * 400);
  }

  String get _line => _restated ? _set.paraphrase : _set.partner.text;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speech = ref.read(speechProvider);
    final settings = ref.read(settingsProvider);
    _feel = Feel(enabled: settings.haptics);
    _coaching = !settings.coachSeen;
    _guard = ref.read(audioGuardProvider);
    _cuts = _guard.cuts.listen((_) => _cut());
    _voices = _speech.pair(partner: settings.partnerVoice, you: settings.yourVoice);
    _ladder = ref.read(ladderProvider).value ?? Ladder.empty;
    _scenesBefore = ref.read(treeDataProvider).value?.shape.scenes ?? 0;
    _doneBefore = {
      for (final r in ref.read(sceneResultsProvider).value ?? const <TurnResult>[])
        r.sceneId
    };
    _window = AnimationController(vsync: this, duration: Duration(milliseconds: _windowMs))
      ..addStatusListener((st) {
        if (st == AnimationStatus.completed && mounted) _windowClosed();
      });
    _seedFlight =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cuts?.cancel();
    _guard.release();
    _window.dispose();
    _seedFlight.dispose();
    _chat.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Put away mid-line is a line not heard, the same as headphones out.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) _cut();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chat.hasClients) return;
      _chat.animateTo(
        _chat.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  // ------------------------------------------------------------ hearing

  List<({String word, bool stressed})> _beatsOf(String text, List<String> stress) {
    final keys = {for (final w in stress) stressKey(w)};
    return [
      for (final t in SpeechService.tokens(text)) (word: t.word, stressed: isStressed(keys, t.word)),
    ];
  }

  void _onWord(int i) {
    if (!mounted || i >= _beats.length) return;
    setState(() => _beat = i);
    _feel.word(stressed: _beats[i].stressed);
  }

  /// Their line, from the top. The replies appear only when the engine says
  /// it has finished — never on a guess of how long the line takes.
  Future<void> _listen() async {
    setState(() {
      _step = _Step.listening;
      _beats = _beatsOf(_line, _set.partner.stress);
      _beat = -1;
    });
    _toBottom();
    unawaited(_guard.hold());
    if (!_speech.available) {
      // No voice on this phone: the line is shown instead, and the window
      // opens straight away so the screen is still usable.
      _openWindow();
      return;
    }
    final said = await _speech.say(
      _line,
      rate: _rate,
      voice: _voices.partner,
      pitch: _voices.partnerPitch,
      onWord: _onWord,
    );
    if (!mounted || _step != _Step.listening || !said) return;
    setState(() {
      _step = _Step.gap;
      _beat = -1;
    });
    await Future<void>.delayed(_gapAfterLine);
    if (!mounted || _step != _Step.gap) return;
    _openWindow();
  }

  void _openWindow() {
    setState(() => _step = _Step.replying);
    _window.duration = Duration(milliseconds: _windowMs);
    _window.value = 0;
    // Held while the reply is explained, the first time.
    if (_coach == null) _window.forward(from: 0);
  }

  /// The window closed with nothing chosen: the second hearing, if there is
  /// one to give; otherwise the reply is missed.
  void _windowClosed() {
    if (_step != _Step.replying) return;
    if (_replayAllowed && !_restated) {
      _restate();
    } else {
      _answer(null);
    }
  }

  /// The line again, once, in other words — asked for, or because the window
  /// closed. A right reply after it pays the floor and no more.
  void _restate() {
    if (_restated || _step != _Step.replying) return;
    _window.stop();
    _restated = true;
    _replyRestated++;
    _feel.restate();
    _listen();
  }

  /// The sound was cut off while the line was being heard or answered. The
  /// clock stops and nothing is recorded; the line starts again from the top
  /// when they ask.
  void _cut() {
    if (_step != _Step.listening && _step != _Step.gap && _step != _Step.replying) return;
    _speech.stop();
    _window.stop();
    _guard.release();
    setState(() {
      _step = _Step.paused;
      _beat = -1;
    });
  }

  // ------------------------------------------------------------ answering

  Future<void> _answer(int? i) async {
    if (_step != _Step.replying) return;
    // Read before the window is stopped: speed is what the seeds are for.
    final left = 1 - _window.value;
    final clean = !_restated;
    _window.stop();
    unawaited(_guard.release());
    final card = _card;
    final right = i != null && i == _set.reply.answer;
    right ? _feel.right() : _feel.wrong();
    if (right) {
      _replyRight++;
    } else {
      _replyWrong++;
    }
    if (!card.review && !_doneBefore.contains(card.scene.id)) {
      _doneBefore = {..._doneBefore, card.scene.id};
      _firstTimes++;
    }
    setState(() {
      _picked = i;
      _right = right;
      _step = _Step.replied;
      _paid = 0;
    });
    _toBottom();

    final repo = ref.read(repositoryProvider);
    final out = await repo.recordTurn(
      sceneId: card.scene.id,
      turn: 0,
      correct: right,
      inWindow: clean,
      review: card.review,
      windowLeft: left,
    );
    if (!mounted) return;
    setState(() {
      _ladder = out.ladder;
      _promoted.addAll(out.promoted);
      _paid = out.seeds;
      _seedRun += out.seeds;
    });
    if (out.seeds > 0) await _pay(i, out.seeds);
  }

  Future<void> _pay(int? from, int paid) async {
    ref.read(progressProvider.notifier).state =
        await ref.read(repositoryProvider).loadProgress();
    if (!mounted) return;
    _aimSeeds(from, paid);
    _seedFlight.forward(from: 0);
  }

  /// The right reply, said back in the learner's own voice.
  Future<void> _say() async {
    if (_step != _Step.replied) return;
    setState(() {
      _step = _Step.saying;
      _paid = 0;
    });
    _toBottom();
    if (_speech.available) {
      await _speech.say(
        _set.reply.options[_set.reply.answer],
        voice: _voices.you,
        pitch: _voices.youPitch,
      );
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    if (!mounted || _step != _Step.saying) return;
    setState(() {
      _step = _Step.predicting;
      _tent = null;
    });
    _toBottom();
  }

  /// Their answer, which settles the guess.
  Future<void> _respond() async {
    if (_step != _Step.predicting || _tent == null) return;
    setState(() {
      _step = _Step.responding;
      _beats = _beatsOf(_set.response.text, _set.response.stress);
      _beat = -1;
    });
    _toBottom();
    if (_speech.available) {
      final said = await _speech.say(
        _set.response.text,
        rate: _rate,
        voice: _voices.partner,
        pitch: _voices.partnerPitch,
        onWord: _onWord,
      );
      if (!said) return;
    }
    if (!mounted || _step != _Step.responding) return;
    final hit = _tent == _set.predict.answer;
    hit ? _feel.right() : _feel.wrong();
    if (hit) {
      _predictHit++;
    } else {
      _predictMiss++;
    }
    setState(() {
      _hit = hit;
      _step = _Step.predicted;
      _beat = -1;
      _paid = 0;
    });
    _toBottom();
    final repo = ref.read(repositoryProvider);
    final paid = await repo.recordPrediction(
        sceneId: _card.scene.id, hit: hit, review: _card.review);
    // A set finished is a day studied, however it went.
    await repo.completeScene();
    if (!mounted) return;
    if (paid > 0) {
      setState(() {
        _paid = paid;
        _seedRun += paid;
      });
      await _pay(_tent, paid);
    } else {
      ref.read(progressProvider.notifier).state = await repo.loadProgress();
    }
  }

  void _next() {
    if (_index + 1 >= widget.queue.length) {
      _feel.finished();
      ref.invalidate(ladderProvider);
      setState(() => _step = _Step.summary);
      return;
    }
    setState(() {
      _index++;
      _step = _Step.ready;
      _restated = false;
      _picked = null;
      _right = false;
      _tent = null;
      _hit = false;
      _beats = const [];
      _beat = -1;
      _paid = 0;
    });
  }

  void _leave({required bool again}) => Navigator.pop(
        context,
        SceneRunResult(
          right: _replyRight,
          answered: _replyRight + _replyWrong,
          promoted: _promoted,
          again: again,
        ),
      );

  Future<void> _quit() async {
    final s = ref.read(stringsProvider);
    if (_step == _Step.summary || (_index == 0 && _step == _Step.ready)) {
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

  /// Where the seeds fly from — the option that earned them — and to.
  void _aimSeeds(int? from, int paid) {
    final body = _bodyKey.currentContext?.findRenderObject();
    final counter = _counterKey.currentContext?.findRenderObject();
    final option = from == null ? null : _optionKeys[from].currentContext?.findRenderObject();
    if (body is! RenderBox || counter is! RenderBox || option is! RenderBox) {
      _grains = const [];
      _seedTo = null;
      return;
    }
    Offset centreIn(RenderBox b) =>
        body.globalToLocal(b.localToGlobal(b.size.center(Offset.zero)));
    final start = centreIn(option);
    _seedTo = centreIn(counter);
    final rnd = Random(_index * 31 + (from ?? 0) * 7 + paid);
    final n = min(paid, seedGrainCap);
    final w = option.size.width * 0.38;
    final h = option.size.height * 0.30;
    _grains = [
      for (var i = 0; i < n; i++)
        _Grain(
          from: start +
              Offset((rnd.nextDouble() * 2 - 1) * w, (rnd.nextDouble() * 2 - 1) * h),
          delay: n == 1 ? 0 : (i / (n - 1)) * 0.42 + rnd.nextDouble() * 0.05,
          lift: 0.22 + rnd.nextDouble() * 0.30,
          sway: (rnd.nextDouble() * 2 - 1) * 40,
          size: 15 + rnd.nextDouble() * 9,
        ),
    ];
  }

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
          child: Stack(
            key: _bodyKey,
            children: [
              if (_step == _Step.summary)
                _summary(s, theme)
              else
                LayoutBuilder(
                  builder: (context, box) => Column(
                    children: [
                      _top(s, theme),
                      Expanded(
                        child: Stack(
                          children: [
                            _conversation(s, theme),
                            // The note for this step, over the conversation
                            // and pointing down at the part it is about.
                            if (_coach != null) ...[
                              Positioned.fill(
                                child: GestureDetector(
                                  onTap: () {},
                                  child: const ColoredBox(color: Color(0x47000000)),
                                ),
                              ),
                              Positioned(
                                left: 12,
                                right: 12,
                                bottom: 10,
                                child: _Coach(
                                  title: s.t(switch (_coach) {
                                    'Listen' => 'setCoachListenTitle',
                                    'Reply' => 'setCoachReplyTitle',
                                    'Result' => 'setCoachResultTitle',
                                    _ => 'setCoachPredictTitle',
                                  }),
                                  body: s.t(switch (_coach) {
                                    'Listen' => 'setCoachListenBody',
                                    'Reply' => 'setCoachReplyBody',
                                    'Result' => 'setCoachResultBody',
                                    _ => 'setCoachPredictBody',
                                  }),
                                  ok: s.t('setCoachOk'),
                                  onOk: _coachDone,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: box.maxHeight * 0.64),
                        // Seen, not yet touched, while its note is up.
                        child: AbsorbPointer(absorbing: _coach != null, child: _sheet(s, theme)),
                      ),
                    ],
                  ),
                ),
              if (_seedTo != null && _grains.isNotEmpty)
                _SeedShower(grains: _grains, to: _seedTo!, flight: _seedFlight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _top(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          IconButton(onPressed: _quit, icon: const Icon(Icons.close)),
          if (_card.review) ...[
            Icon(Icons.history, size: 16, color: scheme.tertiary),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              '${_card.scene.label} · ${_index + 1}/${widget.queue.length}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          _SeedCounter(
            key: _counterKey,
            balance: ref.watch(progressProvider).seeds,
            paid: _paid,
            grains: _grains,
            flight: _seedFlight,
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------- conversation

  Widget _conversation(S s, ThemeData theme) {
    final heard = _step.index >= _Step.replied.index;
    final hidden = !heard && _speech.available;
    final showFirst = _step != _Step.ready;
    final showYours = _step.index >= _Step.saying.index;
    final showSecond = _step == _Step.responding || _step == _Step.predicted;
    return ListView(
      controller: _chat,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      children: [
        if (showFirst)
          _Bubble(
            name: _set.partnerName,
            other: true,
            child: hidden
                ? _Hidden(
                    speaking: _step == _Step.listening && _speech.available,
                    label: _restated ? s.t('setRestatedMark') : '…',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Without a voice the line is read instead, and what is
                      // read is what would have been said.
                      Text(heard ? _set.partner.text : _line,
                          style: theme.textTheme.bodyMedium),
                      if (heard && _set.partner.native.isNotEmpty)
                        _Delayed(
                          key: ValueKey('pn$_index'),
                          wait: _translationAfter,
                          child: _NativeBand(text: _set.partner.native),
                        ),
                    ],
                  ),
          ),
        if (showYours)
          _Bubble(
            name: s.t('speakerYou'),
            other: false,
            child: Text(_set.reply.options[_set.reply.answer],
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onInverseSurface)),
          ),
        // Their next line, not yet said: the blank the guess goes into.
        if (_step == _Step.predicting)
          _NextLine(name: _set.partnerName, label: s.t('setNextLine')),
        if (showSecond)
          _Bubble(
            name: _set.partnerName,
            other: true,
            child: _step == _Step.responding && _speech.available
                ? const _Hidden(speaking: true, label: '…')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_set.response.text, style: theme.textTheme.bodyMedium),
                      if (_step == _Step.predicted && _tent != null) ...[
                        const SizedBox(height: 6),
                        _Gist(
                          hit: _hit,
                          text: s.t('setGist', {
                            'text': _set.predict.options[_tent!],
                            'verdict': _hit
                                ? s.t('setGistHit', {'n': predictSeeds})
                                : s.t('setGistMiss'),
                          }),
                        ),
                      ],
                      if (_step == _Step.predicted && _set.response.native.isNotEmpty)
                        _Delayed(
                          key: ValueKey('rn$_index'),
                          wait: _translationAfter,
                          child: _NativeBand(text: _set.response.native),
                        ),
                    ],
                  ),
          ),
      ],
    );
  }

  // ----------------------------------------------------------------- sheet

  Widget _sheet(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    final name = _set.partnerName;
    final (phase, title, sub) = switch (_step) {
      _Step.ready => ('', s.t('setReadyTitle'), ''),
      // Hearing and replying carry one line each and nothing more: the
      // screen is there to be listened past, not read.
      _Step.listening || _Step.gap => ('', s.t('setSpeakingTitle', {'name': name}), ''),
      _Step.replying => ('', s.t('setReplyTitle'), ''),
      _Step.paused => (s.t('setPausedPhase'), s.t('setPausedTitle'), s.t('setPausedSub')),
      _Step.replied => (
          '',
          _right
              ? s.t('setRight')
              : (_picked == null ? s.t('setTimeUp') : s.t('setWrong')),
          _right ? s.t('setRightSub') : s.t('setWrongSub'),
        ),
      _Step.saying => ('', s.t('setSayingTitle'), ''),
      _Step.predicting => ('', s.t('setPredictTitle'), ''),
      _Step.responding => ('', s.t('setRespondingTitle', {'name': name}), ''),
      _Step.predicted => (
          '',
          _hit ? s.t('setPredictHit') : s.t('setPredictMiss'),
          _hit ? '' : s.t('setPredictMissSub'),
        ),
      _Step.summary => ('', '', ''),
    };

    final speaking = _step == _Step.listening || _step == _Step.responding;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (phase.isNotEmpty)
            Text(phase,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.6)),
          Text(title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          if (sub.isNotEmpty)
            Text(sub,
                style:
                    theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          if (speaking && _beats.isNotEmpty) ...[
            const SizedBox(height: 8),
            _Beats(beats: _beats, now: _beat),
          ],
          if (_step == _Step.replying) ...[
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _window,
              builder: (context, _) => _BandGauge(left: 1 - _window.value),
            ),
          ],
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._options(s, theme),
                  if (_step == _Step.replied) _replyResult(s, theme),
                ],
              ),
            ),
          ),
          _buttons(s),
        ],
      ),
    );
  }

  List<Widget> _options(S s, ThemeData theme) {
    switch (_step) {
      case _Step.replying:
      case _Step.replied:
        final c = _set.reply;
        final open = _step == _Step.replied;
        return [
          for (var i = 0; i < c.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SetOption(
                key: _optionKeys[i],
                number: i + 1,
                text: c.options[i],
                right: open && i == c.answer,
                wrong: open && i == _picked && !_right,
                why: open && i != c.answer ? c.why[i] : '',
                onTap: _step == _Step.replying ? () => _answer(i) : null,
              ),
            ),
        ];
      case _Step.predicting:
      case _Step.responding:
      case _Step.predicted:
        final c = _set.predict;
        final open = _step == _Step.predicted;
        return [
          for (var i = 0; i < c.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SetOption(
                key: _optionKeys[i],
                number: i + 1,
                text: c.options[i],
                native: true,
                speaker: s.t('setSpeaker', {'name': _set.partnerName}),
                tentative: !open && i == _tent,
                tentLabel: s.t('setTentTag'),
                dim: _step == _Step.responding,
                right: open && i == c.answer,
                wrong: open && i == _tent && !_hit,
                why: open && i != c.answer ? c.why[i] : '',
                onTap: _step == _Step.predicting ? () => setState(() => _tent = i) : null,
              ),
            ),
        ];
      default:
        return const [];
    }
  }

  Widget _replyResult(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (_right && _paid > 0)
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: '+$_paid ',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              TextSpan(text: 'Seeds', style: theme.textTheme.bodySmall),
            ])),
          if (_right && _restated)
            _Pill(text: s.t('setFloorPill'), color: const Color(0xFFB06B0A)),
          if (!_right) _Pill(text: s.t('setReplyMissPill'), color: scheme.error),
          if (_promoted.isNotEmpty)
            Text(s.t('ladderUp'),
                style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary)),
        ],
      ),
    );
  }

  Widget _buttons(S s) {
    final last = _index + 1 >= widget.queue.length;
    Widget main(String label, VoidCallback? onPressed) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: FilledButton(onPressed: onPressed, child: Text(label)),
        );
    switch (_step) {
      case _Step.ready:
        return main(s.t('setListenButton'), _listen);
      case _Step.paused:
        return main(s.t('setResume'), _listen);
      case _Step.replying:
        if (!_replayAllowed || _restated) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: OutlinedButton.icon(
            onPressed: _restate,
            icon: const Icon(Icons.replay, size: 18),
            label: Text(s.t('setHearAgain')),
          ),
        );
      case _Step.replied:
        return main(s.t('setSayButton'), _say);
      case _Step.predicting:
        return main(s.t('setCheckButton'), _tent == null ? null : _respond);
      case _Step.predicted:
        return main(last ? s.t('setToSummary') : s.t('setNext'), _next);
      default:
        return const SizedBox.shrink();
    }
  }

  // --------------------------------------------------------------- summary

  Widget _summary(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    final grownTo = _scenesBefore + _firstTimes;
    final stageUp = treeLevel(grownTo) > treeLevel(_scenesBefore);
    Widget row(String label, String value) => Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
          child: Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Text(value,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        );
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            children: [
              Text(s.t('setSummaryPhase'),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.6)),
              Text(s.t('setSummaryTitle'),
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              row(s.t('setSumReply'), '$_replyRight／$_replyWrong（$_replyRestated）'),
              row(s.t('setSumPredict'), '$_predictHit／$_predictMiss'),
              row('Seeds', '+$_seedRun'),
              const SizedBox(height: 10),
              Text(s.t('setSumNote'),
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              if (_promoted.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(s.t('ladderUp'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800)),
                Text([for (final a in _promoted) s.t('axis_${a.name}')].join(' · '),
                    style: theme.textTheme.bodyMedium),
              ],
              if (stageUp) ...[
                const SizedBox(height: 12),
                Text(s.t('treeStageUp', {'name': rankName(s, grownTo)}),
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
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
                child: Text(s.t('setAgain')),
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

/// Colours that mean the same in both themes: right, the guess put down, and
/// the bands of the window from quick to late.
const _okColour = Color(0xFF3F9D5A);
const _tentColour = Color(0xFF3F7FD9);
const _bandColours = <Color>[
  Color(0xFF3F9D5A),
  Color(0xFF8CBF3F),
  Color(0xFFE3C12C),
  Color(0xFFE39B2C),
  Color(0xFFD9534F),
];

/// One of the two speaking: them on the left, the learner on the right.
class _Bubble extends StatelessWidget {
  final String name;
  final bool other;
  final Widget child;
  const _Bubble({required this.name, required this.other, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Align(
      alignment: other ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.86),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: BoxDecoration(
            color: other ? scheme.surfaceContainerLowest : scheme.inverseSurface,
            border: other ? Border.all(color: scheme.outlineVariant) : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(other ? 4 : 16),
              bottomRight: Radius.circular(other ? 16 : 4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: other
                          ? scheme.onSurfaceVariant
                          : scheme.onInverseSurface.withValues(alpha: 0.7))),
              const SizedBox(height: 2),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// What is said, before it may be read: a moving mark while it is being said,
/// and three dots.
class _Hidden extends StatelessWidget {
  final bool speaking;
  final String label;
  const _Hidden({required this.speaking, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (speaking) ...[const _Wave(), const SizedBox(width: 6)],
        Text(label,
            style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
      ],
    );
  }
}

class _Wave extends StatefulWidget {
  const _Wave();

  @override
  State<_Wave> createState() => _WaveState();
}

class _WaveState extends State<_Wave> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 4; i++)
              Container(
                width: 3,
                height: 4 + 10 * (0.5 + 0.5 * sin((_c.value - i * 0.17) * 2 * pi)),
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                    color: _tentColour, borderRadius: BorderRadius.circular(2)),
              ),
          ],
        ),
      );
}

/// Their words in the learner's language, once the ladder still gives them.
class _NativeBand extends StatelessWidget {
  final String text;
  const _NativeBand({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onPrimaryContainer)),
    );
  }
}

/// Shows [child] after [wait]; never, when [wait] is null.
class _Delayed extends StatefulWidget {
  final Duration? wait;
  final Widget child;
  const _Delayed({super.key, required this.wait, required this.child});

  @override
  State<_Delayed> createState() => _DelayedState();
}

class _DelayedState extends State<_Delayed> {
  bool _shown = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final wait = widget.wait;
    if (wait == null) return;
    if (wait == Duration.zero) {
      _shown = true;
    } else {
      _timer = Timer(wait, () {
        if (mounted) setState(() => _shown = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _shown ? widget.child : const SizedBox.shrink();
}

/// "Predicted: … → right / wrong", inside their answer.
class _Gist extends StatelessWidget {
  final bool hit;
  final String text;
  const _Gist({required this.hit, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = hit ? _okColour : theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 4),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: theme.textTheme.labelSmall?.copyWith(color: colour)),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
      );
}

/// One bar per word, the stressed ones taller; the one being said lit.
class _Beats extends StatelessWidget {
  final List<({String word, bool stressed})> beats;
  final int now;
  const _Beats({required this.beats, required this.now});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 3,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        for (var i = 0; i < beats.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: i == now ? 8 : 5,
            height: beats[i].stressed ? 20 : 8,
            decoration: BoxDecoration(
              color: i == now ? _tentColour : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

/// The window as five bands filling from quick to late, and what answering
/// now is worth.
class _BandGauge extends StatelessWidget {
  /// How much of the window is left, 1 down to 0.
  final double left;
  const _BandGauge({required this.left});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gone = 1 - left.clamp(0.0, 1.0);
    final band = seedBandOf(left);
    final worth = seedFloor + (band - 1) * seedPerBand;
    return Row(
      children: [
        for (var k = 0; k < seedBands; k++) ...[
          if (k > 0) const SizedBox(width: 3),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 7,
                child: Stack(
                  children: [
                    Positioned.fill(
                        child: ColoredBox(color: theme.colorScheme.surfaceContainerHighest)),
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (gone * seedBands - k).clamp(0.0, 1.0),
                        child: ColoredBox(color: _bandColours[k]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Text('🌱$worth',
            style: theme.textTheme.labelSmall?.copyWith(
                color: _bandColours[seedBands - band], fontWeight: FontWeight.w800)),
      ],
    );
  }
}

/// One option: a reply in English, or a guess in the learner's language.
class _SetOption extends StatelessWidget {
  final int number;
  final String text;
  final bool native;

  /// "同僚：" in front, when the option is something they would say. Such an
  /// option is shaped like their bubble, so it reads as their line.
  final String speaker;
  final bool tentative;
  final String tentLabel;
  final bool dim;
  final bool right;
  final bool wrong;

  /// Why this option does not fit. Shown once the answer is open.
  final String why;
  final VoidCallback? onTap;

  const _SetOption({
    super.key,
    required this.number,
    required this.text,
    this.native = false,
    this.speaker = '',
    this.tentative = false,
    this.tentLabel = '',
    this.dim = false,
    this.right = false,
    this.wrong = false,
    this.why = '',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shape = speaker.isEmpty
        ? BorderRadius.circular(13)
        : const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomRight: Radius.circular(14),
            bottomLeft: Radius.circular(4),
          );
    final edge = right
        ? _okColour
        : wrong
            ? scheme.error
            : tentative
                ? _tentColour
                : scheme.outlineVariant;
    final fill = right
        ? _okColour.withValues(alpha: 0.12)
        : wrong
            ? scheme.error.withValues(alpha: 0.10)
            : tentative
                ? _tentColour.withValues(alpha: 0.10)
                : scheme.surface;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (speaker.isEmpty)
                SizedBox(width: 20, child: Text('$number', style: muted))
              else
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 2),
                  child: Text(speaker, style: muted),
                ),
              Expanded(
                child: Text(text,
                    style: native ? theme.textTheme.bodyLarge : theme.textTheme.bodyMedium),
              ),
            ],
          ),
          if (why.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 4),
              child: Text(why,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
            ),
        ],
      ),
    );
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dim ? 0.5 : 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: fill,
            borderRadius: shape,
            child: InkWell(
              onTap: onTap,
              borderRadius: shape,
              child: tentative
                  ? CustomPaint(
                      painter: _DashedEdge(colour: edge, shape: shape),
                      child: body,
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: edge, width: right || wrong ? 2 : 1.4),
                        borderRadius: shape,
                      ),
                      child: body,
                    ),
            ),
          ),
          if (tentative)
            Positioned(
              right: 10,
              top: -9,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                    color: _tentColour, borderRadius: BorderRadius.circular(9)),
                child: Text(tentLabel,
                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}

/// A dotted edge, for what is only put down, not given, and for the line not
/// yet said.
class _DashedEdge extends CustomPainter {
  final Color colour;
  final BorderRadius shape;
  const _DashedEdge({required this.colour, required this.shape});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..addRRect(shape.toRRect((Offset.zero & size).deflate(1)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, min(d + 6, metric.length)), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedEdge old) => old.colour != colour || old.shape != shape;
}

/// Their next line, as a blank in the conversation: the guess goes into it,
/// and their answer takes its place.
class _NextLine extends StatelessWidget {
  final String name;
  final String label;
  const _NextLine({required this.name, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const shape = BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(16),
      bottomRight: Radius.circular(16),
      bottomLeft: Radius.circular(4),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _tentColour.withValues(alpha: 0.07),
          borderRadius: shape,
        ),
        child: CustomPaint(
          painter: const _DashedEdge(colour: _tentColour, shape: shape),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.labelSmall?.copyWith(color: _tentColour)),
                const SizedBox(height: 2),
                Text(label,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: _tentColour, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What a step is for, said once in the first question ever taken, over the
/// screen it is about, with the part to look at left in view below it.
class _Coach extends StatelessWidget {
  final String title;
  final String body;
  final String ok;
  final VoidCallback onOk;
  const _Coach({required this.title, required this.body, required this.ok, required this.onOk});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(blurRadius: 16, color: Color(0x40000000), offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onInverseSurface, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(body,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onOk,
              child: Text(ok, style: TextStyle(color: scheme.inversePrimary, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- launcher

/// Which sets to take now, up to [count]: ones never done, in a random order,
/// before any that have been; among those done, the one done longest ago
/// first. Only sets are played now; a conversation kept from before is not.
List<Scene> pickScenes(List<Scene> scenes, List<TurnResult> results,
    {int count = 1, Random? rng}) {
  final open = scenes.where((s) => s.playable).toList();
  if (open.isEmpty) return const [];
  final last = <String, int>{};
  for (final r in results) {
    if (r.review) continue;
    last[r.sceneId] = max(r.at, last[r.sceneId] ?? 0);
  }
  final fresh = [for (final s in open) if (!last.containsKey(s.id)) s]..shuffle(rng ?? Random());
  final done = [for (final s in open) if (last.containsKey(s.id)) s]
    ..sort((a, b) => (last[a.id] ?? 0).compareTo(last[b.id] ?? 0));
  return [...fresh, ...done].take(count).toList();
}

/// The first of [pickScenes], for anything that wants one.
Scene? pickScene(List<Scene> scenes, List<TurnResult> results, {Random? rng}) =>
    pickScenes(scenes, results, rng: rng).firstOrNull;

/// Opens a run: any sets owed from earlier misses, then one fresh one. Loops rather than recurses so a run of "again" does not stack
/// finished screens.
///
/// [all] is the set the caller wants to draw from — everything, one field,
/// one half of a field — so the caller decides what counts; this only chooses
/// among them.
Future<void> startScene(
  BuildContext context,
  WidgetRef ref, {
  required List<Scene> all,
  VoidCallback? onDone,
}) async {
  final repo = ref.read(repositoryProvider);
  final s = ref.read(stringsProvider);
  final everything = await ref.read(allScenesProvider.future);
  final byId = {for (final x in everything) x.id: x, for (final x in all) x.id: x};
  if (!context.mounted) return;
  while (true) {
    final results = await repo.turnResults();
    // One new set a run, as home promises; "again" is the next one.
    final picks = pickScenes(all, results);
    if (!context.mounted) return;
    if (picks.isEmpty) {
      showToast(context, s.t('sceneNoneYet'));
      return;
    }
    final chosen = {for (final p in picks) p.id};
    final owed = [
      for (final r in await repo.reviewsDue())
        if (byId[r.sceneId] case final sc? when sc.playable && !chosen.contains(sc.id))
          SetCard(sc, review: true)
    ];
    if (!context.mounted) return;
    final run = await Navigator.push<SceneRunResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SceneScreen(queue: [...owed, for (final p in picks) SetCard(p)]),
      ),
    );
    if (!context.mounted) return;
    onDone?.call();
    if (run?.again != true) return;
  }
}

// ------------------------------------------------------------------ seeds

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

