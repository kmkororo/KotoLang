/// One field of one kind: the samples that came with the app for it, or the
/// scenes the learner's own AI wrote for it.
///
/// The two kinds never mix on a screen. The samples are there to be
/// outgrown; on the learner's own side, the button to make scenes leads the
/// moment there is nothing yet, and stays close at hand after.
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

  /// The learner's own scenes of this field, as opposed to the samples.
  final bool own;
  const FieldScreen({super.key, required this.field, required this.own});

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
    final scheme = theme.colorScheme;
    final all = ref.watch(allScenesProvider).value ?? const <Scene>[];
    final results = ref.watch(sceneResultsProvider).value ?? const <SceneResult>[];
    final split = splitField(all, field.id);
    final scenes = own ? split.own : split.samples;
    final done = {for (final r in results) if (!r.review) r.sceneId};
    final n = scenes.where((x) => done.contains(x.id)).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('${field.label} · ${s.t(own ? 'fieldOwn' : 'sampleTag')}',
            style: const TextStyle(fontSize: 18)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  if (scenes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(s.t('fieldCount', {'d': n, 'n': scenes.length}),
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                  if (scenes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Icon(own ? Icons.local_florist_outlined : Icons.menu_book_outlined,
                              size: 40, color: scheme.outlineVariant),
                          const SizedBox(height: 12),
                          Text(s.t(own ? 'fieldOwnNone' : 'sceneNoneYet'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  for (final sc in scenes)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        done.contains(sc.id) ? Icons.check_circle : Icons.circle_outlined,
                        color: done.contains(sc.id) ? scheme.primary : scheme.outlineVariant,
                      ),
                      title: Text(sc.label),
                      subtitle: sc.settingNative.isEmpty ? null : Text(sc.settingNative),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (scenes.isNotEmpty)
                    FilledButton(
                      onPressed: () => startScene(context, ref, all: scenes, onDone: () => _refresh(ref)),
                      child: Text(s.t(own ? 'fieldStartOwn' : 'fieldStartSamples')),
                    ),
                  if (own) ...[
                    if (scenes.isNotEmpty) const SizedBox(height: 8),
                    (scenes.isEmpty ? FilledButton.new : OutlinedButton.new)(
                      onPressed: () => _makeScenes(context, ref),
                      child: Text(s.t(scenes.isEmpty ? 'makeOwnScenes' : 'nextScenesMake')),
                    ),
                  ],
                ],
              ),
            ),
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
