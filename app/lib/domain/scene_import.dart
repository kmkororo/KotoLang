/// Making a pasted reply sound before it is stored.
///
/// The AI is told exactly what to write, and mostly does. What arrives is
/// still checked turn by turn: a turn with no single right reply, or with the
/// wrong number of them, would break the one promise the exercise makes —
/// that exactly one of three fits, and that only the sound of the line says
/// which. Such a conversation is set aside and named, never quietly dropped
/// and never quietly kept.
library;

import '../core/util.dart';
import 'scene.dart';

class NormalisedScenes {
  final List<Scene> scenes;
  final List<({String title, String reason})> rejected;
  const NormalisedScenes({required this.scenes, required this.rejected});
}

NormalisedScenes normaliseScenes(Map<String, dynamic> data) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final scenes = <Scene>[];
  final rejected = <({String title, String reason})>[];
  final seen = <String>{};

  for (final raw in (data['scenes'] as List? ?? const [])) {
    if (raw is! Map) {
      rejected.add((title: '?', reason: 'not an object'));
      continue;
    }
    final r = _normaliseScene(Map<String, dynamic>.from(raw), now);
    if (r.scene == null) {
      rejected.add((title: r.title, reason: r.reason ?? 'unusable'));
      continue;
    }
    // The same conversation twice in one reply is a repeat, not a second
    // conversation. Kept once.
    if (!seen.add(r.scene!.id)) continue;
    scenes.add(r.scene!);
  }
  return NormalisedScenes(scenes: scenes, rejected: rejected);
}

({Scene? scene, String title, String? reason}) _normaliseScene(
    Map<String, dynamic> j, int now) {
  final title = clean(j['title'] ?? j['topic']);
  if (title.isEmpty) return (scene: null, title: '?', reason: 'no title');

  final rawTurns = (j['turns'] as List?) ?? const [];
  if (rawTurns.isEmpty) {
    return (scene: null, title: title, reason: 'no turns');
  }
  if (rawTurns.length > maxTurnsPerScene) {
    return (
      scene: null,
      title: title,
      reason: 'has ${rawTurns.length} turns, at most $maxTurnsPerScene'
    );
  }

  // The id comes from the title and the first line together, so two
  // conversations that share a title still land apart.
  final firstLine = rawTurns.first is Map
      ? clean((rawTurns.first as Map)['line'])
      : '';
  final id = sceneId(title, firstLine);

  final turns = <Turn>[];
  for (var i = 0; i < rawTurns.length; i++) {
    final raw = rawTurns[i];
    if (raw is! Map) {
      return (scene: null, title: title, reason: 'turn ${i + 1} is not an object');
    }
    final t = _normTurn(Map<String, dynamic>.from(raw), id, i);
    if (t.turn == null) {
      return (scene: null, title: title, reason: 'turn ${i + 1}: ${t.reason}');
    }
    turns.add(t.turn!);
  }

  // A title in the learner's language that is barely there is no use as a
  // label; the English one is better than a stub.
  final native = clean(j['title_native'] ?? j['titleNative']);

  final window = (j['window_ms'] ?? j['windowMs']) as num?;
  return (
    scene: Scene(
      id: id,
      title: title,
      titleNative: native.length < 2 ? title : native,
      situation: clean(j['situation']),
      settingNative: clean(j['setting_native'] ?? j['settingNative']),
      windowMs: window == null
          ? defaultWindowMs
          : window.toInt().clamp(minWindowMs, maxWindowMs),
      turns: turns,
      createdAt: now,
    ),
    title: title,
    reason: null
  );
}

({Turn? turn, String? reason}) _normTurn(Map<String, dynamic> j, String id, int index) {
  final line = clean(j['line']);
  if (line.isEmpty) return (turn: null, reason: 'no line');

  final rawReplies = (j['replies'] as List?) ?? const [];
  if (rawReplies.length != repliesPerTurn) {
    return (turn: null, reason: 'has ${rawReplies.length} replies, needs $repliesPerTurn');
  }

  final authored = <Reply>[];
  for (final raw in rawReplies) {
    if (raw is! Map) return (turn: null, reason: 'a reply is not an object');
    final text = clean(raw['text']);
    if (text.isEmpty) return (turn: null, reason: 'a reply has no text');
    authored.add(Reply(
      text: text,
      native: clean(raw['native']),
      correct: raw['correct'] == true,
      missedSlot: raw['missedSlot'] == null ? null : clean(raw['missedSlot']),
    ));
  }

  // Exactly one right answer. None and the turn cannot be marked; two and it
  // is not a question.
  final right = authored.where((r) => r.correct).length;
  if (right != 1) {
    return (turn: null, reason: right == 0 ? 'no right reply' : '$right right replies');
  }

  // The AI is told to write the right reply first, so without this it would
  // always be first. The order comes from the conversation's own id, so every
  // device and every language agrees on where it ended up.
  final replies = arrangeBy(optionOrder(id, index), authored);

  final type = TurnType.parse(j['type']);
  final facts = [
    for (final f in (j['facts'] as List? ?? const []))
      if (f is Map) Fact.fromJson(Map<String, dynamic>.from(f))
  ];
  if (type == TurnType.multiFact) {
    if (facts.length < 2) {
      return (turn: null, reason: 'multiFact needs two facts');
    }
    // Each wrong reply names the fact it dropped, and names one that exists.
    // Without that a wrong answer says nothing about what went wrong.
    final slots = {for (final f in facts) f.slot};
    for (final r in replies) {
      if (r.correct) continue;
      final slot = r.missedSlot;
      if (slot == null || !slots.contains(slot)) {
        return (turn: null, reason: 'a wrong reply names no fact it missed');
      }
    }
  }

  final native = j['translations'] is Map
      ? Map<String, dynamic>.from(j['translations'] as Map)
      : const <String, dynamic>{};
  final lineNative = clean(j['line_native'] ?? native['line']);

  // Translations arrive alongside what the author wrote, so they are put on
  // the replies before the shuffle is applied — never after.
  final rawNatives = (native['replies'] as List?) ?? const [];
  final withNatives = rawNatives.length == repliesPerTurn
      ? arrangeBy(
          optionOrder(id, index),
          [
            for (var i = 0; i < authored.length; i++)
              Reply(
                text: authored[i].text,
                native: authored[i].native.isNotEmpty
                    ? authored[i].native
                    : clean(rawNatives[i]),
                correct: authored[i].correct,
                missedSlot: authored[i].missedSlot,
              )
          ],
        )
      : replies;

  return (
    turn: Turn(
      type: type,
      line: line,
      lineNative: lineNative,
      keyWord: clean(j['keyWord'] ?? j['key_word']),
      confusable: clean(j['confusable']),
      facts: facts,
      replies: withNatives,
    ),
    reason: null
  );
}
