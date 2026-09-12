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
import '../domain/progress_service.dart';

// ------------------------------------------------------------ shared pieces

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
                ('🌱', s.t('capStepClimb')),
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
