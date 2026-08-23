/* Frequency - shared utilities.
   Classic script (no ES modules) so the app also loads from file:// URLs. */
(function (FQ) {
  'use strict';

  var U = FQ.util = {};

  // ---------- ids ----------
  var idCounter = 0;
  U.uid = function (prefix) {
    idCounter += 1;
    return (prefix || 'id') + '_' +
      Date.now().toString(36) + '_' +
      idCounter.toString(36) + '_' +
      Math.random().toString(36).slice(2, 7);
  };

  // Stable id derived from text, so re-importing the same material does not
  // create a second record with a different key.
  U.slugId = function (prefix, text) {
    return prefix + '_' + U.hash(text);
  };

  U.hash = function (str) {
    // FNV-1a, 32-bit. Enough to key local records; not a security hash.
    var h = 0x811c9dc5;
    for (var i = 0; i < str.length; i++) {
      h ^= str.charCodeAt(i);
      h = (h + ((h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24))) >>> 0;
    }
    return h.toString(36);
  };

  // ---------- text ----------
  U.nfc = function (s) {
    return typeof s === 'string' && s.normalize ? s.normalize('NFC') : s;
  };

  U.clean = function (s) {
    if (typeof s !== 'string') return '';
    return U.nfc(s).replace(/\s+/g, ' ').trim();
  };

  // Comparison key for duplicate detection: case/space/punctuation insensitive.
  U.normKey = function (s) {
    return U.clean(s)
      .toLowerCase()
      .replace(/[‘’]/g, "'")
      .replace(/[“”]/g, '"')
      .replace(/[.,!?;:"()\[\]]/g, '')
      .replace(/\s+/g, ' ')
      .trim();
  };

  // Answer comparison for dictation: forgiving about case, spacing and quotes,
  // but still strict about spelling.
  U.answerKey = function (s) {
    return U.normKey(s).replace(/[-‐-―]/g, ' ').replace(/\s+/g, ' ').trim();
  };

  U.titleCaseSafe = function (s) { return U.clean(s); };

  U.escapeHtml = function (s) {
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  };

  // ---------- dates (local calendar day, never UTC) ----------
  U.dayKey = function (d) {
    d = d || new Date();
    var m = d.getMonth() + 1, day = d.getDate();
    return d.getFullYear() + '-' + (m < 10 ? '0' + m : m) + '-' + (day < 10 ? '0' + day : day);
  };

  U.parseDay = function (key) { return new Date(key + 'T00:00:00'); };

  U.daysBetween = function (fromKey, toKey) {
    return Math.round((U.parseDay(toKey) - U.parseDay(fromKey)) / 86400000);
  };

  U.addDays = function (key, n) {
    var d = U.parseDay(key);
    d.setDate(d.getDate() + n);
    return U.dayKey(d);
  };

  U.today = function () { return U.dayKey(); };

  // ---------- collections ----------
  U.shuffle = function (arr) {
    var a = arr.slice();
    for (var i = a.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1));
      var t = a[i]; a[i] = a[j]; a[j] = t;
    }
    return a;
  };

  U.sample = function (arr) { return arr[Math.floor(Math.random() * arr.length)]; };

  U.take = function (arr, n) { return arr.slice(0, Math.max(0, n)); };

  U.uniqueBy = function (arr, keyFn) {
    var seen = Object.create(null), out = [];
    arr.forEach(function (x) {
      var k = keyFn(x);
      if (!seen[k]) { seen[k] = 1; out.push(x); }
    });
    return out;
  };

  U.groupBy = function (arr, keyFn) {
    var out = Object.create(null);
    arr.forEach(function (x) {
      var k = keyFn(x);
      (out[k] = out[k] || []).push(x);
    });
    return out;
  };

  U.clamp = function (n, lo, hi) { return Math.min(hi, Math.max(lo, n)); };

  U.sum = function (arr) { return arr.reduce(function (a, b) { return a + b; }, 0); };

  // Weighted pick. table = [{weight:n, ...}]
  U.weightedPick = function (table) {
    var total = U.sum(table.map(function (t) { return t.weight; }));
    var r = Math.random() * total;
    for (var i = 0; i < table.length; i++) {
      r -= table[i].weight;
      if (r <= 0) return table[i];
    }
    return table[table.length - 1];
  };

  // ---------- dom ----------
  U.el = function (sel, root) { return (root || document).querySelector(sel); };
  U.els = function (sel, root) {
    return Array.prototype.slice.call((root || document).querySelectorAll(sel));
  };

  U.on = function (target, evt, handler) {
    if (target) target.addEventListener(evt, handler);
  };

  // Event delegation keeps re-rendered screens from leaking listeners.
  U.delegate = function (root, evt, sel, handler) {
    root.addEventListener(evt, function (e) {
      var node = e.target.closest ? e.target.closest(sel) : null;
      if (node && root.contains(node)) handler(e, node);
    });
  };

  U.fmtNum = function (n) { return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ','); };

  U.pct = function (ok, n) { return n > 0 ? Math.round((ok / n) * 100) : 0; };

})(window.FQ = window.FQ || {});
