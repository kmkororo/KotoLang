/// The study session: play, answer, see why, move on.
///
/// Every format is answered by tapping. Dictation offers a keyboard as an
/// option, never as the default, because typing English on a phone is the
/// friction most likely to end a session early.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/speech.dart';
import '../core/util.dart';
import '../data/repository.dart';
import '../domain/models.dart';
import '../domain/progress_service.dart';
import '../domain/question_generator.dart' as qg;
import '../domain/srs.dart' as srs;

/// Builds a session and runs it. Shared by the home screen and the end of a
/// session, so "one more" starts exactly the same way the first one did.
///
/// Loops rather than recurses: the summary asks for another by popping with
/// `true`, which lands back here with the stack still flat — a night of "one
/// more" must not build a tower of finished sessions to walk back down.
Future<void> startSession(BuildContext context, WidgetRef ref,
    {required int count, VoidCallback? onDone}) async {
  final s = ref.read(stringsProvider);
  var want = count;

  while (true) {
    final realm = ref.read(realmFilterProvider);
    final slots = await ref.read(repositoryProvider).buildSession(
          realmId: realm ?? 'all',
          count: want,
          allow: typesFor(ref.read(formatFilterProvider)),
        );

    if (!context.mounted) return;
    if (slots.isEmpty) {
      showToast(context, s.t('noQuestions'));
      return;
    }

    final again = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => QuizScreen(slots: slots)));
    if (!context.mounted) return;
    ref.invalidate(homeCountsProvider);
    onDone?.call();
    if (again != true) {
      // The format choice belongs to the session that just ended: someone who
      // drilled listening once should not find the app still refusing to say
      // anything tomorrow.
      ref.read(formatFilterProvider.notifier).state = 'all';
      return;
    }
    want = 1;
  }
}


class QuizScreen extends ConsumerStatefulWidget {
  final List<SessionSlot> slots;
  const QuizScreen({super.key, required this.slots});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _index = 0;
  int _correctCount = 0;
  int _seeds = 0;

  /// Correct answers in a row within this session, and what the current run
  /// has just paid. Reset by a wrong answer, never charged for one.
  /// Wrong answers so far. A session that ends with none of these, and is
  /// long enough to mean something, is a perfect run.
  int _missed = 0;

  /// Expressions met for the first time this session.
  int _found = 0;

  /// The session is over and this route is showing its summary.
  bool _ended = false;
  int _bonus = 0;
  bool _perfect = false;
  int _combo = 0;
  int _comboBonus = 0;
  int _bestCombo = 0;
  int _boost = 1;
  int _replaysLeft = 0;
  bool _answered = false;
  bool _hintShown = false;
  bool _played = false;
  AnswerOutcome? _outcome;
  StreakResult? _streak;

  // per-question answer state
  int? _choice;
  final List<_Tile> _placed = [];
  List<_Tile> _bank = const [];
  final _typed = TextEditingController();
  bool _useKeyboard = false;
  final _scroll = ScrollController();

  /// Pending move to the next question after a correct answer. Cancelled by
  /// anything that gets there first — a tap, or leaving the screen.
  Timer? _advance;

  // Held directly: `ref` may not be touched once the widget is disposed, and
  // leaving a session must still stop the audio.
  late final SpeechService _speech;

  SessionSlot get _slot => widget.slots[_index];
  Question get _q => _slot.question;

