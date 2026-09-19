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

  /// The question itself, in the one shape questions now have. Null only for
  /// a conversation kept from before, which is counted but no longer played.
  final ReplyPredict? set;

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
    this.set,
  });

  /// A set, as a scene: the reply is its one turn.
  factory Scene.ofSet({
    required String id,
    required String label,
    required ReplyPredict set,
    SceneSource source = SceneSource.ai,
    String? realmId,
    required int createdAt,
    bool disabled = false,
  }) =>
      Scene(
        id: id,
        title: label,
        titleNative: label,
        turns: [set.asTurn],
        source: source,
        realmId: realmId,
        createdAt: createdAt,
        disabled: disabled,
        set: set,
      );

  /// Whether this can be played: only sets are, now.
  bool get playable => set != null && !disabled;

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
        set: set,
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
        if (set != null) 'set': set!.toJson(),
      };

  factory Scene.fromJson(Map<String, dynamic> j) {
    final set = j['set'] is Map
        ? ReplyPredict.fromJson(Map<String, dynamic>.from(j['set'] as Map))
        : null;
    return Scene(
      id: (j['id'] ?? sceneId('${j['title']}')) as String,
      title: '${j['title'] ?? ''}',
      titleNative: '${j['title_native'] ?? ''}',
      situation: '${j['situation'] ?? ''}',
      settingNative: '${j['setting_native'] ?? ''}',
      windowMs: (j['window_ms'] as num?)?.toInt() ?? defaultWindowMs,
      turns: set != null
          ? [set.asTurn]
          : [
              for (final t in (j['turns'] as List? ?? const []))
                Turn.fromJson(Map<String, dynamic>.from(t as Map))
            ],
      source: SceneSource.parse(j['source']),
      realmId: j['realm_id'] as String?,
      createdAt: (j['created_at'] as num?)?.toInt() ?? 0,
      disabled: (j['disabled'] as bool?) ?? false,
      set: set,
    );
  }
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

// ------------------------------------------------------------------ one set
//
// The question as it is now: one set, not a conversation of turns. The other
// person says something long enough to hold four or five facts, and nothing
// of it is on screen. When they have finished, three things the learner could
// say back appear, and exactly one of them agrees with every fact. Then the
// learner guesses what comes back, from three summaries in their own
// language, and hears it.
//
// Every wrong option carries the line that says why it is wrong — which fact
// it contradicts, or what it asks that was already answered. An option with
// no such line is not a wrong option, it is a second right one, and the
// importer refuses it.

/// Where the prediction is kept among the results. The reply is turn 0; the
/// prediction is not a turn and is kept apart from them, so nothing that reads
/// the turns counts it.
const predictTurn = -1;

/// Seeds for a prediction that came true. One flat amount: there is no clock
/// on the guess, so there is nothing for speed to pay.
const predictSeeds = 20;

/// Something one of the two says, with what is needed to play it.
class Spoken {
  final String text;

  /// The same in the learner's language, shown after answering for as long
  /// as the ladder still gives it.
  final String native;

  /// The words that carry the stress. The phone taps harder on these.
  final List<String> stress;

  const Spoken({required this.text, this.native = '', this.stress = const []});

  Map<String, dynamic> toJson() => {'text': text, 'native': native, 'stress': stress};

  factory Spoken.fromJson(Map<String, dynamic> j) => Spoken(
        text: '${j['text'] ?? ''}',
        native: '${j['native'] ?? ''}',
        stress: [for (final w in (j['stress'] as List? ?? const [])) '$w'],
      );
}

/// Three options and the one that fits, each wrong one with its reason.
class SetChoice {
  final List<String> options;
  final int answer;

  /// One line per option, in the learner's language. Empty at [answer].
  final List<String> why;

  const SetChoice({required this.options, required this.answer, required this.why});

  Map<String, dynamic> toJson() => {'options': options, 'answer': answer, 'why': why};

  factory SetChoice.fromJson(Map<String, dynamic> j) => SetChoice(
        options: [for (final o in (j['options'] as List? ?? const [])) '$o'],
        answer: (j['answer'] as num?)?.toInt() ?? 0,
        why: [for (final w in (j['why'] as List? ?? const [])) '$w'],
      );

  /// The same choice with the options moved into [order], the reasons and
  /// the answer going with them.
  SetChoice arranged(List<int> order) => SetChoice(
        options: arrangeBy(order, options),
        answer: order.indexOf(answer),
        why: arrangeBy(order, why),
      );
}

class ReplyPredict {
  /// Who they are, in the learner's language: "受付". A label on the screen.
  final String partnerName;

  /// What they say first. Never on screen until it has been answered.
  final Spoken partner;

  /// The same facts in other words, for the one second hearing.
  final String paraphrase;

  /// What the learner could say back. English.
  final SetChoice reply;

  /// Which kind of catch the wrong replies are built on. Not shown; kept so
  /// the misses can be told apart.
  final TurnType trap;

  /// What comes back next, summarised in the learner's language.
  final SetChoice predict;

  /// What they actually say next.
  final Spoken response;

  const ReplyPredict({
    required this.partnerName,
    required this.partner,
    required this.paraphrase,
    required this.reply,
    this.trap = TurnType.keyword,
    required this.predict,
    required this.response,
  });

  /// The reply as a turn, so everything that reads turns — the tree, the
  /// listening feed, the coaching prompt — reads a set as one turn.
  Turn get asTurn => Turn(
        type: trap,
        line: partner.text,
        lineNative: partner.native,
        replies: [
          for (var i = 0; i < reply.options.length; i++)
            Reply(text: reply.options[i], correct: i == reply.answer)
        ],
      );

  Map<String, dynamic> toJson() => {
        'type': 'replyPredict',
        'partnerName': partnerName,
        'partner': {...partner.toJson(), 'paraphrase': paraphrase},
        'reply': {...reply.toJson(), 'trap': trap.name},
        'predict': predict.toJson(),
        'response': response.toJson(),
      };

  factory ReplyPredict.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> part(String k) =>
        j[k] is Map ? Map<String, dynamic>.from(j[k] as Map) : const <String, dynamic>{};
    final partner = part('partner');
    final reply = part('reply');
    return ReplyPredict(
      partnerName: '${j['partnerName'] ?? ''}',
      partner: Spoken.fromJson(partner),
      paraphrase: '${partner['paraphrase'] ?? ''}',
      reply: SetChoice.fromJson(reply),
      trap: TurnType.parse(reply['trap']),
      predict: SetChoice.fromJson(part('predict')),
      response: Spoken.fromJson(part('response')),
    );
  }
}

/// A word as it is compared with the stress list: letters and apostrophes
/// only, lower case.
String stressKey(String word) =>
    word.toLowerCase().replaceAll('’', "'").replaceAll(RegExp(r"[^a-z0-9'\-]"), '');

/// Whether [word] as spoken is one of [stress]: a hyphenated word counts if
/// any part of it is listed.
bool isStressed(Set<String> stress, String word) {
  final k = stressKey(word);
  if (k.isEmpty) return false;
  if (stress.contains(k)) return true;
  return k.split('-').any((p) => p.isNotEmpty && stress.contains(p));
}

/// Every word in [text], as the stress list is checked against it.
Set<String> wordsOf(String text) {
  final out = <String>{};
  for (final w in text.split(RegExp(r'\s+'))) {
    final k = stressKey(w);
    if (k.isEmpty) continue;
    out.add(k);
    out.addAll(k.split('-').where((p) => p.isNotEmpty));
  }
  return out;
}
