/// Plain domain entities. These are storage-agnostic: the Drift layer maps to
/// and from them, and every service works with these types only.
library;

import '../core/util.dart';

// ---------------------------------------------------------------- profile

class UserProfile {
  final String englishLevel; // A1..C2 or UNKNOWN
  final double levelConfidence;
  final List<String> roles;
  final List<String> learningPriorities;
  final String notes;

  const UserProfile({
    this.englishLevel = 'UNKNOWN',
    this.levelConfidence = 0.5,
    this.roles = const [],
    this.learningPriorities = const [],
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'english_level': englishLevel,
        'level_confidence': levelConfidence,
        'roles': roles,
        'learning_priorities': learningPriorities,
        'notes': notes,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        englishLevel: (j['english_level'] ?? 'UNKNOWN') as String,
        levelConfidence: (j['level_confidence'] as num?)?.toDouble() ?? 0.5,
        roles: (j['roles'] as List?)?.cast<String>() ?? const [],
        learningPriorities:
            (j['learning_priorities'] as List?)?.cast<String>() ?? const [],
        notes: (j['notes'] ?? '') as String,
      );
}

// ---------------------------------------------------------------- realm

/// One area of the learner's life. The app's namesake: a person has several.
class Realm {
  final String id;
  final String name;
  final String nameNative;
  final String normKeyValue;
  final int importance; // 1..5, how much this area's English is worth learning
  final double confidence;
  final List<String> contexts;
  final bool selected;
  final bool hasMaterial;

  const Realm({
    required this.id,
    required this.name,
    this.nameNative = '',
    required this.normKeyValue,
    this.importance = 3,
    this.confidence = 0.5,
    this.contexts = const [],
    this.selected = false,
    this.hasMaterial = false,
  });

  String get label => nameNative.isNotEmpty ? nameNative : name;

  Realm copyWith({
    String? nameNative,
    int? importance,
    double? confidence,
    List<String>? contexts,
    bool? selected,
    bool? hasMaterial,
  }) =>
      Realm(
        id: id,
        name: name,
        nameNative: nameNative ?? this.nameNative,
        normKeyValue: normKeyValue,
        importance: importance ?? this.importance,
        confidence: confidence ?? this.confidence,
        contexts: contexts ?? this.contexts,
        selected: selected ?? this.selected,
        hasMaterial: hasMaterial ?? this.hasMaterial,
      );
}

// ---------------------------------------------------------------- material

/// A single expression worth learning. This, not the question, is what the
/// review schedule tracks.
class LearningItem {
  final String id;
  final String text;
  final String normKeyValue;
  final String type; // term | phrase | collocation | expression
  final String meaningNative;
  final int priority;
  final double confidence;
  final List<String> relatedTerms;
  final List<String> contexts;
  final List<String> distractorsNative;
  final List<String> realmIds; // one concept may serve several realms
  final bool disabled;

  const LearningItem({
    required this.id,
    required this.text,
    required this.normKeyValue,
    this.type = 'term',
    this.meaningNative = '',
    this.priority = 3,
    this.confidence = 0.7,
    this.relatedTerms = const [],
    this.contexts = const [],
    this.distractorsNative = const [],
    this.realmIds = const [],
    this.disabled = false,
  });

  LearningItem copyWith({
    String? meaningNative,
    int? priority,
    List<String>? relatedTerms,
    List<String>? distractorsNative,
    List<String>? realmIds,
    bool? disabled,
  }) =>
      LearningItem(
        id: id,
        text: text,
        normKeyValue: normKeyValue,
        type: type,
        meaningNative: meaningNative ?? this.meaningNative,
        priority: priority ?? this.priority,
        confidence: confidence,
        relatedTerms: relatedTerms ?? this.relatedTerms,
        contexts: contexts,
        distractorsNative: distractorsNative ?? this.distractorsNative,
        realmIds: realmIds ?? this.realmIds,
        disabled: disabled ?? this.disabled,
      );
}

class Sentence {
  final String id;
  final String text;
  final String normKeyValue;
  final String translationNative;
  final String level;
  final String context;
  final String speechAct;
  final int naturalness;
  final int? quality; // set by the optional audit pass
  final String realmId;
  final List<String> itemIds;

