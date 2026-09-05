/// Who the learner is: the two quick answers and the profile their AI wrote.
///
/// The age and the fields they care about are answered here with a tap and
/// saved at once. The profile itself — level, roles, what they want English
/// for — comes from the learner's own AI, made once and reused every time
/// scenes are written; this screen shows it and offers to remake it. Nothing
/// on this screen leaves the phone except by the learner's own copy and paste.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/l10n/languages.dart';
import '../domain/models.dart';
import '../domain/progress_service.dart';
import '../domain/prompts.dart' as prompts;
import 'ai_links.dart';
import 'onboarding_screens.dart' show copyToClipboard;
import 'paste_box.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  /// Prefilled when the reply arrived through the share sheet.
  final String? initialText;

  /// Opened for the profile alone (from the scenes screen or a share): once
  /// it is in, go back to whoever asked.
  final bool popOnDone;
  const ProfileScreen({super.key, this.initialText, this.popOnDone = false});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _paste = PasteController();
  UserProfile? _profile;
  bool _loaded = false;
  bool _busy = false;
  bool _remaking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final shared = widget.initialText;
    if (shared != null) {
      _paste.field.text = shared;
      _remaking = true;
    }
    _load();
  }

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await ref.read(repositoryProvider).loadProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loaded = true;
    });
  }

  String get _lang => ref.read(languageProvider) ?? fallbackLanguage;

  Future<void> _import() async {
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    final res =
        await ref.read(repositoryProvider).importProfile(_paste.text, uiLanguage: _lang);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!res.ok) {
      setState(() => _error = s.t('importFailedHint'));
      return;
    }
    showToast(
      context,
      res.partial
          ? s.t('partialImported', {'n': res.realms})
          : s.t('importedProfile', {'n': res.realms}),
    );
    _paste.clear();
    await reload(ref);
    ref.invalidate(realmsProvider);
    ref.invalidate(fieldsProvider);
    if (!mounted) return;
    if (widget.popOnDone) {
      Navigator.pop(context);
      return;
    }
    setState(() => _remaking = false);
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
                  Text(s.t('firstRunSub'), style: muted),
                  const SizedBox(height: 18),

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
                  const SizedBox(height: 4),
                  Text(s.t('profileAiBody'), style: muted),
                  const SizedBox(height: 14),

                  if (profile != null && !_remaking) ...[
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
                              _Row(s.t('profilePriorities'),
                                  profile.learningPriorities.join(', ')),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => setState(() => _remaking = true),
                      label: Text(s.t('profileRemake')),
                    ),
                  ] else ...[
                    Text(s.t('useYourAiSub'), style: muted),
                    const SizedBox(height: 14),
                    _StepHeader(1, s.t('step1Title')),
                    FilledButton.icon(
                      icon: const Icon(Icons.copy_all),
                      onPressed: () => copyToClipboard(
                          context, prompts.profilePrompt(uiLanguage: _lang), s.t('copied')),
                      label: Text(s.t('copyPrompt')),
                    ),
                    const SizedBox(height: 16),
                    AiLinks(s: s, prompt: () async => prompts.profilePrompt(uiLanguage: _lang)),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    _StepHeader(2, s.t('step2Title')),
                    Text(s.t('pasteHint'), style: muted),
                    const SizedBox(height: 12),
                    CopyTip(s),
                    const SizedBox(height: 12),
                    PasteBox(controller: _paste, s: s, expecting: 'profile'),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Card(
                        color: scheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.t('importFailedTitle'),
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onErrorContainer)),
                              const SizedBox(height: 4),
                              Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _import,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(s.t('loadProfile')),
                    ),
                    if (profile != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() => _remaking = false),
                        child: Text(s.t('cancel')),
                      ),
                    ],
                  ],
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

class _StepHeader extends StatelessWidget {
  final int n;
  final String title;
  const _StepHeader(this.n, this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: theme.colorScheme.primary,
            child: Text('$n',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: theme.colorScheme.onPrimary)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
        ],
      ),
    );
  }
}
