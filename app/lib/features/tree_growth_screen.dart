/// What grows the tree, and what it becomes.
///
/// The tree is the only reward this app has, and a reward nobody can read is
/// decoration. Three things move it, and each one is a different thing the
/// learner did: the trunk rises with the ladder, thickens with the work, and
/// the crown widens with the fields opened. Said in words that is a rule;
/// drawn at six heights it is something to want.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../domain/ladder.dart';
import '../domain/scene.dart' show TurnType;
import '../domain/tree.dart';
import 'tree_view.dart';

/// One row per name the tree answers to: the step it is earned at, and the
/// step it is drawn at.
///
/// Read off [treeName] rather than divided out of the ladder, which put two
/// rows on the same name and skipped another: the names are not spaced
/// evenly along the ladder, and the only thing that knows where they fall is
/// the function that names them.
List<({int entry, int draw})> get _stages {
  final entry = <int>[];
  var last = -1;
  for (var r = 0; r <= ladderSteps; r++) {
    final n = treeName(r);
    if (n != last) {
      entry.add(r);
      last = n;
    }
  }
  return [
    // Drawn at the top of its band, where it is most itself.
    for (var i = 0; i < entry.length; i++)
      (entry: entry[i], draw: i + 1 < entry.length ? entry[i + 1] - 1 : ladderSteps)
  ];
}

/// A tree made up for the picture: enough work behind it to look like it
/// belongs at that height, and three fields, which is what everyone starts
/// with.
TreeShape _imagined(int reached, {int fields = 3}) {
  final answers = (reached * 8).clamp(0, 400);
  return TreeShape(
    reached: reached,
    answers: answers,
    branches: [
      for (var i = 0; i < fields; i++)
        Branch(
          realmId: 'shown:$i',
          label: '',
          answers: (answers / fields).round(),
          twigs: const {TurnType.keyword: 1},
          learned: 1,
          flowers: reached > ladderSteps ~/ 3 ? 1 : 0,
        ),
    ],
  );
}

class TreeGrowthScreen extends ConsumerWidget {
  const TreeGrowthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final here = ref.watch(treeDataProvider).value?.shape;

    return Scaffold(
      appBar: AppBar(title: Text(s.t('treeHowTitle'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(s.t('treeHowIntro'), style: muted),
            const SizedBox(height: 16),

            // -------- the three rules --------
            _Rule(
              icon: Icons.height,
              title: s.t('treeRuleTallTitle'),
              body: s.t('treeRuleTallBody'),
            ),
            _Rule(
              icon: Icons.circle_outlined,
              title: s.t('treeRuleThickTitle'),
              body: s.t('treeRuleThickBody'),
            ),
            _Rule(
              icon: Icons.open_in_full,
              title: s.t('treeRuleWideTitle'),
              body: s.t('treeRuleWideBody'),
            ),

            const SizedBox(height: 20),
            Text(s.t('treeHowStages'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(s.t('treeHowStagesHint'), style: muted),
            const SizedBox(height: 8),

            // -------- what it becomes --------
            for (final stage in _stages) ...[
              _Stage(
                shape: _imagined(stage.draw),
                name: s.t('treeStage${treeName(stage.draw)}'),
                need: s.t('treeStageNeed', {'n': stage.entry}),
                // The one the learner is standing in, marked rather than
                // written about: they can count the rest themselves.
                now: here != null && treeName(here.reached) == treeName(stage.draw),
                nowLabel: s.t('treeStageNow'),
              ),
              const SizedBox(height: 6),
            ],

            if (here != null) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 14),
              Text(s.t('treeHowYours'), style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                s.t('treeHowYoursLine', {
                  'r': here.reached,
                  't': ladderSteps,
                  'a': here.answers,
                  'f': here.branches.length,
                }),
                style: muted,
              ),
            ],
          ],
        ),
      ),
    );
  }
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

class _Stage extends StatelessWidget {
  final TreeShape shape;
  final String name;
  final String need;
  final bool now;
  final String nowLabel;
  const _Stage({
    required this.shape,
    required this.name,
    required this.need,
    required this.now,
    required this.nowLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: now ? scheme.secondaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
        child: Row(
          children: [
            // Clipped: the ground is drawn wider than the canvas so that a
            // full tree stands on soil rather than on a saucer, which on a
            // preview this narrow means it reaches out over the words.
            ClipRect(
              child: SizedBox(width: 104, child: TreeStill(shape: shape, height: 108)),
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
    );
  }
}
