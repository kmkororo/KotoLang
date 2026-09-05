/// A scene: two exchanges with someone, each answered by two three-way
/// choices — what did they say, and how do you reply.
///
/// Nothing here judges. Every question carries exactly one right answer,
/// decided by the material itself (the two wrong ones are what someone who
/// misheard would pick), so the app only has to compare indexes. The learner's
/// own AI writes scenes in the pack format below; the built-in scenes ship in
/// the same shape.
library;

import '../core/util.dart';

/// Where a scene came from. Built-ins are the samples that ship with the app;
/// only scenes the learner's own AI made make the tree bloom.
enum SceneSource {
  builtin,
  ai;

  static SceneSource parse(Object? s) =>
      '$s'.trim().toLowerCase() == 'builtin' ? SceneSource.builtin : SceneSource.ai;
}

/// "What did they say?" — three English summaries of the line, each with its
/// translation for the moment after the answer.
class Gist {
  final List<String> options;

  /// Translations of [options], same order; empty when the interface language
  /// is English or an older scene carried none.
  final List<String> natives;
  final int answer;
  const Gist({required this.options, this.natives = const [], required this.answer});

  String get correct => options[answer];
  String nativeOf(int i) => i < natives.length ? natives[i] : '';

  Map<String, dynamic> toJson() => {
        'options': [
          for (var i = 0; i < options.length; i++) {'text': options[i], 'native': nativeOf(i)}
        ],
        'answer': answer,
      };

