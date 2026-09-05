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
import 'scene_pack_screen.dart';

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
                // Two lines rather than an ellipsis: these titles are a whole
                // short sentence, and cutting one off mid-word tells the
                // reader nothing about the screen they are on.
                title: Text(back!, maxLines: 2, style: const TextStyle(fontSize: 18)),
              ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: children,
          ),
        ),
      );
}

/// Why an area is not available yet, and what opens it. Shown wherever a
/// locked area is tapped, so the answer is the same everywhere.
///
/// Any tap dismisses it — inside the card as much as outside. It is something
/// to read, not a decision, and hunting for a small button to acknowledge a
/// notice is friction for nothing.
Future<void> explainSeedGate(BuildContext context, WidgetRef ref) {
  final s = ref.read(stringsProvider);
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final t = Theme.of(ctx);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(ctx),
        child: AlertDialog(
          title: Text(s.t('capTitle', {'n': freeRealmSlots})),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('capBody', {'n': freeRealmSlots})),
              const SizedBox(height: 14),
              // The loop, as three steps rather than a paragraph.
              for (final step in [
                ('📚', s.t('capStepStudy')),
                ('🌱', s.t('capStepEarn', {'n': realmUnlockCost})),
                ('🌎', s.t('capStepOpen')),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.$1, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(step.$2, style: t.textTheme.bodyMedium)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
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

// -------------------------------------------------------- 3. paste profile

class PasteProfileScreen extends ConsumerStatefulWidget {
  /// Prefilled when the reply arrived through the share sheet rather than the
  /// clipboard.
  final String? initialText;

  /// Opened from the scenes screen, which only needs the profile: once it is
  /// in, this screen goes back there rather than on to the area picker.
  final bool forScenes;
  const PasteProfileScreen({super.key, this.initialText, this.forScenes = false});

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
    if (widget.forScenes) {
      // The scenes screen sent us; it has what it needs now.
      Navigator.pop(context);
      return;
    }
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
    await reload(ref);
    if (!mounted) return;
    // As the root, the picker is replaced by home once an area is confirmed;
    // pushed from elsewhere, it goes back.
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  Future<void> _unlock(Realm r) async {
    final s = ref.read(stringsProvider);
    final progress = ref.read(progressProvider);
    if (progress.seeds < realmUnlockCost) {
      showToast(
          context, s.t('unlockRealmNeedMore', {'n': realmUnlockCost - progress.seeds}));
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
        context, MaterialPageRoute(builder: (_) => const ScenePackScreen()));
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
              : _unlockTile(r, s, theme, progress.seeds),
        ),
      const SizedBox(height: 12),
      if (widget.firstRun)
        FilledButton(
          onPressed: _selected.isEmpty ? null : _confirmFirstRun,
          child: Text(s.t('continueLabel')),
        )
      else ...[
        // Asking the AI for an area nobody has suggested yet. It lives here
        // rather than in settings because it is the same job as the list
        // above — getting one more area to study.
        const Divider(height: 24),
        Text(s.t('newRealmHint'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          onPressed: _busy ? null : _copyNewRealmPrompt,
          label: Text(s.t('newRealmPrompt')),
        ),
      ],
    ]);
  }

  /// Charges for a brand-new area, then hands over the prompt that asks the
  /// AI to invent it. A name the AI never suggested cannot be opened through
  /// the list above, so it is gated here instead — before the prompt is
  /// copied, so nobody goes to their assistant and comes back to a refusal.
  Future<void> _copyNewRealmPrompt() async {
    final s = ref.read(stringsProvider);
    final repo = ref.read(repositoryProvider);
    final lang = ref.read(languageProvider) ?? fallbackLanguage;
    final settings = ref.read(settingsProvider);

    if (_realms.where((r) => r.unlocked).length >= freeRealmSlots) {
      final seeds = ref.read(progressProvider).seeds;
      if (seeds < realmUnlockCost) {
        showToast(context, s.t('unlockRealmNeedMore', {'n': realmUnlockCost - seeds}));
        return;
      }
      final ok = await confirm(
        context,
        title: s.t('unlockRealmConfirmTitle', {'realm': s.t('realmLabel')}),
        body: s.t('unlockRealmConfirmBody', {'n': realmUnlockCost}),
        confirmLabel: s.t('unlockButton'),
        cancelLabel: s.t('cancel'),
        destructive: false,
      );
      if (!ok || !mounted) return;

      final spent = await repo.spendForNewRealm();
      final after = await repo.loadProgress();
      if (!mounted || !spent) return;
      ref.read(progressProvider.notifier).state = after;
    }

    final profile = await repo.loadProfile();
    if (!mounted) return;
    await copyToClipboard(
      context,
      prompts.addRealmPrompt(
        uiLanguage: lang,
        existingRealms: _realms.map((r) => r.name).toList(),
        level: profile?.englishLevel ?? 'B1',
        batch: prompts.BatchSize.byName(settings.batchSize),
      ),
      s.t('copied'),
    );
  }

  Widget _pickTile(Realm r, bool atCap) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    final checked = _selected.contains(r.id);
    // Beyond the free three the tile stays tappable, but the tap explains the
    // rule instead of ticking the box. A dead checkbox says "no" without ever
    // saying why, and the why — study, earn Seeds, open more — is the part
    // worth knowing on this screen.
    final gated = !checked && atCap;
    return Card(
      child: CheckboxListTile(
        value: checked,
        secondary: gated
            ? Icon(Icons.lock_outline, color: theme.colorScheme.onSurfaceVariant)
            : null,
        onChanged: (v) {
          if (gated) {
            _explainCap();
            return;
          }
          setState(() {
            if (v == true) {
              _selected.add(r.id);
            } else {
              _selected.remove(r.id);
            }
          });
        },
        title: Text(r.label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: gated ? theme.colorScheme.onSurfaceVariant : null,
            )),
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
            if (gated)
              Text(s.t('capTileNote', {'n': realmUnlockCost}),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }

  Future<void> _explainCap() => explainSeedGate(context, ref);

  Widget _unlockTile(Realm r, dynamic s, ThemeData theme, int seeds) => Card(
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
                  context, MaterialPageRoute(builder: (_) => const ScenePackScreen()))
              : null,
        ),
      );
}
