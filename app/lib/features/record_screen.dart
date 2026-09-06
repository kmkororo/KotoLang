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
    final results = ref.watch(sceneResultsProvider).value ?? const <SceneResult>[];
    final realms = ref.watch(realmsProvider).value ?? const <Realm>[];
    final t = today();

    // How often each scene has been finished (reviews are not runs).
    final runs = <String, int>{};
    for (final r in results) {
      if (r.review || r.exchange != 0) continue;
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
            all: pct(stats.all.gist),
            week: pct(stats.week.gist),
            sub: '${s.t('byEarLabel')} ${pct(stats.all.byEar)}',
          ),
          const SizedBox(height: 10),
          _SkillRow(
            label: s.t('skillReply'),
            all: pct(stats.all.reply),
            week: pct(stats.week.reply),
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
            _Cell('${stats.runs.byEar}', s.t('byEarRunNow')),
            _Cell('${stats.runs.bestByEar}', s.t('bestByEarLabel')),
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

        // -------- Seeds --------
        _SeedsBlock(progress: progress, realms: realms),

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

/// Seeds, and the two things they buy: an area and a decoration. The point
/// is that nobody has to go looking for "what is this number for".
class _SeedsBlock extends ConsumerStatefulWidget {
  final Progress progress;
  final List<Realm> realms;
  const _SeedsBlock({required this.progress, required this.realms});

  @override
  ConsumerState<_SeedsBlock> createState() => _SeedsBlockState();
}

class _SeedsBlockState extends ConsumerState<_SeedsBlock> {

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final seeds = widget.progress.seeds;
    final locked = widget.realms.where((r) => !r.unlocked).toList();
    final shortfall = realmUnlockCost - seeds;

    return _Block(title: '🌱 ${s.t('seedsLabel')}', children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              shortfall > 0
                  ? s.t('seedsToNextUnlock', {'n': shortfall})
                  : s.t('seedsCanUnlock'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Text('$seeds',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
      if (locked.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(s.t('unlockRealmCost', {'n': realmUnlockCost}), style: theme.textTheme.bodySmall),
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
