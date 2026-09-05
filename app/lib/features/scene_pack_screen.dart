/// The trip to the learner's own AI: five scenes made for them, in one field.
///
/// Pick the field, copy the prompt, open the assistant, paste the reply,
/// take it in. The first time, the AI has to be told who the learner is —
/// that is the profile, done once, and this screen leads there before
/// anything else. Nothing here talks to a network; the learner's own AI does
/// the writing, in their own app, and the reply comes back through the
/// clipboard or the share sheet.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/l10n/languages.dart';
import '../data/builtin_scenes.dart';
import '../domain/field.dart';
import '../domain/models.dart';
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
  List<({String topic, String reason})> _rejected = const [];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final shared = widget.initialText;
    if (shared != null) _paste.field.text = shared;
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

  /// Same shape as every paste box in the app: with nothing collected, the
  /// button takes the reply off the clipboard instead.
  Future<void> _import() async {
    final s = ref.read(stringsProvider);
    if (_paste.isEmpty) {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (!mounted) return;
      if (text.trim().isEmpty) {
        setState(() => _error = s.t('clipboardEmpty'));
        return;
      }
      _paste.field.text = text;
    }

    setState(() {
      _busy = true;
      _error = null;
      _rejected = const [];
    });
    final out = await ref
        .read(repositoryProvider)
        .importScenes(_paste.text, uiLanguage: _lang, field: _field ?? defaultFieldId);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!out.ok) {
      setState(() {
        _error = out.errors.contains('not a scenes reply')
            ? s.t('scenePackNotScenes')
            : s.t('importFailedHint');
        _rejected = out.rejected;
      });
      return;
    }
    _paste.clear();
    ref.invalidate(allScenesProvider);
    setState(() => _rejected = out.rejected);
    await _load();
    if (!mounted) return;
    showToast(context, s.t('scenesImported', {'n': out.scenes}));
    if (out.rejected.isEmpty) Navigator.popUntil(context, (r) => r.isFirst);
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
    // A field is always chosen: the one asked for, else the first.
    final field = _field ?? (fields.isEmpty ? null : fields.first.id);
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
                  if (widget.initialText != null) ...[
                    Card(
                      color: scheme.secondaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Icon(Icons.ios_share, size: 18, color: scheme.onSecondaryContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(s.t('sharedTextTitle'),
                                style: TextStyle(color: scheme.onSecondaryContainer)),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(s.t('scenePackIntro'), style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  Text(s.t('scenePackWhat'), style: muted),
                  const SizedBox(height: 20),

                  // The one thing the AI needs before it can write for this
                  // person. Done once; the profile screen comes straight back.
                  if (!hasProfile) ...[
                    Card(
                      color: scheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.t('scenePackNeedProfile'),
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onPrimaryContainer)),
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
                  Text(s.t('scenePackField'), style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final f in fields)
                        ChoiceChip(
                          key: ValueKey('field_${f.id}'),
                          label: Text(f.label),
                          selected: f.id == field,
                          onSelected: (_) => setState(() => _field = f.id),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: Text(s.t('fieldAdd')),
                        onPressed: () => showAddFieldDialog(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _StepHeader(1, s.t('step1Title')),
                  FilledButton.icon(
                    icon: const Icon(Icons.copy_all),
                    onPressed: ready ? _copy : null,
                    label: Text(s.t('copyPrompt')),
                  ),
                  const SizedBox(height: 16),
                  AiLinks(s: s, enabled: ready, prompt: _prompt),
                  const SizedBox(height: 10),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.schedule, size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(child: Text(s.t('scenePackTakesTime'), style: muted)),
                  ]),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  _StepHeader(2, s.t('step2Title')),
                  CopyTip(s),
                  const SizedBox(height: 12),
                  PasteBox(controller: _paste, s: s, expecting: 'scenes'),
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
                                    fontWeight: FontWeight.w700, color: scheme.onErrorContainer)),
                            const SizedBox(height: 4),
                            Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  // Scenes the importer could not make sound, named with the
                  // reason. Not an error: the rest went in.
                  if (_rejected.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: scheme.tertiaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          s.t('packRejected', {
                            'n': _rejected.length,
                            'reasons':
                                _rejected.map((r) => '${r.topic} (${r.reason})').join('; '),
                          }),
                          style: TextStyle(color: scheme.onTertiaryContainer),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _busy ? null : _import,
                    child: _busy
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(s.t('packTakeIn')),
                  ),
                ],
              ),
      ),
    );
  }
}

/// "1 — Copy the prompt". The two halves of the trip, numbered.
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
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimary)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
        ],
      ),
    );
  }
}
