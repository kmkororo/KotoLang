/// Home. Opening the app should answer one question: what do I do today?
///
/// The tree, one button that picks a scene at random — from the learner's
/// own scenes once there are any, from the samples until then — one line of
/// numbers, and two doors: the samples and the learner's own scenes, each
/// opening onto its fields. The card under the button says, for as long as
/// only samples are here, that the point of the app is the scenes the
/// learner's own AI writes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../domain/field.dart';
import '../domain/models.dart';
import '../domain/scene.dart';
import '../domain/skills.dart';
import '../domain/tree.dart';
import 'field_screen.dart';
import 'listen_screen.dart';
import 'scene_pack_screen.dart';
import 'scene_screen.dart';
import 'tree_view.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(sceneResultsProvider);
    ref.invalidate(skillStatsProvider);
    ref.invalidate(treeDataProvider);
  }

  Future<void> _openPack(BuildContext context, WidgetRef ref) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScenePackScreen()));
    if (!context.mounted) return;
    ref.invalidate(allScenesProvider);
    _refresh(ref);
  }

  Future<void> _openField(BuildContext context, WidgetRef ref, Field field, {required bool own}) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => FieldScreen(field: field, own: own)));
    if (!context.mounted) return;
    ref.invalidate(allScenesProvider);
    _refresh(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = ref.watch(progressProvider);
    final scenes = ref.watch(allScenesProvider).value ?? const <Scene>[];
    final results = ref.watch(sceneResultsProvider).value ?? const <SceneResult>[];
    final stats = ref.watch(skillStatsProvider).value ?? SkillStats.empty;
    final fields = ref.watch(fieldsProvider).value ?? const <Field>[];
    final samplesOpen = ref.watch(samplesOpenProvider);

    final ownScenes = [for (final x in scenes) if (!x.isBuiltin) x];
    final hasOwn = ownScenes.isNotEmpty;
    final done = {for (final r in results) if (!r.review) r.sceneId};
    final allDone = scenes.isNotEmpty && scenes.every((x) => done.contains(x.id));
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    // Today's scene comes from the learner's own scenes once there are any.
    final pool = hasOwn ? ownScenes : scenes;
    // The learner's own side lists only the fields that have scenes: the
    // fields grow as the AI writes for them, rather than standing empty.
    final ownFields = [for (final f in fields) if (splitField(ownScenes, f.id).own.isNotEmpty) f];
    final sampleFields = [for (final f in fields) if (splitField(scenes, f.id).samples.isNotEmpty) f];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // -------- streak / seeds strip --------
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Text('KotoLang',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            Wrap(spacing: 8, runSpacing: 4, children: [
              _Pill(icon: '☀️', text: s.t('streakPill', {'n': progress.streak})),
              _Pill(icon: '🌱', text: '${progress.seeds} Seeds'),
            ]),
          ],
        ),
        const SizedBox(height: 16),

        _Banner(progress: progress),

        // -------- the tree --------
        const TreePanel(),
        const SizedBox(height: 4),
        Text(
          stats.scenes == 0
              ? s.t(hasOwn ? 'treeSproutHintOwn' : 'treeSproutHint')
              : '${s.t('treeStage${treeStage(stats.scenes)}')} · ${s.t('treeGrownScenes', {'n': stats.scenes})}',
          textAlign: TextAlign.center,
          style: muted,
        ),
        const SizedBox(height: 16),

        // -------- the one button --------
        if (allDone && hasOwn) ...[
          _Card(
            color: scheme.tertiaryContainer,
            fg: scheme.onTertiaryContainer,
            title: s.t('allDoneTitle'),
            body: s.t('allDoneBody'),
            button: s.t('nextScenesMake'),
            onTap: () => _openPack(context, ref),
          ),
          const SizedBox(height: 12),
        ],
        if (scenes.isEmpty)
          FilledButton(
            onPressed: () => _openPack(context, ref),
            child: Text(s.t('firstSceneMake')),
          )
        else ...[
          FilledButton(
            onPressed: () => startScene(context, ref, all: pool, onDone: () => _refresh(ref)),
            child: Text(s.t(hasOwn ? 'todayScene' : 'todaySceneSample')),
          ),
          const SizedBox(height: 4),
          Text(s.t('todayRandomNote'), textAlign: TextAlign.center, style: muted),
        ],

        // For as long as only samples are here: the way to the real thing,
        // always in view. Gone the moment one own scene arrives.
        if (!hasOwn && scenes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Card(
            color: scheme.secondaryContainer,
            fg: scheme.onSecondaryContainer,
            title: s.t('ownScenesCardTitle'),
            body: s.t('ownScenesCardBody'),
            button: s.t('makeOwnScenes'),
            onTap: () => _openPack(context, ref),
          ),
        ],

        // -------- the one line of numbers --------
        const SizedBox(height: 12),
        Text(
          stats.exchanges == 0
              ? s.t('axisEmpty')
              : s.t('axisLine', {
                  'g': stats.all.gist.pct ?? 0,
                  'r': stats.all.reply.pct ?? 0,
                }),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),

        // -------- the learner's own scenes, by field --------
        const SizedBox(height: 20),
        _GroupTitle(icon: Icons.local_florist, title: s.t('ownFieldsTitle'), color: scheme.primary),
        const SizedBox(height: 8),
        if (ownFields.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(s.t('fieldOwnEmptyHint'), style: muted),
          ),
        for (final f in ownFields) ...[
          _FieldTile(
            field: f,
            scenes: splitField(ownScenes, f.id).own,
            done: done,
            own: true,
            onTap: () => _openField(context, ref, f, own: true),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 18),
              onPressed: () => _openPack(context, ref),
              label: Text(s.t(hasOwn ? 'nextScenesMake' : 'makeOwnScenes')),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              onPressed: () => showOpenFieldSheet(context, ref),
              label: Text(s.t('fieldAdd')),
            ),
          ],
        ),

        // -------- the samples, by field: folded away by default --------
        const SizedBox(height: 20),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => ref.read(samplesOpenProvider.notifier).state = !samplesOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: _GroupTitle(
                      icon: Icons.menu_book_outlined, title: s.t('samplesFieldsTitle'), color: scheme.onSurfaceVariant),
                ),
                Icon(samplesOpen ? Icons.expand_less : Icons.expand_more, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (samplesOpen)
          for (final f in sampleFields) ...[
          _FieldTile(
            field: f,
            scenes: splitField(scenes, f.id).samples,
            done: done,
            own: false,
            onTap: () => _openField(context, ref, f, own: false),
          ),
          const SizedBox(height: 8),
        ],

        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ListenScreen())),
            child: Text(s.t('listenButton')),
          ),
        ),
      ],
    );
  }
}

