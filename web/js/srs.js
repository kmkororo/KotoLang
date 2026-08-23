/* Frequency - spaced repetition.
   Scheduling is tracked per Learning Item, not per question, because the item
   is what the learner is memorising; the three formats are different ways of
   probing the same knowledge.

   Boxes and intervals:
     box 0 -> due tomorrow      (new / just failed)
     box 1 -> +1 day
     box 2 -> +3 days
     box 3 -> +7 days
     box 4 -> +16 days
     box 5 -> +35 days

   Recognition gate: an item cannot move past box 3 on multiple choice alone.
   Choosing from four options is recognition; typing or rebuilding the phrase is
   production. Without one correct production answer the item stays at box 3,
   so "I only ever tapped the right button" never counts as mastered. */
(function (FQ) {
  'use strict';

  var U = FQ.util;
  var DB = FQ.db;

  var INTERVALS = [1, 1, 3, 7, 16, 35];
  var MAX_BOX = INTERVALS.length - 1;
  var RECOGNITION_CAP = 3;          // highest box reachable without production
  var PRODUCTION_TYPES = ['dictation', 'reorder'];

  var FORMATS = ['gist', 'paraphrase', 'mc', 'dictation', 'reorder'];

  // How often each format should come round relative to the others. Comparing
  // attempts/weight means a heavier format needs proportionally more attempts
  // before the rotation moves on, so gist is served roughly twice as often as
  // the multiple-choice vocabulary question.
  var FORMAT_WEIGHT = { gist: 2.2, paraphrase: 2.2, dictation: 1.5, reorder: 1.0, mc: 0.6 };

  function blankState(itemId) {
    return {
      itemId: itemId,
      box: 0,
      due: U.today(),
      reps: 0,
      lapses: 0,
      lastResult: null,
      lastSeen: null,
      introduced: false,
      formats: {
        gist:      { n: 0, ok: 0 },
        paraphrase:{ n: 0, ok: 0 },
        mc:        { n: 0, ok: 0 },
        dictation: { n: 0, ok: 0 },
        reorder:   { n: 0, ok: 0 }
      }
    };
  }

  function isProduction(type) { return PRODUCTION_TYPES.indexOf(type) !== -1; }

  function hasProductionEvidence(state) {
    return PRODUCTION_TYPES.some(function (t) {
      var f = state.formats && state.formats[t];
      return !!f && f.ok > 0;
    });
  }

  function weightedPick(types) {
    var table = types.map(function (t) {
      return { t: t, weight: FORMAT_WEIGHT[t] || 1 };
    });
    return U.weightedPick(table).t;
  }

  function intervalFor(box) { return INTERVALS[U.clamp(box, 0, MAX_BOX)]; }

  // Apply one answer. Returns the updated state; caller persists it.
  function apply(state, type, correct) {
    var s = state || blankState(null);
    var today = U.today();

    var fmt = s.formats[type] || (s.formats[type] = { n: 0, ok: 0 });
    fmt.n += 1;
    if (correct) fmt.ok += 1;

    s.reps += 1;
    s.introduced = true;
    s.lastResult = correct ? 'correct' : 'wrong';
    s.lastSeen = today;

    if (correct) {
      var next = Math.min(s.box + 1, MAX_BOX);
      // Recognition gate: hold at the cap until production is demonstrated.
      if (next > RECOGNITION_CAP && !hasProductionEvidence(s)) {
        next = RECOGNITION_CAP;
        s.heldByGate = true;
      } else {
        s.heldByGate = false;
      }
      s.box = next;
    } else {
      // A miss on production is a real lapse; a miss on recognition is a hint
      // that the item is weaker than its box suggests, so drop it further.
      s.lapses += 1;
      s.box = isProduction(type) ? 0 : Math.max(0, Math.min(s.box, 1) - 1);
      s.heldByGate = false;
    }

    s.due = U.addDays(today, intervalFor(s.box));
    return s;
  }

  function isDue(state, day) {
    if (!state || !state.due) return false;
    return U.daysBetween(state.due, day || U.today()) >= 0;
  }

  function accuracy(state) {
    var n = 0, ok = 0;
    FORMATS.forEach(function (t) {
      var f = state.formats[t]; if (f) { n += f.n; ok += f.ok; }
    });
    return { n: n, ok: ok, pct: U.pct(ok, n) };
  }

  // An item counts as mastered only at the top box, which the gate makes
  // unreachable without production evidence.
  function isMastered(state) {
    return !!state && state.box >= MAX_BOX;
  }

  // Which format to probe next: the one with the fewest attempts, so dictation
  // and reorder are not crowded out by multiple choice.
  function preferredFormat(state, availableTypes) {
    if (!availableTypes.length) return null;

    // Shuffle first so that formats tied on attempt count are chosen at random
    // rather than by array order; sort is stable, so the shuffle survives.
    var pool = U.shuffle(availableTypes);

    if (!state || !state.introduced) {
      // A brand new item has no history to balance, so pick by weight. Every
      // format stays reachable, which matters because a purely deterministic
      // choice once made reorder unreachable.
      return weightedPick(pool);
    }

    // Once recognition is capped, push production formats explicitly.
    if (state.box >= RECOGNITION_CAP && !hasProductionEvidence(state)) {
      var prod = pool.filter(isProduction);
      if (prod.length) return prod[0];
    }

    return pool.sort(function (a, b) {
      var fa = state.formats[a] || { n: 0 }, fb = state.formats[b] || { n: 0 };
      return (fa.n / (FORMAT_WEIGHT[a] || 1)) - (fb.n / (FORMAT_WEIGHT[b] || 1));
    })[0];
  }

  // Selection priority, highest first:
  //   1. reviews that have come due
  //   2. items currently being answered wrongly
  //   3. material never studied yet
  //   4. everything else, climbing only as it goes stale
  //
  // Rank 3 above rank 4 is what keeps sessions varied. An item answered today
  // is not due again for at least a day; when such items outranked untouched
  // material the planner drilled the same few forever and never introduced the
  // rest, which made every session feel like the same sentences.
  function priority(state, item, domain, day) {
    var today = day || U.today();
    var imp = domain ? (domain.importance || 3) : 3;

    if (state && isDue(state, today)) {
      var overdue = U.daysBetween(state.due, today);      // 0 = due today
      return 10000 + Math.min(overdue, 60) * 10 + imp;
    }

    if (state && state.introduced) {
      var acc = accuracy(state);
      // Weak items come next, worst first.
      if (acc.n >= 2 && acc.pct < 60) return 5000 + (60 - acc.pct) * 10 + imp;
      // Otherwise it waits its turn, rising only as it sits unseen.
      var idle = state.lastSeen ? U.daysBetween(state.lastSeen, today) : 0;
      return 100 + Math.min(idle, 90) * 4 + imp;
    }

    // Never studied: ranked above seen-but-not-due so breadth comes first.
    return 500 + imp * 10 + (item ? (item.priority || 3) : 3);
  }

  function load(itemIds) {
    return DB.getAll('srs').then(function (all) {
      var byId = {};
      all.forEach(function (s) { byId[s.itemId] = s; });
      if (itemIds) {
        itemIds.forEach(function (id) { if (!byId[id]) byId[id] = blankState(id); });
      }
      return byId;
    });
  }

  function save(state) { return DB.put('srs', state); }

  // Count of items whose review has come due today.
  function dueCount(states, day) {
    var today = day || U.today();
    return Object.keys(states).filter(function (k) {
      return states[k].introduced && isDue(states[k], today);
    }).length;
  }

  FQ.srs = {
    INTERVALS: INTERVALS,
    MAX_BOX: MAX_BOX,
    RECOGNITION_CAP: RECOGNITION_CAP,
    FORMATS: FORMATS,
    FORMAT_WEIGHT: FORMAT_WEIGHT,
    blankState: blankState,
    apply: apply,
    isDue: isDue,
    isMastered: isMastered,
    hasProductionEvidence: hasProductionEvidence,
    accuracy: accuracy,
    preferredFormat: preferredFormat,
    priority: priority,
    load: load,
    save: save,
    dueCount: dueCount
  };

})(window.FQ = window.FQ || {});
