/* Frequency - local question generation.
   The AI supplies sentences; the app turns each one into up to three question
   formats. Doing this locally keeps AI output small, guarantees the formats
   stay consistent, and means no AI call is ever needed to study. */
(function (FQ) {
  'use strict';

  var U = FQ.util;

  var MAX_REORDER_TOKENS = 12;
  var MIN_REORDER_TOKENS = 4;

  // --------------------------------------------------------------- tokenizer

  // Splits into tiles for the reorder exercise. Sentence-final punctuation is
  // stripped and re-applied at render time so it cannot leak word order;
  // internal punctuation (commas, apostrophes) stays glued to its word.
  function tokenize(text) {
    var trimmed = U.clean(text);
    var finalPunct = '';
    var m = trimmed.match(/([.!?]+)$/);
    if (m) { finalPunct = m[1]; trimmed = trimmed.slice(0, -finalPunct.length).trim(); }
    var tokens = trimmed.split(' ').filter(Boolean);
    return { tokens: tokens, finalPunct: finalPunct };
  }

  // ------------------------------------------------------------- dictation

  // Locate a target phrase inside the sentence, returning the exact original
  // substring plus the text around it.
  function locatePhrase(sentence, phrase) {
    var sTokens = sentence.split(' ');
    var pLen = phrase.split(' ').filter(Boolean).length;
    var pKey = U.answerKey(phrase);
    for (var i = 0; i + pLen <= sTokens.length; i++) {
      var slice = sTokens.slice(i, i + pLen).join(' ');
      // Compare ignoring surrounding punctuation, but keep the original text.
      if (U.answerKey(slice) === pKey) {
        return {
          before: sTokens.slice(0, i).join(' '),
          answer: slice,
          after: sTokens.slice(i + pLen).join(' ')
        };
      }
      // Allow a trailing comma/period on the final token of the match.
      var stripped = slice.replace(/[.,!?;:]+$/, '');
      if (U.answerKey(stripped) === pKey) {
        return {
          before: sTokens.slice(0, i).join(' '),
          answer: stripped,
          after: slice.slice(stripped.length) + ' ' + sTokens.slice(i + pLen).join(' ')
        };
      }
    }
    return null;
  }

  // --------------------------------------------------- distractor selection

  // Same domain, similar length, genuinely different meaning (§18).
  function pickDistractors(correct, pool, want, keyFn) {
    var correctKey = U.normKey(correct);
    var len = correct.length;
    var candidates = pool.filter(function (x) {
      var t = keyFn ? keyFn(x) : x;
      return t && U.normKey(t) !== correctKey;
    });
    candidates = U.uniqueBy(candidates, function (x) {
      return U.normKey(keyFn ? keyFn(x) : x);
    });
    // Prefer options of comparable length so the answer is not obvious by shape.
    candidates.sort(function (a, b) {
      var ta = (keyFn ? keyFn(a) : a).length, tb = (keyFn ? keyFn(b) : b).length;
      return Math.abs(ta - len) - Math.abs(tb - len);
    });
    // Take from a widened band, then shuffle, to avoid always picking the same trio.
    var band = candidates.slice(0, Math.max(want * 4, want));
    return U.take(U.shuffle(band), want);
  }

  // ------------------------------------------------------------- generation

  // sentences: newly added records. itemsById: lookup for targets.
  // corpus: all sentences (existing + new) used as a distractor source.
  function generateForSentences(sentences, itemsById, corpus) {
    var out = [];
    var all = corpus || sentences;
    var byDomain = U.groupBy(all, function (s) { return s.domainId; });
    var wordsByDomain = {};

    sentences.forEach(function (s) {
      var domainPool = (byDomain[s.domainId] || []).filter(function (x) {
        return x.id !== s.id && !x.disabled;
      });
      var targets = (s.itemIds || []).map(function (id) { return itemsById[id]; }).filter(Boolean);

      if (!wordsByDomain[s.domainId]) {
        wordsByDomain[s.domainId] = collectWords(byDomain[s.domainId] || []);
      }

      var para = buildParaphrase(s);
      if (para) out.push(para);

      var gist = buildGist(s, domainPool);
      if (gist) out.push(gist);

      var dict = buildDictation(s, targets, wordsByDomain[s.domainId]);
      if (dict) out.push(dict);

      var reorder = buildReorder(s, targets);
      if (reorder) out.push(reorder);
    });

    return out;
  }

  // Vocabulary drawn from the same domain, used as decoy tiles in the tap-to-
  // build dictation. Real domain words are far more confusable than random
  // filler, which is what makes the exercise worth doing.
  function collectWords(sentences) {
    var seen = Object.create(null);
    sentences.forEach(function (s) {
      (s.text || '').split(' ').forEach(function (raw) {
        var w = raw.replace(/[^A-Za-z'-]/g, '');
        if (w.length < 3) return;
        var k = w.toLowerCase();
        if (!seen[k]) seen[k] = w;
      });
    });
    return Object.keys(seen).map(function (k) { return seen[k]; });
  }

  function baseQuestion(s, type, variant, itemId) {
    return {
      id: 'q_' + s.id + '_' + type + (variant ? '_' + variant : ''),
      type: type,
      variant: variant || null,
      sentenceId: s.id,
      domainId: s.domainId,
      itemId: itemId || (s.itemIds && s.itemIds[0]) || null,
      text: s.text,
      translationJa: s.translationJa,
      level: s.level,
      context: s.context,
      disabled: false,
      createdAt: Date.now()
    };
  }

  // "Which English sentence says the same thing?" All four options restate the
  // whole sentence, so the answer cannot be found by spotting a fragment that
  // appeared verbatim in the audio - which is all the previous
  // expression-matching question really tested. Reading four near-identical
  // English sentences also puts more vocabulary in front of the learner.
  function buildParaphrase(s) {
    var correct = U.clean(s.paraphraseEn || '');
    if (!correct) return null;

    var wrong = U.uniqueBy(
      (s.paraphraseOptionsEn || []).filter(function (o) {
        return U.normKey(o) !== U.normKey(correct) && U.normKey(o) !== U.normKey(s.text);
      }),
      function (o) { return U.normKey(o); }
    );
    if (wrong.length < 3) return null;

    // Comparable length stops the answer standing out by shape alone.
    var picked = pickDistractors(correct, wrong, 3);
    if (picked.length < 3) return null;

    var choices = U.shuffle([correct].concat(picked));
    var q = baseQuestion(s, 'paraphrase', null, (s.itemIds && s.itemIds[0]) || null);
    q.prompt = '聞こえた英文の趣旨に最も近いのはどれですか？';
    q.options = choices;
    q.correct = choices.indexOf(correct);
    q.answerText = correct;
    return q;
  }

  // "Which of these is closest to what you heard?" - a comprehension question
  // rather than a vocabulary one. The AI supplies near-miss readings of the
  // same sentence (negation flipped, wrong actor, wrong tense), which are far
  // harder than borrowing an unrelated sentence's translation.
  function buildGist(s, domainPool) {
    if (!s.translationJa) return null;

    var near = (s.meaningOptionsJa || []).filter(function (o) {
      return U.normKey(o) !== U.normKey(s.translationJa);
    });
    var options, source;

    if (near.length >= 3) {
      options = U.take(U.shuffle(near), 3);
      source = 'authored';
    } else {
      // Fallback for material imported before this field existed: prefer
      // sentences from the same situation, which read more alike than random
      // ones from the domain.
      var ranked = domainPool.filter(function (x) { return x.translationJa; })
        .map(function (x) {
          var score = 0;
          if (x.context && x.context === s.context) score += 3;
          if (x.speechAct && x.speechAct === s.speechAct) score += 2;
          if ((x.itemIds || []).some(function (id) { return (s.itemIds || []).indexOf(id) !== -1; })) score += 4;
          // Similar length reads as a similar statement.
          score -= Math.abs(x.translationJa.length - s.translationJa.length) / 12;
          return { s: x, score: score };
        })
        .sort(function (a, b) { return b.score - a.score; })
        .map(function (r) { return r.s.translationJa; });

      var picked = U.uniqueBy(
        ranked.filter(function (t) { return U.normKey(t) !== U.normKey(s.translationJa); }),
        function (t) { return U.normKey(t); }
      );
      if (picked.length < 3) return null;
      // Take from the closest band so the options stay confusable.
      options = U.take(U.shuffle(picked.slice(0, 8)), 3);
      source = 'related';
    }

    var choices = U.shuffle([s.translationJa].concat(options));
    var q = baseQuestion(s, 'gist', null, (s.itemIds && s.itemIds[0]) || null);
    q.prompt = '聞こえた内容に最も近いのはどれですか？';
    q.options = choices;
    q.correct = choices.indexOf(s.translationJa);
    q.answerText = s.translationJa;
    q.optionSource = source;
    return q;
  }

  // Never dictate a whole sentence: the answer is the target expression.
  function buildDictation(s, targets, domainWords) {
    for (var i = 0; i < targets.length; i++) {
      var loc = locatePhrase(s.text, targets[i].text);
      if (loc && loc.answer.split(' ').length <= 4) {
        var q = baseQuestion(s, 'dictation', null, targets[i].id);
        q.prompt = '聞こえた表現を組み立ててください';
        q.before = loc.before;
        q.after = loc.after;
        q.answerText = loc.answer;
        q.meaningJa = targets[i].meaningJa || '';
        q.answerWords = loc.answer.split(' ').filter(Boolean);
        q.bankPool = decoyWords(q.answerWords, domainWords || [], 12);
        return q;
      }
    }
    return null;
  }

  // Decoys of comparable length to the answer words, so tile shape gives
  // nothing away.
  function decoyWords(answerWords, domainWords, want) {
    var taken = Object.create(null);
    answerWords.forEach(function (w) { taken[w.toLowerCase()] = 1; });
    var avgLen = U.sum(answerWords.map(function (w) { return w.length; })) /
                 Math.max(1, answerWords.length);

    var pool = domainWords.filter(function (w) { return !taken[w.toLowerCase()]; });
    pool.sort(function (a, b) {
      return Math.abs(a.length - avgLen) - Math.abs(b.length - avgLen);
    });
    return U.take(U.shuffle(pool.slice(0, want * 2)), want);
  }

  function buildReorder(s, targets) {
    var t = tokenize(s.text);
    if (t.tokens.length < MIN_REORDER_TOKENS || t.tokens.length > MAX_REORDER_TOKENS) return null;
    var q = baseQuestion(s, 'reorder', null, targets[0] ? targets[0].id : null);
    q.prompt = '単語を並べ替えて英文を完成させてください';
    q.tokens = t.tokens;
    q.finalPunct = t.finalPunct;
    q.answerText = s.text;
    return q;
  }

  // Adds paraphrase questions to material that already carries the field but
  // predates the format.
  function backfillParaphrase(questions, sentences) {
    var have = {};
    questions.forEach(function (q) { if (q.type === 'paraphrase') have[q.sentenceId] = true; });
    var out = [];
    (sentences || []).filter(function (s) { return !s.disabled; }).forEach(function (s) {
      if (have[s.id]) return;
      var q = buildParaphrase(s);
      if (q) out.push(q);
    });
    return out;
  }

  // Adds the gist question to material imported before that format existed.
  function backfillGist(questions, sentences) {
    var have = {};
    questions.forEach(function (q) { if (q.type === 'gist') have[q.sentenceId] = true; });

    var live = (sentences || []).filter(function (s) { return !s.disabled; });
    var byDomain = U.groupBy(live, function (s) { return s.domainId; });

    var out = [];
    live.forEach(function (s) {
      if (have[s.id]) return;
      var pool = (byDomain[s.domainId] || []).filter(function (x) { return x.id !== s.id; });
      var q = buildGist(s, pool);
      if (q) out.push(q);
    });
    return out;
  }

  // Material imported before tap-input existed has no word bank. Rebuilding it
  // from the stored answer and the domain vocabulary avoids asking the learner
  // to import everything again.
  function backfillDictation(questions, sentences) {
    var live = (sentences || []).filter(function (s) { return !s.disabled; });
    var byDomain = U.groupBy(live, function (s) { return s.domainId; });
    var wordCache = {};
    var updated = [];

    questions.forEach(function (q) {
      if (q.type !== 'dictation') return;
      if (q.answerWords && q.answerWords.length && q.bankPool && q.bankPool.length) return;

      var answer = U.clean(q.answerText || '');
      if (!answer) return;
      var answerWords = answer.split(' ').filter(Boolean);

      if (!wordCache[q.domainId]) {
        wordCache[q.domainId] = collectWords(byDomain[q.domainId] || []);
      }
      updated.push(Object.assign({}, q, {
        answerWords: answerWords,
        bankPool: decoyWords(answerWords, wordCache[q.domainId], 12),
        prompt: '聞こえた表現を組み立ててください'
      }));
    });
    return updated;
  }

  // -------------------------------------------------------------- grading

  function gradeDictation(input, answer) {
    var a = U.answerKey(input || '');
    var b = U.answerKey(answer || '');
    if (!a) return { correct: false, close: false };
    if (a === b) return { correct: true, close: false };
    // A single-character slip is reported as "close" so the UI can show the
    // spelling without treating it as a pass.
    return { correct: false, close: editDistance(a, b) <= 1 };
  }

  function editDistance(a, b) {
    if (Math.abs(a.length - b.length) > 2) return 99;
    var prev = [], cur = [], i, j;
    for (j = 0; j <= b.length; j++) prev[j] = j;
    for (i = 1; i <= a.length; i++) {
      cur[0] = i;
      for (j = 1; j <= b.length; j++) {
        cur[j] = Math.min(
          prev[j] + 1, cur[j - 1] + 1,
          prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1)
        );
      }
      prev = cur.slice();
    }
    return prev[b.length];
  }

  function gradeReorder(arrangedTokens, question) {
    return arrangedTokens.join(' ') === question.tokens.join(' ');
  }

  // Integrity checks used after import and by the settings screen.
  function validateQuestion(q, sentencesById) {
    var problems = [];
    if (!q.id) problems.push('id なし');
    if (['mc', 'gist', 'paraphrase', 'dictation', 'reorder'].indexOf(q.type) === -1) problems.push('type 不明: ' + q.type);
    if (!q.sentenceId || (sentencesById && !sentencesById[q.sentenceId])) problems.push('参照先の英文がない');
    if (!U.clean(q.text)) problems.push('英文が空');
    if (q.type === 'mc' || q.type === 'gist' || q.type === 'paraphrase') {
      if (!Array.isArray(q.options) || q.options.length !== 4) problems.push('選択肢が4個でない');
      else if (q.correct == null || q.correct < 0 || q.correct > 3) problems.push('正解位置が不正');
      else if (U.uniqueBy(q.options, function (o) { return U.normKey(o); }).length !== 4) {
        problems.push('選択肢が重複');
      }
    }
    if (q.type === 'dictation' && !U.clean(q.answerText)) problems.push('答えが空');
    if (q.type === 'reorder' && (!Array.isArray(q.tokens) || q.tokens.length < 3)) {
      problems.push('並べ替えトークンが不足');
    }
    return problems;
  }

  FQ.questions = {
    generateForSentences: generateForSentences,
    tokenize: tokenize,
    locatePhrase: locatePhrase,
    backfillDictation: backfillDictation,
    backfillGist: backfillGist,
    backfillParaphrase: backfillParaphrase,
    buildParaphrase: buildParaphrase,
    buildGist: buildGist,
    gradeDictation: gradeDictation,
    gradeReorder: gradeReorder,
    validateQuestion: validateQuestion
  };

})(window.FQ = window.FQ || {});
