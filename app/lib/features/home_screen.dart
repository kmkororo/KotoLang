/// Home. Opening the app should answer one question: what do I do today?
///
/// The tree, one button that picks a scene at random, one line of numbers,
/// and then the fields — work, travel, school, everyday, and the learner's
/// own — for the days one wants to choose. The samples that ship with the
/// app make the button live from the first minute; the card under it says,
/// for as long as only samples are here, that the point of the app is the
/// scenes the learner's own AI writes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../domain/field.dart';
import '../domain/models.dart';
import '../domain/progress_service.dart';
import '../domain/scene.dart';
import '../domain/skills.dart';
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

  Future<void> _openField(BuildContext context, WidgetRef ref, Field field) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => FieldScreen(field: field)));
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

    final hasOwn = scenes.any((x) => !x.isBuiltin);
    final done = {for (final r in results) if (!r.review) r.sceneId};
    final allDone = scenes.isNotEmpty && scenes.every((x) => done.contains(x.id));
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

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
              _Pill(icon: '🔥', text: s.t('streakPill', {'n': progress.streak})),
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
              : s.t('treeGrownScenes', {'n': stats.scenes}),
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
            onPressed: () => startScene(context, ref, all: scenes, onDone: () => _refresh(ref)),
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

        // -------- the fields --------
        const SizedBox(height: 20),
        Text(s.t('fieldsTitle'), style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final f in fields) ...[
          _FieldTile(
            field: f,
            split: splitField(scenes, f.id),
            done: done,
            onTap: () => _openField(context, ref, f),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          onPressed: () => showAddFieldDialog(context, ref),
          label: Text('${s.t('fieldAdd')} · $realmUnlockCost Seeds'),
        ),

        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          children: [
            if (hasOwn)
              TextButton(
                onPressed: () => _openPack(context, ref),
                child: Text(s.t('nextScenesMake')),
              ),
            TextButton(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const ListenScreen())),
              child: Text(s.t('listenButton')),
            ),
          ],
        ),
      ],
    );
  }
}

/// One field on the home screen: its name, and how far along the samples and
/// the learner's own scenes are.
class _FieldTile extends ConsumerWidget {
  final Field field;
  final ({List<Scene> samples, List<Scene> own}) split;
  final Set<String> done;
  final VoidCallback onTap;
  const _FieldTile({
    required this.field,
    required this.split,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    int doneOf(List<Scene> xs) => xs.where((x) => done.contains(x.id)).length;
    final parts = <String>[
      if (split.samples.isNotEmpty)
        '${s.t('sampleTag')} ${doneOf(split.samples)}/${split.samples.length}',
      '${s.t('fieldOwn')} ${doneOf(split.own)}/${split.own.length}',
    ];
    return Material(
      color: scheme.surfaceContainerLow,
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
                color: scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(field.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(parts.join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (split.own.isNotEmpty) Icon(Icons.local_florist, size: 16, color: scheme.primary),
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
