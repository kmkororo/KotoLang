/// The study session: play, answer, see why, move on.
///
/// Every format is answered by tapping. Dictation offers a keyboard as an
/// option, never as the default, because typing English on a phone is the
/// friction most likely to end a session early.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/speech.dart';
import '../core/util.dart';
import '../data/repository.dart';
import '../domain/models.dart';
import '../domain/progress_service.dart';
import '../domain/question_generator.dart' as qg;

class QuizScreen extends ConsumerStatefulWidget {
  final List<SessionSlot> slots;
  const QuizScreen({super.key, required this.slots});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _index = 0;
  int _correctCount = 0;
  int _xp = 0;
  int _boost = 1;
  int _replaysLeft = 0;
  bool _answered = false;
  AnswerOutcome? _outcome;
  StreakResult? _streak;

  // per-question answer state
  int? _choice;
  final List<_Tile> _placed = [];
  List<_Tile> _bank = const [];
  final _typed = TextEditingController();
  bool _useKeyboard = false;

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
    // The boost is spent the moment a session begins.
    if (progress.pendingBoost > 1) {
      final next = progress.copyWith(pendingBoost: 0);
      ref.read(progressProvider.notifier).state = next;
      ref.read(repositoryProvider).saveProgress(next);
    }
    _prepare(firstPlay: true);
  }

  @override
  void dispose() {
    _typed.dispose();
    _speech.stop();
    super.dispose();
  }

  void _prepare({bool firstPlay = false}) {
    final settings = ref.read(settingsProvider);
    _replaysLeft = settings.level.replays;
    _answered = false;
    _choice = null;
    _outcome = null;
    _placed.clear();
    _typed.clear();

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

    // Some formats must not be read aloud before the answer: `produce` asks
    // the learner to recall the sentence, and playing it would simply hand it
    // over. The audio still comes, as the model answer, once they have
    // committed.
    if (_silent) return;

    if (firstPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _play(countsAgainstBudget: false));
    } else {
      _play(countsAgainstBudget: false);
    }
  }

  bool get _silent => silentUntilAnswered.contains(_q.type);

  void _play({bool countsAgainstBudget = true}) {
    final settings = ref.read(settingsProvider);
    if (countsAgainstBudget && settings.level.replays > 0) {
      if (_replaysLeft <= 0) return;
      setState(() => _replaysLeft -= 1);
    }
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

    final res = await ref.read(repositoryProvider).recordAnswer(
          question: _q,
          correct: correct,
          wasDue: _slot.wasDue,
          boost: _boost,
        );

    if (!mounted) return;
    ref.read(progressProvider.notifier).state = res.progress;
    setState(() {
      _answered = true;
      _outcome = res;
      _streak = res.streak;
      _xp += res.xp;
      if (correct) _correctCount++;
    });

    // The model answer, now that withholding it no longer gives anything away.
    if (_silent) _play(countsAgainstBudget: false);
  }

  void _next() {
    _speech.stop();
    if (_index < widget.slots.length - 1) {
      setState(() => _index++);
      _prepare();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SummaryScreen(
            xp: _xp,
            boosted: _boost > 1,
            correct: _correctCount,
            total: widget.slots.length,
            streakAdvanced: _streak?.advanced ?? false,
          ),
        ),
      );
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
                              child: Container(
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
                    ]),
                    const SizedBox(height: 10),
                    Text(promptText,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 14),

                    // play
                    //
                    // Withheld entirely on the formats that must not be heard
                    // first. Leaving a dead play button on screen would only
                    // invite the learner to press it and wonder why nothing
                    // happens.
                    if (!_silent || _answered)
                      Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: (settings.level.replays > 0 && _replaysLeft <= 0)
                            ? null
                            : () => _play(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: (settings.level.replays > 0 && _replaysLeft <= 0)
                                    ? theme.colorScheme.surfaceContainerHighest
                                    : theme.colorScheme.primary,
                                child: Icon(Icons.play_arrow,
                                    color: theme.colorScheme.onPrimary),
                              ),
                              const SizedBox(width: 12),
                              Text(s.t('playAgain'),
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              if (settings.level.replays > 0) ...[
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
                    ),
                    if (!speech.available && (!_silent || _answered)) ...[
                      const SizedBox(height: 8),
                      Text(
                        speech.supported ? s.t('noAudioVoice') : s.t('noAudioSupport'),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 16),

                    ..._buildBody(s, theme),

                    if (_answered) ...[
                      const SizedBox(height: 16),
                      _feedback(s, theme),
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
        return [
          if (_q.context.isNotEmpty) ...[
            _situationCard(s.t('contextLabel'), _q.context, theme),
            const SizedBox(height: 12),
          ],
          ..._choices(),
        ];

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
          if (_q.context.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(_q.context,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
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
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _placed)
                _WordChip(
                  label: t.word,
                  onTap: _answered
                      ? null
                      : () => setState(() => _placed.removeWhere((x) => x.id == t.id)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in _bank)
              _WordChip(
                label: t.word,
                used: _placed.any((p) => p.id == t.id),
                onTap: _answered || _placed.any((p) => p.id == t.id)
                    ? null
                    : () => setState(() => _placed.add(t)),
              ),
          ],
        ),
      ];

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

    return Container(
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
          if (_q.context.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('${s.t('contextLabel')}: ${_q.context}',
                style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 8),
          Text('+${res.xp} ${s.t('xpLabel')}',
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
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
  final VoidCallback? onTap;
  const _WordChip({required this.label, this.used = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: used ? 0.28 : 1,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
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

// ---------------------------------------------------------------- summary

class SummaryScreen extends ConsumerStatefulWidget {
  final int xp;
  final bool boosted;
  final int correct;
  final int total;
  final bool streakAdvanced;

  const SummaryScreen({
    super.key,
    required this.xp,
    required this.boosted,
    required this.correct,
    required this.total,
    required this.streakAdvanced,
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
        _ => s.t('rewardXp'),
      };

  String _rewardNote(dynamic s, ChestReward r) => switch (r.id) {
        'freeze' => s.t('rewardFreezeNote'),
        'boost' => s.t('rewardBoostNote'),
        _ => s.t('rewardXpNote'),
      };

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final progress = ref.watch(progressProvider);
    final theme = Theme.of(context);

    Widget tile(String v, String l) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(children: [
                Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(l, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
              ]),
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
              tile('+${widget.xp}${widget.boosted ? ' ×2' : ''}', s.t('xpGained')),
              const SizedBox(width: 10),
              tile('${widget.correct}/${widget.total}', s.t('correctOf')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              tile('🔥 ${progress.streak}',
                  widget.streakAdvanced ? s.t('streakChip') : s.t('alreadyToday')),
              const SizedBox(width: 10),
              tile('${progress.freezes}', s.t('freezesLabel')),
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
                    icon: Text(_reward == null ? '🎁' : '✨',
                        style: const TextStyle(fontSize: 48)),
                  ),
                  if (_reward != null) ...[
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
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.t('backHome')),
            ),
          ],
        ),
      ),
    );
  }
}