  @override
  void initState() {
    super.initState();
    _speech = ref.read(speechProvider);
    final settings = ref.read(settingsProvider);
    final progress = ref.read(progressProvider);
    _boost = progress.pendingBoost > 1 ? progress.pendingBoost : 1;
    _useKeyboard = settings.inputMode == 'keyboard';
    // The boost is spent the moment a session begins — but not from inside
    // initState. Writing a provider during a widget life-cycle throws, which
    // took the whole screen down for anyone who had just won a boost from the
    // chest.
    if (_boost > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final next = ref.read(progressProvider).copyWith(pendingBoost: 0);
        ref.read(progressProvider.notifier).state = next;
        ref.read(repositoryProvider).saveProgress(next);
      });
    }
    _prepare();
  }

  @override
  void dispose() {
    _advance?.cancel();
    _typed.dispose();
    _scroll.dispose();
    _speech.stop();
    super.dispose();
  }

  void _prepare() {
    final settings = ref.read(settingsProvider);
    _replaysLeft = settings.level.replays;
    _answered = false;
    _hintShown = false;
    _played = false;
    _choice = null;
    _outcome = null;
    _placed.clear();
    _typed.clear();
    // The previous question was scrolled down to its feedback; the next one
    // has to start at its own beginning. Twice over: the jump lands on the
    // outgoing question's layout, and the incoming one can be a different
    // height, which leaves the list a little way down its own content.
    if (_scroll.hasClients) _scroll.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients && _scroll.offset != 0) {
        _scroll.jumpTo(0);
      }
    });

    if (_q.type == QuestionType.dictation) {
      // Decoys scale to the answer: a flat count buries a two-word phrase under
      // a wall of irrelevant tiles, which reads as noise rather than difficulty.
      final answer = _q.answerWords;
      final want = settings.level.bankExtra.clamp(2, answer.length * 2);
      final answers = answer.map((w) => w.toLowerCase()).toSet();
      final decoys = take(
        shuffled(_q.bankPool.where((w) => !answers.contains(w.toLowerCase()))),
        want,
      );
      _bank = shuffled([
        for (var i = 0; i < answer.length; i++) _Tile(answer[i], 'a$i'),
        for (var i = 0; i < decoys.length; i++) _Tile(decoys[i], 'd$i'),
      ]);
    } else if (_q.type == QuestionType.reorder || _q.type == QuestionType.produce) {
      _bank = shuffled([
        for (var i = 0; i < _q.tokens.length; i++) _Tile(_q.tokens[i], 't$i'),
      ]);
    } else {
      _bank = const [];
    }

    // Nothing plays on its own. The question is worth reading before the
    // audio starts — and audio that begins the moment a screen appears is
    // audio half of it is missed.
  }

  /// Still on course for a perfect run. Vanishes the moment one is missed, so
  /// it never nags about a chance already gone.
  bool get _perfectAlive =>
      _missed == 0 && _correctCount > 0 && widget.slots.length >= perfectRunMin;

  bool get _silent => silentUntilAnswered.contains(_q.type);

  /// Replays are limited only while the question is still open. Once it has
  /// been answered the audio is the model answer, and rationing how often
  /// someone may listen to the correct sentence teaches nothing.
  bool get _replayLimited =>
      !_answered && ref.read(settingsProvider).level.replays > 0 && _replaysLeft <= 0;

  void _play({bool countsAgainstBudget = true}) {
    final settings = ref.read(settingsProvider);
    // The first listen is not a replay. The budget is there to stop someone
    // looping the audio until they can transcribe it, not to charge them for
    // hearing the question once.
    if (countsAgainstBudget && !_answered && _played && settings.level.replays > 0) {
      if (_replaysLeft <= 0) return;
      setState(() => _replaysLeft -= 1);
    }
    if (!_played) setState(() => _played = true);
    // `reply` speaks the other person's line; everything else speaks its own.
    _speech.speak(_q.spokenText, rate: settings.rate);
  }

  bool get _canSubmit {
    if (_answered) return true;
    switch (_q.type) {
      case QuestionType.paraphrase:
      case QuestionType.gist:
      case QuestionType.reply:
      case QuestionType.register:
        return _choice != null;
      case QuestionType.dictation:
        return _useKeyboard ? clean(_typed.text).isNotEmpty : _placed.isNotEmpty;
      case QuestionType.reorder:
        return _placed.length == _q.tokens.length;
      case QuestionType.produce:
        return _useKeyboard
            ? clean(_typed.text).isNotEmpty
            : _placed.length == _q.tokens.length;
    }
  }

  Future<void> _submit() async {
    if (_answered) {
      _next();
      return;
    }

    bool correct;
    switch (_q.type) {
      case QuestionType.paraphrase:
      case QuestionType.gist:
      case QuestionType.reply:
      case QuestionType.register:
        correct = _choice == _q.correct;
      case QuestionType.dictation:
        final given =
            _useKeyboard ? _typed.text : _placed.map((t) => t.word).join(' ');
        correct = qg.gradeDictation(given, _q.answerText).correct;
      case QuestionType.reorder:
        correct = qg.gradeReorder(_placed.map((t) => t.word).toList(), _q);
      case QuestionType.produce:
        // Typed answers get the same near-miss tolerance as dictation; tiles
        // can only be right or wrong, so they are compared exactly.
        correct = _useKeyboard
            ? qg.gradeDictation(_typed.text, _q.answerText).correct
            : qg.gradeReorder(_placed.map((t) => t.word).toList(), _q);
    }

    final combo = correct ? _combo + 1 : 0;
    final bonus = comboBonus(combo);

    final res = await ref.read(repositoryProvider).recordAnswer(
          question: _q,
          correct: correct,
          wasDue: _slot.wasDue,
          boost: _boost,
          bonusSeeds: bonus,
        );

    if (!mounted) return;
    ref.read(progressProvider.notifier).state = res.progress;
    // Felt before it is read. A different weight for right and wrong is the
    // fastest signal the app can give — it arrives before the eyes have
    // reached the words.
    if (ref.read(settingsProvider).haptics) {
      if (res.breakthrough || bonus > 0) {
        HapticFeedback.mediumImpact();
      } else if (correct) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
    }
    setState(() {
      _answered = true;
      _outcome = res;
      _streak = res.streak;
      _seeds += res.seeds;
      _combo = combo;
      _comboBonus = bonus;
      if (combo > _bestCombo) _bestCombo = combo;
      if (correct) _correctCount++;
      if (!correct) _missed++;
      if (res.discovered) _found++;
    });

    // Whether the answer was right, and why, is the whole point of the
    // exercise — and it is appended below a question that already fills the
    // screen, so on a small phone it lands out of sight.
    _revealFeedback();

    // The model answer, now that withholding it no longer gives anything away.
    if (_silent) _play(countsAgainstBudget: false);

  }
  void _revealFeedback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _next() async {
    _advance?.cancel();
    _speech.stop();
    if (_index < widget.slots.length - 1) {
      setState(() => _index++);
      _prepare();
    } else {
      // The session-length and journey-complete bonuses only make sense once
      // the whole session is in, so they are settled here rather than
      // per-answer.
      final result =
          await ref.read(repositoryProvider).finishSession(
              answered: widget.slots.length, missed: _missed);
      if (!mounted) return;
      ref.read(progressProvider.notifier).state = result.progress;

      // Shown inside this route rather than pushed over it. `pushReplacement`
      // completes the route's future the moment it runs, so "one more" popped
      // with a result nobody was still waiting for — and the loop that was
      // meant to start the next session had already ended.
      setState(() {
        _bonus = result.bonus;
        _perfect = result.perfect;
        _ended = true;
      });
    }
  }

  Future<void> _quit() async {
    final s = ref.read(stringsProvider);
    final ok = await confirm(
      context,
      title: s.t('quitTitle'),
      body: s.t('quitBody'),
      confirmLabel: s.t('quitConfirm'),
      cancelLabel: s.t('cancel'),
      destructive: false,
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // The summary is the last page of this route, so popping from it returns
    // to whoever started the session — which is what lets "one more" begin
    // another without stacking finished sessions on top of each other.
    if (_ended) {
      return SummaryScreen(
        seeds: _seeds + _bonus,
        boosted: _boost > 1,
        correct: _correctCount,
        total: widget.slots.length,
        streakAdvanced: _streak?.advanced ?? false,
        bestCombo: _bestCombo,
        perfect: _perfect,
        discovered: _found,
      );
    }

    final s = ref.watch(stringsProvider);
    final settings = ref.watch(settingsProvider);
    final speech = ref.watch(speechProvider);
    final theme = Theme.of(context);

    final typeLabel = switch (_q.type) {
      QuestionType.paraphrase => s.t('typeParaphrase'),
      QuestionType.gist => s.t('typeGist'),
      QuestionType.dictation => s.t('typeDictation'),
      QuestionType.reorder => s.t('typeReorder'),
      QuestionType.produce => s.t('typeProduce'),
      QuestionType.reply => s.t('typeReply'),
      QuestionType.register => s.t('typeRegister'),
    };
    final promptText = switch (_q.type) {
      QuestionType.paraphrase => s.t('promptParaphrase'),
      QuestionType.gist => s.t('promptGist'),
      QuestionType.dictation =>
        _useKeyboard ? s.t('promptDictationKeyboard') : s.t('promptDictationTap'),
      QuestionType.reorder => s.t('promptReorder'),
      QuestionType.produce => s.t('promptProduce'),
      QuestionType.reply => s.t('promptReply'),
      QuestionType.register => s.t('promptRegister'),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quit();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // progress
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(onPressed: _quit, icon: const Icon(Icons.close)),
                    Expanded(
                      child: Row(
                        children: [
                          for (var i = 0; i < widget.slots.length; i++)
                            Expanded(
                              // Animated so the bar visibly fills rather than
                              // jumping: it is the only thing on screen that
                              // shows the session going somewhere.
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOut,
                                height: 5,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: i < _index
                                      ? theme.colorScheme.primary
                                      : i == _index
                                          ? theme.colorScheme.primary.withValues(alpha: 0.55)
                                          : theme.colorScheme.surfaceContainerHighest,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      Chip(
                        label: Text(typeLabel),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        side: BorderSide.none,
                      ),
                      if (_slot.wasDue)
                        Chip(
                          label: Text(s.t('reviewChip')),
                          visualDensity: VisualDensity.compact,
                          side: BorderSide.none,
                        ),
                      if (_perfectAlive)
                        Chip(
                          label: Text(s.t('perfectRunChip', {
                            'n': _correctCount,
                            'total': widget.slots.length,
                          })),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: theme.colorScheme.tertiaryContainer,
                          side: BorderSide.none,
                        ),
                    ]),
                    // The setting comes before anything else. Knowing you are
                    // in a design review is what makes the sentence make sense
                    // — arriving after the audio has already played is too
                    // late to help.
                    if (_q.context.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _situationCard(s.t('contextLabel'), _q.context, theme),
                    ],
                    const SizedBox(height: 10),
                    Text(promptText,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 14),

                    // Before answering only. Afterwards the audio is the model
                    // answer, and it belongs under the answer it demonstrates
                    // rather than above the question.
                    if (!_silent && !_answered) _playCard(s, theme, settings),
                    if (!speech.available && (!_silent || _answered)) ...[
                      const SizedBox(height: 8),
                      Text(
                        speech.supported ? s.t('noAudioVoice') : s.t('noAudioSupport'),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ],

                    // A hint, for the learner who caught the shape of the
                    // sentence but not all of it. Offered only while the
                    // question is open and only where the audio is the thing
                    // being tested — on a "say it" question there is no
                    // spoken sentence to give half of.
                    if (!_answered && !_silent) ...[
                      const SizedBox(height: 8),
                      if (_hintShown)
                        Card(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.t('hintLabel'),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant)),
                                const SizedBox(height: 4),
                                Text(qg.blankedHint(_q.spokenText),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.1)),
                              ],
                            ),
                          ),
                        )
                      else
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            icon: const Icon(Icons.lightbulb_outline, size: 18),
                            onPressed: () => setState(() => _hintShown = true),
                            label: Text(s.t('showHint')),
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),

                    ..._buildBody(s, theme),

                    if (_answered) ...[
                      const SizedBox(height: 16),
                      _feedback(s, theme),
                      // Under the answer it demonstrates, where someone who
                      // has just read the correct sentence can hear it.
                      const SizedBox(height: 12),
                      _playCard(s, theme, settings),
                    ],
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  child: Text(_answered
                      ? (_index < widget.slots.length - 1
                          ? s.t('nextQuestion')
                          : s.t('finishSession'))
                      : s.t('answerLabel')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The four-option list, shared by every multiple-choice format.
  List<Widget> _choices() => [
        for (var i = 0; i < _q.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionTile(
              text: _q.options[i],
              state: !_answered
                  ? (_choice == i ? _OptionState.selected : _OptionState.idle)
                  : i == _q.correct
                      ? _OptionState.correct
                      : (i == _choice ? _OptionState.wrong : _OptionState.idle),
              onTap: _answered ? null : () => setState(() => _choice = i),
            ),
          ),
      ];

  /// The card that carries the situation a question is set in.
  Widget _situationCard(String label, String body, ThemeData theme) => Card(
        color: theme.colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      color: theme.colorScheme.onSecondaryContainer)),
              const SizedBox(height: 6),
              Text(body,
                  style: theme.textTheme.titleMedium?.copyWith(
                      height: 1.5, color: theme.colorScheme.onSecondaryContainer)),
            ],
          ),
        ),
      );

  List<Widget> _buildBody(dynamic s, ThemeData theme) {
    switch (_q.type) {
      case QuestionType.paraphrase:
      case QuestionType.gist:
        return _choices();

      case QuestionType.reply:
        // The cue is heard, not read: showing the English would turn a
        // listening question into a reading one. Its reading appears only
        // once the answer is in.
        // The setting is already at the top of the screen.
        return _choices();

      case QuestionType.register:
        return [
          _situationCard(s.t('typeRegister'), _q.translationNative, theme),
          const SizedBox(height: 12),
          ..._choices(),
        ];

      case QuestionType.produce:
        // The meaning is the whole prompt. Everything else about this format
        // is the reorder machinery, reused.
        return [
          _situationCard(s.t('yourAnswerLabel'), _q.translationNative, theme),
          const SizedBox(height: 14),
          ..._inputArea(s, theme),
        ];

      case QuestionType.dictation:
        // The blanked sentence is always visible: it is what tells the learner
        // which expression is being asked for. Hiding it made the word tiles
        // look unrelated to the audio.
        final after = _q.after;
        final glue = RegExp(r'^[.,!?;:]').hasMatch(after) ? '' : ' ';
        return [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.titleMedium?.copyWith(height: 1.7),
                  children: [
                    if (_q.before.isNotEmpty) TextSpan(text: '${_q.before} '),
                    TextSpan(
                      text: '_' * (_q.answerWords.length * 4).clamp(4, 16),
                      style: TextStyle(
                          color: theme.colorScheme.primary, fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: '$glue$after'),
                  ],
                ),
              ),
            ),
          ),
          if (_q.translationNative.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_q.translationNative,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 14),
          ..._inputArea(s, theme),
        ];

      case QuestionType.reorder:
        return _tileArea(theme);
    }
  }

  /// Word tiles or the keyboard, whichever the learner prefers, plus the
  /// switch between them. Shared by dictation and produce.
  List<Widget> _inputArea(dynamic s, ThemeData theme) => [
        if (_useKeyboard)
          TextField(
            controller: _typed,
            enabled: !_answered,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(),
          )
        else
          ..._tileArea(theme),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _answered
                ? null
                : () => setState(() {
                      _useKeyboard = !_useKeyboard;
                      _placed.clear();
                      _typed.clear();
                    }),
            child: Text(_useKeyboard ? s.t('switchToTap') : s.t('switchToKeyboard')),
          ),
        ),
      ];

  Widget _playCard(dynamic s, ThemeData theme, AppSettings settings) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _replayLimited ? null : () => _play(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _replayLimited
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.primary,
                  child: Icon(Icons.play_arrow, color: theme.colorScheme.onPrimary),
                ),
                const SizedBox(width: 12),
                Text(_answered || _played ? s.t('playAgain') : s.t('playFirst'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (settings.level.replays > 0 && !_answered && _played) ...[
                  const SizedBox(width: 10),
                  Chip(
                    label: Text(s.t('replaysLeft', {'n': _replaysLeft})),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                  ),
                ],
              ],
            ),
          ),
        ),
      );

  /// Puts [tile] into gap [gap] of the answer, taking it out of wherever it
  /// was first.
  void _placeAt(_Tile tile, int gap) {
    setState(() {
      final from = _placed.indexWhere((p) => p.id == tile.id);
      final at = qg.reinsertIndex(from, gap);
      if (from >= 0) _placed.removeAt(from);
      _placed.insert(at.clamp(0, _placed.length), tile);
    });
  }

  List<Widget> _tileArea(ThemeData theme) => [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: theme.colorScheme.outlineVariant,
                style: BorderStyle.solid,
                width: 1.5),
          ),
          // Gaps between the words are drop targets, so a word can go into
          // the middle of the sentence. Tapping used to be the only way in,
          // and it could only append — one wrong word early on meant taking
          // the whole sentence apart to fix it.
          child: Wrap(
            spacing: 0,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < _placed.length; i++) ...[
                _DropGap(index: i, onDrop: _placeAt, enabled: !_answered),
                // The word itself takes a drop too, landing in front of it.
                // Aiming at the gaps alone meant hitting a strip a few pixels
                // wide, which is not something a finger can do.
                DragTarget<_Tile>(
                  onWillAcceptWithDetails: (d) => !_answered && d.data.id != _placed[i].id,
                  onAcceptWithDetails: (d) => _placeAt(d.data, i),
                  builder: (_, _, _) => Draggable<_Tile>(
                    data: _placed[i],
                    maxSimultaneousDrags: _answered ? 0 : 1,
                    feedback: Material(
                      color: Colors.transparent,
                      child: _WordChip(label: _placed[i].word, dragging: true),
                    ),
                    childWhenDragging:
                        Opacity(opacity: 0.3, child: _WordChip(label: _placed[i].word)),
                    child: _WordChip(
                      label: _placed[i].word,
                      onTap: _answered
                          ? null
                          : () => setState(
                              () => _placed.removeWhere((x) => x.id == _placed[i].id)),
                    ),
                  ),
                ),
              ],
              _DropGap(index: _placed.length, onDrop: _placeAt, enabled: !_answered),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in _bank)
              if (_placed.any((p) => p.id == t.id))
                _WordChip(label: t.word, used: true)
              else
                // Tap still appends, which is the fast path when building a
                // sentence left to right; drag is for putting one somewhere
                // other than the end.
                Draggable<_Tile>(
                  data: t,
                  maxSimultaneousDrags: _answered ? 0 : 1,
                  feedback: Material(
                    color: Colors.transparent,
                    child: _WordChip(label: t.word, dragging: true),
                  ),
                  childWhenDragging:
                      Opacity(opacity: 0.3, child: _WordChip(label: t.word)),
                  child: _WordChip(
                    label: t.word,
                    onTap: _answered ? null : () => setState(() => _placed.add(t)),
                  ),
                ),
          ],
        ),
      ];

  /// A small celebration strip inside the feedback card. Used for the two
  /// things worth calling out by name: a struggling item won back, and an
  /// expression growing into its next stage.
  Widget _banner(String emoji, String title, String body, ThemeData theme) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.tertiaryContainer,
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onTertiaryContainer)),
                Text(body,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer)),
              ],
            ),
          ),
        ]),
      );

  Widget _feedback(dynamic s, ThemeData theme) {
    final res = _outcome!;
    final correct = res.correct;
    final close = !correct &&
        (_q.type == QuestionType.dictation ||
            (_q.type == QuestionType.produce && _useKeyboard)) &&
        qg
            .gradeDictation(
                _useKeyboard ? _typed.text : _placed.map((t) => t.word).join(' '),
                _q.answerText)
            .close;

    // Grows into place rather than appearing. The movement is what makes the
    // verdict register as a response to the tap.
    return TweenAnimationBuilder<double>(
      key: ValueKey('feedback-$_index'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
      ),
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: correct
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.errorContainer,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            correct
                ? s.t('correctLabel')
                : (close ? s.t('closeLabel') : s.t('incorrectLabel')),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: correct
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onErrorContainer,
            ),
          ),
          // The line that was heard, revealed now rather than during the
          // question, where reading it would have replaced the listening.
          if (_q.cueText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('${s.t('cueLabel')}: ${_q.cueText}',
                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14)),
            if (_q.cueTranslationNative.isNotEmpty)
              Text(_q.cueTranslationNative, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 8),
          Text(_q.text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          if (_q.translationNative.isNotEmpty && _q.type != QuestionType.register) ...[
            const SizedBox(height: 4),
            Text(_q.translationNative, style: theme.textTheme.bodySmall),
          ],
          if (_q.type == QuestionType.dictation) ...[
            const SizedBox(height: 6),
            Text('${s.t('targetLabel')}: ${_q.answerText}',
                style: theme.textTheme.bodySmall),
          ],
          // The reason the phrasing fits. Without it the register question is
          // a coin toss the learner learns nothing from.
          if (_q.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('${s.t('registerWhyLabel')}: ${_q.note}',
                style: theme.textTheme.bodySmall),
          ],
          // The setting is not repeated here: it has been at the top of the
          // screen since before the question was answered.
          const SizedBox(height: 8),
          // The hard-won item. Called out above the Seeds line, because the
          // number alone would not say what just happened.
          // A first meeting comes before anything else this answer did: it is
          // the only banner that names something new rather than something
          // that moved.
          if (res.discovered)
            _banner('🔍', s.t('discoveredTitle'), s.t('discoveredBody'), theme)
          else if (res.breakthrough)
            _banner('🎉', s.t('breakthroughTitle'),
                s.t('breakthroughBody', {'n': breakthroughBonus}), theme)
          // Growth is announced only when a breakthrough is not
          // already announcing it: two banners for one answer is noise.
          else if (res.stageUp != null)
            _banner(srs.stageEmoji[res.stageUp!]!, s.t('stageUpTitle'),
                s.t('stageUpBody',
                    {'stage': s.t(srs.stageKey[res.stageUp!]!)}), theme),
          Row(children: [
            // Counted up rather than printed. A number that climbs is read as
            // something being handed over; the same number printed is not.
            // Nothing is shown for a wrong answer: "+0" is not information.
            if (res.seeds > 0)
              TweenAnimationBuilder<int>(
                key: ValueKey('seeds-$_index'),
                tween: IntTween(begin: 0, end: res.seeds),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, n, _) => Text('🌱 +$n',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            // The run, and what it just added. Only once it is actually
            // paying — a counter that sits at zero is noise.
            if (_comboBonus > 0) ...[
              const SizedBox(width: 10),
              Chip(
                label: Text(s.t('comboChip', {'n': _combo, 'bonus': _comboBonus})),
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
                backgroundColor: theme.colorScheme.primaryContainer,
              ),
            ],
          ]),
        ],
      ),
      ),
    );
  }
}

