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

  /// Questions in one session. A preference the learner sets, not something
  /// bought: `sessionSizeAll` serves everything available.
  final int sessionSize;

  /// Short vibrations on answering. On by default: the feedback arrives
  /// before the eyes have moved to the words, which is most of what makes an
  /// answer feel like it landed.
  final bool haptics;

  /// Asked once, at first run, so the scenes fit the learner's life: '10s',
  /// '20s', '30s', '40s', '50s+' or '' when not answered. Handed to the AI
  /// as a description, never shown back as a number.
  final String ageBand;

  /// Where they want to use English — 'work', 'travel', 'school', 'daily'.
  /// Orders the built-in scenes and steers the AI's.
  final List<String> interests;

  /// The first-run walkthrough has been completed (or skipped).
  final bool tutorialDone;

  /// Each scene speaks in its own voice, drawn from the voices of the chosen
  /// voice's region; off, every scene uses the chosen voice.
  final bool voicePerScene;

  const AppSettings({
    this.voiceName,
    this.speechRate,
    this.difficulty = 'hard',
    this.inputMode = 'tap',
    this.dailyGoal = 1, // the whole point: one question is a complete day
    this.theme = 'system',
    this.batchSize = 'standard',
    this.sessionSize = baseSessionSize,
    this.haptics = true,
    this.ageBand = '',
    this.interests = const [],
    this.tutorialDone = false,
    this.voicePerScene = true,
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
    int? sessionSize,
    bool? haptics,
    String? ageBand,
    List<String>? interests,
    bool? tutorialDone,
    bool? voicePerScene,
  }) =>
      AppSettings(
        voicePerScene: voicePerScene ?? this.voicePerScene,
        ageBand: ageBand ?? this.ageBand,
        interests: interests ?? this.interests,
        tutorialDone: tutorialDone ?? this.tutorialDone,
        voiceName: voiceName ?? this.voiceName,
        speechRate: clearSpeechRate ? null : (speechRate ?? this.speechRate),
        difficulty: difficulty ?? this.difficulty,
        inputMode: inputMode ?? this.inputMode,
        dailyGoal: dailyGoal ?? this.dailyGoal,
        theme: theme ?? this.theme,
        batchSize: batchSize ?? this.batchSize,
        sessionSize: sessionSize ?? this.sessionSize,
        haptics: haptics ?? this.haptics,
      );
}

// ---------------------------------------------------------------- streak

class StreakResult {
  final bool advanced;
  final int from;
  final int to;
  const StreakResult(this.advanced, this.from, this.to);
}

