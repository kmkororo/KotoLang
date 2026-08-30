/// Progress. Honest numbers only — every figure here is computed from the
/// learner's own answers, and there are no invented competitors.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/util.dart';
import '../domain/models.dart';
import '../domain/progress_service.dart' as ps;
import '../domain/srs.dart' as srs;
import 'home_screen.dart';

class _Stats {
  final int todayCount;
  final int todayCorrect;
  final int dueNow;
  final int studyDays;
  final List<int> heat; // 0..3 intensity for the last 28 days
  final Map<QuestionType, ({int n, int ok})> formats;
  final int mastered;
  final int learning;
  final int untouched;
  final int totalAnswers;
  final List<({String name, int done, int total})> byRealm;
  final Map<srs.MasteryStage, int> stages;
  final List<ps.Badge> badgeShelf;

  const _Stats({
    required this.todayCount,
    required this.todayCorrect,
    required this.dueNow,
    required this.studyDays,
    required this.heat,
    required this.formats,
    required this.mastered,
    required this.learning,
    required this.untouched,
    required this.totalAnswers,
    required this.byRealm,
    required this.stages,
    required this.badgeShelf,
  });
}

final _statsProvider = FutureProvider.autoDispose<_Stats>((ref) async {
  final repo = ref.watch(repositoryProvider);
  final history = await repo.history();
  final states = await repo.srsStates();
  final items = await repo.items();
  final questions = await repo.questions();
  final realms = await repo.realms();
  final t = today();

  final todayRows = history.where((h) => h.day == t).toList();

  final formats = <QuestionType, ({int n, int ok})>{
    for (final type in QuestionType.values) type: (n: 0, ok: 0)
  };
  for (final h in history) {
    final cur = formats[h.type]!;
    formats[h.type] = (n: cur.n + 1, ok: cur.ok + (h.correct ? 1 : 0));
  }

  final perDay = <String, int>{};
  for (final h in history) {
    perDay[h.day] = (perDay[h.day] ?? 0) + 1;
  }
  final heat = [
    for (var i = 27; i >= 0; i--)
      switch (perDay[addDays(t, -i)] ?? 0) {
        0 => 0,
        < 3 => 1,
        < 8 => 2,
        _ => 3,
      }
  ];

  final byId = {for (final s in states) s.itemId: s};
  final mastered = states.where(srs.isMastered).length;
  final learning = states.where((s) => s.introduced && !srs.isMastered(s)).length;
  final withQuestions = questions.map((q) => q.itemId).whereType<String>().toSet();

  // Every expression the learner could be asked about, sorted by how far it
  // has come. Items with no questions behind them are left out: they cannot
  // grow, so counting them as seeds would be misleading.
  final stages = <srs.MasteryStage, int>{
    for (final stage in srs.MasteryStage.values) stage: 0
  };
  for (final id in withQuestions) {
    final stage = srs.stageFor(byId[id]);
    stages[stage] = stages[stage]! + 1;
  }

  final progress = ref.watch(progressProvider);
  return _Stats(
    stages: stages,
    badgeShelf: ps.badges(
      history: history,
      bestStreak: progress.bestStreak,
      masteredItems: mastered,
      realmsWithMaterial: realms.where((r) => r.hasMaterial).length,
    ),
    todayCount: todayRows.length,
    todayCorrect: todayRows.where((h) => h.correct).length,
    dueNow: srs.dueCount(states),
    studyDays: perDay.length,
    heat: heat,
    formats: formats,
    mastered: mastered,
    learning: learning,
    untouched: (withQuestions.length - mastered - learning).clamp(0, 1 << 30),
    totalAnswers: history.length,
    byRealm: [
      for (final r in realms.where((r) => r.hasMaterial))
        (
          name: r.label,
          done: items
              .where((i) => i.realmIds.contains(r.id) && (byId[i.id]?.introduced ?? false))
              .length,
          total: items.where((i) => i.realmIds.contains(r.id)).length,
        )
    ],
  );
});

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final progress = ref.watch(progressProvider);
    final theme = Theme.of(context);
    final home = ref.watch(homeStatsProvider).value;
    final realms = (ref.watch(realmsProvider).value ?? const <Realm>[])
        .where((r) => r.hasMaterial)
        .toList();

    return ref.watch(_statsProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (d) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(s.t('statsTitle'),
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),

              // Moved off the home screen, which is now the tree and the way
              // into a session. These are the figures worth looking at when
              // you have come here to look at figures.
              if (home?.mastery != null) ...[
                MasteryCard(mastery: home!.mastery!, s: s, theme: theme),
                const SizedBox(height: 12),
              ],
              if (realms.isNotEmpty) ...[
                JourneyCard(
                  realms: realms,
                  touchedToday: home?.touchedToday ?? const {},
                  s: s,
                  theme: theme,
                ),
                const SizedBox(height: 12),
              ],
              if (home != null) ...[
                WeekStrip(
                    week: home.week, label: s.t('weekStripLabel'), theme: theme),
                const SizedBox(height: 12),
              ],
              Row(children: [
                MiniTile(
                    value: '${progress.bestStreak}', label: s.t('bestStreakLabel')),
                const SizedBox(width: 8),
                MiniTile(
                  value: '${progress.freezes}',
                  label: s.t('freezesLabel'),
                  onTap: () => explainNote(context,
                      title: s.t('freezeHelpTitle'),
                      body: s.t('freezeHelpBody'),
                      closeLabel: s.t('capUnderstood')),
                ),
                const SizedBox(width: 8),
                MiniTile(
                    value: '${d.learning}', label: s.t('itemsInProgress')),
              ]),
              const SizedBox(height: 12),


              _Block(title: s.t('todaySection'), children: [
                _Row3(
                  a: ('${d.todayCount}', s.t('answersLabel')),
                  b: (d.todayCount == 0 ? '—' : '${percent(d.todayCorrect, d.todayCount)}%',
                      s.t('accuracyPct')),
                  c: ('${d.dueNow}', s.t('remainingReview')),
                ),
              ]),

              _Block(title: s.t('continuitySection'), children: [
                _Row3(
                  a: ('🔥 ${progress.streak}', s.t('streakDays')),
                  b: ('${progress.bestStreak}', s.t('bestStreakLabel')),
                  c: ('${d.studyDays}', s.t('studyDays')),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 14,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  children: [
                    for (final level in d.heat)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: switch (level) {
                            0 => theme.colorScheme.surfaceContainerHighest,
                            1 => theme.colorScheme.primary.withValues(alpha: 0.3),
                            2 => theme.colorScheme.primary.withValues(alpha: 0.6),
                            _ => theme.colorScheme.primary,
                          },
                        ),
                        child: const SizedBox.expand(),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(s.t('last28'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ]),

              _Block(title: s.t('formatSection'), children: [
                for (final type in QuestionType.values)
                  _Bar(
                    label: switch (type) {
                      QuestionType.paraphrase => s.t('typeParaphrase'),
                      QuestionType.gist => s.t('typeGist'),
                      QuestionType.dictation => s.t('typeDictation'),
                      QuestionType.reorder => s.t('typeReorder'),
                      QuestionType.produce => s.t('typeProduce'),
                      QuestionType.reply => s.t('typeReply'),
                      QuestionType.register => s.t('typeRegister'),
                    },
                    value: d.formats[type]!.n == 0
                        ? null
                        : percent(d.formats[type]!.ok, d.formats[type]!.n),
                  ),
                const SizedBox(height: 6),
                Text(s.t('gateNote'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ]),

              _Block(title: s.t('masterySection'), children: [
                _Row3(
                  a: ('${d.mastered}', s.t('mastered')),
                  b: ('${d.learning}', s.t('inProgress')),
                  c: ('${d.untouched}', s.t('untouched')),
                ),
              ]),

              // Locked badges are shown alongside earned ones, with the real
              // number underneath. A hidden badge is nothing to aim at; one
              // that says "12 / 100" is.
              // The same items again, but as a journey rather than a verdict:
              // four stages an expression passes through on its way up.
              _Block(title: s.t('stageSection'), children: [
                for (final stage in srs.MasteryStage.values)
                  _Bar(
                    label:
                        '${srs.stageEmoji[stage]!} ${s.t(srs.stageKey[stage]!)}',
                    value: d.stages.values.fold(0, (a, b) => a + b) == 0
                        ? null
                        : percent(d.stages[stage]!,
                            d.stages.values.fold(0, (a, b) => a + b)),
                    trailing: '${d.stages[stage]}',
                  ),
              ]),

              _Block(title: s.t('badgesSection'), children: [
                Text(
                  s.t('badgesEarned', {
                    'n': d.badgeShelf.where((b) => b.earned).length,
                    'total': d.badgeShelf.length,
                  }),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                for (final b in d.badgeShelf)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Icon(
                        b.earned ? Icons.emoji_events : Icons.emoji_events_outlined,
                        size: 22,
                        color: b.earned
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.t('badge_${b.id}'),
                                style: TextStyle(
                                  fontWeight:
                                      b.earned ? FontWeight.w700 : FontWeight.w400,
                                  color: b.earned
                                      ? null
                                      : theme.colorScheme.onSurfaceVariant,
                                )),
                            if (!b.earned) ...[
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: b.ratio,
                                minHeight: 4,
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('${b.progress}/${b.threshold}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ]),
                  ),
              ]),

              if (d.byRealm.isNotEmpty)
                _Block(title: s.t('byRealmSection'), children: [
                  for (final r in d.byRealm)
                    _Bar(
                      label: r.name,
                      value: r.total == 0 ? null : percent(r.done, r.total),
                      trailing: '${r.done}/${r.total}',
                    ),
                ]),

              _Block(title: s.t('totalSection'), children: [
                _Row3(
                  a: ('${progress.seeds}', s.t('seedsLabel')),
                  b: ('${d.totalAnswers}', s.t('totalAnswers')),
                  c: ('', s.t('freezesLabel')),
                  onTapC: () => explainNote(context,
                      title: s.t('freezeHelpTitle'),
                      body: s.t('freezeHelpBody'),
                      closeLabel: s.t('capUnderstood')),
                ),
              ]),
            ],
          ),
        );
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

class _Row3 extends StatelessWidget {
  final (String, String) a, b, c;

  /// Explanation for the third cell, when its label needs one. Same reason as
  /// the home screen's counters: a name like "rest days" cannot carry it.
  final VoidCallback? onTapC;
  const _Row3({required this.a, required this.b, required this.c, this.onTapC});

  Widget _cell(BuildContext context, (String, String) v, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    final body = Column(children: [
      Text(v.$1, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(v.$2,
                textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 3),
            Icon(Icons.info_outline,
                size: 13, color: theme.colorScheme.onSurfaceVariant),
          ],
        ],
      ),
    ]);

    return Expanded(
      child: onTap == null
          ? body
          : InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: body,
            ),
    );
  }

  @override
  Widget build(BuildContext context) => Row(children: [
        _cell(context, a),
        _cell(context, b),
        _cell(context, c, onTap: onTapC),
      ]);
}
class _Bar extends StatelessWidget {
  final String label;
  final int? value; // null when there is nothing to show yet
  final String? trailing;
  const _Bar({required this.label, this.value, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 108,
            child: Text(label,
                style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (value ?? 0) / 100,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(trailing ?? (value == null ? '—' : '$value%'),
                textAlign: TextAlign.right, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
