/// Who the learner is: two quick answers, and the profile their AI wrote.
///
/// The age and the fields they care about are answered here with a tap and
/// saved at once. The profile itself — level, roles, what they want English
/// for — comes from the learner's own AI, made once and reused every time
/// scenes are written: two buttons, copy the prompt and paste the reply, and
/// one line that says where the data stays.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/l10n/languages.dart';
import '../domain/models.dart';
import '../domain/progress_service.dart';
import '../domain/prompts.dart' as prompts;
import 'ai_links.dart';
import 'field_picker_screen.dart';
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
  bool _showBox = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final shared = widget.initialText;
    if (shared != null) {
      _paste.field.text = shared;
      _remaking = true;
      _showBox = true;
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
  String get _promptText => prompts.profilePrompt(uiLanguage: _lang);

  /// Takes the reply off the clipboard; the paste box appears only when the
  /// clipboard had nothing.
  Future<void> _import() async {
    final s = ref.read(stringsProvider);
    if (_paste.isEmpty) {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (!mounted) return;
      if (text.trim().isEmpty) {
        setState(() {
          _showBox = true;
          _error = s.t('clipboardEmpty');
        });
        return;
      }
      _paste.field.text = text;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final res =
        await ref.read(repositoryProvider).importProfile(_paste.text, uiLanguage: _lang);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!res.ok) {
      setState(() {
        _showBox = true;
        _error = s.t('importFailedHint');
      });
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
    // The fields the AI read off the profile: the learner picks the starting
    // ones now, while there are still some to pick.
    final repo = ref.read(repositoryProvider);
    final left = await repo.freeFieldSlotsLeft();
    final anyLocked = (await repo.realms()).any((r) => !r.unlocked);
    if (!mounted) return;
    if (left > 0 && anyLocked) {
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => const RealmPickerScreen(choose: true)));
      if (!mounted) return;
    }
    if (widget.popOnDone) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _remaking = false;
      _showBox = false;
    });
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
                  const SizedBox(height: 12),

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
                              _Row(s.t('profilePriorities'), profile.learningPriorities.join(', ')),
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
                    _BigButton(
                      n: 1,
                      icon: Icons.copy_all,
                      label: s.t('copyPrompt'),
                      onPressed: () => copyToClipboard(context, _promptText, s.t('copied')),
                    ),
                    const SizedBox(height: 10),
                    AiLinks(s: s, prompt: () async => _promptText),
                    const SizedBox(height: 20),
                    _BigButton(
                      n: 2,
                      icon: Icons.download,
                      label: s.t('scenePasteButton'),
                      onPressed: _busy ? null : _import,
                      busy: _busy,
                    ),
                    if (_showBox) ...[
                      const SizedBox(height: 12),
                      PasteBox(controller: _paste, s: s, expecting: 'profile'),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: TextStyle(color: scheme.error)),
                    ],
                    if (profile != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() => _remaking = false),
                        child: Text(s.t('cancel')),
                      ),
                    ],
                  ],

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

/// One of the two steps: a numbered, full-width button.
class _BigButton extends StatelessWidget {
  final int n;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  const _BigButton({
    required this.n,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        alignment: Alignment.centerLeft,
      ),
      onPressed: onPressed,
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: theme.colorScheme.onPrimary.withValues(alpha: 0.25),
            child: Text('$n',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: theme.colorScheme.onPrimary)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          if (busy)
            const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Icon(icon, size: 20),
        ],
      ),
    );
  }
}
