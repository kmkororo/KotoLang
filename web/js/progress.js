/* Frequency - streak, XP, chest rewards and settings.
   A study day is any local calendar day on which at least one question was
   actually answered. Correctness is irrelevant: someone who attempted a hard
   item and missed it still showed up. Opening a screen is not enough. */
(function (FQ) {
  'use strict';

  var U = FQ.util;
  var DB = FQ.db;

  // Reward table kept as a constant so probabilities are debuggable and tunable.
  var CHEST_TABLE = [
    { id: 'freeze', weight: 30, label: '🧊 ストリークフリーズ ×1',
      note: '休んだ日を1日ぶん肩代わりします' },
    { id: 'boost',  weight: 30, label: '⭐ 次のセッションはXP2倍',
      note: '次に学習したときのXPが2倍になります' },
    { id: 'xp20',   weight: 40, label: '🎯 ボーナス +20 XP',
      note: 'すぐに20XPが加算されます' }
  ];

  // XP per answer, capped to 2-10 so grinding easy formats never beats studying.
  var XP = {
    wrong: 2,
    correct: { mc: 5, gist: 6, paraphrase: 7, dictation: 8, reorder: 7 },
    dueBonus: 1,        // answering something actually due
    firstCorrect: 1,    // first time this item is answered correctly
    max: 10
  };

  // Difficulty is several dials moving together rather than one knob, because
  // listening gets harder through speed, fewer replays, less on-screen text and
  // more confusable choices - not through longer sentences.
  // replays: 0 means unlimited.
  // The blanked sentence is always shown: it is what tells the learner which
  // expression is being asked for. Hiding it made the word tiles look unrelated
  // to the audio. Difficulty comes from speed, replay budget and how many
  // confusable decoys sit alongside the answer.
  var DIFFICULTY = {
    easy: {
      key: 'easy', label: 'やさしい', rate: 0.85, replays: 0,
      bankExtra: 2, gistOptions: false,
      hint: 'ゆっくり・聞き直し自由・ダミーは2語'
    },
    normal: {
      key: 'normal', label: 'ふつう', rate: 0.95, replays: 4,
      bankExtra: 4, gistOptions: true,
      hint: '標準の速さ・聞き直しは4回まで・ダミーは4語'
    },
    hard: {
      key: 'hard', label: 'むずかしい', rate: 1.0, replays: 2,
      bankExtra: 6, gistOptions: true,
      hint: '自然な速さ・聞き直しは2回まで・ダミーは6語'
    }
  };

  var DEFAULT_SETTINGS = {
    voiceName: null,
    speechRate: null,   // null = follow the difficulty level
    difficulty: 'hard',
    inputMode: 'tap',   // tap = word buttons, keyboard = free typing
    dailyGoal: 1,       // the whole point: one question is a complete day
    sound: true,
    theme: 'system'
  };

  function levelOf(settings) {
    return DIFFICULTY[(settings && settings.difficulty) || 'normal'] || DIFFICULTY.normal;
  }

  // An explicit speed override wins; otherwise the level decides.
  function rateOf(settings) {
    if (settings && typeof settings.speechRate === 'number') return settings.speechRate;
    return levelOf(settings).rate;
  }

  var DEFAULT_PROGRESS = {
    streak: 0,
    bestStreak: 0,
    lastStudyDay: null,
    freezes: 1,         // start with one so the first slip is survivable
    xpTotal: 0,
    pendingBoost: 0,
    // Transient flags for the home screen, cleared once shown.
    freezeUsed: 0,
    streakLostFrom: 0
  };

  function loadProgress() {
    return DB.getMeta('progress', null).then(function (p) {
      return Object.assign({}, DEFAULT_PROGRESS, p || {});
    });
  }

  function saveProgress(p) { return DB.setMeta('progress', p); }

  function loadSettings() {
    return DB.getMeta('settings', null).then(function (s) {
      return Object.assign({}, DEFAULT_SETTINGS, s || {});
    });
  }

  function saveSettings(s) { return DB.setMeta('settings', s); }

  // Called on startup. Spends freezes for days missed while the app was closed
  // and reports what happened so the UI can explain it.
  function reconcileStreak(p, today) {
    today = today || U.today();
    p.freezeUsed = 0;
    p.streakLostFrom = 0;

    if (!p.lastStudyDay) { p.streak = 0; return p; }

    var gap = U.daysBetween(p.lastStudyDay, today);
    if (gap <= 0) return p;      // same day, or a clock that moved backwards
    if (gap === 1) return p;     // studied yesterday; the chain is still live

    var missed = gap - 1;
    if (p.freezes >= missed) {
      p.freezes -= missed;
      p.freezeUsed = missed;
      // Treat the chain as unbroken by pretending the last study day was
      // yesterday, so today's first answer increments normally.
      p.lastStudyDay = U.addDays(today, -1);
    } else {
      p.streakLostFrom = p.streak;
      p.streak = 0;
    }
    return p;
  }

  // Called when a question is answered. Advances the streak at most once a day.
  function registerStudyDay(p, today) {
    today = today || U.today();
    if (p.lastStudyDay === today) return { advanced: false, from: p.streak, to: p.streak };

    var from = p.streak;
    if (p.lastStudyDay && U.daysBetween(p.lastStudyDay, today) === 1) p.streak += 1;
    else p.streak = 1;

    p.lastStudyDay = today;
    if (p.streak > p.bestStreak) p.bestStreak = p.streak;
    return { advanced: true, from: from, to: p.streak };
  }

  function xpFor(type, correct, opts) {
    opts = opts || {};
    if (!correct) return XP.wrong;
    var base = XP.correct[type] || 5;
    if (opts.wasDue) base += XP.dueBonus;
    if (opts.firstCorrect) base += XP.firstCorrect;
    return U.clamp(base, 2, XP.max);
  }

  function openChest() { return U.weightedPick(CHEST_TABLE); }

  function applyChest(p, reward) {
    if (reward.id === 'freeze') p.freezes += 1;
    else if (reward.id === 'boost') p.pendingBoost = 2;
    else if (reward.id === 'xp20') p.xpTotal += 20;
    return p;
  }

  FQ.progress = {
    CHEST_TABLE: CHEST_TABLE,
    XP: XP,
    DIFFICULTY: DIFFICULTY,
    levelOf: levelOf,
    rateOf: rateOf,
    DEFAULT_SETTINGS: DEFAULT_SETTINGS,
    DEFAULT_PROGRESS: DEFAULT_PROGRESS,
    load: loadProgress,
    save: saveProgress,
    loadSettings: loadSettings,
    saveSettings: saveSettings,
    reconcileStreak: reconcileStreak,
    registerStudyDay: registerStudyDay,
    xpFor: xpFor,
    openChest: openChest,
    applyChest: applyChest
  };

})(window.FQ = window.FQ || {});
