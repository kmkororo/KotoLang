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
import '../domain/progress_service.dart';
import '../domain/prompts.dart' as prompts;
import 'ai_links.dart';
import 'paste_box.dart';

// ------------------------------------------------------------ shared pieces

class _Page extends StatelessWidget {
  final String? back;
  final List<Widget> children;
  const _Page({this.back, required this.children});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: back == null
            ? null
            : AppBar(
                // These screens are sometimes the first route, where a back
                // arrow would sit there doing nothing.
                leading: Navigator.canPop(context) ? const BackButton() : null,
                automaticallyImplyLeading: false,
                title: Text(back!),
              ),
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

/// "1 — Copy the prompt". Copying and pasting live on one screen, so the two
/// halves are numbered: without that the page reads as an undifferentiated
/// pile of buttons and it is not obvious which comes first.
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
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onPrimary)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
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
              // One action only. Copying used to happen here and pasting on
              // the next screen, which left people holding a prompt with no
              // idea where it was meant to go.
              FilledButton.icon(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PasteProfileScreen())),
                label: Text(s.t('goToPaste')),
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
  /// Prefilled when the reply arrived through the share sheet rather than the
  /// clipboard.
  final String? initialText;
  const PasteProfileScreen({super.key, this.initialText});

  @override
  ConsumerState<PasteProfileScreen> createState() => _PasteProfileScreenState();
}

class _PasteProfileScreenState extends ConsumerState<PasteProfileScreen> {
  final _paste = PasteController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final shared = widget.initialText;
    if (shared != null) _paste.field.text = shared;
  }

  @override
  void dispose() {
    _paste.dispose();
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
        .importProfile(_paste.text, uiLanguage: lang);

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
    await reload(ref);
    if (!mounted) return;
    // Pushed, never `pushReplacement`. The root screen decides where the app
    // belongs, and when the root is itself showing a setup step, replacing the
    // route deletes that decision-maker for the rest of the session.
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const RealmPickerScreen(firstRun: true)));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(languageProvider) ?? fallbackLanguage;

    final theme = Theme.of(context);
    String promptText() => prompts.profilePrompt(uiLanguage: lang);

    // Copying and pasting are two halves of one job, so they belong on one
    // screen. Splitting them across two was the whole reason the first run was
    // hard to follow.
    return _Page(back: s.t('goToPaste'), children: [
      Text(s.t('useYourAiSub'),
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 20),

      _StepHeader(1, s.t('step1Title')),
      FilledButton.icon(
        icon: const Icon(Icons.copy_all),
        onPressed: () => copyToClipboard(context, promptText(), s.t('copied')),
        label: Text(s.t('copyPrompt')),
      ),
      const SizedBox(height: 16),
      AiLinks(s: s, prompt: () async => promptText()),

      const SizedBox(height: 24),
      const Divider(),
      const SizedBox(height: 16),

      _StepHeader(2, s.t('step2Title')),
      Text(s.t('pasteHint'),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 12),
      CopyTip(s),
      const SizedBox(height: 12),
      PasteBox(controller: _paste, s: s, expecting: 'profile'),
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
                Text(_error!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer)),
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
    ]);
  }
}

// -------------------------------------------------------- 4. realm picker

/// Two roles for one screen, matching `LanguagePickerScreen`'s own
/// first-run/settings split:
///
/// - `firstRun: true` (straight after profile import) — pick exactly
///   [freeRealmSlots] areas, free, with the rest of the AI-suggested areas
///   left locked for later.
/// - `firstRun: false` (reached from Settings as "your areas") — every area
///   the AI ever suggested, unlocked ones tappable to build more material,
///   locked ones priced and unlockable with Koto Coin.
class RealmPickerScreen extends ConsumerStatefulWidget {
  final bool firstRun;
  const RealmPickerScreen({super.key, this.firstRun = false});

  @override
  ConsumerState<RealmPickerScreen> createState() => _RealmPickerScreenState();
}

