/// Library: what the AI produced, and what the learner has done with it.
///
/// Hiding is offered before deleting, because material that turned out to be
/// awkward is usually worth keeping out of rotation rather than destroying.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/util.dart';
import '../domain/models.dart';
import '../domain/srs.dart' as srs;

class _LibraryData {
  final List<LearningItem> items;
  final List<Sentence> sentences;
  final Map<String, SrsState> states;
  final List<Realm> realms;
  const _LibraryData(this.items, this.sentences, this.states, this.realms);
}

final _libraryProvider = FutureProvider.autoDispose<_LibraryData>((ref) async {
  final repo = ref.watch(repositoryProvider);
  return _LibraryData(
    await repo.items(),
    await repo.sentences(),
    {for (final s in await repo.srsStates()) s.itemId: s},
    await repo.realms(),
  );
});

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _showSentences = false;
  String _query = '';
  String? _realmId;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final data = ref.watch(_libraryProvider);
    final theme = Theme.of(context);

    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (d) {
        final withMaterial = d.realms.where((r) => r.hasMaterial).toList();
        final q = normKey(_query);

        var items = d.items;
        var sentences = d.sentences;
        if (_realmId != null) {
          items = items.where((i) => i.realmIds.contains(_realmId)).toList();
          sentences = sentences.where((x) => x.realmId == _realmId).toList();
        }
        if (q.isNotEmpty) {
          items = items
              .where((i) =>
                  normKey(i.text).contains(q) || normKey(i.meaningNative).contains(q))
              .toList();
          sentences = sentences
              .where((x) =>
                  normKey(x.text).contains(q) ||
                  normKey(x.translationNative).contains(q))
              .toList();
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(s.t('libraryTitle'),
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (withMaterial.length > 1)
              DropdownButtonFormField<String?>(
                initialValue: _realmId,
                decoration: InputDecoration(labelText: s.t('realmLabel'), isDense: true),
                items: [
                  DropdownMenuItem(value: null, child: Text(s.t('allRealms'))),
                  for (final r in withMaterial)
                    DropdownMenuItem(value: r.id, child: Text(r.label)),
                ],
                onChanged: (v) => setState(() => _realmId = v),
              ),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(s.t('tabExpressions'))),
                ButtonSegment(value: true, label: Text(s.t('tabSentences'))),
              ],
              selected: {_showSentences},
              onSelectionChanged: (v) => setState(() => _showSentences = v.first),
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                hintText: s.t('searchHint'),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            if (_showSentences)
              ...sentences.take(300).map((x) => _sentenceTile(x, s, theme))
            else
              ...items.take(300).map((i) => _itemTile(i, d.states[i.id], s, theme)),
            if ((_showSentences ? sentences : items).isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                    child: Text(s.t('emptyList'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant))),
              ),
          ],
        );
      },
    );
  }

  Widget _itemTile(LearningItem i, SrsState? st, dynamic s, ThemeData theme) {
    final acc = st == null ? null : srs.accuracy(st);
    final badge = st == null || !st.introduced
        ? s.t('notStudied')
        : srs.isMastered(st)
            ? s.t('mastered')
            : srs.isDue(st)
                ? s.t('dueNow')
                : s.t('boxLabel', {'n': st.box, 'date': st.due});

    return Opacity(
      opacity: i.disabled ? 0.5 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(i.text, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (i.meaningNative.isNotEmpty)
                Text(i.meaningNative,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Chip(
                    label: Text(badge),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none),
                if (acc != null && acc.n > 0)
                  Chip(
                      label: Text(s.t('accuracyLabel', {'pct': acc.pct, 'n': acc.n})),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none),
                TextButton(
                  onPressed: () async {
                    await ref
                        .read(repositoryProvider)
                        .setItemDisabled(i.id, !i.disabled);
                    ref.invalidate(_libraryProvider);
                  },
                  child: Text(i.disabled ? s.t('resumeQuiz') : s.t('hideFromQuiz')),
                ),
                TextButton(
                  onPressed: () async {
                    final ok = await confirm(
                      context,
                      title: s.t('deleteLabel'),
                      body: i.text,
                      confirmLabel: s.t('deleteLabel'),
                      cancelLabel: s.t('cancel'),
                    );
                    if (!ok) return;
                    await ref.read(repositoryProvider).deleteItem(i.id);
                    ref.invalidate(_libraryProvider);
                  },
                  child: Text(s.t('deleteLabel')),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sentenceTile(Sentence x, dynamic s, ThemeData theme) => Opacity(
        opacity: x.disabled ? 0.5 : 1,
        child: Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(x.text, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (x.translationNative.isNotEmpty)
                  Text(x.translationNative,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Chip(
                      label: Text(x.level),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none),
                  if (x.quality != null)
                    Chip(
                        label: Text('${x.quality}/5'),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none),
                  TextButton.icon(
                    icon: const Icon(Icons.volume_up, size: 18),
                    onPressed: () => ref.read(speechProvider).speak(x.text,
                        rate: ref.read(settingsProvider).rate),
                    label: Text(s.t('playLabel')),
                  ),
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(repositoryProvider)
                          .setSentenceDisabled(x.id, !x.disabled);
                      ref.invalidate(_libraryProvider);
                    },
                    child: Text(x.disabled ? s.t('resumeQuiz') : s.t('hideFromQuiz')),
                  ),
                ]),
              ],
            ),
          ),
        ),
      );
}
