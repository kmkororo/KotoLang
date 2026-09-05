/// The train mode: one argument with an opponent, all by tapping.
///
/// An exchange is five short steps — hear the line, show you caught it,
/// build a reply, see the model replies, follow the branch — and a tree is
/// at most three exchanges deep. Nothing here needs a voice or a keyboard,
/// and nothing here asks an AI anything: the only judgement made on the
/// phone is which model reply yours came closest to. The real critique
/// comes back with the next pack.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/l10n/strings.dart';
import '../core/speech.dart';
import '../core/util.dart';
import '../domain/debate.dart';
import '../domain/debate_logic.dart';

/// The l10n key for each move, so the shelf and the structure check can be
/// read in the learner's language. Every value is listed in `S.keys`.
const moveKey = <Move, String>{
  Move.concede: 'moveConcede',
  Move.however: 'moveHowever',
  Move.reason: 'moveReason',
  Move.evidence: 'moveEvidence',
  Move.example: 'moveExample',
  Move.question: 'moveQuestion',
  Move.reframe: 'moveReframe',
  Move.propose: 'movePropose',
  Move.clarify: 'moveClarify',
  Move.close: 'moveClose',
};

String moveLabel(S s, Move m) => s.t(moveKey[m]!);

/// Opens the tree most worth arguing today, then the next one if asked.
/// Loops rather than recurses, for the same reason `startSession` does.
Future<void> startDebate(BuildContext context, WidgetRef ref,
    {VoidCallback? onDone}) async {
  final s = ref.read(stringsProvider);
  final repo = ref.read(repositoryProvider);
  while (true) {
    final trees = await repo.debates();
    final attempts = await repo.attempts();
    final tree = pickDebate(trees, attempts, today: today());
    if (!context.mounted) return;
    if (tree == null) {
      showToast(context, s.t('debateNoTrees'));
      return;
    }
    final again = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => DebateScreen(tree: tree)));
    if (!context.mounted) return;
    onDone?.call();
    if (again != true) return;
  }
}

enum _Step { listen, grasp, reply, compare, outcome }

class DebateScreen extends ConsumerStatefulWidget {
  final DebateTree tree;
  const DebateScreen({super.key, required this.tree});

  @override
  ConsumerState<DebateScreen> createState() => _DebateScreenState();
}

class _DebateScreenState extends ConsumerState<DebateScreen> {
  late final SpeechService _speech;
  List<Chunk> _chunks = const [];

  late DebateNode _node;
  _Step _step = _Step.listen;
  int _depth = 1;
  bool _revealed = false;

  // grasp — what was tapped for each of the three, in shuffled option order
  final Map<String, String> _grasp = {};
  late Map<String, List<String>> _options;

  // reply
  final List<Chunk> _picked = [];
  final Map<String, String> _slots = {};
  final Set<Move> _moves = {};
  final _free = TextEditingController();

