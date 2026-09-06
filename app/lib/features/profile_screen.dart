/// Who the learner is: two quick answers, and the profile their AI wrote.
///
/// The age and the fields they care about are answered here with a tap and
/// saved at once. The profile itself — level, roles, what they want English
/// for — comes from the learner's own AI, made once and reused every time
/// conversations are written; making or remaking it is the two-screen trip
/// in `ai_screens.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../domain/models.dart';
import '../domain/progress_service.dart';
import 'ai_screens.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  UserProfile? _profile;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ref.read(repositoryProvider).loadProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loaded = true;
    });
  }

  Future<void> _make() async {
    await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const AiPromptScreen(job: AiJob.profile)));
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = ref.watch(settingsProvider);
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final profile = _profile;

    return Scaffold(
      appBar: AppBar(title: Text(s.t('profileTitle'))),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  // -------- the two quick answers --------
                  Text(s.t('ageBandLabel'), style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final band in ageBands)
                        ChoiceChip(
                          label: Text(s.t('age_${band.replaceAll('+', 'plus')}')),
                          selected: settings.ageBand == band,
                          onSelected: (_) =>
                              updateSettings(ref, settings.copyWith(ageBand: band)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(s.t('interestsLabel'), style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final k in interestKinds)
                        FilterChip(
                          label: Text(s.t('interest_$k')),
                          selected: settings.interests.contains(k),
                          onSelected: (on) {
                            final next = {...settings.interests};
                            on ? next.add(k) : next.remove(k);
                            updateSettings(ref, settings.copyWith(interests: next.toList()));
                          },
                        ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // -------- the profile the AI wrote --------
                  Text(s.t('profileAiSection'), style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(s.t('profileAiBody'), style: muted),
                  const SizedBox(height: 12),

                  if (profile != null) ...[
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Row(s.t('profileLevel'), profile.englishLevel),
                            if (profile.roles.isNotEmpty)
                              _Row(s.t('profileRoles'), profile.roles.join(', ')),
                            if (profile.learningPriorities.isNotEmpty)
                              _Row(s.t('profilePriorities'), profile.learningPriorities.join(', ')),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh),
                      onPressed: _make,
                      label: Text(s.t('profileRemake')),
                    ),
                  ] else
                    BigButton(
                      icon: Icons.person_outline,
                      label: s.t('scenePackProfileButton'),
                      onPressed: _make,
                    ),

                  const SizedBox(height: 24),
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

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
