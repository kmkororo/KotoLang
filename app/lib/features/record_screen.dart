/// The record: the two skills, the habit, the scenes, and what the Seeds buy.
/// Honest numbers only — every figure is computed from the learner's own
/// answers, and there are no invented competitors.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/util.dart';
import '../domain/models.dart';
import '../domain/progress_service.dart';
import '../domain/scene.dart';
import '../domain/skills.dart';
import 'field_picker_screen.dart';

class RecordScreen extends ConsumerWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = ref.watch(progressProvider);
    final stats = ref.watch(skillStatsProvider).value ?? SkillStats.empty;
    final scenes = ref.watch(allScenesProvider).value ?? const <Scene>[];
    final results = ref.watch(sceneResultsProvider).value ?? const <TurnResult>[];
    final realms = ref.watch(realmsProvider).value ?? const <Realm>[];
    final t = today();

    // How often each scene has been finished (reviews are not runs).
    final runs = <String, int>{};
    for (final r in results) {
      if (r.review || r.turn != 0) continue;
      runs[r.sceneId] = (runs[r.sceneId] ?? 0) + 1;
    }

    String pct(Rate r) => r.pct == null ? '—' : '${r.pct}%';
    final heat = [
      for (var i = 27; i >= 0; i--)
        switch (stats.perDay[addDays(t, -i)] ?? 0) {
          0 => 0,
          < 2 => 1,
          < 4 => 2,
          _ => 3,
        }
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(s.t('recordTab'),
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),

        // -------- the two skills --------
        _Block(title: s.t('skillsSection'), children: [
          _SkillRow(
            label: s.t('skillUnderstand'),
            all: pct(stats.all.right),
            week: pct(stats.week.right),
            sub: '${s.t("byEarLabel")} ${pct(stats.all.kept)}',
          ),
          const SizedBox(height: 10),
          _SkillRow(
            label: s.t('skillReply'),
            all: pct(stats.all.kept),
            week: pct(stats.week.kept),
          ),
          const SizedBox(height: 8),
          Text('${s.t('allTimeLabel')} · ${s.t('last7Label')}',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ]),

        // -------- the habit --------
        _Block(title: s.t('continuitySection'), children: [
          Row(children: [
            _Cell('☀️ ${progress.streak}', s.t('streakDays')),
            _Cell('${progress.bestStreak}', s.t('bestStreakLabel')),
            _Cell('${stats.scenes}', s.t('scenesDoneLabel')),
          ]),
          const SizedBox(height: 8),
          // Runs of right answers: the one going now by ear, and the longest.
          Row(children: [
            _Cell('${stats.runs.kept}', s.t('byEarRunNow')),
            _Cell('${stats.runs.bestKept}', s.t('bestByEarLabel')),
            _Cell('${stats.runs.bestCombo}', s.t('bestComboLabel')),
          ]),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 14,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: [
              for (final level in heat)
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: switch (level) {
                      0 => scheme.surfaceContainerHighest,
                      1 => scheme.primary.withValues(alpha: 0.3),
                      2 => scheme.primary.withValues(alpha: 0.6),
                      _ => scheme.primary,
                    },
                  ),
                  child: const SizedBox.expand(),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(s.t('last28'),
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ]),

        // -------- the fields --------
        _FieldsBlock(progress: progress, realms: realms),

        // -------- the scenes --------
        _Block(title: s.t('sceneListTitle'), children: [
          if (scenes.isEmpty)
            Text(s.t('sceneNoneYet'),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          for (final sc in scenes)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(sc.label),
              subtitle: sc.settingNative.isEmpty ? null : Text(sc.settingNative),
              leading: sc.isBuiltin
                  ? Chip(
                      label: Text(s.t('sampleTag')),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    )
                  : Icon(Icons.local_florist, color: scheme.primary),
              trailing: Text(s.t('timesDone', {'n': runs[sc.id] ?? 0}),
                  style: theme.textTheme.bodySmall),
            ),
        ]),
      ],
    );
  }
}

class _SkillRow extends StatelessWidget {
  final String label;
  final String all;
  final String week;
  final String? sub;
  const _SkillRow({required this.label, required this.all, required this.week, this.sub});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (sub != null)
                Text(sub!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        Text(all, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(width: 12),
        Text(week,
            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  final String value;
  final String label;
  const _Cell(this.value, this.label);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

/// The balance, and the one thing it is for. The point is that nobody has to
/// go hunting for "what is this number for": the number and its use stand in
/// the same block.
class _FieldsBlock extends ConsumerWidget {
  final Progress progress;
  final List<Realm> realms;
  const _FieldsBlock({required this.progress, required this.realms});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final locked = realms.where((r) => !r.unlocked).toList();
    final room = ref.watch(fieldOpeningsProvider).value ?? 0;
    final short = realmUnlockCost - progress.seeds;

    return _Block(title: '🌱 ${s.t('seedsLabel')}', children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              short > 0
                  ? s.t('seedsToNextUnlock', {'n': short})
                  : s.t('seedsCanUnlock'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Text('${progress.seeds}',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
      if (locked.isNotEmpty) ...[
        const SizedBox(height: 10),
        // The price only applies once the starting three are chosen; quoting
        // it while they are still owed would contradict the picker, which
        // gives those away.
        Text(
          room > 0
              ? s.t('fieldChooseLeft', {'n': room})
              : s.t('unlockRealmCost', {'n': realmUnlockCost}),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: () async {
            await Navigator.push(
                context, MaterialPageRoute(builder: (_) => const RealmPickerScreen()));
            if (!context.mounted) return;
            ref.invalidate(realmsProvider);
          },
          child: Text(s.t('yourRealmsButton')),
        ),
      ],
    ]);
  }
}

class _Block extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Block({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ...children,
              ],
            ),
          ),
        ),
      );
}
