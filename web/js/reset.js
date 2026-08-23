/* Frequency - scoped resets.
   Re-importing material is a normal thing to want (the AI produced something
   weak, or the domain changed), so wiping everything must not be the only
   option. Each function here previews exactly what it will remove before the
   caller confirms, and none of them touch data outside their stated scope. */
(function (FQ) {
  'use strict';

  var U = FQ.util;
  var DB = FQ.db;

  // Which records belong to one domain. Learning Items can be shared across
  // domains, so they are split into "only this domain" (safe to delete, along
  // with their review schedule) and "also used elsewhere" (keep, just unlink).
  function planDomain(domainId) {
    return Promise.all([
      DB.getAll('sentences'), DB.getAll('questions'), DB.getAll('items'), DB.getAll('srs')
    ]).then(function (res) {
      var sentences = res[0], questions = res[1], items = res[2], srs = res[3];

      var deadSentences = sentences.filter(function (s) { return s.domainId === domainId; });
      var deadSentenceIds = {};
      deadSentences.forEach(function (s) { deadSentenceIds[s.id] = true; });

      var deadQuestions = questions.filter(function (q) {
        return q.domainId === domainId || deadSentenceIds[q.sentenceId];
      });

      var owned = items.filter(function (i) { return (i.domainIds || []).indexOf(domainId) !== -1; });
      var deadItems = owned.filter(function (i) { return i.domainIds.length <= 1; });
      var sharedItems = owned.filter(function (i) { return i.domainIds.length > 1; });

      var deadItemIds = {};
      deadItems.forEach(function (i) { deadItemIds[i.id] = true; });
      var deadSrs = srs.filter(function (s) { return deadItemIds[s.itemId]; });

      return {
        domainId: domainId,
        sentences: deadSentences,
        questions: deadQuestions,
        items: deadItems,
        sharedItems: sharedItems,
        srs: deadSrs,
        counts: {
          sentences: deadSentences.length,
          questions: deadQuestions.length,
          items: deadItems.length,
          sharedItems: sharedItems.length,
          srs: deadSrs.length
        }
      };
    });
  }

  // removeDomain=false keeps the domain entry so the user can immediately
  // paste fresh material into it, which is the common case.
  function deleteDomainMaterial(domainId, removeDomain) {
    return planDomain(domainId).then(function (plan) {
      var jobs = [
        DB.delMany('sentences', plan.sentences.map(function (r) { return r.id; })),
        DB.delMany('questions', plan.questions.map(function (r) { return r.id; })),
        DB.delMany('qstats', plan.questions.map(function (r) { return r.id; })),
        DB.delMany('items', plan.items.map(function (r) { return r.id; })),
        DB.delMany('srs', plan.srs.map(function (r) { return r.itemId; }))
      ];

      // Shared terms survive; they simply stop belonging to this domain.
      var unlinked = plan.sharedItems.map(function (i) {
        return Object.assign({}, i, {
          domainIds: i.domainIds.filter(function (d) { return d !== domainId; }),
          updatedAt: Date.now()
        });
      });
      if (unlinked.length) jobs.push(DB.putMany('items', unlinked));

      return Promise.all(jobs)
        .then(function () { return DB.getAll('batches'); })
        .then(function (batches) {
          var dead = batches.filter(function (b) { return b.domainId === domainId; });
          return DB.delMany('batches', dead.map(function (b) { return b.id; }));
        })
        .then(function () { return DB.getOne('domains', domainId); })
        .then(function (domain) {
          if (!domain) return null;
          if (removeDomain) return DB.del('domains', domainId);
          return DB.put('domains', Object.assign({}, domain, {
            hasMaterial: false, updatedAt: Date.now()
          }));
        })
        .then(function () { return plan.counts; });
    });
  }

  function planAllMaterial() {
    return Promise.all([
      DB.count('items'), DB.count('sentences'), DB.count('questions'), DB.count('srs')
    ]).then(function (r) {
      return { items: r[0], sentences: r[1], questions: r[2], srs: r[3] };
    });
  }

  // Removes every imported item, sentence and question plus their review
  // schedules. Domains, profile, streak and XP are left alone.
  function deleteAllMaterial() {
    return planAllMaterial().then(function (counts) {
      return Promise.all([
        DB.getAll('items'), DB.getAll('sentences'), DB.getAll('questions'),
        DB.getAll('srs'), DB.getAll('qstats'), DB.getAll('batches'), DB.getAll('domains')
      ]).then(function (res) {
        return Promise.all([
          DB.delMany('items', res[0].map(function (r) { return r.id; })),
          DB.delMany('sentences', res[1].map(function (r) { return r.id; })),
          DB.delMany('questions', res[2].map(function (r) { return r.id; })),
          DB.delMany('srs', res[3].map(function (r) { return r.itemId; })),
          DB.delMany('qstats', res[4].map(function (r) { return r.questionId; })),
          DB.delMany('batches', res[5].filter(function (b) { return b.kind === 'material'; })
            .map(function (b) { return b.id; })),
          DB.putMany('domains', res[6].map(function (d) {
            return Object.assign({}, d, { hasMaterial: false, updatedAt: Date.now() });
          }))
        ]);
      }).then(function () { return counts; });
    });
  }

  // Keeps the material, forgets how far the learner got with it.
  function resetProgress() {
    return Promise.all([
      DB.getAll('srs'), DB.getAll('qstats'), DB.getAll('history'), DB.getAll('sessions')
    ]).then(function (res) {
      var counts = {
        srs: res[0].length, history: res[2].length, qstats: res[1].length
      };
      return Promise.all([
        DB.delMany('srs', res[0].map(function (r) { return r.itemId; })),
        DB.delMany('qstats', res[1].map(function (r) { return r.questionId; })),
        DB.delMany('history', res[2].map(function (r) { return r.id; })),
        DB.delMany('sessions', res[3].map(function (r) { return r.id; }))
      ]).then(function () {
        return DB.setMeta('progress', Object.assign({}, FQ.progress.DEFAULT_PROGRESS));
      }).then(function () { return counts; });
    });
  }

  // Clears everything the onboarding prompts produced: the profile answers, the
  // discovered domains, and the material that hangs off those domains (a
  // sentence without its domain would be unreachable). Streak, XP and answer
  // history describe what the learner did, so they are kept.
  function resetProfile() {
    return summary().then(function (before) {
      return Promise.all([
        DB.getAll('items'), DB.getAll('sentences'), DB.getAll('questions'),
        DB.getAll('srs'), DB.getAll('qstats'), DB.getAll('domains'), DB.getAll('batches')
      ]).then(function (r) {
        return Promise.all([
          DB.delMany('items', r[0].map(function (x) { return x.id; })),
          DB.delMany('sentences', r[1].map(function (x) { return x.id; })),
          DB.delMany('questions', r[2].map(function (x) { return x.id; })),
          DB.delMany('srs', r[3].map(function (x) { return x.itemId; })),
          DB.delMany('qstats', r[4].map(function (x) { return x.questionId; })),
          DB.delMany('domains', r[5].map(function (x) { return x.id; })),
          DB.delMany('batches', r[6].map(function (x) { return x.id; })),
          DB.del('meta', 'profile')
        ]);
      }).then(function () {
        return {
          domains: before.domains, items: before.items,
          sentences: before.sentences, questions: before.questions, srs: before.srs
        };
      });
    });
  }

  // Back to a first run. keepSettings carries over voice, speed, difficulty and
  // input method, which are preferences rather than learning data.
  function factoryReset(keepSettings) {
    return DB.getMeta('settings', null).then(function (settings) {
      return DB.clearAll().then(function () {
        if (keepSettings === false || !settings) return null;
        return DB.setMeta('settings', settings);
      });
    });
  }

  function summary() {
    return Promise.all([
      DB.getAll('domains'), DB.getAll('items'), DB.getAll('sentences'),
      DB.getAll('questions'), DB.getAll('srs'), DB.getAll('history')
    ]).then(function (r) {
      var domains = r[0], items = r[1], sentences = r[2], questions = r[3];
      return {
        domains: domains.length,
        domainsWithMaterial: domains.filter(function (d) { return d.hasMaterial; }).length,
        items: items.length,
        sentences: sentences.length,
        questions: questions.length,
        srs: r[4].length,
        history: r[5].length,
        byDomain: domains.map(function (d) {
          return {
            id: d.id,
            name: d.nameJa || d.name,
            hasMaterial: !!d.hasMaterial,
            items: items.filter(function (i) { return (i.domainIds || []).indexOf(d.id) !== -1; }).length,
            sentences: sentences.filter(function (s) { return s.domainId === d.id; }).length,
            questions: questions.filter(function (q) { return q.domainId === d.id; }).length
          };
        })
      };
    });
  }

  FQ.reset = {
    planDomain: planDomain,
    deleteDomainMaterial: deleteDomainMaterial,
    planAllMaterial: planAllMaterial,
    deleteAllMaterial: deleteAllMaterial,
    resetProfile: resetProfile,
    resetProgress: resetProgress,
    factoryReset: factoryReset,
    summary: summary
  };

})(window.FQ = window.FQ || {});