  /// Near-miss Japanese readings, used by the gist question.
  final List<String> meaningOptionsNative;

  /// An English restatement plus near-miss English options, used by the
  /// paraphrase question.
  final String paraphraseEn;
  final List<String> paraphraseOptionsEn;

  /// What the other person says that this sentence answers, and its reading.
  /// Empty when the sentence opens an exchange rather than replying to one —
  /// in which case no `reply` question can be built from it.
  final String cueEn;
  final String cueTranslationNative;

  /// Replies that sound plausible but are the wrong move. Optional: without
  /// them the generator falls back to other sentences in the same realm.
  final List<String> replyDistractorsEn;

  /// The same intent said several ways, for the `register` question: which
  /// phrasing fits this relationship. [registerCorrect] indexes the one that
  /// does; [registerWhyNative] explains each, in the learner's language.
  final String registerSituationNative;
  final List<String> registerOptionsEn;
  final List<String> registerWhyNative;
  final int registerCorrect;

  final bool disabled;

  const Sentence({
    required this.id,
    required this.text,
    required this.normKeyValue,
    this.translationNative = '',
    this.level = 'B1',
    this.context = '',
    this.speechAct = 'statement',
    this.naturalness = 4,
    this.quality,
    required this.realmId,
    this.itemIds = const [],
    this.meaningOptionsNative = const [],
    this.paraphraseEn = '',
    this.paraphraseOptionsEn = const [],
    this.cueEn = '',
    this.cueTranslationNative = '',
    this.replyDistractorsEn = const [],
    this.registerSituationNative = '',
    this.registerOptionsEn = const [],
    this.registerWhyNative = const [],
    this.registerCorrect = -1,
    this.disabled = false,
  });

  Sentence copyWith({int? quality, bool? disabled, List<String>? itemIds}) => Sentence(
        id: id,
        text: text,
        normKeyValue: normKeyValue,
        translationNative: translationNative,
        level: level,
        context: context,
        speechAct: speechAct,
        naturalness: naturalness,
        quality: quality ?? this.quality,
        realmId: realmId,
        itemIds: itemIds ?? this.itemIds,
        meaningOptionsNative: meaningOptionsNative,
        paraphraseEn: paraphraseEn,
        paraphraseOptionsEn: paraphraseOptionsEn,
        cueEn: cueEn,
        cueTranslationNative: cueTranslationNative,
        replyDistractorsEn: replyDistractorsEn,
        registerSituationNative: registerSituationNative,
        registerOptionsEn: registerOptionsEn,
        registerWhyNative: registerWhyNative,
        registerCorrect: registerCorrect,
        disabled: disabled ?? this.disabled,
      );
}

// ---------------------------------------------------------------- questions

enum QuestionType {
  /// Which English sentence says the same thing? Comprehension, and the
  /// options themselves add vocabulary.
  paraphrase,

  /// Which Japanese reading matches? Catches meaning errors precisely.
  gist,

  /// Build the target expression from word tiles. Production.
  dictation,

  /// Rebuild the whole sentence from word tiles. Production.
  reorder,

  /// Say it from the meaning alone — no audio until after the answer.
  ///
  /// Every other format plays the English first and asks the learner to
  /// recognise or rebuild it, which is not what happens in a conversation.
  /// Here the only cue is what you want to say, which is the direction
  /// speaking actually runs in. Production, and the strongest of them.
  produce,

  /// Someone says something to you. Which reply is the right move?
  ///
  /// The one format about choosing *what to say* rather than understanding
  /// what was said. Recognition, so it does not satisfy the mastery gate.
  reply,

  /// The same thing said several ways: which one fits this relationship?
  /// Politeness is the part of English that fails silently. Recognition.
  register;

