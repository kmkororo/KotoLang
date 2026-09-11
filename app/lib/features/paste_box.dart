/// The text box every AI reply arrives through, and the piece-by-piece
/// collection that makes it workable on a phone.
///
/// A phone chat app will not let you drag a selection over ten thousand
/// characters, and the copy button sometimes yields only part of a long reply.
/// So the box accepts the reply in as many goes as it takes: paste what you
/// managed to get, add it, copy the rest, add that. Overlapping selections are
/// reconciled rather than duplicated, and after every piece the box says how
/// much of the material it can actually read, so nobody has to guess whether
/// the paste worked until the very end.
library;

import 'package:flutter/material.dart';

import '../core/l10n/strings.dart';
import '../domain/importer.dart' as imp;

/// Holds the text collected so far. The parent screen owns one of these and
/// reads [text] when the learner asks to import.
class PasteController extends ChangeNotifier {
  final field = TextEditingController();
  String _buffer = '';
  imp.ImportPreview preview = imp.ImportPreview.none;

  PasteController() {
    field.addListener(_onFieldChanged);
  }

  /// Everything collected: the added pieces plus whatever is still in the box,
  /// so a single ordinary paste needs no extra tap.
  String get text => imp.appendPiece(_buffer, field.text);

  bool get isEmpty => text.trim().isEmpty;
  bool get hasBuffer => _buffer.trim().isNotEmpty;

  bool get fieldHasText => field.text.trim().isNotEmpty;
  String? _lastPreviewed;

  /// What the box held last time it changed, so a wholesale replacement can be
  /// told apart from ordinary editing.
  String _lastField = '';

  void _onFieldChanged() {
    final now = field.text;
    final was = _lastField;
    _lastField = now;

    // A second paste over the top of a long first one is the phone case: the
    // reply could not be selected in one go, so it arrives in halves. Keeping
    // the earlier half means nobody has to press a button to say "there is
    // more coming" — a button that read almost exactly like the import one
    // and was taken for it.
    //
    // Editing is left alone: growing the text, or cutting it back, both leave
    // one string a prefix of the other.
    if (was.length > 40 &&
        now.trim().isNotEmpty &&
        !now.startsWith(was) &&
        !was.startsWith(now)) {
      _buffer = imp.appendPiece(_buffer, was);
    }
    _refresh();
  }

  /// Folds whatever is in the box into the collected text. The box does this
  /// by itself now; kept for callers that need it explicitly.
  void addPiece() {
    if (!fieldHasText) return;
    _buffer = imp.appendPiece(_buffer, field.text);
    _lastField = '';
    field.clear(); // also fires the listener, which refreshes the preview
    _refresh();
  }

  void clear() {
    _buffer = '';
    _lastField = '';
    field.clear();
    _refresh();
  }

  /// Re-reads the collected text. Skipped when nothing actually changed, since
  /// the field notifies on cursor movement as well as on edits.
  void _refresh() {
    final t = text;
    if (t == _lastPreviewed) return;
    _lastPreviewed = t;
    preview = t.trim().isEmpty ? imp.ImportPreview.none : imp.previewImport(t);
    notifyListeners();
  }

  @override
  void dispose() {
    field.removeListener(_onFieldChanged);
    field.dispose();
    super.dispose();
  }
}

class PasteBox extends StatelessWidget {
  final PasteController controller;
  final S s;

  /// 'material' expects sentences, 'profile' expects areas. Only changes which
  /// count is reported.
  final String expecting;

  const PasteBox({
    super.key,
    required this.controller,
    required this.s,
    this.expecting = 'material',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final p = controller.preview;
        final chars = controller.text.length;

        final status = switch (expecting) {
          'profile' => s.t('collectedRealms', {'chars': _n(chars), 'n': p.realms}),
          'scenes' => s.t('collectedScenes', {'chars': _n(chars), 'n': p.scenes}),
          _ => s.t('collectedScenes', {'chars': _n(chars), 'n': p.scenes}),
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller.field,
              // Deliberately short. The reply comes in through the clipboard
              // now, so this box is a place to check what arrived rather than
              // a place to read it — and a tall text field on a scrolling page
              // swallows the scroll.
              maxLines: 3,
              minLines: 2,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(hintText: s.t('pastePlaceholder')),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (chars > 0)
                  TextButton(
                    onPressed: controller.clear,
                    child: Text(s.t('clearPaste')),
                  ),
              ],
            ),
            if (chars > 0) ...[
              const SizedBox(height: 4),
              Text(
                status,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: p.ok
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: p.ok ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
            if (p.repaired) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.content_cut, size: 16, color: theme.colorScheme.tertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s.t('truncatedNotice'),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.tertiary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// A card explaining how to get a long reply out of a phone chat app. Shown
/// beside every paste box, because this is the one step where people get stuck.
class CopyTip extends StatelessWidget {
  final S s;
  const CopyTip(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(s.t('copyTipTitle'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            Text(s.t('copyTipBody'), style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Thousands separator, so a character count reads as a size rather than as a
/// wall of digits.
String _n(int v) {
  final digits = '$v';
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}
