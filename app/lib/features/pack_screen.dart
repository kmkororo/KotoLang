/// The trip to the learner's own AI, and everything it carries.
///
/// One prompt goes out with what has piled up on this phone — the dates
/// written down after real conversations, the slips the app noticed, the
/// replies waiting for a critique — and one pack comes back with the next
/// opponents, the critiques, and the pieces to argue with. The AI is told
/// to stop after each tree, so the reply arrives in as many pastes as there
/// are trees; the tally above the box turns that into progress rather than
/// chore.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/l10n/languages.dart';
import '../core/l10n/strings.dart';
import '../domain/debate.dart';
import 'ai_links.dart';
import 'onboarding_screens.dart' show copyToClipboard;
import 'paste_box.dart';

/// How many trees one pack is asked for. Same number the prompt requests.
const packTrees = 3;

/// Twenty seconds after a meeting: what is coming, or what could not be
/// said. Returns true when something was kept. Offered from home as well as
/// from the pack screen, because the moment to write it down is not the
/// moment anyone is thinking about prompts.
Future<bool> showCaptureDialog(BuildContext context, WidgetRef ref) async {
  final s = ref.read(stringsProvider);
  final draft = await showDialog<_CaptureDraft>(
    context: context,
    builder: (_) => _CaptureDialog(s: s),
  );
  if (draft == null) return false;
  await ref
      .read(repositoryProvider)
      .addCapture(note: draft.note, date: draft.date, who: draft.who);
  return true;
}

typedef _CaptureDraft = ({String note, String who, String? date});

/// Owns its text controllers, so they live exactly as long as the dialog —
/// including the frames it spends animating out after it has been popped.
class _CaptureDialog extends StatefulWidget {
  final S s;
  const _CaptureDialog({required this.s});

  @override
  State<_CaptureDialog> createState() => _CaptureDialogState();
}

class _CaptureDialogState extends State<_CaptureDialog> {
  final _note = TextEditingController();
  final _who = TextEditingController();
  String? _date;

  @override
  void dispose() {
    _note.dispose();
    _who.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null && mounted) setState(() => _date = _iso(d));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return AlertDialog(
      title: Text(s.t('captureAdd')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _note,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(labelText: s.t('captureNoteLabel')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _who,
              decoration: InputDecoration(labelText: s.t('captureWhoLabel')),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(_date ?? s.t('captureDatePick')),
                    onPressed: _pickDate,
                  ),
                ),
                if (_date != null)
                  IconButton(
                    tooltip: s.t('captureDateClear'),
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _date = null),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('cancel'))),
        FilledButton(
          onPressed: () {
            if (_note.text.trim().isEmpty) return;
            Navigator.pop(context, (note: _note.text, who: _who.text, date: _date));
          },
          child: Text(s.t('captureSave')),
        ),
      ],
    );
  }
}

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class PackScreen extends ConsumerStatefulWidget {
  /// Prefilled when the pack arrived through the share sheet.
  final String? initialText;
  const PackScreen({super.key, this.initialText});

  @override
  ConsumerState<PackScreen> createState() => _PackScreenState();
}

class _PackScreenState extends ConsumerState<PackScreen> {
  final _paste = PasteController();
  List<Capture> _captures = const [];
  List<Failure> _failures = const [];
  List<Attempt> _attempts = const [];
  Map<String, DebateTree> _trees = const {};
  bool _hasChunks = false;
  int _treesToday = 0;

