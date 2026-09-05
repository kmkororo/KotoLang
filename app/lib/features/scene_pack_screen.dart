/// The trip to the learner's own AI: five scenes made for them, in one field.
///
/// Two buttons and one line. Pick the field, copy the prompt (or open the
/// assistant with it), paste the reply. Nobody reads the explanations here,
/// so there are none; the one line that stays is the one that matters —
/// nothing leaves this phone but the text the learner copies.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/l10n/languages.dart';
import '../data/builtin_scenes.dart';
import '../domain/field.dart';
import '../domain/models.dart';
import '../domain/progress_service.dart';
import 'ai_links.dart';
import 'field_screen.dart' show showAddFieldDialog;
import 'onboarding_screens.dart' show copyToClipboard;
import 'paste_box.dart';
import 'profile_screen.dart';

class ScenePackScreen extends ConsumerStatefulWidget {
  /// Prefilled when the reply arrived through the share sheet.
  final String? initialText;

  /// The field the scenes are for, when the caller already knows.
  final String? initialField;
  const ScenePackScreen({super.key, this.initialText, this.initialField});

  @override
  ConsumerState<ScenePackScreen> createState() => _ScenePackScreenState();
}

class _ScenePackScreenState extends ConsumerState<ScenePackScreen> {
  final _paste = PasteController();
  UserProfile? _profile;
  bool _loaded = false;
  int _ownScenes = 0;
  String? _field;
  String? _error;
  bool _busy = false;

  /// The paste box is only shown when the clipboard had nothing to offer.
  bool _showBox = false;

