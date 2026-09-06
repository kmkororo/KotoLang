/// The first five minutes: two questions, one sample scene, a sprout — and
/// the way to the learner's own AI, offered before the samples are.
///
/// Nothing here needs an AI or a network. The samples ship with the app, so
/// the first scene is answered within a minute of choosing a language; the
/// trip to the learner's own AI is shown as the point of the app, not as a
/// gate in front of it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/l10n/languages.dart';
import '../data/builtin_scenes.dart';
import '../domain/progress_service.dart';
import 'scene_pack_screen.dart';
import 'scene_screen.dart';

/// Age group and where English is wanted. Both optional in spirit, but the
/// button waits for an age so the scenes can be pitched; interests may stay
/// empty.
class FirstRunScreen extends ConsumerStatefulWidget {
  const FirstRunScreen({super.key});

  @override
  ConsumerState<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends ConsumerState<FirstRunScreen> {
  String _age = '';
  final _interests = <String>{};

  Future<void> _continue() async {
    final settings = ref.read(settingsProvider);
    await updateSettings(
      ref,
      settings.copyWith(ageBand: _age, interests: _interests.toList()),
    );
    if (!mounted) return;
    // Two ways in: scenes of their own from their AI, or a sample first.
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const StartChoiceScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
          children: [
            Text(s.t('firstRunTitle'), style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(s.t('firstRunSub'), style: muted),
            const SizedBox(height: 28),
            Text(s.t('ageBandLabel'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b in ageBands)
                  ChoiceChip(
                    label: Text(s.t('age_${b.replaceAll('+', 'plus')}')),
                    selected: _age == b,
                    onSelected: (_) => setState(() => _age = b),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(s.t('interestsLabel'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in interestKinds)
                  FilterChip(
                    label: Text(s.t('interest_$k')),
                    selected: _interests.contains(k),
                    onSelected: (on) =>
                        setState(() => on ? _interests.add(k) : _interests.remove(k)),
                  ),
              ],
            ),
            const SizedBox(height: 40),
            FilledButton(
              onPressed: _age.isEmpty ? null : _continue,
              child: Text(s.t('continueLabel')),
            ),
          ],
        ),
      ),
    );
  }
}

/// The fork after the two questions: make scenes with one's own AI now, or
/// try a sample first. The samples are the starter set and the AI is the
/// point, so the AI comes first and in the main colour.
class StartChoiceScreen extends ConsumerWidget {
  const StartChoiceScreen({super.key});

  /// Straight to the scenes screen, over home. With no profile yet, that
  /// screen asks for it first.
  Future<void> _own(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsProvider);
    await updateSettings(ref, settings.copyWith(tutorialDone: true));
    if (!context.mounted) return;
    Navigator.popUntil(context, (r) => r.isFirst);
    await reload(ref);
    if (!context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ScenePackScreen()));
  }

  /// The sample scene with the guide on it, then the sprout.
  Future<void> _sample(BuildContext context, WidgetRef ref) async {
    final lang = ref.read(languageProvider) ?? fallbackLanguage;
    final sample = tutorialScene(lang);
    if (sample == null) {
      // No samples in this build: straight to the sprout, which points at the
      // learner's own AI.
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => const SproutScreen(sampleDone: false)));
      return;
    }
    await Navigator.push<SceneRunResult>(
      context,
      MaterialPageRoute(builder: (_) => SceneScreen(scene: sample, tutorial: true)),
    );
    if (!context.mounted) return;
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const SproutScreen(sampleDone: true)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.t('firstChoiceTitle'), style: theme.textTheme.headlineSmall),
              const SizedBox(height: 24),
              _ChoiceCard(
                icon: Icons.auto_awesome,
                title: s.t('firstChoiceAi'),
                body: s.t('firstChoiceAiBody'),
                color: scheme.primaryContainer,
                fg: scheme.onPrimaryContainer,
                onTap: () => _own(context, ref),
              ),
              const SizedBox(height: 14),
              _ChoiceCard(
                icon: Icons.menu_book_outlined,
                title: s.t('firstChoiceSample'),
                body: s.t('firstChoiceSampleBody'),
                color: scheme.surfaceContainerHigh,
                fg: scheme.onSurface,
                onTap: () => _sample(context, ref),
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(s.t('privacyLine'),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the two doors: icon, title, one line, chevron.
class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final Color fg;
  final VoidCallback onTap;
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, size: 30, color: fg),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: fg, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(body, style: theme.textTheme.bodySmall?.copyWith(color: fg)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

/// The sprout, and the point of the app: what was just done was a sample,
/// and the learner's own scenes come from their own AI. Offered here, first,
/// as the main button; "later" is the small one.
class SproutScreen extends ConsumerWidget {
  final bool sampleDone;
  const SproutScreen({super.key, required this.sampleDone});

  Future<void> _finish(BuildContext context, WidgetRef ref, {required bool toOwn}) async {
    final settings = ref.read(settingsProvider);
    await updateSettings(ref, settings.copyWith(tutorialDone: true));
    if (!context.mounted) return;
    // Back to the root, which now routes to home; then, if asked, straight on
    // to the scenes screen.
    Navigator.popUntil(context, (r) => r.isFirst);
    await reload(ref);
    if (!context.mounted || !toOwn) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ScenePackScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            children: [
              Text(s.t('sproutTitle'), style: theme.textTheme.headlineMedium),
              const SizedBox(height: 18),
              const Text('🌱', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 22),
              Text(s.t(sampleDone ? 'sproutSample' : 'sproutNoSample'),
                  textAlign: TextAlign.center, style: muted),
              const Spacer(),
              FilledButton(
                onPressed: () => _finish(context, ref, toOwn: true),
                child: Text(s.t('makeOwnScenes')),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _finish(context, ref, toOwn: false),
                child: Text(s.t('laterSamples')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
