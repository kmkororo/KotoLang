/// First-run flow: pick a language, copy a prompt, paste the reply, choose
/// areas, build material.
///
/// The friction here is deliberate and one-off. It is the price of material
/// that is actually about the learner's own life, so each screen says plainly
/// what it wants and why.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/l10n/languages.dart';
import '../core/l10n/strings.dart';
import '../domain/models.dart';
import '../domain/prompts.dart' as prompts;

// ------------------------------------------------------------ shared pieces

class _Page extends StatelessWidget {
  final String? back;
  final List<Widget> children;
  const _Page({this.back, required this.children});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: back == null
            ? null
            : AppBar(leading: const BackButton(), title: Text(back!)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: children,
          ),
        ),
      );
}

Future<void> copyToClipboard(BuildContext context, String text, String toast) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showToast(context, toast);
}

// -------------------------------------------------------- 1. language picker

class LanguagePickerScreen extends ConsumerStatefulWidget {
  final bool firstRun;
  const LanguagePickerScreen({super.key, this.firstRun = false});

  @override
  ConsumerState<LanguagePickerScreen> createState() => _LanguagePickerScreenState();
}

class _LanguagePickerScreenState extends ConsumerState<LanguagePickerScreen> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(languageProvider);
    if (_selected == null) {
      // Preselect the closest match to the device, but never decide for them.
      final locale = WidgetsBinding.instance.platformDispatcher.locale;
      _selected = resolveDeviceLanguage(locale.languageCode, locale.countryCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Deliberately uses the *pending* selection, so the screen previews the
    // language as the learner scrolls.
    // Previews the pending choice, so the screen speaks the language being
    // considered rather than the one currently active.
    final s = S(_selected ?? ref.watch(languageProvider) ?? fallbackLanguage);

    return Scaffold(
      appBar: widget.firstRun
          ? null
          : AppBar(leading: const BackButton(), title: Text(s.t('uiLanguageLabel'))),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.firstRun) ...[
                    Text('KotoLang',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                  ],
                  Text(s.t('pickLanguageTitle'),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(s.t('pickLanguageSub'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Expanded(
              child: RadioGroup<String>(
                groupValue: _selected,
                onChanged: (v) => setState(() => _selected = v),
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final lang in supportedLanguages)
                      RadioListTile<String>(
                        value: lang.code,
                        title: Text(lang.endonym,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        secondary: Text(lang.flag, style: const TextStyle(fontSize: 26)),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: FilledButton(
                onPressed: _selected == null
                    ? null
                    : () async {
                        final code = _selected!;
                        await ref.read(repositoryProvider).saveUiLanguage(code);
                        ref.read(languageProvider.notifier).state = code;
                        if (!context.mounted) return;
                        if (widget.firstRun) {
                          await reload(ref);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                child: Text(s.t('continueLabel')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- 2. welcome

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(languageProvider) ?? fallbackLanguage;
    final theme = Theme.of(context);

    Widget step(String n, String title, String sub) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(n,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onPrimaryContainer)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(sub,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        );

    return _Page(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(s.t('welcomeEyebrow').toUpperCase(),
              style: theme.textTheme.labelSmall
                  ?.copyWith(letterSpacing: 1.4, color: theme.colorScheme.onSurfaceVariant)),
          TextButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LanguagePickerScreen())),
            icon: const Icon(Icons.language, size: 18),
            label: Text(languageFor(lang).endonym),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(s.t('welcomeTitle'),
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.3)),
      const SizedBox(height: 12),
      Text(s.t('welcomeLede'),
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 24),
      step('1', s.t('step1Title'), s.t('step1Sub')),
      step('2', s.t('step2Title'), s.t('step2Sub')),
      step('3', s.t('step3Title'), s.t('step3Sub')),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('useYourAiTitle'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 6),
              Text(s.t('useYourAiSub'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 14),
              FilledButton.icon(
                icon: const Icon(Icons.copy_all),
                onPressed: () => copyToClipboard(
                    context, prompts.profilePrompt(uiLanguage: lang), s.t('copied')),
                label: Text(s.t('copyPrompt')),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PasteProfileScreen())),
                child: Text(s.t('goToPaste')),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(s.t('privacyNote'),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    ]);
  }
}

// -------------------------------------------------------- 3. paste profile

class PasteProfileScreen extends ConsumerStatefulWidget {
  const PasteProfileScreen({super.key});

  @override
  ConsumerState<PasteProfileScreen> createState() => _PasteProfileScreenState();
}

class _PasteProfileScreenState extends ConsumerState<PasteProfileScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = ref.read(stringsProvider);
    final lang = ref.read(languageProvider) ?? fallbackLanguage;
    setState(() {
      _busy = true;
      _error = null;
    });

    final res = await ref
        .read(repositoryProvider)
        .importProfile(_controller.text, uiLanguage: lang);

    if (!mounted) return;
    setState(() => _busy = false);

    if (!res.ok) {
      setState(() => _error = s.t('importFailedHint'));
      return;
    }
    showToast(context, s.t('importedProfile', {'n': res.realms}));
    await reload(ref);
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const RealmPickerScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(languageProvider) ?? fallbackLanguage;

    return _Page(back: s.t('pasteTitle'), children: [
      Text(s.t('pasteHint'),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 12),
      TextField(
        controller: _controller,
        maxLines: 12,
        minLines: 8,
        decoration: InputDecoration(hintText: s.t('pastePlaceholder')),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('importFailedTitle'),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onErrorContainer)),
                const SizedBox(height: 4),
                Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer)),
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _busy ? null : _load,
        child: _busy
            ? const SizedBox(
                height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(s.t('loadProfile')),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.copy_all),
        onPressed: () =>
            copyToClipboard(context, prompts.profilePrompt(uiLanguage: lang), s.t('copied')),
        label: Text(s.t('copyPromptAgain')),
      ),
    ]);
  }
}

// -------------------------------------------------------- 4. realm picker

class RealmPickerScreen extends ConsumerStatefulWidget {
  const RealmPickerScreen({super.key});

  @override
  ConsumerState<RealmPickerScreen> createState() => _RealmPickerScreenState();
}

class _RealmPickerScreenState extends ConsumerState<RealmPickerScreen> {
  List<Realm> _realms = const [];
  final _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ref.read(repositoryProvider).realms();
    if (!mounted) return;
    setState(() {
      _realms = list;
      // Preselect the ones the AI rated most important.
      for (final r in list.take(2)) {
        _selected.add(r.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);

    return _Page(back: s.t('realmsTitle'), children: [
      Text(s.t('realmsHint'),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 12),
      for (final r in _realms)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: CheckboxListTile(
              value: _selected.contains(r.id),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _selected.add(r.id);
                } else {
                  _selected.remove(r.id);
                }
              }),
              title: Text(r.label, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (r.nameNative.isNotEmpty && r.nameNative != r.name)
                    Text(r.name, style: theme.textTheme.bodySmall),
                  Text(
                    '${'★' * r.importance}  ${s.t('importanceLabel', {'n': r.importance})}'
                    '${r.hasMaterial ? ' · ${s.t('hasMaterial')}' : ''}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _selected.isEmpty
            ? null
            : () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => MaterialScreen(realmId: _selected.first))),
        child: Text(s.t('continueLabel')),
      ),
    ]);
  }
}

// ------------------------------------------------------- 5. material import

class MaterialScreen extends ConsumerStatefulWidget {
  final String? realmId;
  const MaterialScreen({super.key, this.realmId});

  @override
  ConsumerState<MaterialScreen> createState() => _MaterialScreenState();
}

class _MaterialScreenState extends ConsumerState<MaterialScreen> {
  final _controller = TextEditingController();
  List<Realm> _realms = const [];
  String? _realmId;
  String? _error;
  bool _busy = false;
  int _sentenceCount = 0;

  @override
  void initState() {
    super.initState();
    _realmId = widget.realmId;
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(repositoryProvider);
    final list = await repo.realms();
    final sentences = await repo.sentences();
    if (!mounted) return;
    setState(() {
      _realms = list;
      _realmId ??= list.isEmpty ? null : list.first.id;
      _sentenceCount = sentences.where((s) => s.realmId == _realmId).length;
    });
  }

  Realm? get _realm =>
      _realms.where((r) => r.id == _realmId).firstOrNull;

  Future<void> _copyPrompt() async {
    final s = ref.read(stringsProvider);
    final lang = ref.read(languageProvider) ?? fallbackLanguage;
    final realm = _realm;
    if (realm == null) return;

    final repo = ref.read(repositoryProvider);
    final profile = await repo.loadProfile();
    final existing = (await repo.items())
        .where((i) => i.realmIds.contains(realm.id))
        .map((i) => i.text)
        .toList();

    if (!mounted) return;
    await copyToClipboard(
      context,
      prompts.materialPrompt(
        uiLanguage: lang,
        realmName: realm.name,
        realmNative: realm.nameNative,
        level: profile?.englishLevel ?? 'B1',
        roles: profile?.roles ?? const [],
        priorities: profile?.learningPriorities ?? const [],
        contexts: realm.contexts,
        existingItems: existing,
      ),
      s.t('copied'),
    );
  }

  Future<void> _import() async {
    final s = ref.read(stringsProvider);
    final lang = ref.read(languageProvider) ?? fallbackLanguage;
    setState(() {
      _busy = true;
      _error = null;
    });

    final res = await ref
        .read(repositoryProvider)
        .importMaterial(_controller.text, uiLanguage: lang);

    if (!mounted) return;
    setState(() => _busy = false);

    if (!res.ok) {
      setState(() => _error = s.t('importFailedHint'));
      return;
    }
    _controller.clear();
    await reload(ref);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ReadyScreen(
          items: res.newItems,
          questions: res.questions,
          sentences: res.newSentences,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final realm = _realm;

    final hint = realm == null
        ? s.t('materialHintNoRealm')
        : (_sentenceCount > 0
            ? s.t('materialHintWith', {'name': realm.label, 'n': _sentenceCount})
            : s.t('materialHintEmpty', {'name': realm.label}));

    return _Page(back: s.t('materialTitle'), children: [
      if (_realms.isNotEmpty)
        DropdownButtonFormField<String>(
          initialValue: _realmId,
          decoration: InputDecoration(labelText: s.t('realmLabel')),
          items: [
            for (final r in _realms)
              DropdownMenuItem(value: r.id, child: Text(r.label)),
          ],
          onChanged: (v) {
            setState(() => _realmId = v);
            _load();
          },
        ),
      const SizedBox(height: 10),
      Text(hint,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 14),
      FilledButton.icon(
        icon: const Icon(Icons.copy_all),
        onPressed: realm == null ? null : _copyPrompt,
        label: Text(s.t('copyPrompt')),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _controller,
        maxLines: 10,
        minLines: 6,
        decoration: InputDecoration(hintText: s.t('pastePlaceholder')),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Card(
          color: theme.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('importFailedTitle'),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onErrorContainer)),
                const SizedBox(height: 4),
                Text(_error!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
              ],
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
            : Text(s.t('addQuestions')),
      ),
    ]);
  }
}

// ------------------------------------------------------------- 6. ready

class ReadyScreen extends ConsumerWidget {
  final int items;
  final int questions;
  final int sentences;
  const ReadyScreen({
    super.key,
    required this.items,
    required this.questions,
    required this.sentences,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);

    Widget tile(String value, String label) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Column(
                children: [
                  Text(value,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        );

    return _Page(children: [
      const SizedBox(height: 20),
      const Center(child: Text('🎉', style: TextStyle(fontSize: 52))),
      const SizedBox(height: 12),
      Center(
        child: Text(s.t('readyTitle'),
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
      ),
      const SizedBox(height: 20),
      Row(children: [
        tile('$items', s.t('readyItems')),
        const SizedBox(width: 10),
        tile('$questions', s.t('readyQuestions')),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        tile('$sentences', s.t('readySentences')),
        const SizedBox(width: 10),
        tile('1', s.t('goalOne')),
      ]),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () => Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeShell()),
          (_) => false,
        ),
        child: Text(s.t('goHome')),
      ),
    ]);
  }
}