  /// Critiques taken in during this visit. Not stored: the pack itself does
  /// not remember which paste a critique arrived in, and the count only
  /// matters while the pasting is going on.
  int _critiquesTaken = 0;
  List<({String topic, String reason})> _rejected = const [];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final shared = widget.initialText;
    if (shared != null) _paste.field.text = shared;
    _load();
  }

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(repositoryProvider);
    final captures = await repo.captures(pendingOnly: true);
    final failures = await repo.failures(pendingOnly: true);
    final attempts = await repo.attempts();
    final trees = await repo.debates(includeDisabled: true);
    final chunks = await repo.chunks();
    if (!mounted) return;
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    setState(() {
      _captures = captures;
      _failures = failures;
      _attempts = attempts;
      _trees = {for (final t in trees) t.id: t};
      _hasChunks = chunks.isNotEmpty;
      // Today's trees stand in for "this pack": a pack is pasted in one
      // sitting, and reopening the screen an hour later should still show
      // how far that sitting got.
      _treesToday = trees.where((t) => t.createdAt >= dayStart).length;
    });
  }

  String get _lang => ref.read(languageProvider) ?? fallbackLanguage;

  Future<String> _packPrompt() =>
      ref.read(repositoryProvider).packPromptText(uiLanguage: _lang, debates: packTrees);

  Future<void> _copyPack() async {
    final s = ref.read(stringsProvider);
    final text = await _packPrompt();
    if (!mounted) return;
    await copyToClipboard(context, text, s.t('copied'));
  }

  Future<void> _copyCritique() async {
    final s = ref.read(stringsProvider);
    final text = await ref.read(repositoryProvider).critiquePromptText(uiLanguage: _lang);
    if (!mounted) return;
    await copyToClipboard(context, text, s.t('critiqueNowCopied'));
  }

  Future<void> _capture() async {
    if (await showCaptureDialog(context, ref)) await _load();
  }

  Future<void> _deleteCapture(Capture c) async {
    final s = ref.read(stringsProvider);
    await ref.read(repositoryProvider).deleteCapture(c.id);
    if (!mounted) return;
    showToast(context, s.t('deletedLabel'));
    await _load();
  }

  /// Same shape as the material box: the button imports what is collected,
  /// and with nothing collected takes the reply off the clipboard instead.
  Future<void> _import() async {
    final s = ref.read(stringsProvider);
    if (_paste.isEmpty) {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (!mounted) return;
      if (text.trim().isEmpty) {
        setState(() => _error = s.t('clipboardEmpty'));
        return;
      }
      _paste.field.text = text;
    }

    setState(() {
      _busy = true;
      _error = null;
      _rejected = const [];
    });
    final out = await ref.read(repositoryProvider).importPack(_paste.text, uiLanguage: _lang);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!out.ok) {
      setState(() {
        _error = s.t('importFailedHint');
        _rejected = out.rejected;
      });
      return;
    }
    _paste.clear();
    ref.invalidate(debatesProvider);
    setState(() {
      _critiquesTaken += out.critiques;
      _rejected = out.rejected;
    });
    await _load();
    if (!mounted) return;
    showToast(context, s.t('packImported', {'n': out.debates}));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    final awaiting = _attempts.where((a) => a.awaitingCritique).length;
    final slipKinds = _failures.map((f) => f.kind).toSet().length;
    final critiqued = _attempts.where((a) => a.critique != null).toList()
      ..sort((a, b) => b.at.compareTo(a.at));

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('packTitle'), maxLines: 2, style: const TextStyle(fontSize: 18)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (widget.initialText != null) ...[
              Card(
                color: scheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Icon(Icons.ios_share, size: 18, color: scheme.onSecondaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s.t('sharedTextTitle'),
                          style: TextStyle(color: scheme.onSecondaryContainer)),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // -------- the capture box --------
            Text(s.t('captureTitle'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(s.t('captureHint'), style: muted),
            const SizedBox(height: 8),
            if (_captures.isEmpty)
              Text(s.t('captureEmpty'), style: muted)
            else
              for (final c in _captures)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_note),
                  title: Text(c.noteNative),
                  subtitle: (c.date != null || c.who.isNotEmpty)
                      ? Text([?c.date, if (c.who.isNotEmpty) c.who].join(' · '))
                      : null,
                  trailing: IconButton(
                    tooltip: s.t('deletedLabel'),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteCapture(c),
                  ),
                ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_note),
              onPressed: _capture,
              label: Text(s.t('captureAdd')),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // -------- what the prompt carries --------
            Text(s.t('packContents'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            for (final line in [
              s.t('packEvents', {'n': _captures.length}),
              s.t('packAwaiting', {'n': awaiting}),
              s.t('packFailures', {'n': slipKinds}),
              s.t(_hasChunks ? 'packChunksHave' : 'packChunksNeed'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(children: [
                  Icon(Icons.circle, size: 6, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(child: Text(line, style: theme.textTheme.bodyMedium)),
                ]),
              ),
            const SizedBox(height: 14),

            _StepHeader(1, s.t('step1Title')),
            FilledButton.icon(
              icon: const Icon(Icons.copy_all),
              onPressed: _copyPack,
              label: Text(s.t('copyPrompt')),
            ),
            const SizedBox(height: 16),
            AiLinks(s: s, prompt: _packPrompt),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.schedule, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(child: Text(s.t('aiTakesTime'), style: muted)),
            ]),

            // The extra trip for the learner who cannot wait. Everyone else
            // leaves it alone and the critiques ride along with the pack.
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.rate_review_outlined),
              onPressed: awaiting == 0 ? null : _copyCritique,
              label: Text(s.t('critiqueNow')),
            ),
            const SizedBox(height: 4),
            Text(s.t('critiqueNowHint'), style: muted),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            _StepHeader(2, s.t('step2Title')),
            // The tally. One tree per paste, so this is what turns "paste
            // again" into "two of three".
            Text(
              s.t('packProgress',
                  {'n': _treesToday, 'target': packTrees, 'm': _critiquesTaken}),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
            ),
            if (_treesToday > 0) ...[
              const SizedBox(height: 2),
              Text(s.t(_treesToday >= packTrees ? 'packProgressDone' : 'packProgressNext'),
                  style: muted),
            ],
            const SizedBox(height: 12),
            CopyTip(s),
            const SizedBox(height: 12),
            PasteBox(controller: _paste, s: s, expecting: 'pack'),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Card(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.t('importFailedTitle'),
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: scheme.onErrorContainer)),
                      const SizedBox(height: 4),
                      Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
                    ],
                  ),
                ),
              ),
            ],
            // Trees the importer could not make sound, named with the reason.
            // Not an error: the rest of the pack went in.
            if (_rejected.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                color: scheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    s.t('packRejected', {
                      'n': _rejected.length,
                      'reasons': _rejected.map((r) => '${r.topic} (${r.reason})').join('; '),
                    }),
                    style: TextStyle(color: scheme.onTertiaryContainer),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _busy ? null : _import,
              child: _busy
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(s.t('packTakeIn')),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // -------- critiques that came back --------
            Text(s.t('critiquesTitle'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (critiqued.isEmpty)
              Text(s.t('critiquesEmpty'), style: muted)
            else
              for (final a in critiqued.take(20))
                _CritiqueCard(attempt: a, tree: _trees[a.debateId], s: s),
          ],
        ),
      ),
    );
  }
}

