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
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../domain/models.dart';
import '../domain/scene.dart';
import '../domain/skills.dart';
import '../domain/tree.dart';
import 'field_screen.dart';
import 'listen_screen.dart';
import 'ai_screens.dart';
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
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AiPromptScreen(job: AiJob.scenes)));
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
    final results = ref.watch(sceneResultsProvider).value ?? const <TurnResult>[];
    final stats = ref.watch(skillStatsProvider).value ?? SkillStats.empty;

    final ownScenes = [for (final x in scenes) if (!x.isBuiltin) x];
    final hasOwn = ownScenes.isNotEmpty;
    final done = {for (final r in results) if (!r.review) r.sceneId};
    final allDone = scenes.isNotEmpty && scenes.every((x) => done.contains(x.id));
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    // Today's scene comes from the learner's own scenes once there are any.
    final pool = hasOwn ? ownScenes : scenes;

    // The tree's data is loaded by an auto-disposing provider. Scrolled far
    // enough down — the samples open, on a tall phone — the panel leaves the
    // list's cache, the provider is dropped, and on the way back up the panel
    // remounts as a shorter placeholder while it reloads: the list shrinks
    // under the finger and snaps back to the bottom. Watching here keeps the
    // data alive for as long as home is, and the wide cache keeps the panel
    // itself mounted, so scrolling up is only scrolling up.
    final tree = ref.watch(treeDataProvider);
    ref.watch(treeArtProvider);

    return ListView(
      scrollCacheExtent: const ScrollCacheExtent.pixels(2000),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // -------- the streak and the balance --------
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
              _Pill(icon: '🌱', text: '${progress.seeds}'),
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
              : '${s.t('treeStage${treeName(tree.value?.shape.reached ?? 0)}')} · ${s.t('treeGrownScenes', {'n': stats.scenes})}',
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

        // The same family, one step narrower: a field of their own, or the
        // samples. Both ask which field before they start.
        //
        // The fields button stays even with nothing to play yet, because it is
        // also the only way to open another area from the profile; hiding it
        // until a conversation exists would shut that door for exactly the
        // learner who has not been through one yet. The samples button is
        // shown only when there are samples to show.
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.local_florist, size: 18),
          onPressed: () => showScenesFieldSheet(context, ref, own: true),
          label: Text(s.t('homeFieldScenes')),
        ),
        if (scenes.any((x) => x.isBuiltin)) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            onPressed: () => showScenesFieldSheet(context, ref, own: false),
            label: Text(s.t('homeSampleScenes')),
          ),
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
          stats.turns == 0
              ? s.t('axisEmpty')
              : s.t('axisLine', {
                  'g': stats.all.right.pct ?? 0,
                  'r': stats.all.kept.pct ?? 0,
                }),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),

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
    // Nothing could have saved it. A missed day breaks the chain, and the
    // only decent thing to do is say so plainly.
    if (progress.streakLostFrom > 0) {
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