class _RealmPickerScreenState extends ConsumerState<RealmPickerScreen> {
  List<Realm> _realms = const [];
  final _selected = <String>{};
  bool _busy = false;

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
      if (widget.firstRun) {
        // Preselect the ones the AI rated most important.
        for (final r in list.take(freeRealmSlots)) {
          _selected.add(r.id);
        }
      }
    });
  }

  Future<void> _confirmFirstRun() async {
    await ref.read(repositoryProvider).markRealmsUnlocked(_selected.toList());
    if (!mounted) return;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => MaterialScreen(realmId: _selected.first)));
  }

  Future<void> _unlock(Realm r) async {
    final s = ref.read(stringsProvider);
    final progress = ref.read(progressProvider);
    if (progress.kotoCoins < realmUnlockCost) {
      showToast(
          context, s.t('unlockRealmNeedMore', {'n': realmUnlockCost - progress.kotoCoins}));
      return;
    }
    final ok = await confirm(
      context,
      title: s.t('unlockRealmConfirmTitle', {'realm': r.label}),
      body: s.t('unlockRealmConfirmBody', {'n': realmUnlockCost}),
      confirmLabel: s.t('unlockButton'),
      cancelLabel: s.t('cancel'),
      destructive: false,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    final spent = await ref.read(repositoryProvider).unlockRealm(r.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!spent) return; // balance moved between the check above and now

    ref.read(progressProvider.notifier).state = await ref.read(repositoryProvider).loadProgress();
    await _load();
    if (!mounted) return;
    // A one-time note the moment the very last locked area opens up, rather
    // than a permanent fixture on the home screen for what is a rare state.
    if (_realms.every((x) => x.unlocked)) {
      showToast(context, s.t('allRealmsUnlocked'));
    }
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => MaterialScreen(realmId: r.id)));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final progress = ref.watch(progressProvider);
    final atCap = widget.firstRun && _selected.length >= freeRealmSlots;

    return _Page(back: s.t('realmsTitle'), children: [
      // Only relevant the first time: from Settings, each tile already says
      // for itself whether it has material, is unlocked, or costs Koto Coin.
      if (widget.firstRun) ...[
        Text(s.t('realmsHint'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
      ],
      for (final r in _realms)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: widget.firstRun
              ? _pickTile(r, atCap)
              : _unlockTile(r, s, theme, progress.kotoCoins),
        ),
      const SizedBox(height: 12),
      if (widget.firstRun)
        FilledButton(
          onPressed: _selected.isEmpty ? null : _confirmFirstRun,
          child: Text(s.t('continueLabel')),
        ),
    ]);
  }

  Widget _pickTile(Realm r, bool atCap) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    final checked = _selected.contains(r.id);
    return Card(
      child: CheckboxListTile(
        value: checked,
        // Capped rather than left open: the first three are free, and
        // letting a fourth box get checked here would silently promise
        // something Koto Coin is supposed to gate.
        onChanged: (!checked && atCap)
            ? null
            : (v) => setState(() {
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
              style:
                  theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unlockTile(Realm r, dynamic s, ThemeData theme, int kotoCoins) => Card(
        child: ListTile(
          leading: Icon(
            r.unlocked ? Icons.lock_open : Icons.lock_outline,
            color: r.unlocked ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          ),
          title: Text(r.label, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            r.unlocked
                ? (r.hasMaterial ? s.t('hasMaterial') : s.t('unlockedLabel'))
                : s.t('unlockRealmCost', {'n': realmUnlockCost}),
            style: theme.textTheme.bodySmall?.copyWith(
              color: r.unlocked ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary,
            ),
          ),
          // The app theme gives FilledButton an infinite minimum width
          // (`Size.fromHeight`, meant for full-width buttons elsewhere),
          // which a ListTile's trailing slot cannot lay out. A fixed-size
          // override keeps it to the label's own width here.
          trailing: r.unlocked
              ? null
              : FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(64, 36)),
                  onPressed: _busy ? null : () => _unlock(r),
                  child: Text(s.t('unlockButton')),
                ),
          onTap: r.unlocked
              ? () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => MaterialScreen(realmId: r.id)))
              : null,
        ),
      );
}

// ------------------------------------------------------- 5. material import

class MaterialScreen extends ConsumerStatefulWidget {
  final String? realmId;

  /// Prefilled when the reply arrived through the share sheet rather than the
  /// clipboard.
  final String? initialText;
  const MaterialScreen({super.key, this.realmId, this.initialText});

  @override
  ConsumerState<MaterialScreen> createState() => _MaterialScreenState();
}

class _MaterialScreenState extends ConsumerState<MaterialScreen> {
  final _paste = PasteController();
  List<Realm> _realms = const [];
  String? _realmId;
  String? _error;
  bool _busy = false;
  int _sentenceCount = 0;

  prompts.BatchSize get _batch =>
      prompts.BatchSize.byName(ref.read(settingsProvider).batchSize);

  /// Purely informational, and derived rather than stored: it tells the AI
  /// roughly where in the sequence this request sits.
  int get _round => 1 + (_sentenceCount ~/ _batch.sentences);

  @override
  void initState() {
    super.initState();
    _realmId = widget.realmId;
    final shared = widget.initialText;
    if (shared != null) _paste.field.text = shared;
    _load();
  }

