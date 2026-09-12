/// A conversation: someone speaks, and you have a moment to reply.
///
/// The three replies are read *before* the line is played, so reading them is
/// not part of the listening. Only the sound of the line decides which one
/// fits: all three are things a person could say here, and the right one
/// turns on a word the ear has to catch. Nothing here judges — the material
/// carries its own answer and the app compares indexes.
library;

import '../core/util.dart';

/// Where a scene came from. Built-ins are the samples that ship with the app.
enum SceneSource {
  builtin,
  ai;

  static SceneSource parse(Object? s) =>
      '$s'.trim().toLowerCase() == 'builtin' ? SceneSource.builtin : SceneSource.ai;
}

/// What the ear has to catch for this turn. The three are mixed through a
/// set: they are not difficulty, they are variety. Difficulty lives in the
/// audio — speed, noise, accent — never in the shape of the question.
enum TurnType {
  /// One word decides, and a word that sounds like it would change the
  /// meaning. Twelve and twenty, Tuesday and Thursday.
  keyword,

  /// A reversing word decides: not, can't, unless, without, hardly. Miss it
  /// and the meaning flips, which is where mishearing costs the most.
  polarity,

  /// Two facts have to be held at once — a time and a place, a day and a
  /// person. Each wrong reply drops exactly one of them and says which.
  multiFact;

  static TurnType parse(Object? s) => switch ('$s'.trim().toLowerCase()) {
        'polarity' => TurnType.polarity,
        'multifact' => TurnType.multiFact,
        _ => TurnType.keyword,
      };
}

/// One of the two things a [TurnType.multiFact] line asks the listener to
/// hold: what it was, and what someone who lost it would have heard instead.
class Fact {
  final String slot;
  final String value;
  final String confusable;
  const Fact({required this.slot, required this.value, this.confusable = ''});

  Map<String, dynamic> toJson() => {'slot': slot, 'value': value, 'confusable': confusable};

  factory Fact.fromJson(Map<String, dynamic> j) => Fact(
        slot: '${j['slot'] ?? ''}',
        value: '${j['value'] ?? ''}',
        confusable: '${j['confusable'] ?? ''}',
      );
}

/// One of the three things the learner can say back.
class Reply {
  final String text;

  /// The same reply in the learner's language, shown only after answering.
  final String native;
  final bool correct;

  /// For [TurnType.multiFact]: which fact this reply dropped. A wrong answer
  /// then names the weakness, and the same one can be practised again.
  final String? missedSlot;

  const Reply({
    required this.text,
    this.native = '',
    this.correct = false,
    this.missedSlot,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'native': native,
        'correct': correct,
        if (missedSlot != null) 'missedSlot': missedSlot,
      };

  factory Reply.fromJson(Map<String, dynamic> j) => Reply(
        text: '${j['text'] ?? ''}',
        native: '${j['native'] ?? ''}',
        correct: j['correct'] == true,
        missedSlot: j['missedSlot'] == null ? null : '${j['missedSlot']}',
      );
}

/// One turn: their line, and the three replies that were on screen before it
/// played.
class Turn {
  final TurnType type;
  final String line;

  /// The line in the learner's language, shown only after answering.
  final String lineNative;

  /// The word the turn hangs on, and the word it could be taken for. What the
  /// material was built around, and what an import can be checked against.
  final String keyWord;
  final String confusable;

  /// For [TurnType.multiFact] only.
  final List<Fact> facts;

  final List<Reply> replies;


  const Turn({
    this.type = TurnType.keyword,
    required this.line,
    this.lineNative = '',
    this.keyWord = '',
    this.confusable = '',
    this.facts = const [],
    required this.replies,
  });

  /// Where the right reply sits. Always exactly one.
  int get answer {
    final i = replies.indexWhere((r) => r.correct);
    return i < 0 ? 0 : i;
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'line': line,
        'line_native': lineNative,
        'keyWord': keyWord,
        'confusable': confusable,
        if (facts.isNotEmpty) 'facts': [for (final f in facts) f.toJson()],
        'replies': [for (final r in replies) r.toJson()],
      };

  factory Turn.fromJson(Map<String, dynamic> j) => Turn(
        type: TurnType.parse(j['type']),
        line: '${j['line'] ?? ''}',
        lineNative: '${j['line_native'] ?? ''}',
        keyWord: '${j['keyWord'] ?? ''}',
        confusable: '${j['confusable'] ?? ''}',
        facts: [
          for (final f in (j['facts'] as List? ?? const []))
            Fact.fromJson(Map<String, dynamic>.from(f as Map))
        ],
        replies: [
          for (final r in (j['replies'] as List? ?? const []))
            Reply.fromJson(Map<String, dynamic>.from(r as Map))
        ],
      );
}

/// How many replies every turn offers. Three, always: two would make guessing
/// cheap and four would make reading them the slow part.
const repliesPerTurn = 3;

/// The longest a conversation runs. A short one is a word in a corridor, a
/// long one a call about a change of plan; the learner is never told which
/// they are in.
const maxTurnsPerScene = 5;

/// How long the reply window stays open when the material does not say.
const defaultWindowMs = 3000;
const minWindowMs = 1200;
const maxWindowMs = 8000;

class Scene {
  final String id;
  final String title;
  final String titleNative;