  static QuestionType? parse(String s) {
    for (final t in QuestionType.values) {
      if (t.name == s) return t;
    }
    return null;
  }
}

/// Formats that require the learner to produce language rather than recognise
/// it. Mastery is gated on these.
///
/// `reply` and `register` are deliberately absent: they are worth a great deal
/// for conversation but they are still four-option questions, and picking the
/// right answer from a list is not evidence that it could have been produced.
const productionTypes = {
  QuestionType.dictation,
  QuestionType.reorder,
  QuestionType.produce,
};

/// Formats whose audio is withheld until the answer is in. Playing it first
/// would hand over the very thing being asked for.
const silentUntilAnswered = {QuestionType.produce, QuestionType.register};

class Question {
  final String id;
  final QuestionType type;
  final String sentenceId;
  final String realmId;
  final String? itemId;

  final String text; // the English that is spoken
  final String translationNative;
  final String level;
  final String context;
  final String prompt;

  // multiple choice (paraphrase / gist)
  final List<String> options;
  final int correct;

  // dictation
  final String before;
  final String after;
  final List<String> answerWords;
  final List<String> bankPool; // decoy tiles drawn from the same realm

  // reorder / produce
  final List<String> tokens;
  final String finalPunct;

  // reply: the other person's line, which is what gets spoken
  final String cueText;
  final String cueTranslationNative;

  /// Why the answer is the right one. Written in the learner's language and
  /// shown after answering; `register` is the format that needs it.
  final String note;

  final String answerText;
  final bool disabled;

  const Question({
    required this.id,
    required this.type,
    required this.sentenceId,
    required this.realmId,
    this.itemId,
    required this.text,
    this.translationNative = '',
    this.level = 'B1',
    this.context = '',
    this.prompt = '',
    this.options = const [],
    this.correct = -1,
    this.before = '',
    this.after = '',
    this.answerWords = const [],
    this.bankPool = const [],
    this.tokens = const [],
    this.finalPunct = '',
    this.cueText = '',
    this.cueTranslationNative = '',
    this.note = '',
    this.answerText = '',
    this.disabled = false,
  });

  /// What the speech engine should read out. For `reply` that is the other
  /// person's line, not the answer — reading the answer would give it away.
  String get spokenText => type == QuestionType.reply && cueText.isNotEmpty
      ? cueText
      : text;

  Question copyWith({bool? disabled, List<String>? answerWords, List<String>? bankPool}) =>
      Question(
        id: id,
        type: type,
        sentenceId: sentenceId,
        realmId: realmId,
        itemId: itemId,
        text: text,
        translationNative: translationNative,
        level: level,
        context: context,
        prompt: prompt,
        options: options,
        correct: correct,
        before: before,
        after: after,
        answerWords: answerWords ?? this.answerWords,
        bankPool: bankPool ?? this.bankPool,
        tokens: tokens,
        finalPunct: finalPunct,
        cueText: cueText,
        cueTranslationNative: cueTranslationNative,
        note: note,
        answerText: answerText,
        disabled: disabled ?? this.disabled,
      );
}

// ---------------------------------------------------------------- srs

class FormatStat {
  final int n;
  final int ok;
  const FormatStat({this.n = 0, this.ok = 0});
  FormatStat plus(bool correct) => FormatStat(n: n + 1, ok: ok + (correct ? 1 : 0));
  Map<String, dynamic> toJson() => {'n': n, 'ok': ok};
  factory FormatStat.fromJson(Map<String, dynamic> j) =>
      FormatStat(n: (j['n'] ?? 0) as int, ok: (j['ok'] ?? 0) as int);
}

/// Review state for one [LearningItem].
class SrsState {
  final String itemId;
  final int box;
  final String due; // day key
  final int reps;
  final int lapses;
  final String? lastResult;
  final String? lastSeen;
  final bool introduced;
  final bool heldByGate; // capped because production is not yet demonstrated
  final String? lastSentenceId; // so the next encounter can vary the context
  final Map<QuestionType, FormatStat> formats;

