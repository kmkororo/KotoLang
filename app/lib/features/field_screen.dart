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
import '../domain/tree.dart';
import 'scene_pack_screen.dart';
import 'scene_screen.dart';
import 'tree_view.dart';

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
    // The bough exists once something here has been answered.
    final hasBough = n > 0;

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
                  // This field's bough alone, the way it stands on the tree.
                  if (hasBough) ...[
                    TreePanel(focus: own ? ownBranch(field.id) : sampleBranch(field.id), compact: true),
                    const SizedBox(height: 8),
                  ],
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

/// Opens one of the areas the AI read off the profile, for Seeds: confirm,
/// pay, and it is a field scenes can be made for. Returns true when opened.
Future<bool> openLockedField(BuildContext context, WidgetRef ref, Field f) async {
  final s = ref.read(stringsProvider);
  final repo = ref.read(repositoryProvider);
  final progress = ref.read(progressProvider);
  if (progress.seeds < realmUnlockCost) {
    showToast(context, s.t('unlockRealmNeedMore', {'n': realmUnlockCost - progress.seeds}));
    return false;
  }
  final ok = await confirm(
    context,
    title: s.t('unlockRealmConfirmTitle', {'realm': f.label}),
    body: s.t('unlockRealmConfirmBody', {'n': realmUnlockCost}),
    confirmLabel: s.t('unlockButton'),
    cancelLabel: s.t('cancel'),
    destructive: false,
  );
  if (!ok || !context.mounted) return false;
  final spent = await repo.unlockRealm(f.id);
  if (!context.mounted || !spent) return false;
  ref.read(progressProvider.notifier).state = await repo.loadProgress();
  ref.invalidate(realmsProvider);
  ref.invalidate(fieldsProvider);
  ref.invalidate(lockedFieldsProvider);
  if (context.mounted) showToast(context, s.t('fieldAdded', {'name': f.label}));
  return true;
}

/// The areas from the profile that are still closed, as a sheet to pick
/// from. There is nothing to type: a field the AI never heard of would have
/// no scenes written for it.
Future<void> showOpenFieldSheet(BuildContext context, WidgetRef ref) async {
  final s = ref.read(stringsProvider);
  final locked = await ref.read(lockedFieldsProvider.future);
  if (!context.mounted) return;
  final picked = await showModalBottomSheet<Field>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(s.t('fieldAdd'), style: Theme.of(ctx).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(s.t('fieldAddBody', {'n': realmUnlockCost}), style: Theme.of(ctx).textTheme.bodySmall),
          const SizedBox(height: 8),
          if (locked.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(s.t('fieldNoneLocked'),
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            ),
          for (final f in locked)
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(f.label),
              trailing: Text('$realmUnlockCost Seeds'),
              onTap: () => Navigator.pop(ctx, f),
            ),
        ],
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  await openLockedField(context, ref, picked);
}