  /// The situation inside a field — "meetings" inside "work". The unit that
  /// opens as the ladder is climbed.
  final String situation;

  /// One line of setting in the learner's language ("at the hotel desk").
  /// Never who the other person is — that would be a hint.
  final String settingNative;

  /// How long the learner has to reply once the line ends. Carried by the
  /// scene rather than fixed, because the gap between turns is what a
  /// conversation is made of: a hurried exchange leaves less of it.
  final int windowMs;

  final List<Turn> turns;
  final SceneSource source;
  final String? realmId;
  final int createdAt;
  final bool disabled;

  const Scene({
    required this.id,
    required this.title,
    this.titleNative = '',
    this.situation = '',
    this.settingNative = '',
    this.windowMs = defaultWindowMs,
    required this.turns,
    this.source = SceneSource.ai,
    this.realmId,
    required this.createdAt,
    this.disabled = false,
  });

  /// The label shown to the learner: their language first.
  String get label => titleNative.isNotEmpty ? titleNative : title;

  bool get isBuiltin => source == SceneSource.builtin;

  Scene copyWith({bool? disabled, String? realmId, String? situation}) => Scene(
        id: id,
        title: title,
        titleNative: titleNative,
        situation: situation ?? this.situation,
        settingNative: settingNative,
        windowMs: windowMs,
        turns: turns,
        source: source,
        realmId: realmId ?? this.realmId,
        createdAt: createdAt,
        disabled: disabled ?? this.disabled,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'title_native': titleNative,
        'situation': situation,
        'setting_native': settingNative,
        'window_ms': windowMs,
        'turns': [for (final t in turns) t.toJson()],
        'source': source.name,
        'realm_id': realmId,
        'created_at': createdAt,
        'disabled': disabled,
      };

  factory Scene.fromJson(Map<String, dynamic> j) => Scene(
        id: (j['id'] ?? sceneId('${j['title']}')) as String,
        title: '${j['title'] ?? ''}',
        titleNative: '${j['title_native'] ?? ''}',
        situation: '${j['situation'] ?? ''}',
        settingNative: '${j['setting_native'] ?? ''}',
        windowMs: (j['window_ms'] as num?)?.toInt() ?? defaultWindowMs,
        turns: [
          for (final t in (j['turns'] as List? ?? const []))
            Turn.fromJson(Map<String, dynamic>.from(t as Map))
        ],
        source: SceneSource.parse(j['source']),
        realmId: j['realm_id'] as String?,
        createdAt: (j['created_at'] as num?)?.toInt() ?? 0,
        disabled: (j['disabled'] as bool?) ?? false,
      );
}

/// Content-derived id, so the same conversation pasted twice lands on itself
/// — and two that happen to share a title do not: the first line tells them
/// apart.
String sceneId(String title, [String firstLine = '']) =>
    slugId('scene', firstLine.isEmpty ? title : '$title|$firstLine');

/// Where the right reply sits, decided by the material's own id rather than
/// by chance, so it is the same on every device and in every language — and
/// so an author never has to think about position.
///
/// The AI is told to write the right reply first. Without this it would
/// always be first.
List<int> optionOrder(String sceneId, int turn) {
  final order = [for (var i = 0; i < repliesPerTurn; i++) i];
  var h = 0;
  for (final code in '$sceneId#$turn'.codeUnits) {
    h = (h * 31 + code) & 0x7fffffff;
  }
  // Fisher-Yates, driven by the hash rather than a random source.
  for (var i = order.length - 1; i > 0; i--) {
    h = (h * 1103515245 + 12345) & 0x7fffffff;
    final j = h % (i + 1);
    final tmp = order[i];
    order[i] = order[j];
    order[j] = tmp;
  }
  return order;
}

/// Applies an [optionOrder] to what the author wrote.
List<T> arrangeBy<T>(List<int> order, List<T> authored) =>
    [for (final i in order) authored[i]];

/// One turn answered.
class TurnResult {
  final String sceneId;
  final int turn;
  final bool correct;

  /// For a missed [TurnType.multiFact]: the fact that was dropped.
  final String? missedSlot;

  /// Answered inside the window, without waiting for the line to be said
  /// again. Keeping up at conversation speed is only claimed when true.
  final bool inWindow;

  /// Came up as a review rather than inside its conversation.
  final bool review;

  final String day;
  final int at;

  const TurnResult({
    required this.sceneId,
    required this.turn,
    required this.correct,
    this.missedSlot,
    this.inWindow = true,
    this.review = false,
    required this.day,
    required this.at,
  });
}

/// A turn that was missed and is owed another look: the next day, then three
/// days on, then gone.
class ReviewItem {
  final String sceneId;
  final int turn;
  final String dueDay;
  final int stage;
  const ReviewItem({
    required this.sceneId,
    required this.turn,
    required this.dueDay,
    this.stage = 0,
  });
}

const reviewGaps = [1, 3];