  @override
  void dispose() {
    _paste.dispose();
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

  /// Built on demand: it needs the stored expressions so the AI is told what
  /// not to repeat, and both the copy button and the assistant shortcuts want
  /// exactly the same text.
  Future<String> _promptText() async {
    final lang = ref.read(languageProvider) ?? fallbackLanguage;
    final realm = _realm;
    if (realm == null) return '';

    final repo = ref.read(repositoryProvider);
    final profile = await repo.loadProfile();
    final existing = (await repo.items())
        .where((i) => i.realmIds.contains(realm.id))
        .map((i) => i.text)
        .toList();

    return prompts.materialPrompt(
      uiLanguage: lang,
      realmName: realm.name,
      realmNative: realm.nameNative,
      level: profile?.englishLevel ?? 'B1',
      roles: profile?.roles ?? const [],
      priorities: profile?.learningPriorities ?? const [],
      contexts: realm.contexts,
      existingItems: existing,
      batch: _batch,
      round: _round,
    );
  }

  Future<void> _copyPrompt() async {
    final s = ref.read(stringsProvider);
    final text = await _promptText();
    if (!mounted || text.isEmpty) return;
    await copyToClipboard(context, text, s.t('copied'));
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
        .importMaterial(_paste.text, uiLanguage: lang);

    if (!mounted) return;
    setState(() => _busy = false);

    if (!res.ok) {
      setState(() => _error = s.t('importFailedHint'));
      return;
    }
    _paste.clear();
    if (res.partial) {
      showToast(context, s.t('partialImported', {'n': res.newSentences}));
    }
    await reload(ref);
    if (!mounted) return;
    Navigator.push(
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
    final settings = ref.watch(settingsProvider);
    final realm = _realm;

    final hint = realm == null
        ? s.t('materialHintNoRealm')
        : (_sentenceCount > 0
            ? s.t('materialHintWith', {'name': realm.label, 'n': _sentenceCount})
            : s.t('materialHintEmpty', {'name': realm.label}));

    return _Page(back: s.t('materialTitle'), children: [
      if (widget.initialText != null) ...[
        Card(
          color: theme.colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(Icons.ios_share, size: 18, color: theme.colorScheme.onSecondaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(s.t('sharedTextTitle'),
                    style: TextStyle(color: theme.colorScheme.onSecondaryContainer)),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
      ],
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

      // With no area there is no prompt to build, so every control below is
      // dead. Saying so without offering the way out is what left people
      // stranded here after a reset.
      if (realm == null) ...[
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.arrow_forward),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PasteProfileScreen())),
          label: Text(s.t('goToPaste')),
        ),
      ],
      const SizedBox(height: 14),

      // How much to ask for. Kept next to the copy button rather than buried in
      // settings, because this is the control that decides whether the reply
      // can be copied at all on the device in the learner's hand.
      DropdownButtonFormField<String>(
        initialValue: settings.batchSize,
        isExpanded: true,
        decoration: InputDecoration(labelText: s.t('batchSizeLabel'), isDense: true),
        items: [
          DropdownMenuItem(value: 'small', child: Text(s.t('batchSmall'))),
          DropdownMenuItem(value: 'standard', child: Text(s.t('batchStandard'))),
          DropdownMenuItem(value: 'large', child: Text(s.t('batchLarge'))),
        ],
        onChanged: (v) async {
          if (v == null) return;
          await updateSettings(ref, settings.copyWith(batchSize: v));
          if (mounted) setState(() {});
        },
      ),
      const SizedBox(height: 6),
      Text(s.t('batchNote'),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 12),
      _StepHeader(1, s.t('step1Title')),
      FilledButton.icon(
        icon: const Icon(Icons.copy_all),
        onPressed: realm == null ? null : _copyPrompt,
        label: Text(s.t('copyPrompt')),
      ),
      const SizedBox(height: 16),
      AiLinks(s: s, enabled: realm != null, prompt: _promptText),

      const SizedBox(height: 24),
      const Divider(),
      const SizedBox(height: 16),

      _StepHeader(2, s.t('step2Title')),
      CopyTip(s),
      const SizedBox(height: 12),
      PasteBox(controller: _paste, s: s),
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
        // Pops back to the root rather than pushing the home shell over it.
        // `pushAndRemoveUntil(..., (_) => false)` used to drop every route
        // including the root, and the root is the only thing that decides
        // which screen the app should be on. Once it was gone, a later reset
        // wiped the database but left the learner staring at a home screen
        // with nothing in it and no way forward.
        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        child: Text(s.t('goHome')),
      ),
    ]);
  }
}
