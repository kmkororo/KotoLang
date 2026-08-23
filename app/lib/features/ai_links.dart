/// One-tap handover to the learner's own AI.
///
/// The prompt is copied to the clipboard *and then* the assistant is opened,
/// in that order, so that by the time its input box appears the prompt is
/// already waiting to be pasted. The prompts run to a few thousand characters,
/// far past what a URL can reliably carry, so prefilling the question through
/// a query parameter is not attempted: it would silently truncate on some
/// services and quietly produce worse material.
///
/// Failing to open is not treated as an error worth stopping for — the prompt
/// is on the clipboard either way, which is the part that matters.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../core/l10n/strings.dart';

class AiService {
  final String name;
  final String url;
  final Color color;
  final IconData icon;
  const AiService(this.name, this.url, this.color, this.icon);
}

/// Deliberately generic glyphs rather than the services' own marks: KotoLang
/// is not affiliated with any of them, and a lookalike logo would imply it is.
const aiServices = <AiService>[
  AiService('ChatGPT', 'https://chatgpt.com/', Color(0xFF10A37F),
      Icons.forum_outlined),
  AiService('Claude', 'https://claude.ai/new', Color(0xFFD97757),
      Icons.auto_awesome),
  AiService('Gemini', 'https://gemini.google.com/app', Color(0xFF4285F4),
      Icons.blur_on),
  AiService('Copilot', 'https://copilot.microsoft.com/', Color(0xFF0078D4),
      Icons.hub_outlined),
];

/// A row of assistants. [prompt] is evaluated lazily, because building it can
/// mean a database read and most taps never happen.
class AiLinks extends StatelessWidget {
  final S s;
  final Future<String> Function() prompt;

  /// Disabled while there is nothing to ask for yet.
  final bool enabled;

  const AiLinks({
    super.key,
    required this.s,
    required this.prompt,
    this.enabled = true,
  });

  Future<void> _open(BuildContext context, AiService ai) async {
    final text = await prompt();
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    showToast(context, s.t('promptCopiedOpening', {'name': ai.name}));

    final ok = await launchUrl(
      Uri.parse(ai.url),
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);

    if (!ok && context.mounted) showToast(context, s.t('openFailed'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.t('openAiTitle'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(s.t('openAiSub'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        // One row that divides the width evenly, rather than a Wrap: at 320dp
        // a fixed tile width spills the last assistant onto a line of its own.
        Row(
          children: [
            for (final ai in aiServices)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _AiButton(
                    ai: ai,
                    onTap: enabled ? () => _open(context, ai) : null,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _AiButton extends StatelessWidget {
  final AiService ai;
  final VoidCallback? onTap;
  const _AiButton({required this.ai, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: on ? 1 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: ai.color,
                child: Icon(ai.icon, size: 19, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                ai.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
