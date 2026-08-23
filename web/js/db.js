/* Frequency - storage layer.
   IndexedDB is the primary store (material, history and SRS data all grow).
   A localStorage-backed adapter takes over when IndexedDB is unavailable
   (private windows, some file:// contexts) so the app degrades instead of
   crashing. Both adapters expose the same async API. */
(function (FQ) {
  'use strict';

  var DB_NAME = 'frequency';
  var DB_VERSION = 1;

  // Store definitions live in one place so future migrations stay reviewable.
  var STORES = {
    meta:      { keyPath: 'key', indexes: [] },
    domains:   { keyPath: 'id', indexes: [['byKey', 'normKey', {}]] },
    items:     { keyPath: 'id', indexes: [
                   ['byKey', 'normKey', {}],
                   ['byDomain', 'domainIds', { multiEntry: true }]
                 ] },
    sentences: { keyPath: 'id', indexes: [
                   ['byKey', 'normKey', {}],
                   ['byDomain', 'domainId', {}],
                   ['byItem', 'itemIds', { multiEntry: true }]
                 ] },
    questions: { keyPath: 'id', indexes: [
                   ['bySentence', 'sentenceId', {}],
                   ['byItem', 'itemId', {}],
                   ['byDomain', 'domainId', {}],
                   ['byType', 'type', {}]
                 ] },
    srs:       { keyPath: 'itemId', indexes: [['byDue', 'due', {}]] },
    qstats:    { keyPath: 'questionId', indexes: [] },
    history:   { keyPath: 'id', autoIncrement: true, indexes: [['byDay', 'day', {}]] },
    sessions:  { keyPath: 'id', indexes: [['byDay', 'day', {}]] },
    batches:   { keyPath: 'id', indexes: [] }
  };

  var STORE_NAMES = Object.keys(STORES);

  // ---------------------------------------------------------------- IndexedDB

  function openIDB() {
    return new Promise(function (resolve, reject) {
      var req;
      if (typeof indexedDB === 'undefined' || !indexedDB) {
        reject(new Error('no indexedDB'));
        return;
      }
      try { req = indexedDB.open(DB_NAME, DB_VERSION); }
      catch (e) { reject(e); return; }

      req.onupgradeneeded = function (e) {
        var db = e.target.result;
        STORE_NAMES.forEach(function (name) {
          var def = STORES[name];
          var store;
          if (db.objectStoreNames.contains(name)) {
            store = e.target.transaction.objectStore(name);
          } else {
            var opts = { keyPath: def.keyPath };
            if (def.autoIncrement) opts.autoIncrement = true;
            store = db.createObjectStore(name, opts);
          }
          def.indexes.forEach(function (ix) {
            if (!store.indexNames.contains(ix[0])) {
              store.createIndex(ix[0], ix[1], ix[2] || {});
            }
          });
        });
      };
      req.onsuccess = function () { resolve(req.result); };
      req.onerror = function () { reject(req.error || new Error('indexedDB open failed')); };
      req.onblocked = function () { reject(new Error('indexedDB blocked')); };
    });
  }

  function idbAdapter(db) {
    // Every helper resolves only when the transaction completes, so callers
    // never read a value that a later abort would roll back.
    function tx(names, mode, fn) {
      return new Promise(function (resolve, reject) {
        var t;
        try { t = db.transaction(names, mode); }
        catch (e) { reject(e); return; }
        var box = {};
        t.oncomplete = function () { resolve(box.value); };
        t.onerror = function () { reject(t.error); };
        t.onabort = function () { reject(t.error || new Error('transaction aborted')); };
        try { fn(t.objectStore ? t : t, box, t); }
        catch (e) { try { t.abort(); } catch (e2) {} reject(e); }
      });
    }

    function capture(request, box, transform) {
      request.onsuccess = function () {
        box.value = transform ? transform(request.result) : request.result;
      };
    }

    return {
      kind: 'indexeddb',

      getOne: function (store, key) {
        return tx([store], 'readonly', function (t, box) {
          capture(t.objectStore(store).get(key), box, function (v) {
            return v === undefined ? null : v;
          });
        });
      },

      getAll: function (store) {
        return tx([store], 'readonly', function (t, box) {
          capture(t.objectStore(store).getAll(), box, function (v) { return v || []; });
        });
      },

      getAllByIndex: function (store, index, value) {
        return tx([store], 'readonly', function (t, box) {
          capture(t.objectStore(store).index(index).getAll(value), box, function (v) {
            return v || [];
          });
        });
      },

      put: function (store, value) {
        return tx([store], 'readwrite', function (t) {
          t.objectStore(store).put(value);
        }).then(function () { return value; });
      },

      putMany: function (store, values) {
        if (!values || !values.length) return Promise.resolve(0);
        return tx([store], 'readwrite', function (t) {
          var s = t.objectStore(store);
          values.forEach(function (v) { s.put(v); });
        }).then(function () { return values.length; });
      },

      // A single transaction across stores keeps an import all-or-nothing.
      putBulk: function (map) {
        var names = Object.keys(map).filter(function (n) { return map[n] && map[n].length; });
        if (!names.length) return Promise.resolve(0);
        var count = 0;
        return tx(names, 'readwrite', function (t) {
          names.forEach(function (n) {
            var s = t.objectStore(n);
            map[n].forEach(function (v) { s.put(v); count++; });
          });
        }).then(function () { return count; });
      },

      del: function (store, key) {
        return tx([store], 'readwrite', function (t) { t.objectStore(store).delete(key); });
      },

      delMany: function (store, keys) {
        if (!keys || !keys.length) return Promise.resolve();
        return tx([store], 'readwrite', function (t) {
          var s = t.objectStore(store);
          keys.forEach(function (k) { s.delete(k); });
        });
      },

      count: function (store) {
        return tx([store], 'readonly', function (t, box) {
          capture(t.objectStore(store).count(), box);
        }).then(function (n) { return n || 0; });
      },

      clearAll: function () {
        return tx(STORE_NAMES, 'readwrite', function (t) {
          STORE_NAMES.forEach(function (n) { t.objectStore(n).clear(); });
        });
      }
    };
  }

  // ------------------------------------------------------------- localStorage

  // Mirrors the same API but keeps everything in one JSON blob. Capacity is far
  // smaller, so the UI surfaces a warning when this adapter is in use.
  function lsAdapter() {
    var KEY = 'frequency.fallback.v1';
    var mem = null;
    var writable = true;

    try {
      var raw = window.localStorage.getItem(KEY);
      if (raw) mem = JSON.parse(raw);
    } catch (e) { mem = null; }
    if (!mem || typeof mem !== 'object') mem = {};
    STORE_NAMES.forEach(function (n) { if (!mem[n]) mem[n] = {}; });
    if (!mem.__seq) mem.__seq = 1;

    function flush() {
      if (!writable) return Promise.resolve();
      try {
        window.localStorage.setItem(KEY, JSON.stringify(mem));
      } catch (e) {
        writable = false;
        return Promise.reject(new Error('storage-full'));
      }
      return Promise.resolve();
    }

    function keyOf(store, value) {
      var def = STORES[store];
      if (def.autoIncrement) {
        if (value.id == null) value.id = mem.__seq++;
        return String(value.id);
      }
      return String(value[def.keyPath]);
    }

    function all(store) {
      return Object.keys(mem[store]).map(function (k) { return mem[store][k]; });
    }

    return {
      kind: 'localstorage',
      getOne: function (store, key) {
        return Promise.resolve(mem[store][String(key)] || null);
      },
      getAll: function (store) { return Promise.resolve(all(store)); },
      getAllByIndex: function (store, index, value) {
        var ix = STORES[store].indexes.filter(function (i) { return i[0] === index; })[0];
        if (!ix) return Promise.resolve([]);
        var path = ix[1], multi = ix[2] && ix[2].multiEntry;
        return Promise.resolve(all(store).filter(function (r) {
          var v = r[path];
          return multi ? (Array.isArray(v) && v.indexOf(value) !== -1) : v === value;
        }));
      },
      put: function (store, value) {
        mem[store][keyOf(store, value)] = value;
        return flush().then(function () { return value; });
      },
      putMany: function (store, values) {
        (values || []).forEach(function (v) { mem[store][keyOf(store, v)] = v; });
        return flush().then(function () { return (values || []).length; });
      },
      putBulk: function (map) {
        var count = 0;
        Object.keys(map).forEach(function (store) {
          (map[store] || []).forEach(function (v) {
            mem[store][keyOf(store, v)] = v; count++;
          });
        });
        return flush().then(function () { return count; });
      },
      del: function (store, key) { delete mem[store][String(key)]; return flush(); },
      delMany: function (store, keys) {
        (keys || []).forEach(function (k) { delete mem[store][String(k)]; });
        return flush();
      },
      count: function (store) { return Promise.resolve(Object.keys(mem[store]).length); },
      clearAll: function () {
        STORE_NAMES.forEach(function (n) { mem[n] = {}; });
        mem.__seq = 1;
        return flush();
      }
    };
  }

  // ------------------------------------------------------------------ facade

  var adapter = null;
  var readyPromise = null;

  var DB = FQ.db = {
    STORE_NAMES: STORE_NAMES,
    kind: 'unknown',

    ready: function () {
      if (readyPromise) return readyPromise;
      readyPromise = openIDB()
        .then(function (db) {
          var a = idbAdapter(db);
          // Prove a write round-trips; some environments open the database and
          // then reject every transaction.
          return a.put('meta', { key: '__probe', value: Date.now() })
            .then(function () { return a; });
        })
        .catch(function (err) {
          console.warn('[Frequency] IndexedDB unavailable, falling back to localStorage:',
            err && err.message);
          return lsAdapter();
        })
        .then(function (a) { adapter = a; DB.kind = a.kind; return a; });
      return readyPromise;
    },

    getOne: function (s, k) { return DB.ready().then(function (a) { return a.getOne(s, k); }); },
    getAll: function (s) { return DB.ready().then(function (a) { return a.getAll(s); }); },
    getAllByIndex: function (s, i, v) { return DB.ready().then(function (a) { return a.getAllByIndex(s, i, v); }); },
    put: function (s, v) { return DB.ready().then(function (a) { return a.put(s, v); }); },
    putMany: function (s, v) { return DB.ready().then(function (a) { return a.putMany(s, v); }); },
    putBulk: function (m) { return DB.ready().then(function (a) { return a.putBulk(m); }); },
    del: function (s, k) { return DB.ready().then(function (a) { return a.del(s, k); }); },
    delMany: function (s, k) { return DB.ready().then(function (a) { return a.delMany(s, k); }); },
    count: function (s) { return DB.ready().then(function (a) { return a.count(s); }); },
    clearAll: function () { return DB.ready().then(function (a) { return a.clearAll(); }); },

    getMeta: function (key, fallback) {
      return DB.getOne('meta', key).then(function (rec) {
        return rec && 'value' in rec ? rec.value : (fallback === undefined ? null : fallback);
      });
    },
    setMeta: function (key, value) {
      return DB.put('meta', { key: key, value: value });
    }
  };

})(window.FQ = window.FQ || {});