  // compare
  Rebuttal? _closest;
  ({List<Move> present, List<Move> missing})? _check;
  int _gainedHere = 0;
  int _seeds = 0;
  Outcome? _outcome;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _speech = ref.read(speechProvider);
    // Without a voice the words have to be on screen from the start; there
    // is nothing else to catch them from.
    _revealed = !_speech.available;
    _enter(widget.tree.root);
    ref.read(repositoryProvider).chunks().then((c) {
      if (mounted) setState(() => _chunks = c);
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _free.dispose();
    super.dispose();
  }

  void _enter(DebateNode node) {
    _node = node;
    _step = _Step.listen;
    _grasp.clear();
    _picked.clear();
    _slots.clear();
    _moves.clear();
    _free.clear();
    _closest = null;
    _check = null;
    _gainedHere = 0;
    _peeked = _revealed && _speech.available;
    // Shuffled once per node so the answer is not always the first option,
    // and seeded so the same node shuffles the same way every time.
    final rnd = Random(node.id.hashCode);
    _options = {
      'claim': List.of(node.grasp.claim.options)..shuffle(rnd),
      'reason': List.of(node.grasp.reason.options)..shuffle(rnd),
      'weak': List.of(node.grasp.weakPoint.options)..shuffle(rnd),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  void _play() {
    if (!mounted || !_speech.available) return;
    _speech.speak(_node.line, rate: ref.read(settingsProvider).rate);
  }

  void _buzz(void Function() f) {
    if (ref.read(settingsProvider).haptics) f();
  }

  // ---------------------------------------------------------------- grasp

  bool get _graspDone => _grasp.length == 3;

  String _answerFor(String key) => switch (key) {
        'claim' => _node.grasp.claim.answer,
        'reason' => _node.grasp.reason.answer,
        _ => _node.grasp.weakPoint.answer,
      };

  bool _graspRight(String key) => _grasp[key] == _answerFor(key);

  /// The words were on screen before the line was grasped. Only counts when
  /// there was a voice to catch it from — with no voice, showing the text is
  /// the only way to hear the line at all.
  bool _peeked = false;

  List<String> get _graspMisses => [
        if (!_graspRight('claim')) FailureKind.claimMissed,
        if (!_graspRight('reason')) FailureKind.reasonMissed,
        if (!_graspRight('weak')) FailureKind.weakPointMissed,
      ];

  /// Everything written down about the grasp step, misses and the peek.
  List<String> get _graspSlips => [..._graspMisses, if (_peeked) FailureKind.peeked];

  void _toggleReveal() {
    setState(() => _revealed = !_revealed);
    if (_revealed && _speech.available && _step.index <= _Step.grasp.index) {
      _peeked = true;
    }
  }

  void _pickGrasp(String key, String option) {
    if (_graspDone) return; // the third tap locks all three
    _buzz(HapticFeedback.selectionClick);
    setState(() => _grasp[key] = option);
  }

  // ---------------------------------------------------------------- reply

  String get _youSaid {
    final built = assemble(_picked, _slots);
    final typed = _free.text.trim();
    return [built, typed].where((t) => t.isNotEmpty).join(' ');
  }

  void _pickChunk(Chunk c) {
    _buzz(HapticFeedback.selectionClick);
    setState(() {
      _picked.add(c);
      _moves.add(c.move);
    });
  }

  void _unpick(int i) => setState(() => _picked.removeAt(i));

  /// What the models put in this slot, when they filled it; otherwise
  /// anything any of them put anywhere, which is still a better tap than a
  /// blank field on a moving train.
  List<String> _suggestionsFor(String slot) {
    final exact = uniqueBy(
      [for (final r in _node.rebuttals) ?r.slots[slot]],
      (v) => normKey(v),
    );
    return exact.isNotEmpty ? exact : slotSuggestions(_node);
  }

  Future<void> _send() async {
    final s = ref.read(stringsProvider);
    final said = _youSaid;
    if (said.isEmpty) {
      showToast(context, s.t('debateEmpty'));
      return;
    }
    final moves = [for (final m in Move.values) if (_moves.contains(m)) m];
    final closest = closestRebuttal(_node, said, moves);
    final check = structureCheck(_node, moves);
    final outcome =
        closest.isLeaf ? (closest.outcome ?? Outcome.forStrength(closest.strength)) : null;

    setState(() => _saving = true);
    final res = await ref.read(repositoryProvider).recordExchange(
          tree: widget.tree,
          node: _node,
          youSaid: said,
          moves: moves,
          closest: closest,
          graspedAll: _graspMisses.isEmpty,
          missingMoves: check.missing,
          graspMisses: _graspSlips,
          outcome: outcome?.name,
        );
    if (!mounted) return;
    ref.read(progressProvider.notifier).state = res.progress;
    _buzz(closest.strength == Strength.strong
        ? HapticFeedback.mediumImpact
        : HapticFeedback.lightImpact);
    setState(() {
      _saving = false;
      _closest = closest;
      _check = check;
      _gainedHere = res.seeds;
      _seeds += res.seeds;
      _outcome = outcome;
      _step = _Step.compare;
    });
  }

  void _follow() {
    final next = _closest?.next;
    final node = next == null ? null : widget.tree.node(next);
    if (node == null) {
      _speech.stop();
      setState(() => _step = _Step.outcome);
      return;
    }
    setState(() {
      _depth += 1;
      _enter(node);
    });
  }

  Future<void> _quit() async {
    final s = ref.read(stringsProvider);
    if (_step == _Step.outcome) {
      Navigator.pop(context, false);
      return;
    }
    final ok = await confirm(
      context,
      title: s.t('quitTitle'),
      body: s.t('debateQuitBody'),
      confirmLabel: s.t('quitConfirm'),
      cancelLabel: s.t('cancel'),
      destructive: false,
    );
    if (ok && mounted) Navigator.pop(context, false);
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final tree = widget.tree;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quit();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(onPressed: _quit, icon: const Icon(Icons.close)),
                    Expanded(
                      child: Text(tree.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall),
                    ),
                    const SizedBox(width: 8),
                    // One dot per exchange so far: the depth of the argument,
                    // not a countdown — the tree decides where it ends.
                    for (var i = 0; i < _depth; i++)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  // A new list per step and per line, so each one opens at
                  // its top instead of wherever the last one was scrolled to.
                  key: ValueKey('${_node.id}/${_step.name}'),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: switch (_step) {
                    _Step.listen => _listen(s, theme),
                    _Step.grasp => _graspStep(s, theme),
                    _Step.reply => _replyStep(s, theme),
                    _Step.compare => _compareStep(s, theme),
                    _Step.outcome => _outcomeStep(s, theme),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lineCard(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    return Card(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.tree.personaNative.isNotEmpty
                        ? widget.tree.personaNative
                        : widget.tree.persona,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                if (_speech.available)
                  IconButton(
                    tooltip: s.t('debateReplay'),
                    onPressed: _play,
                    icon: const Icon(Icons.replay),
                  ),
                IconButton(
                  tooltip: s.t(_revealed ? 'debateHideText' : 'debateShowText'),
                  onPressed: _toggleReveal,
                  icon: Icon(_revealed ? Icons.visibility_off : Icons.visibility),
                ),
              ],
            ),
            if (_revealed)
              Text(_node.line, style: theme.textTheme.bodyLarge)
            else
              Text('· · ·',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  List<Widget> _listen(S s, ThemeData theme) {
    final tree = widget.tree;
    final position = tree.positionNative.isNotEmpty ? tree.positionNative : tree.position;
    return [
      Text(s.t('debateListenTitle'), style: theme.textTheme.titleLarge),
      if (tree.event != null)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(s.t('debateEventOn', {'date': tree.event}),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
      const SizedBox(height: 4),
      Text(position, style: theme.textTheme.bodyMedium),
      const SizedBox(height: 12),
      _lineCard(s, theme),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: () => setState(() => _step = _Step.grasp),
        child: Text(s.t('debateGraspTitle')),
      ),
    ];
  }

  List<Widget> _graspStep(S s, ThemeData theme) {
    Widget block(String key, String title) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              for (final o in _options[key]!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _Tile(
                    text: o,
                    state: !_graspDone
                        ? (_grasp[key] == o ? _TileState.selected : _TileState.idle)
                        : o == _answerFor(key)
                            ? _TileState.correct
                            : _grasp[key] == o
                                ? _TileState.wrong
                                : _TileState.idle,
                    onTap: _graspDone ? null : () => _pickGrasp(key, o),
                  ),
                ),
            ],
          ),
        );

    final right = _graspDone ? 3 - _graspMisses.length : null;
    return [
      Text(s.t('debateGraspTitle'), style: theme.textTheme.titleLarge),
      const SizedBox(height: 12),
      _lineCard(s, theme),
      block('claim', s.t('debateGraspClaim')),
      block('reason', s.t('debateGraspReason')),
      block('weak', s.t('debateGraspWeak')),
      if (right != null) ...[
        const SizedBox(height: 8),
        Text(s.t('debateGraspScore', {'n': right}),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => setState(() => _step = _Step.reply),
          child: Text(s.t('debateGraspNext')),
        ),
      ],
    ];
  }

  List<Widget> _replyStep(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    final slots = slotsIn(_picked);
    final byMove = <Move, List<Chunk>>{};
    for (final c in _chunks) {
      byMove.putIfAbsent(c.move, () => []).add(c);
    }
    final said = _youSaid;

    return [
      Text(s.t('debateAssembleTitle'), style: theme.textTheme.titleLarge),
      const SizedBox(height: 12),
      _lineCard(s, theme),
      const SizedBox(height: 16),
      // the reply so far
      Text(s.t('debateYourReply'), style: theme.textTheme.titleSmall),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.primary, width: 1.5),
        ),
        child: said.isEmpty
            ? Text(s.t('debateShelfHint'),
                style: TextStyle(color: scheme.onSurfaceVariant))
            : Text(said, style: const TextStyle(fontSize: 15)),
      ),
      if (_picked.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < _picked.length; i++)
              _Piece(_picked[i].text, picked: true, onTap: () => _unpick(i)),
          ],
        ),
      ],
      // slots
      for (final slot in slots) ...[
        const SizedBox(height: 12),
        Text(s.t('debateSlotLabel', {'slot': slot}), style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final v in _suggestionsFor(slot))
              ChoiceChip(
                label: Text(v),
                selected: _slots[slot] == v,
                onSelected: (_) => setState(() => _slots[slot] = v),
              ),
          ],
        ),
      ],
      // moves
      const SizedBox(height: 16),
      Text(s.t('debateMovesLabel'), style: theme.textTheme.titleSmall),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final m in Move.values)
            FilterChip(
              label: Text(moveLabel(s, m)),
              selected: _moves.contains(m),
              onSelected: (on) => setState(() => on ? _moves.add(m) : _moves.remove(m)),
            ),
        ],
      ),
      // shelf
      for (final e in byMove.entries) ...[
        const SizedBox(height: 16),
        Text(moveLabel(s, e.key),
            style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in e.value)
              _Piece(
                c.text,
                tooltip: c.native.isNotEmpty ? c.native : null,
                onTap: () => _pickChunk(c),
              ),
          ],
        ),
      ],
      // own words
      const SizedBox(height: 16),
      TextField(
        controller: _free,
        minLines: 1,
        maxLines: 3,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: s.t('debateFreeHint'),
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _saving || said.isEmpty ? null : _send,
        child: Text(s.t('debateSend')),
      ),
    ];
  }

  List<Widget> _compareStep(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    final closest = _closest!;
    final check = _check!;
    final ordered = [
      for (final st in Strength.values)
        ..._node.rebuttals.where((r) => r.strength == st),
    ];

    return [
      Text(s.t('debateCompareTitle'), style: theme.textTheme.titleLarge),
      const SizedBox(height: 12),
      Text(s.t('debateYourReply'), style: theme.textTheme.titleSmall),
      const SizedBox(height: 6),
      Text(_youSaid, style: const TextStyle(fontSize: 15)),
      const SizedBox(height: 16),
      for (final r in ordered)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: r.id == closest.id ? scheme.primaryContainer : null,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: r.id == closest.id ? scheme.primary : scheme.outlineVariant,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      s.t(switch (r.strength) {
                        Strength.strong => 'debateStrong',
                        Strength.weak => 'debateWeak',
                        Strength.concede => 'debateConcede',
                      }),
                      style: theme.textTheme.labelLarge,
                    ),
                    if (r.id == closest.id) ...[
                      const SizedBox(width: 8),
                      Text(s.t('debateClosest'),
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: scheme.primary)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(r.model, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  r.moves.map((m) => moveLabel(s, m)).join(' → '),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 6),
      Text(
        check.missing.isEmpty
            ? s.t('debateStructureOk')
            : s.t('debateStructureMissing',
                {'moves': check.missing.map((m) => moveLabel(s, m)).join(', ')}),
        style: theme.textTheme.bodyMedium?.copyWith(
            color: check.missing.isEmpty ? scheme.primary : scheme.onSurfaceVariant),
      ),
      const SizedBox(height: 4),
      Text('+$_gainedHere Seeds',
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary)),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _follow,
        child: Text(s.t(closest.next == null ? 'debateFinish' : 'debateContinue')),
      ),
    ];
  }

  List<Widget> _outcomeStep(S s, ThemeData theme) {
    final scheme = theme.colorScheme;
    final key = switch (_outcome) {
      Outcome.won => 'debateOutcomeWon',
      Outcome.held => 'debateOutcomeHeld',
      Outcome.pressed => 'debateOutcomePressed',
      Outcome.conceded || null => 'debateOutcomeConceded',
    };
    return [
      const SizedBox(height: 32),
      Text(s.t(key), style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      Text('+$_seeds Seeds',
          style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary),
          textAlign: TextAlign.center),
      const SizedBox(height: 12),
      Text(s.t('debateOutcomeNote'),
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center),
      const SizedBox(height: 32),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text(s.t('debateAnother')),
      ),
      const SizedBox(height: 10),
      OutlinedButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(s.t('debateDone')),
      ),
    ];
  }
}

