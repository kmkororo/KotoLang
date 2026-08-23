/// Progress. Honest numbers only — every figure here is computed from the
/// learner's own answers, and there are no invented competitors.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/util.dart';
import '../domain/models.dart';
import '../domain/srs.dart' as srs;

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

  return _Stats(
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
                  a: ('${progress.xpTotal}', s.t('xpLabel')),
                  b: ('${d.totalAnswers}', s.t('totalAnswers')),
                  c: ('${progress.freezes}', s.t('freezesLabel')),
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
  const _Row3({required this.a, required this.b, required this.c});

  Widget _cell(BuildContext context, (String, String) v) => Expanded(
        child: Column(children: [
          Text(v.$1, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(v.$2,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      );

  @override
  Widget build(BuildContext context) =>
      Row(children: [_cell(context, a), _cell(context, b), _cell(context, c)]);
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
