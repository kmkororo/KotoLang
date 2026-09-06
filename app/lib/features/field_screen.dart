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
import 'ai_screens.dart';
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
        MaterialPageRoute(builder: (_) => AiPromptScreen(job: AiJob.scenes, initialField: field.id)));
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

/// Opens one of the areas the AI read off the profile: as one of the starting
/// fields while those are still to be chosen, for Seeds after that. When
/// [toScenes] is set, the scenes screen follows with the field already
/// chosen — an open field with no scenes is nothing yet. Returns true when
/// opened.
Future<bool> openLockedField(BuildContext context, WidgetRef ref, Field f,
    {bool toScenes = false}) async {
  final s = ref.read(stringsProvider);
  final repo = ref.read(repositoryProvider);
  // The starting fields are the learner's to choose; after those, a field
  // is bought with Seeds, and the dialog says so.
  final choosing = await repo.freeFieldSlotsLeft() > 0;
  if (!context.mounted) return false;
  if (!choosing) {
    final ok = await showLockedFieldDialog(context, ref, f.label);
    if (!ok || !context.mounted) return false;
  }
  final opened = await repo.openField(f.id);
  if (!context.mounted || !opened) return false;
  ref.read(progressProvider.notifier).state = await repo.loadProgress();
  ref.invalidate(realmsProvider);
  ref.invalidate(fieldsProvider);
  ref.invalidate(lockedFieldsProvider);
  ref.invalidate(freeFieldSlotsProvider);
  if (!context.mounted) return true;
  showToast(context, s.t('fieldAdded', {'name': f.label}));
  if (toScenes) {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => AiPromptScreen(job: AiJob.scenes, initialField: f.id)));
  }
  return true;
}

/// The locked field's popup: what it costs, what the learner has, and — when
/// the balance covers it — the button that opens it. Returns true only when
/// that button was pressed.
Future<bool> showLockedFieldDialog(BuildContext context, WidgetRef ref, String label) async {
  final s = ref.read(stringsProvider);
  final seeds = ref.read(progressProvider).seeds;
  final enough = seeds >= realmUnlockCost;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.lock_outline),
      // A field name can be long; the default headline size wraps it into
      // three lines on a narrow screen.
      titleTextStyle: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      title: Text(s.t('lockedFieldTitle', {'realm': label})),
      content: Text(s.t('lockedFieldBody', {'n': realmUnlockCost, 'have': seeds})),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(s.t(enough ? 'cancel' : 'close')),
        ),
        if (enough)
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.t('seedsCost', {'n': realmUnlockCost})),
          ),
      ],
    ),
  );
  return ok ?? false;
}

/// One field as a card: the name on its own line, so a long one wraps
/// instead of being squeezed beside a button; under it a small line and,
/// for a closed field, the button that opens it.
class FieldCard extends StatelessWidget {
  final String label;
  final String? sub;
  final bool locked;

  /// The button's words, when there is one: "Choose" while starting fields
  /// are still to be picked, the Seeds price after that.
  final String? action;
  final VoidCallback? onTap;
  const FieldCard({
    super.key,
    required this.label,
    this.sub,
    this.locked = false,
    this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dim = locked ? scheme.onSurfaceVariant : null;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(locked ? Icons.lock_outline : Icons.local_florist,
                      size: 18, color: locked ? scheme.onSurfaceVariant : scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(label,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700, color: dim)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(sub ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ),
                  if (action != null)
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 12)),
                      onPressed: onTap,
                      child: Text(action!),
                    )
                  else
                    Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The areas from the profile that are still closed, as a sheet to pick
/// from. There is nothing to type: a field the AI never heard of would have
/// no scenes written for it.
Future<void> showOpenFieldSheet(BuildContext context, WidgetRef ref) async {
  final s = ref.read(stringsProvider);
  final locked = await ref.read(lockedFieldsProvider.future);
  final left = await ref.read(freeFieldSlotsProvider.future);
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
          Text(
            left > 0 ? s.t('fieldChooseLeft', {'n': left}) : s.t('fieldAddBody', {'n': realmUnlockCost}),
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (locked.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(s.t('fieldNoneLocked'),
                  style: Theme.of(ctx)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            ),
          for (final f in locked) ...[
            FieldCard(
              label: f.label,
              locked: true,
              sub: s.t('fieldFromProfile'),
              action: left > 0 ? s.t('fieldChooseButton') : s.t('seedsCost', {'n': realmUnlockCost}),
              onTap: () => Navigator.pop(ctx, f),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  await openLockedField(context, ref, picked, toScenes: true);
}