/// One piece of a reply, on the shelf or already picked. Not a Chip: a Chip
/// is one line tall and clips whatever does not fit, and a piece whose end
/// cannot be read cannot be chosen with any confidence. This wraps.
class _Piece extends StatelessWidget {
  final String text;
  final bool picked;
  final String? tooltip;
  final VoidCallback onTap;
  const _Piece(this.text, {required this.onTap, this.picked = false, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(text, style: const TextStyle(fontSize: 14))),
          if (picked) ...[
            const SizedBox(width: 6),
            Icon(Icons.close, size: 16, color: scheme.onPrimaryContainer),
          ],
        ],
      ),
    );
    if (tooltip != null) body = Tooltip(message: tooltip!, child: body);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 32),
      child: Material(
        color: picked ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: body,
        ),
      ),
    );
  }
}

enum _TileState { idle, selected, correct, wrong }

class _Tile extends StatelessWidget {
  final String text;
  final _TileState state;
  final VoidCallback? onTap;
  const _Tile({required this.text, required this.state, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, border) = switch (state) {
      _TileState.idle => (null, scheme.outlineVariant),
      _TileState.selected => (scheme.primaryContainer, scheme.primary),
      _TileState.correct => (scheme.primaryContainer, scheme.primary),
      _TileState.wrong => (scheme.errorContainer, scheme.error),
    };
    return Material(
      color: bg ?? scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
              if (state == _TileState.correct) Icon(Icons.check_circle, color: scheme.primary),
              if (state == _TileState.wrong) Icon(Icons.cancel, color: scheme.error),
            ],
          ),
        ),
      ),
    );
  }
}
