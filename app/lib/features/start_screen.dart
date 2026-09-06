/// The first screen after the language: what is about to happen, as four
/// steps down the page, and one button to begin. The samples are offered
/// underneath for anyone who wants to hear one before the trip to their AI.
///
/// This is the root until the setup is done, so leaving the setup halfway
/// lands back here — and "start" picks the flow up where it stopped.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/l10n/languages.dart';
import '../data/builtin_scenes.dart';
import 'ai_screens.dart';
import 'field_picker_screen.dart';
import 'first_run_screen.dart';
import 'scene_screen.dart';

class StartOverviewScreen extends ConsumerWidget {
  const StartOverviewScreen({super.key});

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(repositoryProvider);
    final profile = await repo.loadProfile();
    if (!context.mounted) return;
    if (profile == null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const FirstRunScreen()));
      return;
    }
    // Setup left off after the profile: on to the fields, then the scenes.
    final left = await repo.freeFieldSlotsLeft();
    final anyLocked = (await repo.realms()).any((r) => !r.unlocked);
    if (!context.mounted) return;
    if (left > 0 && anyLocked) {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const RealmPickerScreen(choose: true, firstRun: true)));
      if (!context.mounted) return;
    }
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const AiPromptScreen(job: AiJob.scenes, firstRun: true)));
  }

  Future<void> _sample(BuildContext context, WidgetRef ref) async {
    final lang = ref.read(languageProvider) ?? fallbackLanguage;
    final sample = tutorialScene(lang);
    if (sample == null) return;
    await Navigator.push<SceneRunResult>(
      context,
      MaterialPageRoute(builder: (_) => SceneScreen(scene: sample, tutorial: true)),
    );
    if (!context.mounted) return;
    // Home from here; the way to the learner's own AI is on it.
    final settings = ref.read(settingsProvider);
    await updateSettings(ref, settings.copyWith(tutorialDone: true));
    await reload(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final lang = ref.watch(languageProvider) ?? fallbackLanguage;
    final hasSample = tutorialScene(lang) != null;

    final steps = [
      (s.t('step1Title'), s.t('step1Hint')),
      (s.t('step2Title'), s.t('step2Hint')),
      (s.t('step3Title'), s.t('step3Hint')),
      (s.t('step4Title'), s.t('step4Hint')),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          children: [
            Text(s.t('startTitle'), style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(s.t('startIntro'), style: muted),
            const SizedBox(height: 24),
            for (var i = 0; i < steps.length; i++)
              _StepRow(
                n: i + 1,
                title: steps[i].$1,
                hint: steps[i].$2,
                last: i == steps.length - 1,
              ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => _start(context, ref),
              child: Text(s.t('startButton')),
            ),
            if (hasSample) ...[
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => _sample(context, ref),
                child: Text(s.t('startSample')),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(child: Text(s.t('privacyLine'), style: muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One step of the flowchart: a numbered circle, a line down to the next,
/// the step's name and one line on it.
class _StepRow extends StatelessWidget {
  final int n;
  final String title;
  final String hint;
  final bool last;
  const _StepRow({required this.n, required this.title, required this.hint, required this.last});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: scheme.primary,
                child: Text('$n',
                    style: TextStyle(
                        color: scheme.onPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
              if (!last)
                Expanded(
                  child: Container(width: 2, color: scheme.primary.withValues(alpha: 0.35)),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: last ? 0 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(hint,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
