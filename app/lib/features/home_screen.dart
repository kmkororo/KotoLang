/// Home. Opening the app should answer one question: what do I do today?
///
/// "Just one question" is deliberately as prominent as the full session. On a
/// day with no motivation, lowering the floor keeps the streak alive, and in
/// practice one question usually turns into several.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/util.dart';
import '../data/repository.dart';
import '../domain/models.dart';
import '../domain/progress_service.dart';
import 'onboarding_screens.dart';
import 'quiz_screen.dart';

final homeCountsProvider = FutureProvider.autoDispose<HomeCounts>((ref) async {
  final realm = ref.watch(realmFilterProvider);
  return ref.watch(repositoryProvider).homeCounts(realm ?? 'all');
});

final realmsProvider = FutureProvider.autoDispose<List<Realm>>(
    (ref) => ref.watch(repositoryProvider).realms());

/// Everything the home screen derives from the answer log, read once rather
/// than once per widget: how well main-idea and reply questions have gone,
/// which realms today's journey has already touched, and the last 7 days.
class _HomeStats {
  final int? mastery;
  final Set<String> touchedToday;
  final List<bool> week;
  const _HomeStats({required this.mastery, required this.touchedToday, required this.week});
}

final _homeStatsProvider = FutureProvider.autoDispose<_HomeStats>((ref) async {
  final history = await ref.watch(repositoryProvider).history();
  final t = today();
  return _HomeStats(
    mastery: listeningMastery(history),
    touchedToday: history.where((h) => h.day == t).map((h) => h.realmId).toSet(),
    week: weeklyStrip(history, t),
  );
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final progress = ref.watch(progressProvider);
    final counts = ref.watch(homeCountsProvider);
    final realms = ref.watch(realmsProvider).value ?? const <Realm>[];
    final withMaterial = realms.where((r) => r.hasMaterial).toList();
    final filter = ref.watch(realmFilterProvider);
    final stats = ref.watch(_homeStatsProvider).value;
    final locked = realms.where((r) => !r.unlocked);
    final nextLocked = locked.isEmpty ? null : locked.first;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(homeCountsProvider);
        ref.invalidate(realmsProvider);
        ref.invalidate(_homeStatsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // -------- streak / xp / coin strip --------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('KotoLang',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Wrap(spacing: 8, runSpacing: 4, children: [
                _Pill(icon: '🔥', text: '${progress.streak}'),
                _Pill(icon: '⚡', text: '${progress.xpTotal}'),
                _Pill(icon: '🪙', text: '${progress.kotoCoins}'),
              ]),
            ],
          ),
          if (nextLocked != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                s.t('nextGoalLabel', {
                  'realm': nextLocked.label,
                  'n': (realmUnlockCost - progress.kotoCoins).clamp(0, realmUnlockCost),
                }),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
          const SizedBox(height: 16),

          _Banner(progress: progress, due: counts.value?.due ?? 0),

          if (stats?.mastery != null) ...[
            _MasteryCard(mastery: stats!.mastery!, s: s, theme: theme),
            const SizedBox(height: 16),
          ],

          if (withMaterial.isNotEmpty) ...[
            _JourneyCard(
              realms: withMaterial,
              touchedToday: stats?.touchedToday ?? const {},
              s: s,
              theme: theme,
            ),
            const SizedBox(height: 16),
          ],

          if (stats != null) ...[
            _WeekStrip(week: stats.week, theme: theme),
            const SizedBox(height: 16),
          ],

          // -------- today --------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(s.t('todayEyebrow').toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 1.2,
                              color: theme.colorScheme.onSurfaceVariant)),
                      if (withMaterial.length > 1)
                        DropdownButton<String?>(
                          value: filter,
                          underline: const SizedBox.shrink(),
                          isDense: true,
                          hint: Text(s.t('allRealms')),
                          items: [
                            DropdownMenuItem(value: null, child: Text(s.t('allRealms'))),
                            for (final r in withMaterial)
                              DropdownMenuItem(value: r.id, child: Text(r.label)),
                          ],
                          onChanged: (v) =>
                              ref.read(realmFilterProvider.notifier).state = v,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  counts.when(
                    loading: () => const Center(
                        child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator())),
                    error: (e, _) => Text('$e'),
                    data: (c) => Row(
                      children: [
                        _Metric(
                            value: '${c.due}',
                            label: s.t('todayReview'),
                            highlight: c.due > 0),
                        _Metric(value: '${c.fresh}', label: s.t('newQuestions')),
                        _Metric(value: '${progress.xpTotal}', label: s.t('xpLabel')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // -------- actions --------
          if ((counts.value?.questions ?? 0) == 0)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.t('noMaterialTitle'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(s.t('noMaterialHint'),
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const MaterialScreen())),
                      child: Text(s.t('createMaterial')),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            FilledButton(
              onPressed: () => _start(context, ref, count: 5),
              child: Text(s.t('startLearning')),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _start(context, ref, count: 1),
              child: Text(s.t('justOne')),
            ),
          ],

          const SizedBox(height: 16),
          Row(children: [
            _Mini(value: '${progress.bestStreak}', label: s.t('bestStreakLabel')),
            const SizedBox(width: 8),
            _Mini(value: '${progress.freezes}', label: s.t('freezesLabel')),
            const SizedBox(width: 8),
            _Mini(
                value: '${counts.value?.total ?? 0}', label: s.t('itemsInProgress')),
          ]),
        ],
      ),
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref, {required int count}) async {
    final s = ref.read(stringsProvider);
    final realm = ref.read(realmFilterProvider);
    final slots = await ref
        .read(repositoryProvider)
        .buildSession(realmId: realm ?? 'all', count: count);

    if (!context.mounted) return;
    if (slots.isEmpty) {
      showToast(context, s.t('noQuestions'));
      return;
    }
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => QuizScreen(slots: slots)));
    if (!context.mounted) return;
    ref.invalidate(homeCountsProvider);
    // Otherwise Listening Mastery, today's journey and the weekly strip all
    // read the answer log from before this session — stale until the next
    // pull-to-refresh, which nobody does right after finishing.
    ref.invalidate(_homeStatsProvider);
  }
}