class _Tile {
  final String word;
  final String id; // distinguishes repeated words such as "the"
  const _Tile(this.word, this.id);
}

enum _OptionState { idle, selected, correct, wrong }

class _OptionTile extends StatelessWidget {
  final String text;
  final _OptionState state;
  final VoidCallback? onTap;
  const _OptionTile({required this.text, required this.state, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, border) = switch (state) {
      _OptionState.idle => (null, scheme.outlineVariant),
      _OptionState.selected => (scheme.primaryContainer, scheme.primary),
      _OptionState.correct => (scheme.primaryContainer, scheme.primary),
      _OptionState.wrong => (scheme.errorContainer, scheme.error),
    };

    return Material(
      color: bg ?? scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
              if (state == _OptionState.correct)
                Icon(Icons.check_circle, color: scheme.primary),
              if (state == _OptionState.wrong) Icon(Icons.cancel, color: scheme.error),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  final String label;
  final bool used;
  final bool dragging;
  final VoidCallback? onTap;
  const _WordChip(
      {required this.label, this.used = false, this.dragging = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: used ? 0.28 : 1,
      child: Material(
        color: dragging ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        elevation: dragging ? 6 : 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Text(label, style: const TextStyle(fontSize: 15)),
          ),
        ),
      ),
    );
  }
}