class _CritiqueCard extends StatelessWidget {
  final Attempt attempt;
  final DebateTree? tree;
  final S s;
  const _CritiqueCard({required this.attempt, required this.tree, required this.s});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = attempt.critique!;
    final line = tree?.node(attempt.nodeId)?.line;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tree?.label ?? attempt.debateId,
                style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
            if (line != null && line.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(line, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Text(s.t('debateYourReply'), style: theme.textTheme.labelMedium),
            Text(attempt.youSaid, style: const TextStyle(fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
            Text(c.verdictNative, style: theme.textTheme.bodyMedium),
            if (c.better.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(s.t('critiqueBetter'), style: theme.textTheme.labelMedium),
              for (final b in c.better)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('· $b', style: theme.textTheme.bodyMedium),
                ),
            ],
            if (c.watchNative.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(s.t('critiqueWatch'), style: theme.textTheme.labelMedium),
              Text(c.watchNative,
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary)),
            ],
          ],
        ),
      ),
    );
  }
}

/// "1 — Copy the prompt". The same numbering as the material screen, so the
/// two halves of the trip read in the same order everywhere.
class _StepHeader extends StatelessWidget {
  final int n;
  final String title;
  const _StepHeader(this.n, this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: theme.colorScheme.primary,
            child: Text('$n',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimary)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
        ],
      ),
    );
  }
}
