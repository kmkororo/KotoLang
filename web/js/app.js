/* Frequency - application controller.
   Owns navigation, the quiz runtime and every event binding. Nothing here
   contacts a network: the only outside interaction is the user pasting text
   they obtained from their own AI. */
(function (FQ) {
  'use strict';

  var U = FQ.util;
  var DB = FQ.db;
  var UI = FQ.ui;
  var SRS = FQ.srs;

  var app = {
    progress: null,
    settings: null,
    profile: null,
    domains: [],
    activeDomain: 'all',
    run: null,         // active session
    libMode: 'items'
  };

  // ------------------------------------------------------------ navigation

  function go(name) {
    UI.show(name);
    if (name === 'home') return renderHome();
    if (name === 'library') return renderLibrary();
    if (name === 'stats') return renderStats();
    if (name === 'settings') return renderSettings();
    if (name === 'material') return renderMaterialScreen();
    return Promise.resolve();
  }

  function refreshTop() { UI.renderTopStats(app.progress); }

  // ------------------------------------------------------------------ home

  function renderHome() {
    return FQ.session.counts(app.activeDomain).then(function (counts) {
      UI.renderDomainSelect('home-domain', app.domains.filter(function (d) { return d.hasMaterial; }),
        app.activeDomain, { includeAll: true });
      UI.renderHome({ progress: app.progress, counts: counts });
      refreshTop();
      // Banners describe a one-time event, so clear the flags once shown.
      if (app.progress.freezeUsed || app.progress.streakLostFrom) {
        app.progress.freezeUsed = 0;
        app.progress.streakLostFrom = 0;
        FQ.progress.save(app.progress);
      }
    });
  }

  // ------------------------------------------------------------ quiz cycle

  function startSession(count) {
    return FQ.session.build({ domainId: app.activeDomain, count: count })
      .then(function (built) {
        if (built.empty) {
          UI.toast('出題できる問題がありません。教材を追加してください。');
          return go('material');
        }
        app.run = {
          items: built.items,
          pool: built.pool,
          index: 0,
          correct: 0,
          xp: 0,
          boost: app.progress.pendingBoost > 1 ? app.progress.pendingBoost : 1,
          answered: false
        };
        // The boost is spent the moment a session starts.
        if (app.progress.pendingBoost > 1) {
          app.progress.pendingBoost = 0;
          FQ.progress.save(app.progress);
        }
        UI.show('quiz');
        return showQuestion();
      });
  }

  // keepReplays re-renders the same question (e.g. after switching input
  // method) without refunding the replay budget, which would otherwise be an
  // easy way to listen indefinitely.
  function showQuestion(keepReplays) {
    var run = app.run;
    var slot = run.items[run.index];
    var q = slot.question;
    var domain = run.pool.domainById[q.domainId];
    var level = FQ.progress.levelOf(app.settings);

    run.answered = false;
    if (!keepReplays) run.replaysLeft = level.replays || 0;
    document.getElementById('btn-submit').dataset.locked = '0';

    UI.renderDots(run.items.length, run.index);
    UI.renderQuestion({
      question: q,
      wasDue: slot.wasDue,
      domainLabel: domain ? (domain.nameJa || domain.name) : '',
      level: level,
      inputMode: app.settings.inputMode,
      replaysLeft: run.replaysLeft
    });

    if (!keepReplays) playAudio(true);
    return Promise.resolve();
  }

  // firstPlay is free; every later press spends one of the remaining replays.
  function playAudio(firstPlay) {
    var run = app.run;
    if (!run) return;
    var level = FQ.progress.levelOf(app.settings);
    var q = run.items[run.index].question;

    if (!firstPlay && level.replays) {
      if (run.replaysLeft <= 0) return;
      run.replaysLeft -= 1;
      UI.renderReplays(run.replaysLeft, level.replays);
    }

    document.getElementById('btn-play').classList.remove('pulse');
    FQ.speech.speak(q.text, {
      rate: FQ.progress.rateOf(app.settings),
      delay: firstPlay ? 420 : 180
    });
  }

  function submitAnswer() {
    var run = app.run;
    var submit = document.getElementById('btn-submit');

    // Second press advances to the next question.
    if (run.answered) return nextQuestion();

    var slot = run.items[run.index];
    var q = slot.question;
    var given = submit._getAnswer ? submit._getAnswer() : null;

    var correct = false, close = false, yourAnswer = null;
    if (q.type === 'mc' || q.type === 'gist' || q.type === 'paraphrase') {
      correct = (given === q.correct);
      UI.markMC(q, given);
    } else if (q.type === 'dictation') {
      var graded = FQ.questions.gradeDictation(given, q.answerText);
      correct = graded.correct; close = graded.close;
      yourAnswer = U.clean(given);
    } else {
      correct = FQ.questions.gradeReorder(given || [], q);
      yourAnswer = (given || []).join(' ');
    }

    run.answered = true;
    submit.dataset.locked = '1';
    if (correct) run.correct += 1;

    var item = q.itemId ? run.pool.itemById[q.itemId] : null;

    return FQ.session.recordAnswer({
      question: q, correct: correct, wasDue: slot.wasDue, boost: run.boost
    }).then(function (res) {
      app.progress = res.progress;
      run.xp += res.xp;
      run.streakResult = res.streak;

      UI.renderFeedback({
        correct: correct,
        close: close,
        sentence: q.text + (q.finalPunct && q.type === 'reorder' ? '' : ''),
        translation: q.translationJa,
        target: (q.type === 'gist') ? (item ? item.text : null)
                : (q.answerText && q.type !== 'reorder' ? q.answerText : (item ? item.text : null)),
        targetMeaning: item ? item.meaningJa : null,
        yourAnswer: (!correct && yourAnswer) ? yourAnswer : null,
        context: q.context,
        xp: res.xp
      });

      refreshTop();
      submit.disabled = false;
      submit.textContent = (run.index < run.items.length - 1) ? '次の問題へ' : '完了する';
      submit.focus();
    });
  }

  function nextQuestion() {
    var run = app.run;
    run.index += 1;
    if (run.index < run.items.length) return showQuestion();
    return finishSession();
  }

  function finishSession() {
    var run = app.run;
    FQ.speech.stop();
    return FQ.session.counts(app.activeDomain).then(function (counts) {
      UI.show('summary');
      UI.renderSummary({
        xp: run.xp,
        boosted: run.boost > 1,
        correct: run.correct,
        total: run.items.length,
        streak: app.progress.streak,
        streakAdvanced: run.streakResult ? run.streakResult.advanced : false,
        due: counts.due
      });
      refreshTop();
    });
  }

  function quitSession() {
    FQ.speech.stop();
    app.run = null;
    return go('home');
  }

  // --------------------------------------------------------------- library

  function renderLibrary() {
    return Promise.all([
      DB.getAll('items'), DB.getAll('sentences'), DB.getAll('srs')
    ]).then(function (res) {
      var items = res[0], sentences = res[1], srsAll = res[2];
      var srsById = {};
      srsAll.forEach(function (s) { srsById[s.itemId] = s; });

      UI.renderDomainSelect('lib-domain', app.domains, app.activeDomain,
        { includeAll: true, materialOnly: true });

      var d = app.activeDomain;
      if (d && d !== 'all') {
        items = items.filter(function (i) { return (i.domainIds || []).indexOf(d) !== -1; });
        sentences = sentences.filter(function (s) { return s.domainId === d; });
      }

      UI.renderLibrary({
        mode: app.libMode,
        items: items,
        sentences: sentences,
        srsById: srsById,
        query: document.getElementById('lib-search').value
      });
    });
  }

  // ----------------------------------------------------------------- stats

  function renderStats() {
    return Promise.all([
      DB.getAll('history'), DB.getAll('srs'), DB.getAll('items'), DB.getAll('questions')
    ]).then(function (res) {
      var history = res[0], srsAll = res[1], items = res[2], questions = res[3];
      var today = U.today();

      var todayRows = history.filter(function (h) { return h.day === today; });
      var formats = { gist: { n: 0, ok: 0 }, paraphrase: { n: 0, ok: 0 },
                      dictation: { n: 0, ok: 0 }, reorder: { n: 0, ok: 0 }, mc: { n: 0, ok: 0 } };
      history.forEach(function (h) {
        var f = formats[h.type];
        if (f) { f.n += 1; if (h.correct) f.ok += 1; }
      });

      var days = {};
      history.forEach(function (h) { days[h.day] = (days[h.day] || 0) + 1; });

      // 28-day activity grid, oldest first.
      var heat = [];
      for (var i = 27; i >= 0; i--) {
        var key = U.addDays(today, -i);
        var n = days[key] || 0;
        heat.push(n === 0 ? 0 : (n < 3 ? 1 : (n < 8 ? 2 : 3)));
      }

      var mastered = 0, learning = 0;
      srsAll.forEach(function (s) {
        if (SRS.isMastered(s)) mastered += 1;
        else if (s.introduced) learning += 1;
      });

      var itemsWithQuestions = {};
      questions.forEach(function (q) { if (q.itemId) itemsWithQuestions[q.itemId] = true; });
      var totalItems = Object.keys(itemsWithQuestions).length;

      var byDomain = app.domains.filter(function (d) { return d.hasMaterial; }).map(function (d) {
        var ids = items.filter(function (i) { return (i.domainIds || []).indexOf(d.id) !== -1; });
        var done = ids.filter(function (i) {
          var s = srsAll.filter(function (x) { return x.itemId === i.id; })[0];
          return s && s.introduced;
        }).length;
        return {
          name: d.nameJa || d.name, done: done, total: ids.length,
          pct: ids.length ? Math.round((done / ids.length) * 100) : 0
        };
      });

      UI.renderStats({
        progress: app.progress,
        today: { n: todayRows.length, ok: todayRows.filter(function (h) { return h.correct; }).length },
        dueNow: SRS.dueCount(srsAll.reduce(function (a, s) { a[s.itemId] = s; return a; }, {})),
        studyDays: Object.keys(days).length,
        heat: heat,
        formats: formats,
        mastered: mastered,
        learning: learning,
        fresh: Math.max(0, totalItems - mastered - learning),
        domains: byDomain,
        totalAnswers: history.length
      });
    });
  }

  // -------------------------------------------------------------- settings

  function renderSettings() {
    var sel = document.getElementById('set-voice');
    var voices = FQ.speech.voices;
    if (!FQ.speech.supported) {
      sel.innerHTML = '<option>音声に対応していません</option>';
      sel.disabled = true;
    } else if (!voices.length) {
      sel.innerHTML = '<option>英語の音声が見つかりません</option>';
      sel.disabled = true;
    } else {
      sel.disabled = false;
      sel.innerHTML = voices.map(function (v, i) {
        return '<option value="' + i + '">' + U.escapeHtml(v.name) + ' (' + v.lang + ')</option>';
      }).join('');
      var cur = FQ.speech.chosen;
      if (cur) {
        var idx = voices.indexOf(cur);
        if (idx >= 0) sel.value = String(idx);
      }
    }

    document.getElementById('voice-help').textContent = FQ.speech.supported
      ? (voices.length ? 'カタカナ英語に聞こえる場合は、Neural / Natural / Online と付く音声を選ぶと自然になります。'
                       : 'Windowsの「設定 → 時刻と言語 → 音声」から英語の音声を追加し、ブラウザを再起動してください。')
      : 'このブラウザでは音声読み上げを利用できません。学習機能は問題なく使えます。';

    var rate = FQ.progress.rateOf(app.settings);
    document.getElementById('set-rate').value = rate;
    document.getElementById('rate-val').textContent = '×' + rate.toFixed(2) +
      (app.settings.speechRate == null ? '（難易度に連動）' : '');
    document.getElementById('set-goal').value = String(app.settings.dailyGoal);

    var level = FQ.progress.levelOf(app.settings);
    document.getElementById('set-difficulty').value = level.key;
    document.getElementById('difficulty-hint').textContent = level.hint;
    document.getElementById('set-input').value = app.settings.inputMode || 'tap';

    document.getElementById('storage-note').textContent = DB.kind === 'indexeddb'
      ? '保存先: IndexedDB（この端末のブラウザ内）'
      : '保存先: localStorage（IndexedDBが使えないため簡易保存です。容量が限られるので、こまめにエクスポートしてください）';

    document.getElementById('build-note').textContent =
      'schema ' + FQ.prompts.SCHEMA_VERSION + ' / backup ' + FQ.backup.BACKUP_VERSION +
      ' / ' + (navigator.onLine ? 'オンライン' : 'オフライン');
    return renderResetPanel();
  }

  // ------------------------------------------------------------ reset panel

  function renderResetPanel() {
    return FQ.reset.summary().then(function (s) {
      document.getElementById('reset-summary').innerHTML =
        '<span>分野 <b>' + s.domains + '</b></span>' +
        '<span>表現 <b>' + s.items + '</b></span>' +
        '<span>英文 <b>' + s.sentences + '</b></span>' +
        '<span>問題 <b>' + s.questions + '</b></span>' +
        '<span>学習中 <b>' + s.srs + '</b></span>' +
        '<span>回答履歴 <b>' + s.history + '</b></span>';

      var sel = document.getElementById('reset-domain');
      var keep = sel.value;
      sel.innerHTML = s.byDomain.map(function (d) {
        return '<option value="' + d.id + '">' + U.escapeHtml(d.name) +
          (d.hasMaterial ? '（教材 ' + d.sentences + '文）' : '（教材なし）') + '</option>';
      }).join('') || '<option value="">（分野がありません）</option>';
      if (keep && s.byDomain.some(function (d) { return d.id === keep; })) sel.value = keep;

      var chosen = s.byDomain.filter(function (d) { return d.id === sel.value; })[0];
      document.getElementById('reset-domain-detail').textContent = chosen
        ? '表現 ' + chosen.items + ' 件 / 英文 ' + chosen.sentences + ' 件 / 問題 ' + chosen.questions + ' 件'
        : '';

      var none = !s.byDomain.length;
      document.getElementById('btn-reset-domain').disabled = none;
      document.getElementById('btn-reset-domain-all').disabled = none;
    });
  }

  function resetDomain(removeDomain) {
    var sel = document.getElementById('reset-domain');
    var id = sel.value;
    if (!id) return Promise.resolve();
    var name = sel.options[sel.selectedIndex].textContent;

    return FQ.reset.planDomain(id).then(function (plan) {
      var c = plan.counts;
      var body = '表現 ' + c.items + ' 件、英文 ' + c.sentences + ' 件、問題 ' + c.questions +
        ' 件と、その復習予定を削除します。';
      if (c.sharedItems) {
        body += 'ほかの分野でも使われている ' + c.sharedItems +
          ' 件の表現は、この分野との紐づけを外すだけで残します。';
      }
      body += removeDomain ? '分野そのものも一覧から消えます。'
                           : '分野は残るので、すぐに教材を入れ直せます。';

      return UI.confirm(removeDomain ? 'この分野ごと削除しますか' : 'この分野の教材を削除しますか',
        body, '削除する'
      ).then(function (yes) {
        if (!yes) return null;
        return FQ.reset.deleteDomainMaterial(id, removeDomain).then(function (done) {
          showResetResult(name + ' を削除しました', done);
          return relaunchToSettings();
        });
      });
    });
  }

  function showResetResult(title, counts) {
    var box = document.getElementById('reset-result');
    box.hidden = false;
    box.className = 'result';
    var rows = [
      ['表現', counts.items], ['英文', counts.sentences], ['問題', counts.questions],
      ['復習予定', counts.srs], ['回答履歴', counts.history]
    ].filter(function (r) { return typeof r[1] === 'number'; });
    box.innerHTML = '<strong>' + U.escapeHtml(title) + '</strong><dl>' +
      rows.map(function (r) { return '<dt>' + r[0] + '</dt><dd>' + r[1] + '</dd>'; }).join('') +
      '</dl>';
  }

  // Reload cached state after a reset without leaving the settings screen.
  function relaunchToSettings() {
    return Promise.all([
      FQ.progress.load(), DB.getMeta('profile', null), reloadDomains()
    ]).then(function (res) {
      app.progress = res[0];
      app.profile = res[1];
      app.activeDomain = 'all';
      refreshTop();
      return renderSettings();
    });
  }

  // Rebuilds the option list. The current selection is passed back in, because
  // regenerating the options otherwise resets the select to its first entry -
  // which made choosing a domain appear to do nothing.
  function renderMaterialScreen() {
    var sel = document.getElementById('material-domain');
    var current = sel.value;
    UI.renderDomainSelect('material-domain', app.domains, current || null, {});
    return updateMaterialHint();
  }

  // Called when the user changes the selection: only the description updates,
  // never the option list.
  function updateMaterialHint() {
    var sel = document.getElementById('material-domain');
    var d = app.domains.filter(function (x) { return x.id === sel.value; })[0];
    var hint = document.getElementById('material-hint');

    if (!d) {
      hint.textContent = 'まずプロフィールを読み込んで分野を作成してください。';
      return Promise.resolve();
    }
    return DB.getAllByIndex('sentences', 'byDomain', d.id).then(function (existing) {
      hint.textContent = '「' + (d.nameJa || d.name) + '」のプロンプトをコピーして、AIに貼り付けてください。' +
        (existing.length ? '（この分野には英文が ' + existing.length + ' 件あります。追加で取り込めます）'
                         : '（この分野はまだ教材がありません）');
    });
  }

  // ------------------------------------------------------------ clipboard

  function promptFor(kind) {
    if (kind === 'profile') return Promise.resolve(FQ.prompts.profile());
    if (kind === 'audit') {
      return DB.getAll('sentences').then(function (list) {
        var texts = list.filter(function (s) { return !s.disabled; })
          .slice(0, 120).map(function (s, i) { return (i + 1) + '. ' + s.text; }).join('\n');
        return FQ.prompts.audit(texts);
      });
    }
    if (kind === 'domain') {
      return Promise.resolve(FQ.prompts.newDomain({
        existingDomains: app.domains.map(function (d) { return d.name; }),
        level: app.profile ? app.profile.english_level : 'B1'
      }));
    }
    // material
    var sel = document.getElementById('material-domain');
    var d = app.domains.filter(function (x) { return x.id === (sel && sel.value); })[0] || app.domains[0];
    if (!d) return Promise.resolve(FQ.prompts.material({}));
    return DB.getAll('items').then(function (items) {
      var existing = items.filter(function (i) { return (i.domainIds || []).indexOf(d.id) !== -1; })
        .map(function (i) { return i.text; });
      return FQ.prompts.material({
        domainName: d.name, domainJa: d.nameJa,
        level: app.profile ? app.profile.english_level : 'B1',
        roles: app.profile ? app.profile.roles : [],
        priorities: app.profile ? app.profile.learning_priorities : [],
        contexts: d.contexts, existingItems: existing
      });
    });
  }

  function copyText(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(text)
        .then(function () { return true; })
        .catch(function () { return legacyCopy(text); });
    }
    return Promise.resolve(legacyCopy(text));
  }

  function legacyCopy(text) {
    try {
      var ta = document.createElement('textarea');
      ta.value = text;
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      var ok = document.execCommand('copy');
      document.body.removeChild(ta);
      return ok;
    } catch (e) { return false; }
  }

  // ----------------------------------------------------------------- boot

  function reloadDomains() {
    return DB.getAll('domains').then(function (list) {
      list.sort(function (a, b) { return (b.importance || 0) - (a.importance || 0); });
      app.domains = list;
      return list;
    });
  }

  function counts() {
    return Promise.all([
      DB.count('items'), DB.count('sentences'), DB.count('questions'), DB.count('domains')
    ]).then(function (r) {
      return { items: r[0], sentences: r[1], questions: r[2], domains: r[3] };
    });
  }

  // Brings material imported by an older build up to date in place, so nothing
  // has to be re-imported when question formats gain new fields.
  function migrate() {
    return Promise.all([DB.getAll('questions'), DB.getAll('sentences'), DB.getAll('domains')])
      .then(function (res) {
        var questions = res[0], sentences = res[1], domains = res[2];

        // hasMaterial drives the domain pickers, so recompute it from what is
        // actually stored rather than trusting a flag that could drift.
        var counted = {};
        sentences.forEach(function (s) { counted[s.domainId] = (counted[s.domainId] || 0) + 1; });
        var fixed = domains.filter(function (d) {
          return !!d.hasMaterial !== (counted[d.id] > 0);
        }).map(function (d) {
          return Object.assign({}, d, { hasMaterial: counted[d.id] > 0, updatedAt: Date.now() });
        });

        // Gist was briefly stored as an mc variant. Remove those so the newly
        // typed questions replace them rather than both being served.
        var legacy = questions.filter(function (q) {
          return q.type === 'mc' && q.variant === 'gist';
        });
        if (legacy.length) {
          questions = questions.filter(function (q) {
            return !(q.type === 'mc' && q.variant === 'gist');
          });
        }

        var patched = FQ.questions.backfillDictation(questions, sentences);
        var gists = FQ.questions.backfillGist(questions, sentences);
        var paras = FQ.questions.backfillParaphrase(questions, sentences);

        if (!patched.length && !fixed.length && !gists.length && !paras.length && !legacy.length) return 0;
        return DB.delMany('questions', legacy.map(function (q) { return q.id; })).then(function () {
          return DB.putBulk({ questions: patched.concat(gists).concat(paras), domains: fixed });
        }).then(function () {
          if (gists.length) {
            console.info("[Frequency] added " + gists.length + " gist questions");
          }
          if (patched.length) {
            console.info('[Frequency] backfilled ' + patched.length + ' dictation questions');
          }
          if (fixed.length) {
            console.info('[Frequency] corrected hasMaterial on ' + fixed.length + ' domain(s)');
          }
          return patched.length + fixed.length;
        });
      })
      .catch(function (e) {
        // A failed migration must never block startup.
        console.warn('[Frequency] migration skipped:', e && e.message);
        return 0;
      });
  }

  function boot() {
    return DB.ready()
      .then(function () {
        return Promise.all([
          FQ.progress.load(), FQ.progress.loadSettings(), DB.getMeta('profile', null), reloadDomains()
        ]);
      })
      .then(function (res) {
        app.progress = FQ.progress.reconcileStreak(res[0]);
        app.settings = res[1];
        app.profile = res[2];

        FQ.speech.setRate(FQ.progress.rateOf(app.settings));
        if (app.settings.voiceName) FQ.speech.setVoiceName(app.settings.voiceName);
        FQ.speech.onChange(function () {
          if (UI.current === 'settings') renderSettings();
        });

        return FQ.progress.save(app.progress);
      })
      .then(migrate)
      .then(counts)
      .then(function (c) {
        document.getElementById('boot').hidden = true;
        document.getElementById('app').hidden = false;
        bindEvents();
        refreshTop();
        return routeForState();
      })
      .catch(function (err) {
        console.error('[Frequency] boot failed', err);
        document.getElementById('boot').innerHTML =
          '<div class="boot-inner"><p>起動できませんでした。</p><p class="hint">' +
          U.escapeHtml(err && err.message ? err.message : String(err)) + '</p></div>';
      });
  }

  // --------------------------------------------------------------- events

  function bindEvents() {
    // Speech engines need a user gesture before they will make sound, and the
    // first utterance is the one most likely to be clipped, so prime it early.
    ['pointerdown', 'keydown'].forEach(function (evt) {
      document.addEventListener(evt, function primeOnce() {
        FQ.speech.warmUp();
        document.removeEventListener(evt, primeOnce);
      }, { once: true });
    });

    // navigation
    U.delegate(document.body, 'click', '[data-nav]', function (e, node) {
      e.preventDefault();
      go(node.dataset.nav);
    });
    U.on(document.getElementById('brand-home'), 'click', function () { go('home'); });

    // prompt copy buttons
    U.delegate(document.body, 'click', '[data-copy]', function (e, node) {
      promptFor(node.dataset.copy).then(copyText).then(function (ok) {
        UI.toast(ok ? 'プロンプトをコピーしました' : 'コピーできませんでした。手動で選択してください');
      });
    });

    U.on(document.getElementById('go-paste-profile'), 'click', function () { go('paste-profile'); });
    U.on(document.getElementById('go-restore'), 'click', function () {
      go('settings').then(function () { document.getElementById('import-file').click(); });
    });

    // ---- profile import
    U.on(document.getElementById('btn-load-profile'), 'click', function () {
      var raw = document.getElementById('profile-input').value;
      UI.error('profile-error', null);
      FQ.importer.importProfile(raw).then(function (res) {
        if (!res.ok) return UI.error('profile-error', res.errors);
        app.profile = res.profile;
        return reloadDomains().then(function (list) {
          UI.renderDomainPicker(list);
          UI.show('domains');
          UI.toast('プロフィールを読み込みました（' + res.summary.domains + '分野）');
        });
      }).catch(function (err) {
        UI.error('profile-error', [err.message || String(err)]);
      });
    });

    // ---- domain selection
    U.delegate(document.getElementById('domain-list'), 'change', 'input[type=checkbox]', function (e, node) {
      var d = app.domains.filter(function (x) { return x.id === node.dataset.id; })[0];
      if (!d) return;
      d.selected = node.checked;
      node.closest('.domain-row').classList.toggle('on', node.checked);
      DB.put('domains', d);
    });

    U.on(document.getElementById('btn-domains-next'), 'click', function () {
      var chosen = app.domains.filter(function (d) { return d.selected; });
      if (!chosen.length) return UI.toast('分野を1つ以上選んでください');
      go('material').then(function () {
        document.getElementById('material-domain').value = chosen[0].id;
        renderMaterialScreen();
      });
    });

    U.on(document.getElementById('material-domain'), 'change', updateMaterialHint);

    // ---- material import
    U.on(document.getElementById('btn-load-material'), 'click', function () {
      var raw = document.getElementById('material-input').value;
      UI.error('material-error', null);
      var btn = this;
      btn.disabled = true;
      FQ.importer.importMaterial(raw).then(function (res) {
        btn.disabled = false;
        if (!res.ok) return UI.error('material-error', res.errors);
        var s = res.summary;
        var box = document.getElementById('material-result');
        box.hidden = false;
        box.innerHTML = '<strong>教材を追加しました</strong><dl>' +
          '<dt>分野</dt><dd>' + U.escapeHtml(s.domain) + '</dd>' +
          '<dt>Learning Items</dt><dd>' + s.newItems + '</dd>' +
          '<dt>英文</dt><dd>' + s.newSentences + '</dd>' +
          '<dt>生成された問題</dt><dd>' + s.questions + '</dd>' +
          (s.duplicateSentences ? '<dt>重複で除外</dt><dd>' + s.duplicateSentences + '</dd>' : '') +
          (s.linkedItems ? '<dt>他分野と共有</dt><dd>' + s.linkedItems + '</dd>' : '') +
          '</dl>';
        document.getElementById('material-input').value = '';
        return reloadDomains().then(counts).then(function (c) {
          UI.renderReady(c);
          setTimeout(function () { UI.show('ready'); }, 900);
        });
      }).catch(function (err) {
        btn.disabled = false;
        UI.error('material-error', [err.message || String(err)]);
      });
    });

    U.on(document.getElementById('btn-ready-start'), 'click', function () { startSession(1); });

    // ---- home
    U.on(document.getElementById('home-domain'), 'change', function () {
      app.activeDomain = this.value;
      renderHome();
    });
    U.on(document.getElementById('btn-start'), 'click', function () {
      startSession(Math.max(5, app.settings.dailyGoal));
    });
    U.on(document.getElementById('btn-start-one'), 'click', function () { startSession(1); });

    // ---- quiz
    U.on(document.getElementById('btn-play'), 'click', function () { playAudio(false); });
    U.on(document.getElementById('btn-submit'), 'click', function () {
      if (app.run) submitAnswer();
    });
    U.on(document.getElementById('btn-quit'), 'click', function () {
      if (!app.run) return go('home');
      UI.confirm('学習をやめますか', 'ここまでの回答は保存されています。', 'やめる')
        .then(function (yes) { if (yes) quitSession(); });
    });

    // ---- chest
    U.on(document.getElementById('chest'), 'click', function () {
      var btn = this;
      if (btn.disabled) return;
      btn.disabled = true;
      btn.classList.add('open');
      btn.textContent = '✨';
      var reward = FQ.progress.openChest();
      FQ.progress.applyChest(app.progress, reward);
      FQ.progress.save(app.progress).then(function () {
        document.getElementById('chest-result').innerHTML =
          U.escapeHtml(reward.label) + '<br><span class="hint">' + U.escapeHtml(reward.note) + '</span>';
        refreshTop();
      });
    });

    // ---- library
    U.on(document.getElementById('lib-domain'), 'change', function () {
      app.activeDomain = this.value;
      renderLibrary();
    });
    U.on(document.getElementById('lib-search'), 'input', function () { renderLibrary(); });
    U.delegate(document.body, 'click', '[data-lib]', function (e, node) {
      app.libMode = node.dataset.lib;
      U.els('[data-lib]').forEach(function (b) { b.classList.toggle('active', b === node); });
      renderLibrary();
    });

    U.delegate(document.getElementById('lib-list'), 'click', '[data-act]', function (e, node) {
      var id = node.dataset.id, act = node.dataset.act;
      if (act === 'speak') {
        DB.getOne('sentences', id).then(function (s) {
          if (s) FQ.speech.speak(s.text, { rate: FQ.progress.rateOf(app.settings) });
        });
      } else if (act === 'toggle-sentence') {
        toggleSentence(id);
      } else if (act === 'toggle-item') {
        toggleItem(id);
      } else if (act === 'del-item') {
        deleteItem(id);
      }
    });

    // ---- settings
    U.on(document.getElementById('set-voice'), 'change', function () {
      var v = FQ.speech.voices[parseInt(this.value, 10)];
      if (!v) return;
      FQ.speech.setVoiceName(v.name);
      app.settings.voiceName = v.name;
      FQ.progress.saveSettings(app.settings);
      FQ.speech.speak('This is how your listening practice will sound.', { rate: FQ.progress.rateOf(app.settings) });
    });
    U.on(document.getElementById('set-rate'), 'input', function () {
      app.settings.speechRate = parseFloat(this.value);
      document.getElementById('rate-val').textContent = '×' + app.settings.speechRate.toFixed(2);
      FQ.speech.setRate(app.settings.speechRate);
      FQ.progress.saveSettings(app.settings);
    });
    U.on(document.getElementById('btn-test-voice'), 'click', function () {
      var ok = FQ.speech.speak('We need to review the repair policy before proceeding.',
        { rate: FQ.progress.rateOf(app.settings) });
      if (!ok) UI.toast('再生できる英語音声がありません');
    });
    U.on(document.getElementById('set-goal'), 'change', function () {
      app.settings.dailyGoal = parseInt(this.value, 10) || 1;
      FQ.progress.saveSettings(app.settings);
    });

    U.on(document.getElementById('set-difficulty'), 'change', function () {
      app.settings.difficulty = this.value;
      // Changing level re-arms the speed unless the user pinned one by hand.
      FQ.speech.setRate(FQ.progress.rateOf(app.settings));
      FQ.progress.saveSettings(app.settings).then(renderSettings);
      UI.toast('難易度を「' + FQ.progress.levelOf(app.settings).label + '」にしました');
    });

    U.on(document.getElementById('set-input'), 'change', function () {
      app.settings.inputMode = this.value;
      FQ.progress.saveSettings(app.settings);
    });

    U.on(document.getElementById('btn-rate-auto'), 'click', function () {
      app.settings.speechRate = null;
      FQ.speech.setRate(FQ.progress.rateOf(app.settings));
      FQ.progress.saveSettings(app.settings).then(renderSettings);
    });

    // Let the learner switch input method from inside a question, since which
    // one suits depends on whether they are on a phone right now.
    U.delegate(document.body, 'click', '.switch-input', function (e, node) {
      app.settings.inputMode = node.dataset.input;
      FQ.progress.saveSettings(app.settings);
      if (app.run && !app.run.answered) showQuestion(true);
    });

    U.on(document.getElementById('btn-audit'), 'click', function () {
      var p = document.getElementById('audit-panel');
      p.hidden = !p.hidden;
    });
    U.on(document.getElementById('btn-load-audit'), 'click', function () {
      var raw = document.getElementById('audit-input').value;
      FQ.importer.importAudit(raw).then(function (res) {
        var box = document.getElementById('audit-result');
        box.hidden = false;
        if (!res.ok) {
          box.className = 'alert';
          box.textContent = res.errors.join(' / ');
          return;
        }
        box.className = 'result';
        box.innerHTML = '<strong>監査結果を読み込みました</strong><dl>' +
          '<dt>照合できた英文</dt><dd>' + res.summary.matched + '</dd>' +
          '<dt>低品質（1-2）</dt><dd>' + res.summary.low + '</dd></dl>' +
          (res.summary.low ? '<button class="btn btn-ghost" id="btn-disable-low">低品質の英文を出題から外す</button>' : '');
        var b = document.getElementById('btn-disable-low');
        if (b) b.addEventListener('click', function () {
          FQ.importer.disableLowQuality().then(function (r) {
            UI.toast(r.sentences + '件の英文を出題から外しました');
          });
        });
      });
    });

    // ---- backup
    U.on(document.getElementById('btn-export'), 'click', function () {
      FQ.backup.exportAll().then(function (payload) {
        FQ.backup.download(payload);
        UI.toast('エクスポートしました');
      }).catch(function (e) { UI.toast('エクスポートに失敗しました'); });
    });

    U.on(document.getElementById('btn-import'), 'click', function () {
      document.getElementById('import-file').click();
    });

    U.on(document.getElementById('import-file'), 'change', function () {
      var file = this.files && this.files[0];
      this.value = '';
      if (!file) return;
      FQ.backup.readFile(file).then(function (obj) {
        var err = FQ.backup.validateBackup(obj);
        if (err) throw new Error(err);
        return UI.confirm('データを復元しますか',
          '「統合」は既存データを残して追加します。取り消せないため、先に現在のデータをエクスポートしておくことをおすすめします。',
          '統合して復元'
        ).then(function (yes) {
          if (!yes) return null;
          return FQ.backup.restore(obj, 'merge');
        });
      }).then(function (res) {
        if (!res) return;
        var box = document.getElementById('backup-result');
        box.hidden = false;
        box.className = 'result';
        box.innerHTML = '<strong>復元しました</strong><p>' + res.restored + ' 件のレコードを読み込みました。</p>';
        return relaunch();
      }).catch(function (err) {
        var box = document.getElementById('backup-result');
        box.hidden = false;
        box.className = 'alert';
        box.textContent = err.message || String(err);
      });
    });

    // ---- scoped resets
    U.on(document.getElementById('reset-domain'), 'change', renderResetPanel);

    U.on(document.getElementById('btn-reset-domain'), 'click', function () {
      resetDomain(false);
    });
    U.on(document.getElementById('btn-reset-domain-all'), 'click', function () {
      resetDomain(true);
    });

    U.on(document.getElementById('btn-reset-material'), 'click', function () {
      FQ.reset.planAllMaterial().then(function (c) {
        return UI.confirm('教材をすべて削除しますか',
          '表現 ' + c.items + ' 件、英文 ' + c.sentences + ' 件、問題 ' + c.questions +
          ' 件と、その復習予定を削除します。分野の一覧・ストリーク・XP・学習履歴は残ります。',
          '教材を削除する'
        ).then(function (yes) {
          if (!yes) return null;
          return FQ.reset.deleteAllMaterial().then(function (done) {
            showResetResult('教材を削除しました', done);
            return relaunchToSettings();
          });
        });
      });
    });

    U.on(document.getElementById('btn-reset-progress'), 'click', function () {
      UI.confirm('学習記録をリセットしますか',
        '復習予定・正答率・学習履歴・ストリーク・XPが消え、すべて未学習に戻ります。教材はそのまま残ります。',
        '記録をリセットする'
      ).then(function (yes) {
        if (!yes) return null;
        return FQ.reset.resetProgress().then(function (done) {
          showResetResult('学習記録をリセットしました', done);
          return relaunchToSettings();
        });
      });
    });

    // Re-running the profile prompt is not destructive: importing a new profile
    // updates existing domains in place and leaves their material attached.
    U.on(document.getElementById('btn-reprofile'), 'click', function () {
      UI.toast('プロンプトをコピーして、AIの回答を貼り付けてください');
      go('paste-profile');
    });

    U.on(document.getElementById('btn-reset-profile'), 'click', function () {
      FQ.reset.summary().then(function (s) {
        return UI.confirm('プロフィールと分野を初期化しますか',
          '分野 ' + s.domains + ' 件とプロフィールを削除します。分野に属する教材（表現 ' +
          s.items + ' 件、英文 ' + s.sentences + ' 件、問題 ' + s.questions +
          ' 件）も一緒に消えます。ストリーク・XP・回答履歴は残ります。' +
          'この後、最初のプロンプトからやり直せます。',
          '初期化する'
        ).then(function (yes) {
          if (!yes) return null;
          return FQ.reset.resetProfile().then(function (done) {
            UI.toast('プロフィールと分野を初期化しました');
            return relaunch();
          });
        });
      });
    });

    U.on(document.getElementById('btn-wipe'), 'click', function () {
      UI.confirm('すべて初期化しますか',
        'プロフィール・分野・教材・学習履歴・ストリーク・XP・音声や難易度の設定まで、' +
        'すべて消えて初回起動の状態に戻ります。この操作は取り消せません。',
        '完全に初期化する'
      ).then(function (yes) {
        if (!yes) return;
        // A true factory state: settings go too, since the user asked for
        // everything rather than "everything except my preferences".
        return FQ.reset.factoryReset(false).then(function () {
          UI.toast('初期化しました');
          return relaunch();
        });
      });
    });

    // Keyboard: number keys pick options, Enter submits.
    document.addEventListener('keydown', function (e) {
      if (UI.current !== 'quiz' || !app.run) return;
      var q = app.run.items[app.run.index].question;
      if (q.type === 'mc' && !app.run.answered && /^[1-4]$/.test(e.key)) {
        var opt = U.els('.option')[parseInt(e.key, 10) - 1];
        if (opt) opt.click();
      } else if (e.key === 'Enter') {
        var s = document.getElementById('btn-submit');
        if (!s.disabled && document.activeElement !== s) { e.preventDefault(); s.click(); }
      }
    });
  }

  function toggleSentence(id) {
    return DB.getOne('sentences', id).then(function (s) {
      if (!s) return;
      s.disabled = !s.disabled;
      // Questions built from a disabled sentence must stop appearing too.
      return DB.getAllByIndex('questions', 'bySentence', id).then(function (qs) {
        var upd = qs.map(function (q) { return Object.assign({}, q, { disabled: s.disabled }); });
        return DB.putBulk({ sentences: [s], questions: upd });
      }).then(renderLibrary);
    });
  }

  function toggleItem(id) {
    return DB.getOne('items', id).then(function (i) {
      if (!i) return;
      i.disabled = !i.disabled;
      return DB.getAllByIndex('questions', 'byItem', id).then(function (qs) {
        var upd = qs.map(function (q) { return Object.assign({}, q, { disabled: i.disabled }); });
        return DB.putBulk({ items: [i], questions: upd });
      }).then(renderLibrary);
    });
  }

  // Removing an item also removes its questions and schedule, but leaves the
  // sentences: they may carry other items worth keeping.
  function deleteItem(id) {
    return UI.confirm('この表現を削除しますか',
      '関連する問題と学習状況も削除されます。英文は残ります。', '削除する'
    ).then(function (yes) {
      if (!yes) return;
      return DB.getAllByIndex('questions', 'byItem', id).then(function (qs) {
        return DB.delMany('questions', qs.map(function (q) { return q.id; }));
      }).then(function () {
        return Promise.all([DB.del('items', id), DB.del('srs', id)]);
      }).then(function () {
        UI.toast('削除しました');
        return renderLibrary();
      });
    });
  }

  // Where the app belongs given what is actually stored. Shared by startup and
  // by every reset, so wiping the profile really does return to step one
  // instead of stranding the user on an empty home screen.
  function routeForState() {
    return counts().then(function (c) {
      if (!app.profile && !c.domains) return go('welcome');
      if (!c.questions) return go(app.domains.length ? 'material' : 'welcome');
      return go('home');
    });
  }

  function relaunch() {
    return Promise.all([
      FQ.progress.load(), FQ.progress.loadSettings(), DB.getMeta('profile', null), reloadDomains()
    ]).then(function (res) {
      app.progress = FQ.progress.reconcileStreak(res[0]);
      app.settings = res[1];
      app.profile = res[2];
      app.activeDomain = 'all';
      FQ.speech.setRate(FQ.progress.rateOf(app.settings));
      if (app.settings.voiceName) FQ.speech.setVoiceName(app.settings.voiceName);
      refreshTop();
      return routeForState();
    });
  }

  // Service worker only registers over http(s); file:// has no SW support and
  // must not produce an error.
  function registerSW() {
    if (!('serviceWorker' in navigator)) return;
    if (location.protocol !== 'http:' && location.protocol !== 'https:') return;
    navigator.serviceWorker.register('sw.js').catch(function (e) {
      console.warn('[Frequency] service worker not registered:', e && e.message);
    });
  }

  FQ.app = app;
  FQ.debug = {
    state: app,
    startSession: startSession,
    go: go,
    counts: counts,
    reloadDomains: reloadDomains,
    relaunch: relaunch
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () { boot(); registerSW(); });
  } else { boot(); registerSW(); }

})(window.FQ = window.FQ || {});