class _Banner extends ConsumerWidget {
  final Progress progress;
  final int due;
  const _Banner({required this.progress, required this.due});

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
    } else if (due > 0) {
      title = s.t('reviewBannerTitle', {'n': due});
      body = s.t('reviewBannerBody');
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
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer)),
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

/// "82%" reads as "82% of English", which nothing here can honestly measure.
/// What can be reported is accuracy on the two listening formats, captioned
/// as exactly that — never as a fluency score.
class _MasteryCard extends StatelessWidget {
  final int mastery;
  final dynamic s;
  final ThemeData theme;
  const _MasteryCard({required this.mastery, required this.s, required this.theme});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('🎧', style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.t('listeningMasteryLabel'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(s.t('listeningMasteryCaption'),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Text('$mastery%',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
            ],
          ),
        ),
      );
}

/// One row per realm with material: a check once today's history has an
/// entry for it, a hollow circle otherwise. The whole app's several worlds,
/// treated as today's journey through them.
class _JourneyCard extends StatelessWidget {
  final List<Realm> realms;
  final Set<String> touchedToday;
  final dynamic s;
  final ThemeData theme;
  const _JourneyCard({
    required this.realms,
    required this.touchedToday,
    required this.s,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('todaysJourneyTitle'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              for (final r in realms)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        touchedToday.contains(r.id)
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 18,
                        color: touchedToday.contains(r.id)
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(r.label)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
}

/// The last 7 days, derived straight from the answer log rather than tracked
/// separately — so it never goes stale independently of a streak reset, and
/// it never needs its own storage.
class _WeekStrip extends StatelessWidget {
  final List<bool> week;
  final ThemeData theme;
  const _WeekStrip({required this.week, required this.theme});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final answered in week)
            Icon(
              answered ? Icons.headphones : Icons.circle_outlined,
              size: 20,
              color: answered ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            ),
        ],
      );
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
        child: Text('$icon $text',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  final bool highlight;
  const _Metric({required this.value, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: highlight ? theme.colorScheme.primary : null,
              )),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final String value;
  final String label;
  const _Mini({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              children: [
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                Text(label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );
}
