/// What grows the tree, and what it becomes.
///
/// The tree is the only reward this app has, and a reward nobody can read is
/// decoration. Three things move it, and each one is a different thing the
/// learner did: the trunk rises with the ladder, thickens with the work, and
/// the crown widens with the fields opened. Said in words that is a rule;
/// drawn at every name it answers to, it is something to want.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../domain/scene.dart' show TurnType;
import '../domain/tree.dart';
import 'tree_view.dart';

/// One row per name the tree answers to: the number of questions it is
/// earned at, and the number it is drawn at.
///
/// Read off [treeName] rather than worked out from the table, so that the
/// screen and the tree can never disagree about where a name begins.
List<({int entry, int draw, int? levels})> get _stages {
  final entry = <int>[];
  var last = -1;
  for (var r = 0; r <= treeLevelAt(treeFullLevel); r++) {
    final n = treeName(r);
    if (n != last) {
      entry.add(r);
      last = n;
    }
  }
  // Drawn at the question it is earned at, not at the top of its band: the
  // row then shows what the learner will be looking at on the day the name
  // arrives, and the number beside it is the number that drew it. Drawn at
  // the top, the first row came out a small tree rather than a seed.
  return [
    for (var i = 0; i < entry.length; i++)
      (
        entry: entry[i],
        draw: entry[i],
        // The last name has no last level: it goes on for as long as there
        // are questions, which is the point of it.
        levels: i < treeLevelsPerName.length ? treeLevelsPerName[i] : null,
      )
  ];
}

/// A tree made up for the picture: the questions it takes to earn the name,
/// and three fields, which is what everyone starts with.
TreeShape _imagined(int scenes, {int fields = 3}) {
  // Two turns to the question, which is what the built-in conversations
  // average, so the boughs are the length they would really be.
  final answers = scenes * 2;
  return TreeShape(
    scenes: scenes,
    answers: answers,
    branches: [
      for (var i = 0; i < fields; i++)
        Branch(
          realmId: 'shown:$i',
          label: '',
          answers: (answers / fields).round(),
          twigs: const {TurnType.keyword: 1},
          learned: 1,
          flowers: treeName(scenes) >= 4 ? 1 : 0,
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
                levels: stage.levels,
                need: s.t('treeStageNeed', {'n': stage.entry}),
                // The one the learner is standing in, marked rather than
                // written about: they can count the rest themselves.
                now: here != null && treeName(here.scenes) == treeName(stage.draw),
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
                  'a': here.scenes,
                  'f': here.fields,
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

  /// How many levels this name holds, or null for the last one, which holds
  /// as many as there are questions.
  final int? levels;
  final String need;
  final bool now;
  final String nowLabel;
  const _Stage({
    required this.shape,
    required this.name,
    required this.levels,
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
                  Text(levels == null ? '$name  Lv.1 -' : '$name  Lv.1-$levels',
                      style: theme.textTheme.titleSmall),
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
