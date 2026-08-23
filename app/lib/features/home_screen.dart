/// Home. Opening the app should answer one question: what do I do today?
///
/// "Just one question" is deliberately as prominent as the full session. On a
/// day with no motivation, lowering the floor keeps the streak alive, and in
/// practice one question usually turns into several.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../data/repository.dart';
import '../domain/models.dart';
import 'onboarding_screens.dart';
import 'quiz_screen.dart';

final homeCountsProvider = FutureProvider.autoDispose<HomeCounts>((ref) async {
  final realm = ref.watch(realmFilterProvider);
  return ref.watch(repositoryProvider).homeCounts(realm ?? 'all');
});

final realmsProvider = FutureProvider.autoDispose<List<Realm>>(
    (ref) => ref.watch(repositoryProvider).realms());

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

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(homeCountsProvider);
        ref.invalidate(realmsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // -------- streak / xp strip --------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('KotoLang',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Row(children: [
                _Pill(icon: '🔥', text: '${progress.streak}'),
                const SizedBox(width: 8),
                _Pill(icon: '⚡', text: '${progress.xpTotal}'),
              ]),
            ],
          ),
          const SizedBox(height: 16),

          _Banner(progress: progress, due: counts.value?.due ?? 0),

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
