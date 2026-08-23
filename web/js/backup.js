/* Frequency - backup and restore.
   There is no cloud copy of anything, so export is a required feature rather
   than a nicety. The export is a plain JSON file the user keeps themselves. */
(function (FQ) {
  'use strict';

  var U = FQ.util;
  var DB = FQ.db;

  var BACKUP_VERSION = '1.0';

  function exportAll() {
    var stores = DB.STORE_NAMES;
    return Promise.all(stores.map(function (n) { return DB.getAll(n); }))
      .then(function (results) {
        var data = {};
        stores.forEach(function (n, i) { data[n] = results[i]; });
        return {
          app: 'frequency',
          backup_version: BACKUP_VERSION,
          exported_at: new Date().toISOString(),
          counts: stores.reduce(function (acc, n) { acc[n] = data[n].length; return acc; }, {}),
          data: data
        };
      });
  }

  function download(payload) {
    var json = JSON.stringify(payload, null, 2);
    var blob = new Blob([json], { type: 'application/json' });
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = 'frequency-backup-' + U.today() + '.json';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
  }

  function validateBackup(obj) {
    if (!obj || typeof obj !== 'object') return 'ファイルの形式が正しくありません';
    if (obj.app !== 'frequency') return 'このアプリのバックアップではありません';
    if (!obj.data || typeof obj.data !== 'object') return 'data がありません';
    return null;
  }

  // mode: 'merge' keeps existing records and adds/overwrites by key.
  //       'replace' wipes everything first. Both require explicit confirmation
  //       in the UI because they are hard to undo.
  function restore(obj, mode) {
    var err = validateBackup(obj);
    if (err) return Promise.reject(new Error(err));

    var start = mode === 'replace' ? DB.clearAll() : Promise.resolve();

    return start.then(function () {
      var map = {};
      DB.STORE_NAMES.forEach(function (n) {
        var rows = obj.data[n];
        if (Array.isArray(rows) && rows.length) map[n] = rows;
      });
      return DB.putBulk(map).then(function (n) {
        return {
          restored: n,
          counts: Object.keys(map).reduce(function (acc, k) { acc[k] = map[k].length; return acc; }, {})
        };
      });
    });
  }

  function readFile(file) {
    return new Promise(function (resolve, reject) {
      var reader = new FileReader();
      reader.onload = function () {
        try { resolve(JSON.parse(reader.result)); }
        catch (e) { reject(new Error('JSONとして読み取れませんでした')); }
      };
      reader.onerror = function () { reject(new Error('ファイルを読み込めませんでした')); };
      reader.readAsText(file);
    });
  }

  FQ.backup = {
    BACKUP_VERSION: BACKUP_VERSION,
    exportAll: exportAll,
    download: download,
    restore: restore,
    readFile: readFile,
    validateBackup: validateBackup
  };

})(window.FQ = window.FQ || {});