/// Run at start-up. Works out what a gap since the last study day did to the
/// streak, and records it so home can say so.
///
/// There is nothing here that could save a streak any more. The rest day was
/// a token, a token is a thing to be given and spent, and this app keeps no
/// balance of anything — so a missed day breaks the chain and the record is
/// honest about it. What survives is the best streak, which is a fact rather
/// than a currency.
Progress reconcileStreak(Progress p, [String? day]) {
  final now = day ?? today();
  final out = p.copyWith(streakLostFrom: 0);

  if (out.lastStudyDay == null) return out.copyWith(streak: 0);

  final gap = daysBetween(out.lastStudyDay!, now);
  if (gap <= 0) return out; // same day, or a clock that moved backwards
  if (gap == 1) return out; // studied yesterday; the chain is still live

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

// ---------------------------------------------------------------- opening
//
// What opens, and what opens it. There is one answer to the second question
// and it is the ladder: a field or a situation opens because the learner can
// hold a setting they could not hold before, never because a balance reached
// a number. The v1 model had Koto Seeds, a chest and a price list here; all
// of it is gone. A second number that goes up invites a shop, and a shop has
// nothing to do with hearing English.

/// The fields the learner chooses at the end of the first run. Three, so the
/// choice is a real one without being a morning's work.
const freeRealmSlots = 3;

/// Steps of the ladder between one field opening and the next, once the
/// starting three are chosen. A provisional number, deliberately a constant:
/// the pace wants to be felt on a device before it is settled.
const stepsPerField = 6;

/// Conversations answered in a field before its results are worth sending to
/// the AI. Below this there is not enough there to see a pattern.
const feedbackAfter = 5;

/// How many turns a run holds. A preference, and nothing but: it is never
/// priced, and every size does the same thing to the ladder. `sessionSizeAll`
/// means every conversation there is, for the days somebody wants the lot.
const baseSessionSize = 5;
const sessionSizeAll = 0;
const sessionSizes = <int>[3, 5, 10, 20, sessionSizeAll];
const maxSessionSize = 45;

/// How many fields are open to a learner whose ladder has reached [reached]
/// steps: the three they chose, and one more every [stepsPerField] after
/// that. Never fewer than the three, however the ladder moves.
int fieldsOpenAt(int reached) =>
    freeRealmSlots + (reached <= 0 ? 0 : reached ~/ stepsPerField);

/// Steps still to climb before the next field opens, or null once every field
/// the profile named is already open.
int? stepsToNextField(int reached, {required int fieldsHeld}) {
  if (fieldsHeld <= fieldsOpenAt(reached)) return null;
  final next = (reached ~/ stepsPerField + 1) * stepsPerField;
  return next - reached;
}

// ------------------------------------------------------- listening mastery
//
// "82%" invites the reading "82% of English", which this app has no way to
// measure and no business claiming. What it can honestly report is how often
// the learner has picked the right main idea or the right reply when it
// counted — so that is exactly what gets shown, captioned as what it is
// ("大意をつかむ力"), never as a global fluency score.

/// Accuracy over the two listening formats — main-idea comprehension and
/// choosing the right reply — as a 0..100 percentage. Null when there is
/// nothing to compute it from yet, so the caller can show "not enough data"
/// rather than a misleading 0%.
int? listeningMastery(List<HistoryEntry> history) {
  var n = 0, ok = 0;
  for (final h in history) {
    if (h.type != QuestionType.gist && h.type != QuestionType.reply) continue;
    n++;
    if (h.correct) ok++;
  }
  if (n == 0) return null;
  return ((ok / n) * 100).round();
}

/// The last 7 local calendar days, oldest first, true where at least one
/// question was answered. A thin slice of the same history the 28-day heatmap
/// in the stats screen reads, so a streak reset never erases it — it is
/// derived from the answer log, not from the streak counter.
List<bool> weeklyStrip(List<HistoryEntry> history, String today) {
  final days = {for (final h in history) h.day};
  return [for (var i = 6; i >= 0; i--) days.contains(addDays(today, -i))];
}

// ------------------------------------------------------------ next milestone
//
// "One more question" is the whole hook of a short session, and it only works
// if the learner can see what the one more question buys. Everything here is
// derived from the answer log and the streak — nothing new is stored.

/// A goal that is close enough to be worth naming, and how far away it is.
class NextGoal {
  /// Which goal: 'week' (beat this week's answers), 'streak' (reach the next
  /// streak milestone), 'today' (finish today's own record).
  final String kind;
  final int remaining;
  final int target;
  const NextGoal(this.kind, this.remaining, this.target);
}

/// Streak lengths worth calling out. Close together early, where the habit is
/// still forming and a distant number would not pull.
const streakMilestones = [3, 7, 14, 30, 60, 100];

/// How many answers ahead a goal may sit and still be shown. Beyond this it is
/// not "one more question", it is a chore.
const goalWithinReach = 5;

/// The nearest thing worth finishing, or null when nothing is close.
///
/// Streak first: it is the one that expires. A streak milestone one study day
/// away needs only a single question, which is exactly the promise the app
/// makes.
NextGoal? nextGoal({
  required List<HistoryEntry> history,
  required int streak,
  required String today,
  required bool studiedToday,
}) {
  if (!studiedToday) {
    for (final m in streakMilestones) {
      if (streak + 1 == m) return NextGoal('streak', 1, m);
    }
  }

  // This week against last week, counted over the same seven days.
  final thisWeek = _answersWithin(history, today, 0, 6);
  final lastWeek = _answersWithin(history, today, 7, 13);
  if (lastWeek > 0 && thisWeek <= lastWeek) {
    final need = lastWeek - thisWeek + 1;
    if (need <= goalWithinReach) return NextGoal('week', need, lastWeek + 1);
  }

  // Otherwise: round today up to the next handful, so there is always a small
  // finish line while the app is open.
  final todayCount = history.where((h) => h.day == today).length;
  if (todayCount > 0) {
    final target = ((todayCount ~/ 5) + 1) * 5;
    return NextGoal('today', target - todayCount, target);
  }
  return null;
}

int _answersWithin(List<HistoryEntry> history, String today, int from, int to) {
  final days = {for (var i = from; i <= to; i++) addDays(today, -i)};
  return history.where((h) => days.contains(h.day)).length;
}

// ------------------------------------------------------------------ badges
//
// A shelf of things already done. Every one is computed from the answer log or
// the schedule, so there is nothing to keep in step and nothing to lose.

class Badge {
  final String id;
  final int threshold;

  /// Where the learner is against [threshold], capped at it.
  final int progress;

  const Badge(this.id, this.threshold, this.progress);

  bool get earned => progress >= threshold;
  double get ratio => threshold == 0 ? 1 : (progress / threshold).clamp(0.0, 1.0);
}

/// The full shelf, earned and not, in the order it is shown. Unearned ones are
/// shown too: a locked badge with a real number under it is a goal, while a
/// hidden one is nothing at all.
List<Badge> badges({
  required List<HistoryEntry> history,
  required int bestStreak,
  required int masteredItems,
  required int realmsWithMaterial,
}) {
  final answers = history.length;
  final days = {for (final h in history) h.day}.length;
  final listening = history
      .where((h) => h.type == QuestionType.gist || h.type == QuestionType.reply)
      .length;
  final perfectDays = <String>{};
  final byDay = <String, List<HistoryEntry>>{};
  for (final h in history) {
    (byDay[h.day] ??= []).add(h);
  }
  byDay.forEach((day, list) {
    if (list.length >= 5 && list.every((h) => h.correct)) perfectDays.add(day);
  });

  return [
    Badge('answers10', 10, answers),
    Badge('answers100', 100, answers),
    Badge('answers500', 500, answers),
    Badge('days7', 7, days),
    Badge('days30', 30, days),
    Badge('streak7', 7, bestStreak),
    Badge('streak30', 30, bestStreak),
    Badge('listening100', 100, listening),
    Badge('mastered1', 1, masteredItems),
    Badge('mastered25', 25, masteredItems),
    Badge('realms3', 3, realmsWithMaterial),
    Badge('perfectDay', 1, perfectDays.length),
  ];
}

// ------------------------------------------------------------------- combo
//
// Consecutive correct answers inside one session. It only ever adds: a wrong
// answer resets the run to zero but never takes Seeds away, because a
// mechanic that punishes mistakes teaches people to avoid hard questions.

/// Seeds added on top of the answer's own, for a run of [streak] correct
/// answers ending now. Nothing for the first two, then one Seed per further
/// answer, capped so a long run cannot dwarf the studying itself.
int comboBonus(int streak) {
  if (streak < 3) return 0;
  return clampInt(streak - 2, 1, maxComboBonus);
}

const maxComboBonus = 5;

/// Fresh questions left before the app starts asking for more material. Set
/// well above zero: refilling means a trip to an assistant and back, which is
/// not something to discover at the moment there is nothing left to answer.
const lowMaterialMark = 6;

// ------------------------------------------------------------------ debates
//
// One exchange is one of the opponent's lines answered: three things caught,
// a reply built, a branch taken. Paid in the same currency as everything else
// and on the same principle — nothing is ever taken away for a bad reply.

/// All three things caught: claim, reason and the weak point. The core of the
/// listening, weighted like the gist question it replaces.
/// Scenes: what one exchange and one finished scene pay. Understanding is
/// worth a little, the reply a little more, and finishing is worth showing
/// up for — the streak is decided by finishing, not by being right.
const gistSeeds = 3;
const replySeeds = 5;
const sceneCompleteSeeds = 5;

const graspSeeds = 3;

/// The reply came closest to the strong model. The hardest thing here.
const strongRebuttalSeeds = 6;

/// The reply carried every move the strong model carries. Form before
/// content: the skeleton is the transferable part.
const structureSeeds = 2;

/// How the whole exchange ended, in place of the session-length bonus.
int outcomeSeeds(String outcome) => switch (outcome) {
      'won' => 15,
      'held' => 10,
      _ => 0,
    };

/// Seeds for one exchange, before the outcome.
int exchangeSeeds({
  required bool graspedAll,
  required bool closestIsStrong,
  required bool structureComplete,
}) =>
    (graspedAll ? graspSeeds : 0) +
    (closestIsStrong ? strongRebuttalSeeds : 0) +
    (structureComplete ? structureSeeds : 0);

// ----------------------------------------------------------- breakthrough
//
// The item that kept going wrong and finally stopped. That moment is the
// hardest-won progress the app can detect, and until now it passed silently:
// the same three Seeds as any other answer.
//
// Paid once per item, so an item that later slips and climbs again is not a
// second payday — which also means nobody can farm it by missing on purpose.

/// Wrong answers an item must have collected before its recovery counts as
/// hard-won rather than ordinary progress.
const breakthroughLapses = 3;

/// The box that counts as recovered. Above `recognitionCap`, so it cannot be
/// reached without having produced the expression, not merely recognised it.
const breakthroughBox = 4;

const breakthroughBonus = 25;

/// Whether this answer is the one that turned a struggling item around.
///
/// [before] is the state as it stood when the question was asked, [after] the
/// state the answer produced. Crossing the line is what matters: an item
/// already at or above the box stays quiet.
bool isBreakthrough(SrsState? before, SrsState? after) {
  if (after == null) return false;
  if (after.lapses < breakthroughLapses) return false;
  if (after.box < breakthroughBox) return false;
  return (before?.box ?? 0) < breakthroughBox;
}

// ------------------------------------------------------------ perfect run

/// A session finished without a single wrong answer. Three is the floor: two
/// out of two is not an achievement worth a ceremony. The reward is modest
/// because with short sessions this comes round often — a windfall every few
/// minutes stops reading as a windfall.
const perfectRunMin = 3;
const perfectRunBonus = 10;
bool isPerfectRun({required int answered, required int missed}) =>
    missed == 0 && answered >= perfectRunMin;

// --------------------------------------------------------- format filter

/// The question types each filter draws from. Grouped by what the learner is
/// actually being asked to do, because that is the choice they are making —
/// not the seven internal format names.
const formatFilters = <String, List<QuestionType>>{
  'listening': [QuestionType.gist, QuestionType.reply, QuestionType.dictation],
  'phrasing': [QuestionType.paraphrase, QuestionType.register],
  'speaking': [QuestionType.produce, QuestionType.reorder],
};

/// Null means no restriction, which is also what an unknown value gives.
Set<QuestionType>? typesFor(String filter) {
  return formatFilters[filter]?.toSet();
}

// ------------------------------------------------------------- ornaments

/// What a tree decoration costs. Purely cosmetic, and the only thing Seeds buy
/// that changes no number in the app — which is the point: once the areas are
/// open and the sessions are long, Seeds need somewhere to go that cannot
/// distort what the learner chooses to study.
const ornamentCost = 40;

const ornamentKinds = <String>['ribbon', 'star', 'lantern', 'bell'];

// ------------------------------------------------------------- first run

/// The age groups offered at first run, as stored. Empty means not answered.
const ageBands = ['10s', '20s', '30s', '40s', '50s+'];

/// Where the learner wants to use English, as stored.
const interestKinds = ['work', 'travel', 'school', 'daily'];

/// The stored age band as the AI should read it. A description, not a
/// number: the AI chooses settings and register from it.
String ageBandDescription(String band) => switch (band) {
      '10s' => 'teenager (secondary school age)',
      '20s' => 'in their twenties (student or early career)',
      '30s' => 'in their thirties',
      '40s' => 'in their forties',
      '50s+' => 'fifty or older',
      _ => '',
    };

String interestDescription(String kind) => switch (kind) {
      'work' => 'English at work',
      'travel' => 'English while travelling abroad',
      'school' => 'English at school and on campus',
      'daily' => 'everyday English',
      _ => kind,
    };
