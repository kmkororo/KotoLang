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
import '../domain/models.dart';
import '../domain/progress_service.dart';
import 'debate_screen.dart';
import 'listen_screen.dart';
import 'onboarding_screens.dart';
import 'pack_screen.dart';
import 'quiz_screen.dart';
import 'tree_view.dart';

/// Everything the home screen derives from the answer log, read once rather
/// than once per widget: how well main-idea and reply questions have gone,
/// which areas have been studied today, how many questions that came to, and
/// the last 7 days.
class HomeStats {
  final int? mastery;
  final Set<String> touchedToday;
  final int answeredToday;
  final List<bool> week;
  final NextGoal? goal;
  const HomeStats({
    required this.mastery,
    required this.touchedToday,
    required this.answeredToday,
    required this.week,
    required this.goal,
  });
}

final homeStatsProvider = FutureProvider.autoDispose<HomeStats>((ref) async {
  final history = await ref.watch(repositoryProvider).history();
  final t = today();
  final todays = history.where((h) => h.day == t);
  final progress = ref.watch(progressProvider);
  return HomeStats(
    mastery: listeningMastery(history),
    touchedToday: todays.map((h) => h.realmId).toSet(),
    answeredToday: todays.length,
    week: weeklyStrip(history, t),
    goal: nextGoal(
      history: history,
      streak: progress.streak,
      today: t,
      studiedToday: todays.isNotEmpty,
    ),
  );
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final progress = ref.watch(progressProvider);
    final settings = ref.watch(settingsProvider);
    final counts = ref.watch(homeCountsProvider);
    final realms = ref.watch(realmsProvider).value ?? const <Realm>[];
    // The picker offers every area the learner owns, not only the ones that
    // happen to hold questions — an empty area is exactly the one they need
    // to find in order to fill it.
    final mine = realms.where((r) => r.unlocked).toList();
    final filter = ref.watch(realmFilterProvider);
    final stats = ref.watch(homeStatsProvider).value;
    final locked = realms.where((r) => !r.unlocked);
    final nextLocked = locked.isEmpty ? null : locked.first;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(homeCountsProvider);
        ref.invalidate(realmsProvider);
        ref.invalidate(homeStatsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // -------- streak / seeds strip --------
          // Wrap rather than a Row: the pills now carry words, and on a narrow
          // screen — or a long streak label — the name and the pills together
          // are wider than the line.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text('KotoLang',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              // Both pills say what their number is. A bare flame next to a
              // bare number is a puzzle, not a status.
              Wrap(spacing: 8, runSpacing: 4, children: [
                _Pill(
                    icon: '🔥',
                    text: s.t('streakPill', {'n': progress.streak})),
                _Pill(icon: '🌱', text: '${progress.seeds} Seeds'),
              ]),
            ],
          ),
          const SizedBox(height: 16),

          _Banner(progress: progress, due: counts.value?.due ?? 0),

          // -------- the tree --------
          // The first thing on the first screen, because it is the thing all
          // the answering is for.
          const TreePanel(),
          const SizedBox(height: 12),

          // Today in one line. Three tiles of numbers was the bulk of what
          // made this screen dense, and none of them changed what to do next.
          counts.when(
            loading: () => const SizedBox(height: 18),
            error: (e, _) => Text('$e'),
            data: (c) => Text(
              s.t('todayLine', {
                'due': c.due,
                'fresh': c.fresh,
                'left': c.unanswered,
                'done': stats?.answeredToday ?? 0,
              }),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),

          // What the next session draws from. Controls rather than readouts,
          // so they stay on this screen while the statistics move to Progress.
          // Stacked on a narrow phone: side by side, the area names — which
          // come from the AI and run long — are cut to nothing.
          LayoutBuilder(builder: (context, box) {
            final realmPicker = DropdownButtonFormField<String?>(
              initialValue: filter,
              isExpanded: true,
              isDense: true,
              decoration: const InputDecoration(
                  isDense: true, border: OutlineInputBorder()),
              items: [
                DropdownMenuItem(
                    value: null,
                    child:
                        Text(s.t('allRealms'), overflow: TextOverflow.ellipsis)),
                for (final r in mine)
                  DropdownMenuItem(
                      value: r.id,
                      child: Text(
                          r.hasMaterial
                              ? r.label
                              : '${r.label} · ${s.t('emptyRealmTag')}',
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => _pickRealm(context, ref, mine, v),
            );
            final formatPicker = DropdownButtonFormField<String>(
              initialValue: ref.watch(formatFilterProvider),
              isExpanded: true,
              isDense: true,
              decoration: const InputDecoration(
                  isDense: true, border: OutlineInputBorder()),
              items: [
                DropdownMenuItem(value: 'all', child: Text(s.t('formatAll'))),
                DropdownMenuItem(
                    value: 'listening', child: Text(s.t('formatListening'))),
                DropdownMenuItem(
                    value: 'phrasing', child: Text(s.t('formatPhrasing'))),
                DropdownMenuItem(
                    value: 'speaking', child: Text(s.t('formatSpeaking'))),
              ],
              onChanged: (v) => v == null
                  ? null
                  : ref.read(formatFilterProvider.notifier).state = v,
            );

            if (mine.length < 2) return formatPicker;
            if (box.maxWidth < 360) {
              return Column(children: [
                realmPicker,
                const SizedBox(height: 8),
                formatPicker,
              ]);
            }
            return Row(children: [
              Expanded(child: realmPicker),
              const SizedBox(width: 8),
              Expanded(child: formatPicker),
            ]);
          }),
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
            // The reason to press the button, right above the button. "One
            // more question" only works if the learner can see what the one
            // more question is worth.
            if (stats?.goal != null) ...[
              Row(children: [
                Icon(Icons.flag_outlined,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    s.t('goal${stats!.goal!.kind}', {
                      'n': stats.goal!.remaining,
                      'target': stats.goal!.target,
                    }),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
            ],
            FilledButton(
              onPressed: () => _start(context, ref, count: settings.sessionSize),
              child: Text(s.t('startLearning')),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _start(context, ref, count: 1),
              child: Text(s.t('justOne')),
            ),
            // Arguing back. Shown only once a pack has brought an opponent:
            // a door to an empty room is worse than no door.
            if ((ref.watch(debatesProvider).value ?? const []).isNotEmpty) ...[
              const SizedBox(height: 10),
              FilledButton.tonal(
                onPressed: () => startDebate(context, ref, onDone: () {
                  ref.invalidate(homeStatsProvider);
                  ref.invalidate(treeDataProvider);
                }),
                child: Text(s.t('debateButton')),
              ),
            ],
            // The two doors to the AI trip: writing something down right
            // after a meeting, and building the next pack from what has been
            // written. Always present — this is how the first opponent
            // arrives, so it cannot wait for one to exist.
            const SizedBox(height: 4),
            // A Wrap, not a Row: at 320dp the two labels do not share a line
            // in every language, and a cut-off label is worse than two lines.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.edit_note, size: 18),
                  onPressed: () => showCaptureDialog(context, ref),
                  label: Text(s.t('captureAdd')),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  onPressed: () async {
                    await Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PackScreen()));
                    if (!context.mounted) return;
                    ref.invalidate(debatesProvider);
                  },
                  label: Text(s.t('packTitle')),
                ),
              ],
            ),
            // Listening with nothing to answer. Not a session and not scored:
            // it is here for the minutes when a question is too much but the
            // sentences are not.
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ListenScreen())),
              child: Text(s.t('listenButton')),
            ),
            // Running low. Said before the library is actually empty, because
            // the fix takes a trip to an assistant and back — not something
            // to discover at the moment there is nothing left to answer.
            if ((counts.value?.fresh ?? 99) <= lowMaterialMark) ...[
              const SizedBox(height: 10),
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.t('lowMaterialTitle', {'n': counts.value?.fresh ?? 0}),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSecondaryContainer)),
                      const SizedBox(height: 4),
                      Text(s.t('lowMaterialBody'),
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer)),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const MaterialScreen()));
                          if (!context.mounted) return;
                          ref.invalidate(homeCountsProvider);
                          ref.invalidate(realmsProvider);
                        },
                        child: Text(s.t('createMaterial')),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),

          const SizedBox(height: 16),


          // -------- what the Seeds are for --------
          // Deliberately below the two start buttons: studying is free and
          // comes first, and this is what studying is growing towards.
          const SizedBox(height: 16),
          _SeedsCard(
            progress: progress,
            settings: settings,
            realms: realms,
            nextLocked: nextLocked,
            sentences: counts.value?.questions ?? 0,
          ),

        ],
      ),
    );
  }

  /// Switches the filter, and offers the way out when the chosen area has
  /// nothing in it yet — otherwise picking one lands on a home screen with
  /// zero questions and no hint about what to do next.
  Future<void> _pickRealm(
      BuildContext context, WidgetRef ref, List<Realm> realms, String? id) async {
    ref.read(realmFilterProvider.notifier).state = id;
    if (id == null) return;

    final realm = realms.where((r) => r.id == id).firstOrNull;
    if (realm == null || realm.hasMaterial) return;

    final s = ref.read(stringsProvider);
    final go = await confirm(
      context,
      title: s.t('emptyRealmTitle', {'realm': realm.label}),
      body: s.t('emptyRealmBody'),
      confirmLabel: s.t('createMaterial'),
      cancelLabel: s.t('cancel'),
      destructive: false,
    );
    if (!go || !context.mounted) return;

    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => MaterialScreen(realmId: realm.id)));
    if (!context.mounted) return;
    ref.invalidate(realmsProvider);
    ref.invalidate(homeCountsProvider);
  }

  Future<void> _start(BuildContext context, WidgetRef ref, {required int count}) =>
      startSession(context, ref,
          count: count,
          // Otherwise Listening Mastery, today's areas and the weekly strip all
          // read the answer log from before this session — stale until the next
          // pull-to-refresh, which nobody does right after finishing.
          onDone: () => ref.invalidate(homeStatsProvider));
}

