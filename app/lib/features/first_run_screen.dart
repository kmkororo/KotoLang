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
    if (!mounted) return;
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const SproutScreen(sampleDone: true)));
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
