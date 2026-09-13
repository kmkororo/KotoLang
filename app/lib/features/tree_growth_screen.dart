/// What grows the tree, and what it becomes.
///
/// The tree is the only reward this app has, and a reward nobody can read is
/// decoration. One thing grows it, the questions answered; the name it goes
/// by says what shape it has, and the camera pulls back as it gets bigger.
/// Said in words that is a rule; drawn at every level it answers to — all two
/// hundred of them, to scroll through — it is something to want.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../domain/tree.dart';
import 'tree_view.dart';

class TreeGrowthScreen extends ConsumerStatefulWidget {
  const TreeGrowthScreen({super.key});

  @override
  ConsumerState<TreeGrowthScreen> createState() => _TreeGrowthScreenState();
}

class _TreeGrowthScreenState extends ConsumerState<TreeGrowthScreen> {
  /// Roughly what one row takes, so the list can be opened where the learner
  /// stands rather than at the top of two hundred of them.
  static const _row = 142.0;

  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final here = ref.watch(treeDataProvider).value?.shape;
    final at = here == null ? 0 : treeLevel(here.scenes);

    // Opened two rows above where they stand, so what was just earned is on
    // screen with the next one under it.
    _scroll ??= ScrollController(initialScrollOffset: at <= 2 ? 0 : (at - 2) * _row);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('treeHowTitle'))),
      body: SafeArea(
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          // The header, every level, and the line about the last one.
          itemCount: treeTopLevel + 2,
          itemBuilder: (context, i) {
            if (i == 0) return _header(s, theme, muted, here);
            if (i == treeTopLevel + 1) {
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(s.t('treeLastLevelNote'), style: muted),
              );
            }
            final level = i;
            final q = treeLevelAt(level);
            final r = treeRankOfLevel(level);
            return _Level(
              level: level.toDouble(),
              name: s.t('treeRankLabel',
                  {'name': s.t('treeStage${r.name}'), 'n': r.level}),
              need: s.t('treeStageNeed', {'n': q}),
              now: level == at,
              nowLabel: s.t('treeStageNow'),
            );
          },
        ),
      ),
    );
  }

  Widget _header(dynamic s, ThemeData theme, TextStyle? muted, TreeShape? here) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t('treeHowIntro'), style: muted),
          const SizedBox(height: 16),
          _Rule(
            icon: Icons.open_in_full,
            title: s.t('treeRuleTallTitle'),
            body: s.t('treeRuleTallBody'),
          ),
          _Rule(
            icon: Icons.eco_outlined,
            title: s.t('treeRuleThickTitle'),
            body: s.t('treeRuleThickBody'),
          ),
          _Rule(
            icon: Icons.public,
            title: s.t('treeRuleWideTitle'),
            body: s.t('treeRuleWideBody'),
          ),
          if (here != null) ...[
            const SizedBox(height: 4),
            Text(s.t('treeHowYours'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(s.t('treeHowYoursLine', {'a': here.scenes, 'f': here.fields}),
                style: muted),
          ],
          const SizedBox(height: 20),
          Text(s.t('treeHowStages'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(s.t('treeHowStagesHint'), style: muted),
          const SizedBox(height: 8),
        ],
      );
}

class _Rule extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Rule({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(body,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Level extends StatelessWidget {
  final double level;
  final String name;
  final String need;
  final bool now;
  final String nowLabel;
  const _Level({
    required this.level,
    required this.name,
    required this.need,
    required this.now,
    required this.nowLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Card(
        margin: EdgeInsets.zero,
        color: now ? scheme.secondaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(width: 120, child: TreeStill(level: level, height: 120)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(need,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                    if (now) ...[
                      const SizedBox(height: 6),
                      Text(nowLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSecondaryContainer,
                              fontWeight: FontWeight.w800)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
