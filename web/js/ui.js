/* Frequency - rendering and view state.
   Views are plain sections toggled by name; there is no framework and no
   client-side router beyond a name -> section map. Each render function reads
   from the database and writes DOM, so no view state is duplicated in memory. */
(function (FQ) {
  'use strict';

  var U = FQ.util;
  var DB = FQ.db;
  var SRS = FQ.srs;

  var UI = FQ.ui = {};

  var VIEWS = ['welcome', 'paste-profile', 'domains', 'material', 'ready',
               'home', 'quiz', 'summary', 'library', 'stats', 'settings'];
  var TAB_VIEWS = { home: 1, library: 1, stats: 1, settings: 1 };

  var TYPE_LABEL = {
    gist: '内容リスニング',
    paraphrase: '言い換えリスニング',
    mc: '表現リスニング',
    dictation: 'ディクテーション',
    reorder: '並べ替え'
  };

  UI.current = null;

  UI.show = function (name) {
    if (VIEWS.indexOf(name) === -1) name = 'home';
    VIEWS.forEach(function (v) {
      var el = document.getElementById('view-' + v);
      if (el) el.hidden = (v !== name);
    });
    UI.current = name;

    U.els('.tabbtn').forEach(function (b) {
      b.classList.toggle('active', b.dataset.nav === name);
    });
    document.getElementById('tabbar').hidden = !TAB_VIEWS[name];
    document.getElementById('topstats').hidden = (name === 'quiz');
    window.scrollTo(0, 0);
  };

  UI.toast = function (msg, ms) {
    var t = document.getElementById('toast');
    t.textContent = msg;
    t.hidden = false;
    clearTimeout(t._timer);
    t._timer = setTimeout(function () { t.hidden = true; }, ms || 2200);
  };

  UI.confirm = function (title, body, okLabel) {
    var dlg = document.getElementById('confirm');
    document.getElementById('confirm-title').textContent = title;
    document.getElementById('confirm-body').textContent = body;
    document.getElementById('confirm-yes').textContent = okLabel || '実行する';
    return new Promise(function (resolve) {
      function done(v) {
        dlg.close();
        document.getElementById('confirm-yes').onclick = null;
        document.getElementById('confirm-no').onclick = null;
        resolve(v);
      }
      document.getElementById('confirm-yes').onclick = function () { done(true); };
      document.getElementById('confirm-no').onclick = function () { done(false); };
      dlg.showModal();
    });
  };

  UI.error = function (elId, messages) {
    var box = document.getElementById(elId);
    if (!messages || !messages.length) { box.hidden = true; box.innerHTML = ''; return; }
    box.hidden = false;
    box.innerHTML = '<strong>読み込めませんでした</strong><ul>' +
      messages.map(function (m) { return '<li>' + U.escapeHtml(m) + '</li>'; }).join('') +
      '</ul><p style="margin:8px 0 0">AIに「JSONのみで出力してください」と伝えて、もう一度お試しください。</p>';
  };

  // ------------------------------------------------------------- top stats

  UI.renderTopStats = function (progress) {
    document.getElementById('topstats').innerHTML =
      '<span class="pill streak">🔥 ' + progress.streak + '</span>' +
      '<span class="pill xp">⚡ ' + U.fmtNum(progress.xpTotal) + '</span>';
  };

  // ------------------------------------------------------------ onboarding

  UI.renderDomainPicker = function (domains) {
    var box = document.getElementById('domain-list');
    if (!domains.length) {
      box.innerHTML = '<p class="empty">分野が読み取れませんでした。プロフィールをもう一度読み込んでください。</p>';
      return;
    }
    box.innerHTML = domains.map(function (d) {
      return '<label class="domain-row' + (d.selected ? ' on' : '') + '" data-id="' + d.id + '">' +
        '<input type="checkbox"' + (d.selected ? ' checked' : '') + ' data-id="' + d.id + '">' +
        '<span><span class="dn">' + U.escapeHtml(d.name) + '</span>' +
        (d.nameJa ? '<span class="dj"> ' + U.escapeHtml(d.nameJa) + '</span>' : '') +
        '<span class="dmeta"><span class="imp">' + '★'.repeat(d.importance) + '</span>' +
        ' 重要度 ' + d.importance + '/5' +
        (d.hasMaterial ? ' ・教材あり' : '') +
        (d.contexts && d.contexts.length ? ' ・' + U.escapeHtml(d.contexts.slice(0, 2).join('、')) : '') +
        '</span></span></label>';
    }).join('');
  };

  UI.renderDomainSelect = function (selectId, domains, value, opts) {
    opts = opts || {};
    var sel = document.getElementById(selectId);
    if (!sel) return;
    var list = opts.materialOnly ? domains.filter(function (d) { return d.hasMaterial; }) : domains;
    var html = '';
    if (opts.includeAll) html += '<option value="all">すべての分野</option>';
    html += list.map(function (d) {
      return '<option value="' + d.id + '">' + U.escapeHtml(d.nameJa || d.name) + '</option>';
    }).join('');
    if (!list.length && !opts.includeAll) html = '<option value="">（分野がありません）</option>';
    sel.innerHTML = html;
    if (value) sel.value = value;
  };

  UI.renderReady = function (counts) {
    document.getElementById('ready-stats').innerHTML =
      '<div><b>' + counts.items + '</b><span>Learning Items</span></div>' +
      '<div><b>' + counts.questions + '</b><span>Questions</span></div>' +
      '<div><b>' + counts.sentences + '</b><span>英文</span></div>' +
      '<div><b>' + counts.domains + '</b><span>分野</span></div>';
  };

  // ------------------------------------------------------------------ home

  UI.renderHome = function (data) {
    var p = data.progress, c = data.counts;

    document.getElementById('m-due').textContent = c.due;
    document.getElementById('m-new').textContent = c.fresh;
    document.getElementById('m-xp').textContent = U.fmtNum(p.xpTotal);

    var hasMaterial = c.questions > 0;
    document.getElementById('home-empty').hidden = hasMaterial;
    document.getElementById('home-actions').hidden = !hasMaterial;

    var banner = document.getElementById('streak-banner');
    if (p.freezeUsed > 0) {
      banner.hidden = false;
      banner.innerHTML = '<strong>🧊 ストリークフリーズを使いました</strong>' +
        '<p>' + p.freezeUsed + '日ぶんを肩代わりしたので、連続記録は ' + p.streak + ' 日のままです。</p>';
    } else if (p.streakLostFrom > 0) {
      banner.hidden = false;
      banner.innerHTML = '<strong>おかえりなさい</strong>' +
        '<p>' + p.streakLostFrom + '日の連続記録が途切れました。今日やれば、またここから積み直せます。</p>';
    } else if (c.due > 0) {
      banner.hidden = false;
      banner.innerHTML = '<strong>今日の復習が ' + c.due + ' 件あります</strong>' +
        '<p>忘れかけたタイミングで出しています。ここで思い出すほど記憶に残ります。</p>';
    } else {
      banner.hidden = true;
    }

    document.getElementById('home-mini').innerHTML =
      '<div class="m"><b>' + p.bestStreak + '</b>最高記録</div>' +
      '<div class="m"><b>' + p.freezes + '</b>🧊 フリーズ</div>' +
      '<div class="m"><b>' + c.total + '</b>学習中の表現</div>' +
      (p.pendingBoost > 1 ? '<div class="m"><b>×2</b>次回XPブースト</div>' : '');
  };

  // ------------------------------------------------------------------ quiz

  UI.renderDots = function (total, index) {
    var box = document.getElementById('quiz-dots');
    box.setAttribute('aria-valuemin', '0');
    box.setAttribute('aria-valuemax', String(total));
    box.setAttribute('aria-valuenow', String(index));
    var html = '';
    for (var i = 0; i < total; i++) {
      html += '<span class="d' + (i < index ? ' done' : (i === index ? ' now' : '')) + '"></span>';
    }
    box.innerHTML = html;
  };

  UI.renderQuestion = function (ctx) {
    var q = ctx.question;

    document.getElementById('q-type').textContent = TYPE_LABEL[q.type] || q.type;
    document.getElementById('q-domain').textContent = ctx.domainLabel || '';
    document.getElementById('q-due').hidden = !ctx.wasDue;
    // Dictation wording depends on how the learner is answering right now,
    // so it is chosen at render time rather than baked into the question.
    var promptText = q.prompt || '';
    if (q.type === 'dictation') {
      promptText = ctx.inputMode === 'keyboard'
        ? '聞こえた表現を入力してください'
        : '聞こえた表現を、タップして組み立ててください';
    }
    document.getElementById('q-prompt').textContent = promptText;
    document.getElementById('q-feedback').hidden = true;
    document.getElementById('q-feedback').innerHTML = '';
    document.getElementById('btn-play').classList.add('pulse');

    var submit = document.getElementById('btn-submit');
    submit.disabled = true;
    submit.textContent = 'こたえる';

    var body = document.getElementById('q-body');
    body.innerHTML = '';

    if (q.type === 'mc' || q.type === 'gist' || q.type === 'paraphrase') renderMC(q, body, submit);
    else if (q.type === 'dictation') renderDictation(q, body, submit, ctx);
    else renderReorder(q, body, submit);

    UI.renderReplays(ctx.replaysLeft, ctx.level ? ctx.level.replays : 0);

    var warn = document.getElementById('audio-warn');
    if (!FQ.speech.supported) {
      warn.hidden = false;
      warn.textContent = 'このブラウザは音声読み上げに対応していません。英文を読んで解答してください。';
    } else if (!FQ.speech.available) {
      warn.hidden = false;
      warn.textContent = '英語の音声が見つかりません。設定から音声を選ぶか、OSに英語音声を追加してください。';
    } else {
      warn.hidden = true;
    }
  };

  // The answer getter is stashed on the submit button so the runtime can read
  // the current selection without the UI holding module-level state.
  function renderMC(q, body, submit) {
    body.innerHTML = '<div class="options" role="radiogroup">' +
      q.options.map(function (o, i) {
        return '<button class="option" type="button" role="radio" aria-checked="false" data-i="' + i + '">' +
          U.escapeHtml(o) + '</button>';
      }).join('') + '</div>';

    var chosen = null;
    U.els('.option', body).forEach(function (btn) {
      btn.addEventListener('click', function () {
        if (submit.dataset.locked === '1') return;
        U.els('.option', body).forEach(function (b) {
          b.classList.remove('sel'); b.setAttribute('aria-checked', 'false');
        });
        btn.classList.add('sel');
        btn.setAttribute('aria-checked', 'true');
        chosen = parseInt(btn.dataset.i, 10);
        submit.disabled = false;
      });
    });
    submit._getAnswer = function () { return chosen; };
  }

  function renderDictation(q, body, submit, opts) {
    opts = opts || {};
    var level = opts.level || { bankExtra: 6 };
    var useKeyboard = opts.inputMode === 'keyboard';

    // Space before punctuation looks wrong; join intelligently.
    var after = q.after || '';
    var glue = /^[.,!?;:]/.test(after) ? '' : ' ';

    // The blanked sentence is always visible: it is the only thing that says
    // which expression is wanted. Without it the tiles look arbitrary.
    var contextHtml =
      '<div class="dictation-line">' +
        U.escapeHtml(q.before || '') + (q.before ? ' ' : '') +
        '<span class="blank">' + '?'.repeat(Math.max(1, (q.answerWords || ['x']).length)) + '</span>' +
        glue + U.escapeHtml(after) +
      '</div>' +
      (q.translationJa
        ? '<p class="dictation-ja">' + U.escapeHtml(q.translationJa) + '</p>'
        : '');

    if (useKeyboard) {
      body.innerHTML = contextHtml +
        '<input class="dictation-input" id="dict-input" type="text" autocomplete="off" ' +
        'autocapitalize="off" autocorrect="off" spellcheck="false" aria-label="聞き取った表現">' +
        '<button class="linkbtn switch-input" type="button" data-input="tap">タップ入力に切り替える</button>';

      var input = document.getElementById('dict-input');
      input.addEventListener('input', function () {
        submit.disabled = !U.clean(input.value);
      });
      input.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' && !submit.disabled) submit.click();
      });
      submit._getAnswer = function () { return input.value; };
      return;
    }

    // Tap-to-build: the whole exercise is thumb-reachable buttons, which is
    // what makes this usable on a phone.
    var answer = (q.answerWords && q.answerWords.length)
      ? q.answerWords
      : U.clean(q.answerText || '').split(' ').filter(Boolean);

    // Decoys must never collide with an answer word, or the correct tile could
    // be indistinguishable from a wrong one. Reshuffled per render for variety.
    var answerKeys = {};
    answer.forEach(function (w) { answerKeys[w.toLowerCase()] = true; });

    // Scale the decoys to the answer. A flat count buries a two-word phrase
    // under a wall of irrelevant tiles, which reads as noise rather than
    // difficulty.
    var wanted = Math.min(level.bankExtra, Math.max(2, answer.length * 2));
    var decoys = U.take(
      U.shuffle((q.bankPool || []).filter(function (w) { return !answerKeys[w.toLowerCase()]; })),
      wanted
    );

    var bank = U.shuffle(
      answer.map(function (w, i) { return { w: w, id: 'a' + i }; })
        .concat(decoys.map(function (w, i) { return { w: w, id: 'd' + i }; }))
    );

    body.innerHTML = contextHtml +
      '<div class="slot" id="slot" aria-label="組み立てた表現"></div>' +
      '<div class="tiles" id="pool"></div>' +
      '<button class="linkbtn switch-input" type="button" data-input="keyboard">キーボードで入力する</button>';

    var slot = document.getElementById('slot');
    var pool = document.getElementById('pool');
    var placed = [];

    function draw() {
      pool.innerHTML = bank.map(function (t) {
        var used = placed.some(function (p) { return p.id === t.id; });
        return '<button class="tile' + (used ? ' used' : '') + '" type="button" data-id="' + t.id + '">' +
          U.escapeHtml(t.w) + '</button>';
      }).join('');
      slot.innerHTML = placed.map(function (t) {
        return '<button class="tile" type="button" data-p="' + t.id + '">' + U.escapeHtml(t.w) + '</button>';
      }).join('');
      submit.disabled = placed.length === 0;
    }

    pool.addEventListener('click', function (e) {
      var b = e.target.closest('.tile');
      if (!b || b.classList.contains('used') || submit.dataset.locked === '1') return;
      var t = bank.filter(function (x) { return x.id === b.dataset.id; })[0];
      placed.push(t);
      draw();
    });
    slot.addEventListener('click', function (e) {
      var b = e.target.closest('.tile');
      if (!b || submit.dataset.locked === '1') return;
      placed = placed.filter(function (x) { return x.id !== b.dataset.p; });
      draw();
    });

    draw();
    submit._getAnswer = function () {
      return placed.map(function (p) { return p.w; }).join(' ');
    };
  }

  function renderReorder(q, body, submit) {
    body.innerHTML = '<div class="slot" id="slot" aria-label="組み立てた英文"></div>' +
                     '<div class="tiles" id="pool"></div>';
    var slot = document.getElementById('slot');
    var pool = document.getElementById('pool');

    // Tiles carry their index so duplicate words stay distinguishable.
    var order = U.shuffle(q.tokens.map(function (t, i) { return { t: t, i: i }; }));
    var placed = [];

    function draw() {
      pool.innerHTML = order.map(function (tk) {
        var used = placed.some(function (p) { return p.i === tk.i; });
        return '<button class="tile' + (used ? ' used' : '') + '" type="button" data-i="' + tk.i + '">' +
          U.escapeHtml(tk.t) + '</button>';
      }).join('');
      slot.innerHTML = placed.map(function (tk) {
        return '<button class="tile" type="button" data-p="' + tk.i + '">' + U.escapeHtml(tk.t) + '</button>';
      }).join('');
      submit.disabled = placed.length !== q.tokens.length;
    }

    pool.addEventListener('click', function (e) {
      var b = e.target.closest('.tile');
      if (!b || b.classList.contains('used') || submit.dataset.locked === '1') return;
      var i = parseInt(b.dataset.i, 10);
      var tk = order.filter(function (x) { return x.i === i; })[0];
      placed.push(tk);
      draw();
    });
    slot.addEventListener('click', function (e) {
      var b = e.target.closest('.tile');
      if (!b || submit.dataset.locked === '1') return;
      var i = parseInt(b.dataset.p, 10);
      placed = placed.filter(function (x) { return x.i !== i; });
      draw();
    });

    draw();
    submit._getAnswer = function () { return placed.map(function (p) { return p.t; }); };
  }

  // Limiting replays is the main reason the exercise stays a listening task
  // rather than a puzzle solved by scrubbing the audio repeatedly.
  UI.renderReplays = function (left, max) {
    var el = document.getElementById('play-count');
    if (!el) return;
    if (!max) { el.textContent = ''; el.hidden = true; return; }
    el.hidden = false;
    el.textContent = '残り ' + Math.max(0, left) + ' 回';
    el.classList.toggle('out', left <= 0);
    var btn = document.getElementById('btn-play');
    btn.disabled = left <= 0;
  };

  UI.renderFeedback = function (res) {
    var box = document.getElementById('q-feedback');
    box.hidden = false;
    box.className = 'feedback ' + (res.correct ? 'ok' : 'ng');

    var head = res.correct ? '正解！' : (res.close ? 'おしい！スペルを確認しましょう' : 'もう一度覚えましょう');
    var html = '<div class="fb-head">' + head + '</div>' +
      '<div class="en">' + U.escapeHtml(res.sentence) + '</div>';
    if (res.translation) html += '<div class="ja">' + U.escapeHtml(res.translation) + '</div>';
    if (res.target) {
      html += '<div class="tgt">覚える表現: <strong>' + U.escapeHtml(res.target) + '</strong>' +
        (res.targetMeaning ? ' — ' + U.escapeHtml(res.targetMeaning) : '') + '</div>';
    }
    if (res.yourAnswer) {
      html += '<div class="tgt">あなたの入力: ' + U.escapeHtml(res.yourAnswer) + '</div>';
    }
    if (res.context) html += '<div class="tgt">場面: ' + U.escapeHtml(res.context) + '</div>';
    html += '<div class="tgt xp">+' + res.xp + ' XP</div>';
    box.innerHTML = html;
  };

  UI.markMC = function (q, chosen) {
    U.els('.option').forEach(function (b) {
      var i = parseInt(b.dataset.i, 10);
      if (i === q.correct) b.classList.add('right');
      else if (i === chosen) b.classList.add('wrong');
    });
  };

  // --------------------------------------------------------------- summary

  UI.renderSummary = function (s) {
    document.getElementById('summary-grid').innerHTML =
      '<div><b>+' + s.xp + (s.boosted ? ' ×2' : '') + '</b><span>獲得XP</span></div>' +
      '<div><b>' + s.correct + '/' + s.total + '</b><span>正解</span></div>' +
      '<div><b>🔥 ' + s.streak + '</b><span>' +
        (s.streakAdvanced ? '連続記録' : '今日は達成ずみ') + '</span></div>' +
      '<div><b>' + s.due + '</b><span>残りの復習</span></div>';
    var chest = document.getElementById('chest');
    chest.textContent = '🎁';
    chest.classList.remove('open');
    chest.disabled = false;
    document.getElementById('chest-result').textContent = '';
  };

  // --------------------------------------------------------------- library

  UI.renderLibrary = function (data) {
    var box = document.getElementById('lib-list');
    var q = U.normKey(data.query || '');

    if (data.mode === 'items') {
      var rows = data.items.filter(function (i) {
        return !q || U.normKey(i.text).indexOf(q) !== -1 || U.normKey(i.meaningJa || '').indexOf(q) !== -1;
      });
      if (!rows.length) { box.innerHTML = '<p class="empty">該当する表現がありません。</p>'; return; }
      box.innerHTML = rows.slice(0, 300).map(function (i) {
        var st = data.srsById[i.id];
        var badge = '';
        if (st && st.introduced) {
          if (SRS.isMastered(st)) badge = '<span class="box mastered">習得ずみ</span>';
          else if (SRS.isDue(st)) badge = '<span class="box due">復習</span>';
          else badge = '<span class="box">Box ' + st.box + ' / 次 ' + st.due + '</span>';
        } else {
          badge = '<span class="box">未学習</span>';
        }
        var acc = st ? SRS.accuracy(st) : { n: 0, pct: 0 };
        return '<div class="lib-row' + (i.disabled ? ' off' : '') + '">' +
          '<div class="lt">' + U.escapeHtml(i.text) + '</div>' +
          (i.meaningJa ? '<div class="lj">' + U.escapeHtml(i.meaningJa) + '</div>' : '') +
          '<div class="lb">' + badge +
          (acc.n ? '<span class="box">正答 ' + acc.pct + '% (' + acc.n + '回)</span>' : '') +
          '<button class="linkbtn" data-act="toggle-item" data-id="' + i.id + '">' +
          (i.disabled ? '出題を再開' : '今後出さない') + '</button>' +
          '<button class="linkbtn" data-act="del-item" data-id="' + i.id + '">削除</button>' +
          '</div></div>';
      }).join('');
    } else {
      var srows = data.sentences.filter(function (s) {
        return !q || U.normKey(s.text).indexOf(q) !== -1 || U.normKey(s.translationJa || '').indexOf(q) !== -1;
      });
      if (!srows.length) { box.innerHTML = '<p class="empty">該当する英文がありません。</p>'; return; }
      box.innerHTML = srows.slice(0, 300).map(function (s) {
        return '<div class="lib-row' + (s.disabled ? ' off' : '') + '">' +
          '<div class="lt">' + U.escapeHtml(s.text) + '</div>' +
          (s.translationJa ? '<div class="lj">' + U.escapeHtml(s.translationJa) + '</div>' : '') +
          '<div class="lb">' +
          '<span class="box">' + U.escapeHtml(s.level || '') + '</span>' +
          (s.speechAct ? '<span class="box">' + U.escapeHtml(s.speechAct) + '</span>' : '') +
          (s.quality != null ? '<span class="box">品質 ' + s.quality + '/5</span>' : '') +
          '<button class="linkbtn" data-act="speak" data-id="' + s.id + '">🔊 再生</button>' +
          '<button class="linkbtn" data-act="toggle-sentence" data-id="' + s.id + '">' +
          (s.disabled ? '出題を再開' : '今後出さない') + '</button>' +
          '</div></div>';
      }).join('');
    }
  };

  // ----------------------------------------------------------------- stats

  UI.renderStats = function (d) {
    var el = document.getElementById('stats-body');
    var fmt = d.formats;

    function fmtRow(label, f) {
      var pct = U.pct(f.ok, f.n);
      return '<div class="fmt-row"><span>' + label + '</span>' +
        '<span class="bar"><i style="width:' + pct + '%"></i></span>' +
        '<span class="n">' + (f.n ? pct + '%' : '—') + '</span></div>';
    }

    el.innerHTML =
      '<div class="stat-block"><h2>今日</h2><div class="stat-grid">' +
        '<div><b>' + d.today.n + '</b><span>回答数</span></div>' +
        '<div><b>' + (d.today.n ? U.pct(d.today.ok, d.today.n) + '%' : '—') + '</b><span>正答率</span></div>' +
        '<div><b>' + d.dueNow + '</b><span>残りの復習</span></div>' +
      '</div></div>' +

      '<div class="stat-block"><h2>継続</h2><div class="stat-grid">' +
        '<div><b>🔥 ' + d.progress.streak + '</b><span>連続日数</span></div>' +
        '<div><b>' + d.progress.bestStreak + '</b><span>最高記録</span></div>' +
        '<div><b>' + d.studyDays + '</b><span>学習日数</span></div>' +
      '</div>' +
      '<div class="heat" aria-label="直近28日の学習">' + d.heat.map(function (lv) {
        return '<i class="' + (lv ? 'l' + lv : '') + '"></i>';
      }).join('') + '</div>' +
      '<p class="hint" style="margin:8px 0 0">直近28日</p></div>' +

      '<div class="stat-block"><h2>形式別の正答率</h2>' +
        fmtRow('内容リスニング', fmt.gist) + fmtRow('言い換えリスニング', fmt.paraphrase) +
        fmtRow('ディクテーション', fmt.dictation) + fmtRow('並べ替え', fmt.reorder) +
        '<p class="hint" style="margin:6px 0 0">4択だけで正解しても習得とはみなしません。' +
        'ディクテーションか並べ替えで正解して初めて上位に進みます。</p></div>' +

      '<div class="stat-block"><h2>習得状況</h2><div class="stat-grid">' +
        '<div><b>' + d.mastered + '</b><span>習得ずみ</span></div>' +
        '<div><b>' + d.learning + '</b><span>学習中</span></div>' +
        '<div><b>' + d.fresh + '</b><span>未学習</span></div>' +
      '</div></div>' +

      (d.domains.length ?
      '<div class="stat-block"><h2>分野別</h2>' + d.domains.map(function (x) {
        return '<div class="fmt-row"><span>' + U.escapeHtml(x.name) + '</span>' +
          '<span class="bar"><i style="width:' + x.pct + '%"></i></span>' +
          '<span class="n">' + x.done + '/' + x.total + '</span></div>';
      }).join('') + '</div>' : '') +

      '<div class="stat-block"><h2>累計</h2><div class="stat-grid">' +
        '<div><b>' + U.fmtNum(d.progress.xpTotal) + '</b><span>XP</span></div>' +
        '<div><b>' + U.fmtNum(d.totalAnswers) + '</b><span>総回答数</span></div>' +
        '<div><b>' + d.progress.freezes + '</b><span>🧊 フリーズ</span></div>' +
      '</div></div>';
  };

})(window.FQ = window.FQ || {});