  /// Reads both shapes: plain strings (the 3.0 packs) and {text, native}.
  factory Gist.fromJson(Map<String, dynamic> j) {
    final raw = (j['options'] as List?) ?? const [];
    final texts = <String>[];
    final natives = <String>[];
    for (final o in raw) {
      if (o is Map) {
        texts.add('${o['text'] ?? ''}');
        natives.add('${o['native'] ?? ''}');
      } else {
        texts.add('$o');
      }
    }
    return Gist(
      options: texts,
      natives: natives.length == texts.length ? natives : const [],
      answer: (j['answer'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The order the three choices of one question are shown in: a small
/// deterministic hash of where the question sits, so the right answer is
/// spread across the positions and nobody — not the author, not the AI — has
/// to think about where it lands. `order[k]` is the authored index shown at
/// position k.
List<int> optionOrder(String sceneId, int exchange, String question) {
  const orders = [
    [0, 1, 2],
    [0, 2, 1],
    [1, 0, 2],
    [1, 2, 0],
    [2, 0, 1],
    [2, 1, 0],
  ];
  var h = 0;
  for (final c in '$sceneId/$exchange/$question'.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return orders[h % orders.length];
}

List<T> arrangeBy<T>(List<int> order, List<T> authored) =>
    authored.length == order.length ? [for (final k in order) authored[k]] : authored;

/// One possible reply: the English, its translation, and why it is or is not
/// the one.
class ReplyOption {
  final String text;
  final String native;
  final String why;
  const ReplyOption({required this.text, this.native = '', this.why = ''});

  Map<String, dynamic> toJson() => {'text': text, 'native': native, 'why': why};

  factory ReplyOption.fromJson(Map<String, dynamic> j) => ReplyOption(
        text: (j['text'] ?? '') as String,
        native: (j['native'] ?? '') as String,
        why: (j['why'] ?? '') as String,
      );
}

/// "How do you reply?" — three English replies, one of which answers what was
/// actually said.
class Reply {
  final List<ReplyOption> options;
  final int answer;
  const Reply({required this.options, required this.answer});

  ReplyOption get correct => options[answer];

  Map<String, dynamic> toJson() =>
      {'options': [for (final o in options) o.toJson()], 'answer': answer};

  factory Reply.fromJson(Map<String, dynamic> j) => Reply(
        options: [
          for (final o in (j['options'] as List? ?? const []))
            ReplyOption.fromJson(Map<String, dynamic>.from(o as Map))
        ],
        answer: (j['answer'] as num?)?.toInt() ?? 0,
      );
}

/// One line from the other person and the two questions about it.
class Exchange {
  final String line;
  final String lineNative;
  final Gist gist;
  final Reply reply;

  const Exchange({
    required this.line,
    required this.lineNative,
    required this.gist,
    required this.reply,
  });

  Map<String, dynamic> toJson() => {
        'line': line,
        'line_native': lineNative,
        'gist': gist.toJson(),
        'reply': reply.toJson(),
      };

  factory Exchange.fromJson(Map<String, dynamic> j) => Exchange(
        line: (j['line'] ?? '') as String,
        lineNative: (j['line_native'] ?? '') as String,
        gist: Gist.fromJson(Map<String, dynamic>.from((j['gist'] as Map?) ?? const {})),
        reply: Reply.fromJson(Map<String, dynamic>.from((j['reply'] as Map?) ?? const {})),
      );
}

/// How many exchanges a scene has. The prompt asks for exactly this many and
/// the importer refuses anything else, so a scene is always the same length.
const exchangesPerScene = 2;

class Scene {
  final String id;
  final String topic;
  final String topicNative;

  /// One line of setting in the learner's language ("at the hotel desk").
  /// Never who the other person is — that would be a hint.
  final String settingNative;
  final List<Exchange> exchanges;
  final SceneSource source;
  final String? realmId;
  final int createdAt;
  final bool disabled;

  const Scene({
    required this.id,
    required this.topic,
    required this.topicNative,
    this.settingNative = '',
    required this.exchanges,
    this.source = SceneSource.ai,
    this.realmId,
    required this.createdAt,
    this.disabled = false,
  });

  /// The label shown to the learner: their language first.
  String get label => topicNative.isNotEmpty ? topicNative : topic;

  bool get isBuiltin => source == SceneSource.builtin;

  Scene copyWith({bool? disabled, String? realmId}) => Scene(
        id: id,
        topic: topic,
        topicNative: topicNative,
        settingNative: settingNative,
        exchanges: exchanges,
        source: source,
        realmId: realmId ?? this.realmId,
        createdAt: createdAt,
        disabled: disabled ?? this.disabled,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic': topic,
        'topic_native': topicNative,
        'setting_native': settingNative,
        'exchanges': [for (final e in exchanges) e.toJson()],
        'source': source.name,
        'realm_id': realmId,
        'created_at': createdAt,
        'disabled': disabled,
      };

  factory Scene.fromJson(Map<String, dynamic> j) => Scene(
        id: (j['id'] ?? sceneId('${j['topic']}')) as String,
        topic: (j['topic'] ?? '') as String,
        topicNative: (j['topic_native'] ?? '') as String,
        settingNative: (j['setting_native'] ?? '') as String,
        exchanges: [
          for (final e in (j['exchanges'] as List? ?? const []))
            Exchange.fromJson(Map<String, dynamic>.from(e as Map))
        ],
        source: SceneSource.parse(j['source']),
        realmId: j['realm_id'] as String?,
        createdAt: (j['created_at'] as num?)?.toInt() ?? 0,
        disabled: (j['disabled'] as bool?) ?? false,
      );
}

/// Content-derived id, so the same scene pasted twice lands on itself — and
/// two different scenes that happen to share a topic name do not: the first
/// line tells them apart.
String sceneId(String topic, [String firstLine = '']) => slugId(
    'scn', firstLine.isEmpty ? normKey(topic) : '${normKey(topic)}|${normKey(firstLine)}');

/// One exchange answered. The unit every number in the app is read from.
class SceneResult {
  final String sceneId;
  final int exchange;
  final bool gistOk;
  final bool replyOk;

  /// The words were shown before the gist was answered. Understanding by ear
  /// is only claimed when this is false.
  final bool peeked;

  /// Came up as a review, not inside its scene.
  final bool review;
  final String day;
  final int at;

  const SceneResult({
    required this.sceneId,
    required this.exchange,
    required this.gistOk,
    required this.replyOk,
    this.peeked = false,
    this.review = false,
    required this.day,
    required this.at,
  });
}

/// An exchange owed another look.
class ReviewItem {
  final String sceneId;
  final int exchange;
  final String dueDay;

  /// 0 = due the next day, 1 = due three days on. Past that it is dropped.
  final int stage;
  const ReviewItem({
    required this.sceneId,
    required this.exchange,
    required this.dueDay,
    required this.stage,
  });
}

/// The gaps, in days, between a miss and its reviews. Two looks: the next
/// day, then three days after that. Answer both right and it is gone.
const reviewGaps = [1, 3];