  const SrsState({
    required this.itemId,
    this.box = 0,
    required this.due,
    this.reps = 0,
    this.lapses = 0,
    this.lastResult,
    this.lastSeen,
    this.introduced = false,
    this.heldByGate = false,
    this.lastSentenceId,
    this.formats = const {},
  });

  factory SrsState.blank(String itemId) => SrsState(itemId: itemId, due: today());

  FormatStat statFor(QuestionType t) => formats[t] ?? const FormatStat();

  SrsState copyWith({
    int? box,
    String? due,
    int? reps,
    int? lapses,
    String? lastResult,
    String? lastSeen,
    bool? introduced,
    bool? heldByGate,
    String? lastSentenceId,
    Map<QuestionType, FormatStat>? formats,
  }) =>
      SrsState(
        itemId: itemId,
        box: box ?? this.box,
        due: due ?? this.due,
        reps: reps ?? this.reps,
        lapses: lapses ?? this.lapses,
        lastResult: lastResult ?? this.lastResult,
        lastSeen: lastSeen ?? this.lastSeen,
        introduced: introduced ?? this.introduced,
        heldByGate: heldByGate ?? this.heldByGate,
        lastSentenceId: lastSentenceId ?? this.lastSentenceId,
        formats: formats ?? this.formats,
      );
}

// ---------------------------------------------------------------- progress

class Progress {
  final int streak;
  final int bestStreak;
  final String? lastStudyDay;
  final int freezes;
  final int xpTotal;
  final int pendingBoost;

  /// Set during start-up reconciliation so the home screen can explain what
  /// happened while the app was closed. Cleared once shown.
  final int freezeUsed;
  final int streakLostFrom;

  const Progress({
    this.streak = 0,
    this.bestStreak = 0,
    this.lastStudyDay,
    this.freezes = 1, // one in hand, so the first slip is survivable
    this.xpTotal = 0,
    this.pendingBoost = 0,
    this.freezeUsed = 0,
    this.streakLostFrom = 0,
  });

  Progress copyWith({
    int? streak,
    int? bestStreak,
    String? lastStudyDay,
    int? freezes,
    int? xpTotal,
    int? pendingBoost,
    int? freezeUsed,
    int? streakLostFrom,
  }) =>
      Progress(
        streak: streak ?? this.streak,
        bestStreak: bestStreak ?? this.bestStreak,
        lastStudyDay: lastStudyDay ?? this.lastStudyDay,
        freezes: freezes ?? this.freezes,
        xpTotal: xpTotal ?? this.xpTotal,
        pendingBoost: pendingBoost ?? this.pendingBoost,
        freezeUsed: freezeUsed ?? this.freezeUsed,
        streakLostFrom: streakLostFrom ?? this.streakLostFrom,
      );

  Map<String, dynamic> toJson() => {
        'streak': streak,
        'bestStreak': bestStreak,
        'lastStudyDay': lastStudyDay,
        'freezes': freezes,
        'xpTotal': xpTotal,
        'pendingBoost': pendingBoost,
      };

  factory Progress.fromJson(Map<String, dynamic> j) => Progress(
        streak: (j['streak'] ?? 0) as int,
        bestStreak: (j['bestStreak'] ?? 0) as int,
        lastStudyDay: j['lastStudyDay'] as String?,
        freezes: (j['freezes'] ?? 1) as int,
        xpTotal: (j['xpTotal'] ?? 0) as int,
        pendingBoost: (j['pendingBoost'] ?? 0) as int,
      );
}

/// One answered question, kept as the learning record.
class HistoryEntry {
  final int? id;
  final String day;
  final DateTime at;
  final String questionId;
  final String? itemId;
  final String realmId;
  final QuestionType type;
  final bool correct;
  final bool wasDue;

  const HistoryEntry({
    this.id,
    required this.day,
    required this.at,
    required this.questionId,
    this.itemId,
    required this.realmId,
    required this.type,
    required this.correct,
    required this.wasDue,
  });
}