/// Seeds, and the two things they buy. The point of the card is that a
/// learner should never have to go looking for the answer to "what is this
/// number for, and how much more do I need" — both are on the home screen.
class _SeedsCard extends ConsumerStatefulWidget {
  final Progress progress;
  final AppSettings settings;
  final List<Realm> realms;
  final Realm? nextLocked;

  /// Questions available in the current filter. A longer session cannot be
  /// served out of a library that does not hold enough of them.
  final int sentences;

  const _SeedsCard({
    required this.progress,
    required this.settings,
    required this.realms,
    required this.nextLocked,
    required this.sentences,
  });

  @override
  ConsumerState<_SeedsCard> createState() => _SeedsCardState();
}

class _SeedsCardState extends ConsumerState<_SeedsCard> {
  /// Held from the tap that opens the confirmation until the purchase has
  /// settled, rather than only around the write. The dialog's own barrier
  /// already stops a second tap reaching the button, so this is belt and
  /// braces — but it keeps the button's disabled state honest for the whole
  /// round trip instead of only its last moment.
  bool _busy = false;

  /// Buys one decoration and hangs it on the tree. Behind a confirmation: it
  /// is a row of small pictures next to other small pictures, and spending 40
  /// Seeds on a mistaken tap is the kind of thing nobody forgives an app for.
  Future<void> _buyOrnament(String kind) async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final ok = await confirm(
      context,
      title: s.t('ornamentConfirmTitle'),
      body: s.t('ornamentConfirmBody', {'n': ornamentCost}),
      confirmLabel: s.t('confirmLabel'),
      cancelLabel: s.t('cancel'),
      destructive: false,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final next = await ref.read(repositoryProvider).spendForOrnament(kind);
    if (!mounted) return;
    setState(() => _busy = false);
    if (next == null) return;
    ref.read(progressProvider.notifier).state = next;
    ref.invalidate(treeDataProvider);
    if (mounted) showToast(context, s.t('ornamentDone'));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final seeds = widget.progress.seeds;
    final unlocked = widget.realms.where((r) => r.unlocked).toList();
    // The next thing worth saving for, so the balance always has a purpose
    // attached to it rather than sitting there as a score.
    final nextCost = widget.nextLocked != null ? realmUnlockCost : extraMaterialCost;
    final shortfall = nextCost - seeds;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text('🌱 ${s.t('seedsLabel')}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text('$seeds',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              shortfall > 0
                  ? s.t('seedsToNextUnlock', {'n': shortfall})
                  : s.t('seedsCanUnlock'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),

            const Divider(height: 24),

            // -------- areas --------
            Text('🌎 ${s.t('realmsTitle')}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            // A count, not the names with a tick beside them: "today's areas"
            // is right above with its own ticks, and the same mark meaning
            // "studied today" there and "already yours" here made both
            // harder to read.
            Text(s.t('realmsCount', {'n': unlocked.length}),
                style: theme.textTheme.bodySmall),
            if (widget.nextLocked != null) ...[
              const SizedBox(height: 4),
              Text(s.t('unlockRealmCost', {'n': realmUnlockCost}),
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              // Which area to open is a choice, and the card used to make it
              // for the learner by offering whichever locked one came first.
              OutlinedButton(
                onPressed: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const RealmPickerScreen()));
                  if (!context.mounted) return;
                  ref.invalidate(realmsProvider);
                  ref.invalidate(homeCountsProvider);
                },
                child: Text(s.t('yourRealmsButton')),
              ),
            ],
            const Divider(height: 24),

            // -------- material --------
            // Seeds buy three things and only three: an area, a batch of
            // material for one, and a decoration. Session length used to be a
            // fourth, which made a preference into a price.
            Text('📚 ${s.t('moreQuestionsTitle')}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(s.t('moreMaterialNote', {'n': extraMaterialCost}),
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MaterialScreen()));
                if (!context.mounted) return;
                ref.invalidate(homeCountsProvider);
                ref.invalidate(realmsProvider);
              },
              child: Text(s.t('createMaterial')),
            ),
            const Divider(height: 24),

            // -------- ornaments --------
            // The one thing Seeds buy that changes no number in the app. Once
            // the areas are open and the sessions are long, a balance with
            // nowhere to go stops meaning anything.
            Text('🎀 ${s.t('ornamentTitle')}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(s.t('ornamentNote', {'n': ornamentCost}),
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final kind in ornamentKinds) ...[
                  Expanded(
                    child: Opacity(
                      opacity: seeds >= ornamentCost ? 1 : 0.45,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _busy || seeds < ornamentCost
                            ? null
                            : () => _buyOrnament(kind),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Image.asset('assets/tree/ornament_$kind.png',
                              height: 44),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
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
class MasteryCard extends StatelessWidget {
  final int mastery;
  final dynamic s;
  final ThemeData theme;
  const MasteryCard(
      {super.key, required this.mastery, required this.s, required this.theme});

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
              // The caption wrapped under the percentage and ran into it. A
              // gap keeps the two apart whatever the language does to the
              // length of that line.
              const SizedBox(width: 8),
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
class JourneyCard extends StatelessWidget {
  final List<Realm> realms;
  final Set<String> touchedToday;
  final dynamic s;
  final ThemeData theme;
  const JourneyCard({
    super.key,
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
              const SizedBox(height: 4),
              // The tick meant "studied today" and said so nowhere.
              Text(s.t('journeyHint'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
/// The last seven days, oldest first. It used to be seven unexplained icons
/// floating on their own; without a caption there is no way to tell what the
/// row counts, or which end of it is today.
class WeekStrip extends StatelessWidget {
  final List<bool> week;
  final String label;
  final ThemeData theme;
  const WeekStrip(
      {super.key, required this.week, required this.label, required this.theme});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < week.length; i++)
                Column(
                  children: [
                    Icon(
                      week[i] ? Icons.headphones : Icons.circle_outlined,
                      size: 20,
                      color: week[i]
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 2),
                    // A dot under the last cell, so "today" is not something
                    // the reader has to infer from the ordering.
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == week.length - 1
                            ? theme.colorScheme.onSurfaceVariant
                            : Colors.transparent,
                      ),
                    ),
                  ],
                ),
            ],
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

class MiniTile extends StatelessWidget {
  final String value;
  final String label;

  /// Set on counters whose name cannot explain itself. The tile then carries a
  /// small ⓘ, because a tappable card that looks exactly like a plain one is a
  /// tap nobody makes.
  final VoidCallback? onTap;
  const MiniTile(
      {super.key, required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(label,
                    textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 3),
                Icon(Icons.info_outline,
                    size: 13, color: theme.colorScheme.onSurfaceVariant),
              ],
            ],
          ),
        ],
      ),
    );

    return Expanded(
      child: Card(
        child: onTap == null
            ? body
            : InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: body,
              ),
      ),
    );
  }
}
