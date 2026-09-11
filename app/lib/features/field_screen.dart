/// One field of one kind: the samples that came with the app for it, or the
/// conversations the learner's own AI wrote for it.
///
/// The two kinds never mix on a screen. There is no list of what is inside —
/// a conversation is not something to browse and pick, it is something to
/// start — so the screen is the field's own bough and the three things that
/// can be done with it: start, ask for more, send the results back.
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

class FieldScreen extends ConsumerStatefulWidget {
  final Field field;

  /// The learner's own conversations of this field, as opposed to the samples.
  final bool own;
  const FieldScreen({super.key, required this.field, required this.own});

  @override
  ConsumerState<FieldScreen> createState() => _FieldScreenState();
}

class _FieldScreenState extends ConsumerState<FieldScreen> {
  /// What another batch would cost here. Nothing the first time.
  int _cost = 0;

  @override
  void initState() {
    super.initState();
    _loadCost();
  }

  Future<void> _loadCost() async {
    final cost = await ref.read(repositoryProvider).sceneAddCostFor(widget.field.id);
    if (mounted) setState(() => _cost = cost);
  }

  void _refresh() {
    ref.invalidate(allScenesProvider);
    ref.invalidate(sceneResultsProvider);
    ref.invalidate(skillStatsProvider);
    _loadCost();
  }

