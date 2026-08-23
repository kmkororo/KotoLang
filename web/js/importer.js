/* Frequency - import pipeline.
   Raw AI reply -> extract -> parse -> validate -> normalize -> dedupe -> store.
   Each stage is separate so a failure can be reported precisely and never
   crashes the app. Users are never asked to hand-edit JSON. */
(function (FQ) {
  'use strict';

  var U = FQ.util;
  var DB = FQ.db;

  var SUPPORTED_SCHEMAS = ['1.0'];
  var LEVELS = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  // ------------------------------------------------------------- 1. extract

  // AI replies routinely wrap JSON in prose or fences. Try progressively looser
  // strategies rather than demanding a clean response.
  function extractJson(raw) {
    if (typeof raw !== 'string') return { ok: false, reason: 'empty' };
    var text = raw.replace(/^﻿/, '').trim();
    if (!text) return { ok: false, reason: 'empty' };

    var candidates = [];

    // a) the whole thing
    candidates.push(text);

    // b) fenced blocks (```json ... ``` or ``` ... ```)
    var fence = /```[a-zA-Z]*\s*([\s\S]*?)```/g, m;
    while ((m = fence.exec(text)) !== null) {
      if (m[1] && m[1].trim()) candidates.push(m[1].trim());
    }

    // c) every balanced {...} region, longest first
    balancedObjects(text).forEach(function (s) { candidates.push(s); });

    var errors = [];
    for (var i = 0; i < candidates.length; i++) {
      try {
        var parsed = JSON.parse(candidates[i]);
        if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
          return { ok: true, data: parsed };
        }
      } catch (e) { errors.push(e.message); }
    }
    return { ok: false, reason: 'parse', detail: errors[0] || null };
  }

  // Brace scanner that respects strings and escapes, so braces inside text
  // values do not split the object.
  function balancedObjects(text) {
    var out = [], depth = 0, start = -1, inStr = false, esc = false;
    for (var i = 0; i < text.length; i++) {
      var c = text[i];
      if (inStr) {
        if (esc) { esc = false; }
        else if (c === '\\') { esc = true; }
        else if (c === '"') { inStr = false; }
        continue;
      }
      if (c === '"') { inStr = true; continue; }
      if (c === '{') { if (depth === 0) start = i; depth++; }
      else if (c === '}') {
        depth--;
        if (depth === 0 && start >= 0) { out.push(text.slice(start, i + 1)); start = -1; }
        if (depth < 0) depth = 0;
      }
    }
    return out.sort(function (a, b) { return b.length - a.length; });
  }

  // ------------------------------------------------------------ 2. validate

  function validate(data) {
    var errors = [];
    if (!data || typeof data !== 'object') {
      return { ok: false, errors: ['JSON オブジェクトではありません'] };
    }
    var sv = data.schema_version;
    if (!sv) errors.push('schema_version がありません');
    else if (SUPPORTED_SCHEMAS.indexOf(String(sv)) === -1) {
      errors.push('未対応の schema_version です: ' + sv);
    }

    var type = data.type;
    if (['profile', 'material', 'audit'].indexOf(type) === -1) {
      // Infer when the AI omitted it but the shape is unambiguous.
      if (data.learning_items || data.sentences) type = 'material';
      else if (data.domains || data.profile) type = 'profile';
      else if (data.results) type = 'audit';
      else errors.push('type が profile / material / audit のいずれでもありません');
    }

    if (type === 'profile') {
      if (!Array.isArray(data.domains)) errors.push('domains が配列ではありません');
      else if (!data.domains.length) errors.push('domains が空です');
    } else if (type === 'material') {
      if (!data.domain || !U.clean(data.domain.name)) errors.push('domain.name がありません');
      if (!Array.isArray(data.learning_items)) errors.push('learning_items が配列ではありません');
      if (!Array.isArray(data.sentences)) errors.push('sentences が配列ではありません');
      if (Array.isArray(data.sentences) && !data.sentences.length) errors.push('sentences が空です');
    } else if (type === 'audit') {
      if (!Array.isArray(data.results)) errors.push('results が配列ではありません');
    }

    return { ok: errors.length === 0, errors: errors, type: type };
  }

  // ----------------------------------------------------------- 3. normalize

  function normLevel(v, fallback) {
    var s = U.clean(v).toUpperCase();
    return LEVELS.indexOf(s) !== -1 ? s : (fallback || null);
  }

  function normInt(v, lo, hi, dflt) {
    var n = parseInt(v, 10);
    if (isNaN(n)) return dflt;
    return U.clamp(n, lo, hi);
  }

  function normFloat(v, lo, hi, dflt) {
    var n = parseFloat(v);
    if (isNaN(n)) return dflt;
    return U.clamp(n, lo, hi);
  }

  function normStrArray(v, max) {
    if (!Array.isArray(v)) return [];
    return U.uniqueBy(
      v.map(function (x) { return U.clean(x); }).filter(Boolean),
      function (x) { return x.toLowerCase(); }
    ).slice(0, max || 24);
  }

  function normalizeProfile(data) {
    var p = data.profile || {};
    var profile = {
      english_level: normLevel(p.english_level, null) || 'UNKNOWN',
      level_confidence: normFloat(p.level_confidence, 0, 1, 0.5),
      roles: normStrArray(p.roles, 12),
      learning_priorities: normStrArray(p.learning_priorities, 12),
      notes: U.clean(p.notes).slice(0, 600),
      updatedAt: Date.now()
    };
    var domains = (data.domains || []).map(function (d) {
      var name = U.clean(d && d.name);
      if (!name) return null;
      return {
        name: name,
        nameJa: U.clean(d.name_ja),
        importance: normInt(d.importance, 1, 5, 3),
        confidence: normFloat(d.confidence, 0, 1, 0.5),
        contexts: normStrArray(d.contexts, 10),
        sampleTerms: normStrArray(d.sample_terms, 12)
      };
    }).filter(Boolean);

    domains = U.uniqueBy(domains, function (d) { return U.normKey(d.name); });
    return { profile: profile, domains: domains };
  }

  function normalizeMaterial(data) {
    var d = data.domain || {};
    var domain = {
      name: U.clean(d.name),
      nameJa: U.clean(d.name_ja),
      importance: normInt(d.importance, 1, 5, 3),
      confidence: normFloat(d.confidence, 0, 1, 0.7),
      contexts: normStrArray(d.contexts, 10)
    };

    var items = (data.learning_items || []).map(function (it) {
      var text = U.clean(it && it.text);
      if (!text || text.length > 80) return null;
      return {
        text: text,
        normKey: U.normKey(text),
        type: ['term', 'phrase', 'collocation', 'expression'].indexOf(U.clean(it.type)) !== -1
          ? U.clean(it.type) : 'term',
        meaningJa: U.clean(it.meaning_ja),
        priority: normInt(it.priority, 1, 5, 3),
        confidence: normFloat(it.confidence, 0, 1, 0.7),
        relatedTerms: normStrArray(it.related_terms, 10),
        contexts: normStrArray(it.contexts, 8),
        distractorsJa: normStrArray(it.distractors_ja, 6)
      };
    }).filter(Boolean);
    items = U.uniqueBy(items, function (i) { return i.normKey; });

    var sentences = (data.sentences || []).map(function (s) {
      var text = U.clean(s && s.text);
      if (!text) return null;
      var words = text.split(' ').length;
      // Guard against fragments and paragraph-length output.
      if (words < 3 || words > 40) return null;
      return {
        text: text,
        normKey: U.normKey(text),
        translationJa: U.clean(s.translation_ja),
        level: normLevel(s.level, 'B1'),
        context: U.clean(s.context),
        speechAct: U.clean(s.speech_act) || 'statement',
        targets: normStrArray(s.targets, 6),
        naturalness: normInt(s.naturalness, 1, 5, 4),
        // Near-miss readings of the same sentence, used by the gist question.
        // Anything identical to the correct translation is dropped, since it
        // would create a second valid answer.
        meaningOptionsJa: normStrArray(s.meaning_options_ja, 5).filter(function (o) {
          return U.normKey(o) !== U.normKey(s.translation_ja || '');
        }),
        // English restatement plus near-miss English options. A paraphrase that
        // merely repeats the original is useless, so it is discarded.
        paraphraseEn: (function () {
          var p = U.clean(s.paraphrase_en);
          return (p && U.normKey(p) !== U.normKey(s.text || '')) ? p : '';
        })(),
        paraphraseOptionsEn: normStrArray(s.paraphrase_options_en, 5).filter(function (o) {
          return U.normKey(o) !== U.normKey(s.paraphrase_en || '') &&
                 U.normKey(o) !== U.normKey(s.text || '');
        })
      };
    }).filter(Boolean);
    sentences = U.uniqueBy(sentences, function (s) { return s.normKey; });

    return { domain: domain, items: items, sentences: sentences };
  }

  // -------------------------------------------------------------- 4. persist

  // Profile import: writes the profile and creates/updates domain records.
  // Existing domains keep their id so already-imported material stays linked.
  function importProfile(raw) {
    var ex = extractJson(raw);
    if (!ex.ok) return Promise.resolve(failure(ex));
    var v = validate(ex.data);
    if (!v.ok) return Promise.resolve({ ok: false, stage: 'validate', errors: v.errors });
    if (v.type !== 'profile') {
      return Promise.resolve({ ok: false, stage: 'validate',
        errors: ['これはプロフィールの回答ではありません (type: ' + v.type + ')'] });
    }

    var norm = normalizeProfile(ex.data);

    return DB.getAll('domains').then(function (existing) {
      var byKey = {};
      existing.forEach(function (d) { byKey[d.normKey] = d; });

      var now = Date.now();
      var toWrite = norm.domains.map(function (d) {
        var key = U.normKey(d.name);
        var prev = byKey[key];
        return {
          id: prev ? prev.id : U.slugId('dom', key),
          name: d.name,
          nameJa: d.nameJa || (prev ? prev.nameJa : ''),
          normKey: key,
          importance: d.importance,
          confidence: d.confidence,
          contexts: d.contexts.length ? d.contexts : (prev ? prev.contexts : []),
          sampleTerms: d.sampleTerms,
          selected: prev ? prev.selected : false,
          hasMaterial: prev ? !!prev.hasMaterial : false,
          createdAt: prev ? prev.createdAt : now,
          updatedAt: now
        };
      });

      var batch = {
        id: U.uid('batch'),
        kind: 'profile',
        promptVersion: FQ.prompts.versions.profile,
        at: now,
        counts: { domains: toWrite.length }
      };

      return DB.putBulk({ domains: toWrite, batches: [batch] })
        .then(function () { return DB.setMeta('profile', norm.profile); })
        .then(function () {
          return {
            ok: true,
            profile: norm.profile,
            domains: toWrite,
            added: toWrite.filter(function (d) { return !byKey[d.normKey]; }).length,
            updated: toWrite.filter(function (d) { return !!byKey[d.normKey]; }).length,
            summary: {
              domains: toWrite.length,
              roles: norm.profile.roles.length,
              priorities: norm.profile.learning_priorities.length
            }
          };
        });
    });
  }

  // Material import: merges into whatever already exists. Never destructive.
  function importMaterial(raw) {
    var ex = extractJson(raw);
    if (!ex.ok) return Promise.resolve(failure(ex));
    var v = validate(ex.data);
    if (!v.ok) return Promise.resolve({ ok: false, stage: 'validate', errors: v.errors });
    if (v.type !== 'material') {
      return Promise.resolve({ ok: false, stage: 'validate',
        errors: ['これは教材の回答ではありません (type: ' + v.type + ')'] });
    }

    var norm = normalizeMaterial(ex.data);
    if (!norm.sentences.length) {
      return Promise.resolve({ ok: false, stage: 'validate',
        errors: ['使用できる英文が1件もありませんでした'] });
    }

    return Promise.all([
      DB.getAll('domains'), DB.getAll('items'), DB.getAll('sentences')
    ]).then(function (res) {
      var domains = res[0], allItems = res[1], allSentences = res[2];
      var now = Date.now();

      // -- domain (reuse if the name already exists) --
      var dKey = U.normKey(norm.domain.name);
      var domain = domains.filter(function (d) { return d.normKey === dKey; })[0];
      if (!domain) {
        domain = {
          id: U.slugId('dom', dKey), name: norm.domain.name, nameJa: norm.domain.nameJa,
          normKey: dKey, importance: norm.domain.importance, confidence: norm.domain.confidence,
          contexts: norm.domain.contexts, sampleTerms: [], selected: true,
          hasMaterial: true, createdAt: now, updatedAt: now
        };
      } else {
        domain = Object.assign({}, domain, {
          nameJa: domain.nameJa || norm.domain.nameJa,
          contexts: domain.contexts && domain.contexts.length ? domain.contexts : norm.domain.contexts,
          hasMaterial: true, selected: true, updatedAt: now
        });
      }

      // -- learning items --
      // Identity is the normalized text. The same term appearing in another
      // domain links to that domain rather than creating a duplicate, so one
      // concept keeps one SRS state.
      var itemByKey = {};
      allItems.forEach(function (i) { itemByKey[i.normKey] = i; });

      var itemsToWrite = [], newItems = 0, linkedItems = 0;
      norm.items.forEach(function (it) {
        var prev = itemByKey[it.normKey];
        if (prev) {
          var domainIds = prev.domainIds.slice();
          var changed = false;
          if (domainIds.indexOf(domain.id) === -1) { domainIds.push(domain.id); changed = true; linkedItems++; }
          var merged = Object.assign({}, prev, {
            domainIds: domainIds,
            meaningJa: prev.meaningJa || it.meaningJa,
            distractorsJa: (prev.distractorsJa && prev.distractorsJa.length) ? prev.distractorsJa : it.distractorsJa,
            relatedTerms: U.uniqueBy((prev.relatedTerms || []).concat(it.relatedTerms), function (x) { return x.toLowerCase(); }).slice(0, 10),
            priority: Math.max(prev.priority || 3, it.priority),
            updatedAt: now
          });
          if (changed || JSON.stringify(merged) !== JSON.stringify(prev)) itemsToWrite.push(merged);
          itemByKey[it.normKey] = merged;
        } else {
          var rec = {
            id: U.slugId('item', it.normKey),
            text: it.text, normKey: it.normKey, type: it.type,
            meaningJa: it.meaningJa, priority: it.priority, confidence: it.confidence,
            relatedTerms: it.relatedTerms, contexts: it.contexts,
            distractorsJa: it.distractorsJa,
            domainIds: [domain.id],
            disabled: false, createdAt: now, updatedAt: now
          };
          itemsToWrite.push(rec);
          itemByKey[it.normKey] = rec;
          newItems++;
        }
      });

      // -- sentences --
      var sentKeys = {};
      allSentences.forEach(function (s) { sentKeys[s.normKey] = s; });

      var sentencesToWrite = [], newSentences = 0, dupSentences = 0;
      norm.sentences.forEach(function (s) {
        if (sentKeys[s.normKey]) { dupSentences++; return; }
        // Resolve target texts to item ids; keep only targets that exist and
        // actually appear in the sentence.
        var itemIds = [];
        s.targets.forEach(function (t) {
          var rec = itemByKey[U.normKey(t)];
          if (rec && containsPhrase(s.text, rec.text)) {
            if (itemIds.indexOf(rec.id) === -1) itemIds.push(rec.id);
          }
        });
        // Fall back to any known item that appears verbatim in the sentence.
        if (!itemIds.length) {
          Object.keys(itemByKey).forEach(function (k) {
            if (itemIds.length) return;
            var rec = itemByKey[k];
            if (rec.domainIds.indexOf(domain.id) !== -1 && containsPhrase(s.text, rec.text)) {
              itemIds.push(rec.id);
            }
          });
        }
        var rec2 = {
          id: U.slugId('sent', s.normKey),
          text: s.text, normKey: s.normKey, translationJa: s.translationJa,
          level: s.level, context: s.context, speechAct: s.speechAct,
          meaningOptionsJa: s.meaningOptionsJa,
          paraphraseEn: s.paraphraseEn,
          paraphraseOptionsEn: s.paraphraseOptionsEn,
          naturalness: s.naturalness, quality: null,
          domainId: domain.id, itemIds: itemIds,
          disabled: false, createdAt: now, updatedAt: now
        };
        sentencesToWrite.push(rec2);
        sentKeys[s.normKey] = rec2;
        newSentences++;
      });

      // -- questions generated locally from the new sentences --
      var itemsById = {};
      Object.keys(itemByKey).forEach(function (k) { itemsById[itemByKey[k].id] = itemByKey[k]; });
      allItems.forEach(function (i) { if (!itemsById[i.id]) itemsById[i.id] = i; });

      var questions = FQ.questions.generateForSentences(
        sentencesToWrite, itemsById, allSentences.concat(sentencesToWrite)
      );

      var batch = {
        id: U.uid('batch'), kind: 'material', domainId: domain.id,
        promptVersion: FQ.prompts.versions.material, at: now,
        counts: {
          items: newItems, linkedItems: linkedItems,
          sentences: newSentences, duplicateSentences: dupSentences,
          questions: questions.length
        }
      };

      return DB.putBulk({
        domains: [domain],
        items: itemsToWrite,
        sentences: sentencesToWrite,
        questions: questions,
        batches: [batch]
      }).then(function () {
        return {
          ok: true,
          summary: {
            domain: domain.name,
            newItems: newItems,
            linkedItems: linkedItems,
            newSentences: newSentences,
            duplicateSentences: dupSentences,
            questions: questions.length
          }
        };
      });
    });
  }

  // Audit import (optional): attaches quality scores to existing sentences.
  function importAudit(raw) {
    var ex = extractJson(raw);
    if (!ex.ok) return Promise.resolve(failure(ex));
    var v = validate(ex.data);
    if (!v.ok) return Promise.resolve({ ok: false, stage: 'validate', errors: v.errors });
    if (v.type !== 'audit') {
      return Promise.resolve({ ok: false, stage: 'validate',
        errors: ['これは品質監査の回答ではありません (type: ' + v.type + ')'] });
    }

    var byKey = {};
    (ex.data.results || []).forEach(function (r) {
      var t = U.clean(r && r.text);
      if (!t) return;
      byKey[U.normKey(t)] = {
        score: normInt(r.score, 1, 5, 3),
        issues: normStrArray(r.issues, 6),
        fix: U.clean(r.suggested_fix)
      };
    });

    return DB.getAll('sentences').then(function (sentences) {
      var updates = [], matched = 0, low = 0;
      sentences.forEach(function (s) {
        var a = byKey[s.normKey];
        if (!a) return;
        matched++;
        if (a.score <= 2) low++;
        updates.push(Object.assign({}, s, {
          quality: a.score, auditIssues: a.issues, auditFix: a.fix, updatedAt: Date.now()
        }));
      });
      return DB.putMany('sentences', updates).then(function () {
        return { ok: true, summary: { reviewed: Object.keys(byKey).length, matched: matched, low: low } };
      });
    });
  }

  // Disable sentences that the audit scored 1-2, and their questions.
  function disableLowQuality() {
    return Promise.all([DB.getAll('sentences'), DB.getAll('questions')])
      .then(function (res) {
        var sentences = res[0], questions = res[1];
        var badIds = {};
        var sUpd = [];
        sentences.forEach(function (s) {
          if (s.quality != null && s.quality <= 2 && !s.disabled) {
            badIds[s.id] = true;
            sUpd.push(Object.assign({}, s, { disabled: true, updatedAt: Date.now() }));
          }
        });
        var qUpd = questions.filter(function (q) { return badIds[q.sentenceId] && !q.disabled; })
          .map(function (q) { return Object.assign({}, q, { disabled: true }); });
        return DB.putBulk({ sentences: sUpd, questions: qUpd })
          .then(function () { return { sentences: sUpd.length, questions: qUpd.length }; });
      });
  }

  // ---------------------------------------------------------------- helpers

  // Word-boundary aware containment, tolerant of case and punctuation.
  function containsPhrase(sentence, phrase) {
    var s = ' ' + U.normKey(sentence) + ' ';
    var p = ' ' + U.normKey(phrase) + ' ';
    return p.trim().length > 0 && s.indexOf(p) !== -1;
  }

  function failure(ex) {
    return {
      ok: false,
      stage: 'parse',
      errors: ex.reason === 'empty'
        ? ['入力が空です']
        : ['AIの回答からJSONを読み取れませんでした' + (ex.detail ? ' (' + ex.detail + ')' : '')]
    };
  }

  FQ.importer = {
    extractJson: extractJson,
    validate: validate,
    normalizeProfile: normalizeProfile,
    normalizeMaterial: normalizeMaterial,
    containsPhrase: containsPhrase,
    importProfile: importProfile,
    importMaterial: importMaterial,
    importAudit: importAudit,
    disableLowQuality: disableLowQuality
  };

})(window.FQ = window.FQ || {});