  @override
  void initState() {
    super.initState();
    final shared = widget.initialText;
    if (shared != null) {
      _paste.field.text = shared;
      _showBox = true;
    }
    _field = widget.initialField;
    _load();
  }

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(repositoryProvider);
    final profile = await repo.loadProfile();
    final own = await repo.scenes(includeDisabled: true);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _ownScenes = own.length;
      _loaded = true;
    });
  }

  String get _lang => ref.read(languageProvider) ?? fallbackLanguage;

  Future<String> _prompt() => ref.read(repositoryProvider).scenesPromptText(
        uiLanguage: _lang,
        extraTopics: builtinTopics(),
        lookup: {for (final s in builtinScenes(_lang)) s.id: s},
        field: _field,
      );

  Future<void> _copy() async {
    final s = ref.read(stringsProvider);
    final text = await _prompt();
    if (!mounted) return;
    await copyToClipboard(context, text, s.t('copied'));
  }

  /// Takes the reply off the clipboard; only when that is empty does the
  /// paste box appear.
  Future<void> _import(String field) async {
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
    final out = await ref
        .read(repositoryProvider)
        .importScenes(_paste.text, uiLanguage: _lang, field: field);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!out.ok) {
      setState(() {
        _showBox = true;
        _error = out.errors.contains('not a scenes reply')
            ? s.t('scenePackNotScenes')
            : s.t('importFailedHint');
      });
      return;
    }
    _paste.clear();
    ref.invalidate(allScenesProvider);
    await _load();
    if (!mounted) return;
    showToast(
      context,
      out.rejected.isEmpty
          ? s.t('scenesImported', {'n': out.scenes})
          : '${s.t('scenesImported', {'n': out.scenes})} · ${s.t('packRejected', {
                  'n': out.rejected.length,
                  'reasons': out.rejected.map((r) => r.topic).join(', ')
                })}',
    );
    Navigator.popUntil(context, (r) => r.isFirst);
  }


  /// A priced area picked in the dropdown: confirm, pay, and it becomes the
  /// field the scenes are for.
  Future<void> _openField(Field f) async {
    final s = ref.read(stringsProvider);
    final repo = ref.read(repositoryProvider);
    final progress = ref.read(progressProvider);
    if (progress.seeds < realmUnlockCost) {
      showToast(context, s.t('unlockRealmNeedMore', {'n': realmUnlockCost - progress.seeds}));
      return;
    }
    final ok = await confirm(
      context,
      title: s.t('unlockRealmConfirmTitle', {'realm': f.label}),
      body: s.t('unlockRealmConfirmBody', {'n': realmUnlockCost}),
      confirmLabel: s.t('unlockButton'),
      cancelLabel: s.t('cancel'),
      destructive: false,
    );
    if (!ok || !mounted) return;
    final spent = await repo.unlockRealm(f.id);
    if (!mounted || !spent) return;
    ref.read(progressProvider.notifier).state = await repo.loadProgress();
    ref.invalidate(realmsProvider);
    ref.invalidate(fieldsProvider);
    ref.invalidate(lockedFieldsProvider);
    setState(() => _field = f.id);
  }
  Future<void> _makeProfile() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ProfileScreen(popOnDone: true)));
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final fields = ref.watch(fieldsProvider).value ?? const <Field>[];
    final locked = ref.watch(lockedFieldsProvider).value ?? const <Field>[];
    final interests = ref.watch(settingsProvider).interests;
    // A field is always chosen: the one asked for, else the first the
    // learner said they care about, else the first there is.
    final field = _field ??
        fields.map((f) => f.id).where(interests.contains).firstOrNull ??
        (fields.isEmpty ? null : fields.first.id);
    // Remembered, so the prompt and the import use what the dropdown shows.
    _field ??= field;
    final hasProfile = _profile != null;
    final ready = hasProfile && field != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t(_ownScenes == 0 ? 'firstSceneMake' : 'nextScenesMake'),
            maxLines: 2, style: const TextStyle(fontSize: 18)),
      ),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  // The one thing the AI needs before it can write for this
                  // person. Done once; the profile screen comes straight back.
                  if (!hasProfile) ...[
                    Card(
                      color: scheme.primaryContainer,
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(s.t('scenePackNeedProfile'),
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer)),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              icon: const Icon(Icons.person_outline),
                              onPressed: _makeProfile,
                              label: Text(s.t('scenePackProfileButton')),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // -------- which field --------
                  DropdownButtonFormField<String>(
                    key: const ValueKey('fieldPicker'),
                    initialValue: field,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: s.t('fieldPickLabel'), isDense: true),
                    items: [
                      for (final f in fields)
                        DropdownMenuItem(value: f.id, child: Text(f.label, overflow: TextOverflow.ellipsis)),
                      // The areas read off the profile that are not open yet,
                      // priced; picking one opens it.
                      for (final f in locked)
                        DropdownMenuItem(
                          value: f.id,
                          child: Row(children: [
                            Icon(Icons.lock_outline, size: 16, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Expanded(child: Text(f.label, overflow: TextOverflow.ellipsis)),
                            Text('$realmUnlockCost Seeds', style: theme.textTheme.bodySmall),
                          ]),
                        ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      final l = locked.where((f) => f.id == v).firstOrNull;
                      if (l != null) {
                        _openField(l);
                        return;
                      }
                      setState(() => _field = v);
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      onPressed: () => showAddFieldDialog(context, ref),
                      label: Text(s.t('fieldAdd')),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // -------- 1: the prompt --------
                  _BigButton(
                    n: 1,
                    icon: Icons.copy_all,
                    label: s.t('copyPrompt'),
                    onPressed: ready ? _copy : null,
                  ),
                  const SizedBox(height: 10),
                  AiLinks(s: s, enabled: ready, prompt: _prompt),
                  const SizedBox(height: 20),

                  // -------- 2: the reply --------
                  _BigButton(
                    n: 2,
                    icon: Icons.download,
                    label: s.t('scenePasteButton'),
                    onPressed: _busy || !ready ? null : () => _import(field),
                    busy: _busy,
                  ),
                  if (_showBox) ...[
                    const SizedBox(height: 12),
                    PasteBox(controller: _paste, s: s, expecting: 'scenes'),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: TextStyle(color: scheme.error)),
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
