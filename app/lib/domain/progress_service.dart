/// Streak, XP, difficulty and chest rewards, ported from `progress.js`.
///
/// A study day is any local calendar day on which at least one question was
/// actually answered. Correctness is irrelevant: someone who attempted a hard
/// item and missed it still showed up. Opening a screen is not enough.
library;

import '../core/util.dart';
import 'models.dart';

// ---------------------------------------------------------------- difficulty

/// Difficulty is several dials moving together. The blanked sentence is always
/// shown — it is what tells the learner which expression is being asked for.
/// Hiding it once made the word tiles look unrelated to the audio.
class Difficulty {
  final String key;
  final String label;
  final double rate; // speech rate
  final int replays; // 0 = unlimited
  final int bankExtra; // decoy tile budget
  final String hint;

  const Difficulty({
    required this.key,
    required this.label,
    required this.rate,
    required this.replays,
    required this.bankExtra,
    required this.hint,
  });
}

const difficulties = <String, Difficulty>{
  'easy': Difficulty(
    key: 'easy',
    label: 'やさしい',
    rate: 0.85,
    replays: 0,
    bankExtra: 2,
    hint: 'ゆっくり・聞き直し自由・ダミーは2語',
  ),
  'normal': Difficulty(
    key: 'normal',
    label: 'ふつう',
    rate: 0.95,
    replays: 4,
    bankExtra: 4,
    hint: '標準の速さ・聞き直しは4回まで・ダミーは4語',
  ),
  'hard': Difficulty(
    key: 'hard',
    label: 'むずかしい',
    rate: 1.0,
    replays: 2,
    bankExtra: 6,
    hint: '自然な速さ・聞き直しは2回まで・ダミーは6語',
  ),
};

class AppSettings {
  final String? voiceName;
  final double? speechRate; // null = follow the difficulty level
  final String difficulty;
  final String inputMode; // tap | keyboard
  final int dailyGoal;
  final String theme;

  /// How much one material request asks the AI for: small | standard | large.
  /// Small keeps the reply short enough to copy on a phone in a single tap,
  /// which is the difference between the app being usable there and not.
  final String batchSize;

  const AppSettings({
    this.voiceName,
    this.speechRate,
    this.difficulty = 'hard',
    this.inputMode = 'tap',
    this.dailyGoal = 1, // the whole point: one question is a complete day
    this.theme = 'system',
    this.batchSize = 'standard',
  });

  Difficulty get level => difficulties[difficulty] ?? difficulties['normal']!;

  /// An explicit speed override wins; otherwise the level decides.
  double get rate => speechRate ?? level.rate;

  AppSettings copyWith({
    String? voiceName,
    double? speechRate,
    bool clearSpeechRate = false,
    String? difficulty,
    String? inputMode,
    int? dailyGoal,
    String? theme,
    String? batchSize,
  }) =>
      AppSettings(
        voiceName: voiceName ?? this.voiceName,
        speechRate: clearSpeechRate ? null : (speechRate ?? this.speechRate),
        difficulty: difficulty ?? this.difficulty,
        inputMode: inputMode ?? this.inputMode,
        dailyGoal: dailyGoal ?? this.dailyGoal,
        theme: theme ?? this.theme,
        batchSize: batchSize ?? this.batchSize,
      );
}

// ---------------------------------------------------------------- streak

class StreakResult {
  final bool advanced;
  final int from;
  final int to;
  const StreakResult(this.advanced, this.from, this.to);
}

/// Run at start-up. Spends freezes for days missed while the app was closed and
/// records what happened so the UI can explain it.
Progress reconcileStreak(Progress p, [String? day]) {
  final now = day ?? today();
  var out = p.copyWith(freezeUsed: 0, streakLostFrom: 0);

  if (out.lastStudyDay == null) return out.copyWith(streak: 0);

  final gap = daysBetween(out.lastStudyDay!, now);
  if (gap <= 0) return out; // same day, or a clock that moved backwards
  if (gap == 1) return out; // studied yesterday; the chain is still live

  final missed = gap - 1;
  if (out.freezes >= missed) {
    // Treat the chain as unbroken by moving the marker to yesterday, so today's
    // first answer increments normally.
    return out.copyWith(
      freezes: out.freezes - missed,
      freezeUsed: missed,
      lastStudyDay: addDays(now, -1),
    );
  }
  return out.copyWith(streakLostFrom: out.streak, streak: 0);
}

/// Call when a question is answered. Advances the streak at most once a day.
({Progress progress, StreakResult result}) registerStudyDay(Progress p, [String? day]) {
  final now = day ?? today();
  if (p.lastStudyDay == now) {
    return (progress: p, result: StreakResult(false, p.streak, p.streak));
  }

  final from = p.streak;
  final next = (p.lastStudyDay != null && daysBetween(p.lastStudyDay!, now) == 1)
      ? p.streak + 1
      : 1;

  final updated = p.copyWith(
    streak: next,
    lastStudyDay: now,
    bestStreak: next > p.bestStreak ? next : p.bestStreak,
  );
  return (progress: updated, result: StreakResult(true, from, next));
}

// ---------------------------------------------------------------- xp

/// XP per answer, capped to 2..10 so grinding an easy format never beats
/// studying properly.
const _xpWrong = 2;
const _xpCorrect = <QuestionType, int>{
  QuestionType.gist: 6,
  QuestionType.paraphrase: 7,
  QuestionType.reorder: 7,
  QuestionType.dictation: 8,
};
const xpMax = 10;

int xpFor(QuestionType type, bool correct, {bool wasDue = false, bool firstCorrect = false}) {
  if (!correct) return _xpWrong;
  var base = _xpCorrect[type] ?? 5;
  if (wasDue) base += 1;
  if (firstCorrect) base += 1;
  return clampInt(base, 2, xpMax);
}

// ---------------------------------------------------------------- chest

class ChestReward {
  final String id;
  final double weight;
  final String label;
  final String note;
  const ChestReward(this.id, this.weight, this.label, this.note);
}

/// Kept as a constant so the probabilities are visible and tunable. Every
/// reward has a real effect; none is decorative.
const chestTable = <ChestReward>[
  ChestReward('freeze', 30, '🧊 ストリークフリーズ ×1', '休んだ日を1日ぶん肩代わりします'),
  ChestReward('boost', 30, '⭐ 次のセッションはXP2倍', '次に学習したときのXPが2倍になります'),
  ChestReward('xp20', 40, '🎯 ボーナス +20 XP', 'すぐに20XPが加算されます'),
];

ChestReward openChest() => weightedPick(chestTable, (r) => r.weight);

Progress applyChest(Progress p, ChestReward reward) {
  switch (reward.id) {
    case 'freeze':
      return p.copyWith(freezes: p.freezes + 1);
    case 'boost':
      return p.copyWith(pendingBoost: 2);
    case 'xp20':
      return p.copyWith(xpTotal: p.xpTotal + 20);
    default:
      return p;
  }
}