/// The space between two placed words, and the place a dragged word lands.
/// Narrow until something is hovering over it, then it opens up so the drop
/// point is visible before the finger lifts.
class _DropGap extends StatefulWidget {
  final int index;
  final void Function(_Tile tile, int index) onDrop;
  final bool enabled;
  const _DropGap(
      {required this.index, required this.onDrop, required this.enabled});

  @override
  State<_DropGap> createState() => _DropGapState();
}

class _DropGapState extends State<_DropGap> {
  bool _over = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<_Tile>(
      onWillAcceptWithDetails: (_) {
        if (!widget.enabled) return false;
        setState(() => _over = true);
        return true;
      },
      onLeave: (_) => setState(() => _over = false),
      onAcceptWithDetails: (d) {
        setState(() => _over = false);
        widget.onDrop(d.data, widget.index);
      },
      // Wide enough to aim at. The visible bar stays slim; the rest of the
      // width is invisible target, because a drop zone the width of a hairline
      // is one a finger cannot land on.
      builder: (_, _, _) => SizedBox(
        width: _over ? 32 : 20,
        height: 46,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: _over ? 20 : 3,
            height: _over ? 40 : 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: _over ? scheme.primary : scheme.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- summary

class SummaryScreen extends ConsumerStatefulWidget {
  final int seeds;
  final bool boosted;
  final int bestCombo;
  final int correct;
  final int total;
  final bool streakAdvanced;

  /// The session was finished without a single miss. The bonus is already in
  /// [seeds]; this only says whether to say so.
  final bool perfect;

  /// Expressions met for the first time in this session.
  final int discovered;

  const SummaryScreen({
    super.key,
    required this.seeds,
    required this.boosted,
    required this.bestCombo,
    required this.correct,
    required this.total,
    required this.streakAdvanced,
    this.perfect = false,
    this.discovered = 0,
  });

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  ChestReward? _reward;

  Future<void> _openChest() async {
    if (_reward != null) return;
    final reward = openChest();
    final next = applyChest(ref.read(progressProvider), reward);
    ref.read(progressProvider.notifier).state = next;
    await ref.read(repositoryProvider).saveProgress(next);
    if (mounted) setState(() => _reward = reward);
  }

  String _rewardLabel(dynamic s, ChestReward r) => switch (r.id) {
        'freeze' => s.t('rewardFreeze'),
        'boost' => s.t('rewardBoost'),
        _ => s.t('rewardSeeds'),
      };

  String _rewardNote(dynamic s, ChestReward r) => switch (r.id) {
        'freeze' => s.t('rewardFreezeNote'),
        'boost' => s.t('rewardBoostNote'),
        _ => s.t('rewardSeedsNote'),
      };

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final progress = ref.watch(progressProvider);
    // Expressions still unmet, read live: the session that just ran changed
    // this number, and the card below must not promise what is no longer there.
    final fresh = ref.watch(homeCountsProvider).value?.fresh ?? 0;
    final theme = Theme.of(context);

    // A tile, optionally with an explanation behind it. "Rest day" means
    // nothing on its own — it is the one label here that has to say what it
    // is, and the summary is where people first meet it.
    Widget tile(String v, String l, {VoidCallback? onTap}) => Expanded(
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(children: [
                  Text(v,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(l,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall),
                      ),
                      if (onTap != null) ...[
                        const SizedBox(width: 3),
                        Icon(Icons.help_outline,
                            size: 13, color: theme.colorScheme.onSurfaceVariant),
                      ],
                    ],
                  ),
                ]),
              ),
            ),
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Text(s.t('sessionDone').toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(s.t('wellDone'),
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            Row(children: [
              tile('🌱 +${widget.seeds}${widget.boosted ? ' ×2' : ''}',
                  s.t('seedsGained')),
              const SizedBox(width: 10),
              tile('${widget.correct}/${widget.total}', s.t('correctOf')),
            ]),
            // What was met for the first time, named before the totals: it is
            // the part of the session that will not happen again.
            if (widget.discovered > 0) ...[
              const SizedBox(height: 12),
              Text(s.t('discoveredCount', {'n': widget.discovered}),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary)),
            ],
            // The clean sweep, said plainly and before anything else on the
            // page — it is the thing the session was aiming at.
            if (widget.perfect) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.colorScheme.tertiaryContainer,
                ),
                child: Column(children: [
                  Text('✨ ${s.t('perfectRunTitle')}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onTertiaryContainer)),
                  const SizedBox(height: 2),
                  Text(s.t('perfectRunBody', {'n': perfectRunBonus}),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer)),
                ]),
              ),
            ],
            // The best run of the session, when there was one worth naming.
            if (widget.bestCombo >= 3) ...[
              const SizedBox(height: 10),
              Row(children: [tile('🔥 ${widget.bestCombo}', s.t('bestComboLabel'))]),
            ],
            // What the Seeds are actually for, said at the moment they are
            // handed over. Without it they read as a score.
            const SizedBox(height: 10),
            Text(
              progress.seeds >= realmUnlockCost
                  ? s.t('seedsCanUnlock')
                  : s.t('seedsToNextUnlock',
                      {'n': realmUnlockCost - progress.seeds}),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Row(children: [
              tile('🔥 ${progress.streak}',
                  widget.streakAdvanced ? s.t('streakChip') : s.t('alreadyToday')),
              const SizedBox(width: 10),
              tile(
                '${progress.freezes}',
                s.t('freezesLabel'),
                onTap: () => explainNote(context,
                    title: s.t('freezeHelpTitle'),
                    body: s.t('freezeHelpBody'),
                    closeLabel: s.t('capUnderstood')),
              ),
            ]),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Text(s.t('tapChest'),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  IconButton(
                    iconSize: 56,
                    onPressed: _reward == null ? _openChest : null,
                    icon: Icon(
                      _reward == null ? Icons.card_giftcard : Icons.auto_awesome,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (_reward != null) ...[
                    // The reward, as the thing it is on the tree.
                    Image.asset(
                      switch (_reward!.id) {
                        'freeze' => 'assets/tree/item_repellent.png',
                        'boost' => 'assets/tree/item_tonic.png',
                        _ => 'assets/tree/item_water.png',
                      },
                      height: 64,
                    ),
                    const SizedBox(height: 6),
                    Text(_rewardLabel(s, _reward!),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(_rewardNote(s, _reward!),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 20),
            // The loop, closed. Ending a session on a single "back home"
            // button is where the habit stopped every night: whatever pull
            // the session built was spent walking away from it.
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(s.t('moreTitle'),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      // Only promised when it is actually there. A library
                      // with nothing new left says so instead.
                      fresh > 0
                          ? s.t('moreBody', {'n': fresh})
                          : s.t('moreNoneLeft'),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      // Answered by the route rather than started here: the
                      // session that follows must replace this screen, not
                      // stack on top of a summary already finished with.
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(s.t('moreButton')),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.t('backHome')),
            ),
          ],
        ),
      ),
    );
  }
}