class _GroupTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _GroupTitle({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
        ],
      );
}

/// One field inside one of the two groups: its name and how many of its
/// scenes are done.
class _FieldTile extends ConsumerWidget {
  final Field field;
  final List<Scene> scenes;
  final Set<String> done;
  final bool own;
  final VoidCallback onTap;
  const _FieldTile({
    required this.field,
    required this.scenes,
    required this.done,
    required this.own,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = scenes.where((x) => done.contains(x.id)).length;
    return Material(
      color: own ? scheme.primaryContainer.withValues(alpha: 0.35) : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                switch (field.id) {
                  'work' => Icons.work_outline,
                  'travel' => Icons.flight_takeoff,
                  'school' => Icons.school_outlined,
                  'daily' => Icons.home_outlined,
                  _ => Icons.label_outline,
                },
                color: own ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(field.label, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text(s.t('fieldCount', {'d': n, 'n': scenes.length}),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: scheme.outlineVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Color color;
  final Color fg;
  final String title;
  final String body;
  final String button;
  final VoidCallback onTap;
  const _Card({
    required this.color,
    required this.fg,
    required this.title,
    required this.body,
    required this.button,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: color,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
            const SizedBox(height: 4),
            Text(body, style: theme.textTheme.bodySmall?.copyWith(color: fg)),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onTap, child: Text(button)),
          ],
        ),
      ),
    );
  }
}

/// What happened to the streak while the app was closed, when something did.
class _Banner extends ConsumerWidget {
  final Progress progress;
  const _Banner({required this.progress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);

    String? title, body;
    if (progress.freezeUsed > 0) {
      title = s.t('freezeBannerTitle');
      body = s.t('freezeBannerBody', {'n': progress.freezeUsed, 'streak': progress.streak});
    } else if (progress.streakLostFrom > 0) {
      title = s.t('lostBannerTitle');
      body = s.t('lostBannerBody', {'n': progress.streakLostFrom});
    }
    if (title == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: theme.colorScheme.onPrimaryContainer)),
            const SizedBox(height: 4),
            Text(body!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String icon;
  final String text;
  const _Pill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text('$icon $text', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );
}

/// Whether the samples are unfolded on home. Folded by default: they are the
/// starter set, and the learner's own scenes are the point.
final samplesOpenProvider = StateProvider<bool>((ref) => false);
