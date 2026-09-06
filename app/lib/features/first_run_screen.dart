/// Step 1 of the setup: two questions — age group, and where English is
/// wanted. Both optional in spirit, but the button waits for an age so the
/// conversations can be pitched; interests may stay empty. Then straight on
/// to step 2, the profile from the learner's own AI.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../domain/progress_service.dart';
import 'ai_screens.dart';

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
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const AiPromptScreen(job: AiJob.profile, firstRun: true)));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('firstRunTitle'), style: const TextStyle(fontSize: 18))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            StepBand(step: 1, title: s.t('step1Title'), hint: s.t('step1Hint')),
            Text(s.t('firstRunSub'), style: muted),
            const SizedBox(height: 24),
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
