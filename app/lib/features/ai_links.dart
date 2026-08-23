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

  /// The service's own URL scheme, where it has one. Tried before the web
  /// address because a plain https link does not reliably reach the installed
  /// app: Android only routes it there while "open supported links" is on for
  /// that app, and it is off by default on a good many phones. A scheme is
  /// not subject to that setting.
  final String? scheme;

  const AiService(this.name, this.url, this.color, this.icon, {this.scheme});
}

/// Deliberately generic glyphs rather than the services' own marks: KotoLang
/// is not affiliated with any of them, and a lookalike logo would imply it is.
///
/// Schemes are only listed where the app was seen to declare one. Gemini and
/// Copilot have none, so they open on the web — which is no loss, since the
/// browser gives a full chat box to paste into.
const aiServices = <AiService>[
  AiService('ChatGPT', 'https://chatgpt.com/', Color(0xFF10A37F),
      Icons.forum_outlined, scheme: 'chatgpt'),
  AiService('Claude', 'https://claude.ai/new', Color(0xFFD97757),
      Icons.auto_awesome, scheme: 'claude'),
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

    // The installed app first, the web address second.
    final scheme = ai.scheme;
    if (scheme != null && await _launch(Uri.parse('$scheme://'))) return;
    if (await _launch(Uri.parse(ai.url))) return;

    if (context.mounted) showToast(context, s.t('openFailed'));
  }

  /// True only if something actually opened. `canLaunchUrl` is asked first so
  /// that a scheme nobody handles — the app simply is not installed — falls
  /// through to the web address instead of surfacing an error.
  Future<bool> _launch(Uri uri) async {
    try {
      if (!await canLaunchUrl(uri)) return false;
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
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
