/* Frequency - session assembly and answer recording.
   Selection order follows the SRS priority score: due reviews first, then weak
   items, then long-idle ones, then new material weighted by domain importance.
   Within that ordering the session interleaves formats and avoids repeating the
   same Learning Item, so a session probes breadth rather than drilling one term. */
(function (FQ) {
  'use strict';

  var U = FQ.util;
  var DB = FQ.db;
  var SRS = FQ.srs;

  var TYPES = ['gist', 'paraphrase', 'dictation', 'reorder'];

  // How many recently served sentences to keep out of rotation. Large enough
  // that a sentence does not reappear in the next session or two, small enough
  // that a modest library never runs dry.
  var RECENT_LIMIT = 45;

  function loadRecent() {
    return DB.getMeta('recentSentences', []).then(function (list) {
      return Array.isArray(list) ? list : [];
    });
  }

  // Most recent first; the index doubles as "how long ago".
  function pushRecent(sentenceId) {
    if (!sentenceId) return Promise.resolve();
    return loadRecent().then(function (list) {
      var next = [sentenceId].concat(list.filter(function (id) { return id !== sentenceId; }));
      return DB.setMeta('recentSentences', next.slice(0, RECENT_LIMIT));
    });
  }

  // Loads everything the planner needs in one pass.
  function loadPool(domainId) {
    return Promise.all([
      DB.getAll('questions'), DB.getAll('items'),
      DB.getAll('domains'), DB.getAll('srs'), DB.getAll('sentences'), loadRecent()
    ]).then(function (res) {
      var questions = res[0], items = res[1], domains = res[2], srsAll = res[3], sentences = res[4];
      var recentList = res[5];

      // id -> position, 0 being the most recently served.
      var recent = {};
      recentList.forEach(function (id, i) { recent[id] = i; });

      var sentenceById = {};
      sentences.forEach(function (s) { sentenceById[s.id] = s; });
      var itemById = {};
      items.forEach(function (i) { itemById[i.id] = i; });
      var domainById = {};
      domains.forEach(function (d) { domainById[d.id] = d; });
      var srsById = {};
      srsAll.forEach(function (s) { srsById[s.itemId] = s; });

      var usable = questions.filter(function (q) {
        if (q.disabled) return false;
        var s = sentenceById[q.sentenceId];
        if (!s || s.disabled) return false;
        if (domainId && domainId !== 'all' && q.domainId !== domainId) return false;
        return true;
      });

      return {
        questions: usable, itemById: itemById, domainById: domainById,
        srsById: srsById, sentenceById: sentenceById, recent: recent,
        recentCount: recentList.length,
        allQuestions: questions, sentences: sentences, items: items, domains: domains
      };
    });
  }

  // Groups questions by the item they probe so one item yields one slot.
  function buildPlan(pool, count) {
    var today = U.today();
    var recent = pool.recent || {};
    var byItem = {};

    pool.questions.forEach(function (q) {
      // Questions with no resolved target still deserve to be studied; they are
      // grouped under their sentence so they are not silently dropped.
      var key = q.itemId || ('sent:' + q.sentenceId);
      (byItem[key] = byItem[key] || []).push(q);
    });

    var groups = Object.keys(byItem).map(function (key) {
      var qs = byItem[key];
      var itemId = qs[0].itemId;
      var item = itemId ? pool.itemById[itemId] : null;
      var state = itemId ? pool.srsById[itemId] : null;
      var domain = pool.domainById[qs[0].domainId];
      return {
        key: key, itemId: itemId, item: item, state: state, domain: domain,
        questions: qs,
        due: !!(state && state.introduced && SRS.isDue(state, today)),
        score: SRS.priority(state, item, domain, today)
      };
    });

    // Highest priority first; ties broken randomly so sessions vary.
    groups.sort(function (a, b) {
      if (b.score !== a.score) return b.score - a.score;
      return Math.random() - 0.5;
    });

    var picked = [];
    var lastType = null;
    // One sentence may carry several Learning Items. Without this guard the
    // same sentence could be served twice in a session - once to dictate and
    // once to reorder - which gives the answer away and feels repetitive.
    var usedSentences = {};

    for (var i = 0; i < groups.length && picked.length < count; i++) {
      var g = groups[i];

      var fresh = g.questions.filter(function (q) { return !usedSentences[q.sentenceId]; });
      if (!fresh.length) continue;

      var available = U.uniqueBy(fresh.map(function (q) { return q.type; }), function (t) { return t; });

      // Prefer a format different from the previous question, when the item
      // offers a choice, so formats interleave.
      var wanted = SRS.preferredFormat(g.state, available);
      if (wanted === lastType && available.length > 1) {
        var alt = available.filter(function (t) { return t !== lastType; });
        wanted = SRS.preferredFormat(g.state, alt) || wanted;
      }

      var candidates = fresh.filter(function (q) { return q.type === wanted; });
      if (!candidates.length) candidates = fresh;

      // Meet the item through a different sentence than last time, so the same
      // expression is practised across varied contexts rather than one phrase.
      if (g.state && g.state.lastSentence) {
        var varied = candidates.filter(function (q) { return q.sentenceId !== g.state.lastSentence; });
        if (varied.length) candidates = varied;
      }

      // Skip sentences served in the last few sessions. If every candidate is
      // recent - a small library - fall back to the least recently used rather
      // than refusing to ask anything.
      var unseen = candidates.filter(function (q) { return recent[q.sentenceId] === undefined; });
      if (unseen.length) {
        candidates = unseen;
      } else {
        candidates = candidates.slice().sort(function (a, b) {
          return (recent[b.sentenceId] || 0) - (recent[a.sentenceId] || 0);
        }).slice(0, 3);
      }

      var q2 = U.sample(candidates);
      if (!q2) continue;

      usedSentences[q2.sentenceId] = true;
      picked.push({ question: q2, itemId: g.itemId, wasDue: g.due });
      lastType = q2.type;
    }

    return picked;
  }

  function build(opts) {
    opts = opts || {};
    var count = Math.max(1, opts.count || 5);
    return loadPool(opts.domainId).then(function (pool) {
      var plan = buildPlan(pool, count);
      return {
        items: plan,
        pool: pool,
        empty: plan.length === 0
      };
    });
  }

  // Counts for the home screen: how much is due, and how much is untouched.
  function counts(domainId) {
    return loadPool(domainId).then(function (pool) {
      var today = U.today();
      var dueItems = {}, newItems = {}, totalItems = {};

      pool.questions.forEach(function (q) {
        var key = q.itemId || ('sent:' + q.sentenceId);
        totalItems[key] = true;
        var st = q.itemId ? pool.srsById[q.itemId] : null;
        if (st && st.introduced) {
          if (SRS.isDue(st, today)) dueItems[key] = true;
        } else {
          newItems[key] = true;
        }
      });

      return {
        due: Object.keys(dueItems).length,
        fresh: Object.keys(newItems).length,
        total: Object.keys(totalItems).length,
        questions: pool.questions.length
      };
    });
  }

  // Records one answer: SRS, per-question stats, history, streak and XP.
  // Streak advances here (not at session start) because a day counts only when
  // a question was actually answered.
  function recordAnswer(ctx) {
    var q = ctx.question;
    var correct = !!ctx.correct;
    var today = U.today();

    var jobs = [];

    // -- SRS (item level) --
    var srsPromise = Promise.resolve(null);
    if (q.itemId) {
      srsPromise = DB.getOne('srs', q.itemId).then(function (prev) {
        var state = prev || SRS.blankState(q.itemId);
        var hadCorrect = SRS.accuracy(state).ok > 0;
        var updated = SRS.apply(state, q.type, correct);
        // Remembered so the next encounter can choose a different sentence.
        updated.lastSentence = q.sentenceId;
        return SRS.save(updated).then(function () {
          return { state: updated, firstCorrect: correct && !hadCorrect };
        });
      });
    }

    return srsPromise.then(function (srsResult) {
      // -- per question stats --
      jobs.push(DB.getOne('qstats', q.id).then(function (prev) {
        var st = prev || { questionId: q.id, n: 0, ok: 0, lastAt: null };
        st.n += 1; if (correct) st.ok += 1;
        st.lastAt = Date.now();
        return DB.put('qstats', st);
      }));

      // -- history --
      jobs.push(pushRecent(q.sentenceId));

      jobs.push(DB.put('history', {
        day: today, at: Date.now(), questionId: q.id, itemId: q.itemId || null,
        domainId: q.domainId, type: q.type, correct: correct, wasDue: !!ctx.wasDue
      }));

      // -- streak + xp --
      return FQ.progress.load().then(function (p) {
        var streakResult = FQ.progress.registerStudyDay(p, today);
        var boost = ctx.boost && ctx.boost > 1 ? ctx.boost : 1;
        var gained = FQ.progress.xpFor(q.type, correct, {
          wasDue: ctx.wasDue,
          firstCorrect: srsResult && srsResult.firstCorrect
        }) * boost;
        p.xpTotal += gained;
        jobs.push(FQ.progress.save(p));

        return Promise.all(jobs).then(function () {
          return {
            correct: correct,
            xp: gained,
            streak: streakResult,
            progress: p,
            srs: srsResult ? srsResult.state : null
          };
        });
      });
    });
  }

  FQ.session = {
    TYPES: TYPES,
    build: build,
    loadRecent: loadRecent,
    pushRecent: pushRecent,
    RECENT_LIMIT: RECENT_LIMIT,
    counts: counts,
    loadPool: loadPool,
    recordAnswer: recordAnswer
  };

})(window.FQ = window.FQ || {});