  Future<void> _makeScenes() async {
    final seeds = ref.read(progressProvider).seeds;
    if (_cost > 0 && seeds < _cost) {
      final s = ref.read(stringsProvider);
      showToast(context, s.t('unlockRealmNeedMore', {'n': _cost - seeds}));
      return;
    }
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AiPromptScreen(job: AiJob.scenes, initialField: widget.field.id)));
    if (mounted) _refresh();
  }

  Future<void> _feedback(int done, int need) async {
    final s = ref.read(stringsProvider);
    if (done < need) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.insights_outlined),
          title: Text(s.t('feedbackLockedTitle')),
          content: Text(s.t('feedbackLockedBody', {'n': need, 'd': done})),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('close'))),
          ],
        ),
      );
      return;
    }
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AiPromptScreen(job: AiJob.feedback, initialField: widget.field.id)));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final all = ref.watch(allScenesProvider).value ?? const <Scene>[];
    final results = ref.watch(sceneResultsProvider).value ?? const <TurnResult>[];
    final split = splitField(all, widget.field.id);
    final scenes = widget.own ? split.own : split.samples;
    final done = {for (final r in results) if (!r.review) r.sceneId};
    final here = {for (final x in scenes) x.id};
    final n = here.intersection(done).length;
    // The bough exists once something here has been answered.
    final hasBough = n > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.field.label} · ${s.t(widget.own ? 'fieldOwn' : 'sampleTag')}',
            style: const TextStyle(fontSize: 18)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // This field's bough alone, the way it stands on the tree.
              if (hasBough) ...[
                TreePanel(
                    focus: widget.own
                        ? ownBranch(widget.field.id)
                        : sampleBranch(widget.field.id),
                    compact: true),
                const SizedBox(height: 8),
              ] else
                const Spacer(),
              Text(
                scenes.isEmpty
                    ? s.t(widget.own ? 'fieldOwnNone' : 'sceneNoneYet')
                    : s.t('fieldCount', {'d': n, 'n': scenes.length}),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Spacer(),

              // -------- the three things that can be done here --------
              if (scenes.isNotEmpty)
                FilledButton(
                  onPressed: () =>
                      startScene(context, ref, all: scenes, onDone: _refresh),
                  child: Text(s.t('fieldStart')),
                ),
              if (widget.own) ...[
                if (scenes.isNotEmpty) const SizedBox(height: 10),
                (scenes.isEmpty ? FilledButton.new : OutlinedButton.new)(
                  onPressed: _makeScenes,
                  child: Text(s.t(scenes.isEmpty ? 'makeOwnScenes' : 'nextScenesMake')),
                ),
                if (_cost > 0) ...[
                  const SizedBox(height: 4),
                  Text(s.t('seedsCost', {'n': _cost}),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
                // Sending the results back needs enough of them — but never
                // more than this field holds, or a small field could never
                // reach it.
                if (scenes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _FeedbackButton(
                    label: s.t('feedbackButton'),
                    done: n,
                    need: feedbackAfter < scenes.length ? feedbackAfter : scenes.length,
                    onTap: () => _feedback(
                        n, feedbackAfter < scenes.length ? feedbackAfter : scenes.length),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The way to send this field's results back to the AI — and, until there are
/// enough of them, the count of what is missing. Locked it is a plain
/// black-and-white bar that fills as conversations are finished, so the wait
/// is visible rather than merely refused.
class _FeedbackButton extends StatelessWidget {
  final String label;
  final int done;
  final int need;
  final VoidCallback onTap;
  const _FeedbackButton({
    required this.label,
    required this.done,
    required this.need,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (done >= need) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.insights_outlined, size: 18),
        label: Text(label),
      );
    }

    final fill = (done / need).clamp(0.0, 1.0);
    return Semantics(
      button: true,
      label: '$label · $done / $need',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                // How far along the wait is, as the button's own fill.
                FractionallySizedBox(
                  widthFactor: fill,
                  child: Container(color: scheme.onSurface.withValues(alpha: 0.10)),
                ),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(label,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                      ),
                      const SizedBox(width: 8),
                      Text('$done / $need',
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
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

  /// What kind of field this is, where the list mixes kinds.
  final IconData? icon;

  /// The button's words, when there is one: "Choose" while starting fields
  /// are still to be picked, the Seeds price after that.
  final String? action;
  final VoidCallback? onTap;
  const FieldCard({
    super.key,
    required this.label,
    this.sub,
    this.locked = false,
    this.icon,
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
                  Icon(locked ? Icons.lock_outline : (icon ?? Icons.local_florist),
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

/// Which field to work in: the learner's own, or the samples'. Picking one
/// opens its screen, where the conversations are started. For their own the
/// way to open another field sits at the bottom, since opening one is the
/// only other thing this list can lead to.
Future<void> showScenesFieldSheet(BuildContext context, WidgetRef ref,
    {required bool own}) async {
  final s = ref.read(stringsProvider);
  final all = await ref.read(fieldsProvider.future);
  final scenes = await ref.read(allScenesProvider.future);
  final results = await ref.read(sceneResultsProvider.future);
  if (!context.mounted) return;
  final done = {for (final r in results) if (!r.review) r.sceneId};
  // A field of their own is worth showing before it has anything in it: the
  // field's own screen is where more is asked for.
  final fields = [
    for (final f in all)
      if (own ? (!f.builtin || splitField(scenes, f.id).own.isNotEmpty)
              : splitField(scenes, f.id).samples.isNotEmpty)
        f
  ];

  final picked = await showModalBottomSheet<Field>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(s.t(own ? 'homeFieldScenes' : 'homeSampleScenes'),
              style: Theme.of(ctx).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (fields.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(s.t('fieldOwnEmptyHint'),
                  style: Theme.of(ctx)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            ),
          for (final f in fields) ...[
            Builder(builder: (_) {
              final here = own ? splitField(scenes, f.id).own : splitField(scenes, f.id).samples;
              final n = here.where((x) => done.contains(x.id)).length;
              return FieldCard(
                label: f.label,
                icon: own ? Icons.local_florist : Icons.menu_book_outlined,
                sub: s.t('fieldCount', {'d': n, 'n': here.length}),
                onTap: () => Navigator.pop(ctx, f),
              );
            }),
            const SizedBox(height: 8),
          ],
          if (own) ...[
            const SizedBox(height: 4),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              onPressed: () {
                Navigator.pop(ctx);
                showOpenFieldSheet(context, ref);
              },
              label: Text(s.t('fieldAdd')),
            ),
          ],
        ],
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  await Navigator.push(
      context, MaterialPageRoute(builder: (_) => FieldScreen(field: picked, own: own)));
}
