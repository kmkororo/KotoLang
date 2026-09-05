/// One field of the learner's life, split into the samples that came with
/// the app and the scenes their own AI wrote for it.
///
/// The split is the point: the samples are there to be outgrown, and the
/// button to make scenes of one's own stands out the moment the samples are
/// done or there are no own scenes yet. Both halves start a run of scenes
/// from that half alone.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../domain/field.dart';
import '../domain/progress_service.dart';
import '../domain/scene.dart';
import 'scene_pack_screen.dart';
import 'scene_screen.dart';

class FieldScreen extends ConsumerWidget {
  final Field field;
  const FieldScreen({super.key, required this.field});

  void _refresh(WidgetRef ref) {
    ref.invalidate(allScenesProvider);
    ref.invalidate(sceneResultsProvider);
    ref.invalidate(skillStatsProvider);
  }

  Future<void> _makeScenes(BuildContext context, WidgetRef ref) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ScenePackScreen(initialField: field.id)));
    if (context.mounted) _refresh(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final scenes = ref.watch(allScenesProvider).value ?? const <Scene>[];
    final results = ref.watch(sceneResultsProvider).value ?? const <SceneResult>[];
    final split = splitField(scenes, field.id);
    final done = {for (final r in results) if (!r.review) r.sceneId};
    int doneOf(List<Scene> xs) => xs.where((x) => done.contains(x.id)).length;
    final samplesDone = split.samples.isNotEmpty && doneOf(split.samples) == split.samples.length;
    // Making scenes of one's own is the main thing to do here once the
    // samples are used up or there is nothing of one's own yet.
    final makeLeads = split.own.isEmpty || samplesDone;

    return Scaffold(
      appBar: AppBar(title: Text(field.label)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Half(
              title: s.t('sampleTag'),
              scenes: split.samples,
              done: done,
              empty: s.t('sceneNoneYet'),
              button: split.samples.isEmpty
                  ? null
                  : OutlinedButton(
                      onPressed: () => startScene(context, ref,
                          all: split.samples, onDone: () => _refresh(ref)),
                      child: Text(s.t('fieldStartSamples')),
                    ),
            ),
            const SizedBox(height: 16),
            _Half(
              title: s.t('fieldOwn'),
              scenes: split.own,
              done: done,
              flowers: true,
              empty: s.t('fieldOwnNone'),
              button: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (split.own.isNotEmpty)
                    (makeLeads ? OutlinedButton.new : FilledButton.new)(
                      onPressed: () => startScene(context, ref,
                          all: split.own, onDone: () => _refresh(ref)),
                      child: Text(s.t('fieldStartOwn')),
                    ),
                  if (split.own.isNotEmpty) const SizedBox(height: 8),
                  (makeLeads ? FilledButton.new : OutlinedButton.new)(
                    onPressed: () => _makeScenes(context, ref),
                    child: Text(s.t(split.own.isEmpty ? 'makeOwnScenes' : 'nextScenesMake')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(s.t('ownScenesCardBody'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// The samples, or the learner's own: a count, the scenes with a mark on the
/// ones done, and what to do with them.
class _Half extends ConsumerWidget {
  final String title;
  final List<Scene> scenes;
  final Set<String> done;
  final String empty;
  final Widget? button;
  final bool flowers;
  const _Half({
    required this.title,
    required this.scenes,
    required this.done,
    required this.empty,
    required this.button,
    this.flowers = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = scenes.where((x) => done.contains(x.id)).length;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(flowers ? Icons.local_florist : Icons.menu_book_outlined,
                    size: 18, color: flowers ? scheme.primary : scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                if (scenes.isNotEmpty)
                  Text(s.t('fieldCount', {'d': n, 'n': scenes.length}),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 8),
            if (scenes.isEmpty)
              Text(empty,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))
            else
              for (final sc in scenes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        done.contains(sc.id) ? Icons.check_circle : Icons.circle_outlined,
                        size: 16,
                        color: done.contains(sc.id) ? scheme.primary : scheme.outlineVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(sc.label, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                ),
            if (button != null) ...[const SizedBox(height: 12), button!],
          ],
        ),
      ),
    );
  }
}

/// Asks for the name of a new field and adds it, for Seeds. The dialog owns
/// its text field; a controller disposed by the screen while the dialog is
/// still animating out is how this used to crash.
Future<void> showAddFieldDialog(BuildContext context, WidgetRef ref) async {
  final s = ref.read(stringsProvider);
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _AddFieldDialog(
      title: s.t('fieldAdd'),
      body: s.t('fieldAddBody', {'n': realmUnlockCost}),
      hint: s.t('fieldAddHint'),
      confirm: s.t('confirmLabel'),
      cancel: s.t('cancel'),
    ),
  );
  if (name == null || name.trim().isEmpty || !context.mounted) return;
  final repo = ref.read(repositoryProvider);
  final realm = await repo.addField(name);
  if (!context.mounted) return;
  if (realm == null) {
    final progress = ref.read(progressProvider);
    showToast(context, s.t('unlockRealmNeedMore', {'n': realmUnlockCost - progress.seeds}));
    return;
  }
  ref.read(progressProvider.notifier).state = await repo.loadProgress();
  ref.invalidate(realmsProvider);
  ref.invalidate(fieldsProvider);
  if (context.mounted) showToast(context, s.t('fieldAdded', {'name': realm.label}));
}

class _AddFieldDialog extends StatefulWidget {
  final String title, body, hint, confirm, cancel;
  const _AddFieldDialog({
    required this.title,
    required this.body,
    required this.hint,
    required this.confirm,
    required this.cancel,
  });

  @override
  State<_AddFieldDialog> createState() => _AddFieldDialogState();
}

class _AddFieldDialogState extends State<_AddFieldDialog> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.body, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _ctl,
              autofocus: true,
              decoration: InputDecoration(hintText: widget.hint),
              textInputAction: TextInputAction.done,
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, _ctl.text), child: Text(widget.confirm)),
        ],
      );
}
