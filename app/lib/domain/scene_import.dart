/// Making a pasted scenes reply sound before it is stored.
///
/// The AI is told exactly what to write, and mostly does. What arrives is
/// still checked line by line: a scene with a question that has no single
/// right answer, or the wrong number of choices, would break the one promise
/// the exercise makes — that the answer is always one of three and always
/// decidable. Such a scene is set aside and named, never quietly dropped and
/// never quietly kept.
library;

import '../core/util.dart';
import 'scene.dart';

class NormalisedScenes {
  final List<Scene> scenes;
  final List<({String topic, String reason})> rejected;
  const NormalisedScenes({required this.scenes, required this.rejected});
}

/// How many choices every question has. Fixed: the screen shows three rows
/// and a swipe picks one.
const choicesPerQuestion = 3;

NormalisedScenes normaliseScenes(Map<String, dynamic> data) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final scenes = <Scene>[];
  final rejected = <({String topic, String reason})>[];
  final seen = <String>{};

  for (final raw in (data['scenes'] as List? ?? const [])) {
    if (raw is! Map) {
      rejected.add((topic: '?', reason: 'not an object'));
      continue;
    }
    final r = _normaliseScene(Map<String, dynamic>.from(raw), now);
    if (r.scene == null) {
      rejected.add((topic: r.topic, reason: r.reason ?? 'unusable'));
      continue;
    }
    // The same topic twice in one reply: the second is a repeat, not a
    // different scene. Kept once.
    if (!seen.add(r.scene!.id)) continue;
    scenes.add(r.scene!);
  }
  return NormalisedScenes(scenes: scenes, rejected: rejected);
}

({Scene? scene, String topic, String? reason}) _normaliseScene(
    Map<String, dynamic> j, int now) {
  final topic = clean(j['topic']);
  if (topic.isEmpty) return (scene: null, topic: '?', reason: 'no topic');

  final rawExchanges = j['exchanges'];
  if (rawExchanges is! List) return (scene: null, topic: topic, reason: 'no exchanges');
  if (rawExchanges.length != exchangesPerScene) {
    return (
      scene: null,
      topic: topic,
      reason: 'has ${rawExchanges.length} exchanges, needs $exchangesPerScene'
    );
  }

  final exchanges = <Exchange>[];
  for (var i = 0; i < rawExchanges.length; i++) {
    final e = rawExchanges[i];
    if (e is! Map) return (scene: null, topic: topic, reason: 'exchange ${i + 1} is not an object');
    final m = Map<String, dynamic>.from(e);
    final line = clean(m['line']);
    if (line.isEmpty) return (scene: null, topic: topic, reason: 'exchange ${i + 1} has no line');

    final gist = _normGist(m['gist']);
    if (gist == null) {
      return (scene: null, topic: topic, reason: 'exchange ${i + 1}: the gist question is not three choices with one answer');
    }
    final reply = _normReply(m['reply']);
    if (reply == null) {
      return (scene: null, topic: topic, reason: 'exchange ${i + 1}: the reply question is not three choices with one answer');
    }
    exchanges.add(Exchange(
      line: line,
      lineNative: clean(m['line_native']),
      gist: gist,
      reply: reply,
    ));
  }

  return (
    scene: Scene(
      id: sceneId(topic),
      topic: topic,
      topicNative: clean(j['topic_native']),
      settingNative: clean(j['setting_native']),
      exchanges: exchanges,
      source: SceneSource.parse(j['source']),
      realmId: clean(j['realm_id']).isEmpty ? null : clean(j['realm_id']),
      createdAt: now,
    ),
    topic: topic,
    reason: null,
  );
}

/// Exactly three non-empty, distinct options and an answer that points at one
/// of them. Anything else is not a question the app can ask.
Gist? _normGist(Object? raw) {
  if (raw is! Map) return null;
  final options = _options(raw['options']);
  final answer = _answer(raw['answer'], options?.length);
  if (options == null || answer == null) return null;
  return Gist(options: options, answer: answer);
}

Reply? _normReply(Object? raw) {
  if (raw is! Map) return null;
  final rawOptions = raw['options'];
  if (rawOptions is! List || rawOptions.length != choicesPerQuestion) return null;
  final options = <ReplyOption>[];
  for (final o in rawOptions) {
    if (o is! Map) return null;
    final text = clean(o['text']);
    if (text.isEmpty) return null;
    options.add(ReplyOption(text: text, native: clean(o['native']), why: clean(o['why'])));
  }
  if (options.map((o) => normKey(o.text)).toSet().length != choicesPerQuestion) return null;
  final answer = _answer(raw['answer'], options.length);
  if (answer == null) return null;
  return Reply(options: options, answer: answer);
}

List<String>? _options(Object? raw) {
  if (raw is! List || raw.length != choicesPerQuestion) return null;
  final out = [for (final o in raw) clean(o)];
  if (out.any((o) => o.isEmpty)) return null;
  if (out.map(normKey).toSet().length != choicesPerQuestion) return null;
  return out;
}

/// The answer as a 0-based index, as the prompt asks for it. A letter is
/// accepted too ("B" is 1) for an AI that labelled the choices instead.
int? _answer(Object? raw, int? count) {
  if (count == null) return null;
  int? i;
  if (raw is num) {
    i = raw.toInt();
  } else if (raw is String) {
    final s = raw.trim().toUpperCase();
    i = s.length == 1 && 'ABC'.contains(s) ? 'ABC'.indexOf(s) : int.tryParse(s);
  }
  if (i == null || i < 0 || i >= count) return null;
  return i;
}
