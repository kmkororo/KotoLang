/// The shape a language's translations of the samples take.
///
/// One file per language, keyed by the conversation's id, so a language can
/// be added or corrected without touching the English — and so a language
/// nobody has translated yet still plays, in English, rather than not being
/// there at all.
library;

/// One conversation's words in one language. [turns] runs in the order the
/// turns are written in `base.dart`.
class SceneText {
  final String title;

  /// Where they are. Never who the other person is — that would give the
  /// answer away before a word is said.
  final String setting;
  final List<TurnText> turns;

  const SceneText({
    required this.title,
    required this.setting,
    required this.turns,
  });
}

/// One turn's words. [replies] is **right-first**, the order the English is
/// authored in rather than the order it is shown in: the merge puts both
/// through the same shuffle, so a translation cannot drift away from the
/// reply it belongs to.
class TurnText {
  final String line;
  final List<String> replies;
  const TurnText({required this.line, required this.replies});
}
