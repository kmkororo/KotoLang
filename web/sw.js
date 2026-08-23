/* Frequency - service worker.
   Caches the app shell so studying works with no network at all. User data
   lives in IndexedDB and is never touched here. Material only needs the network
   when the user goes to their own AI for new content. */

var CACHE = 'frequency-v1';

var SHELL = [
  './',
  './index.html',
  './css/app.css',
  './js/util.js',
  './js/db.js',
  './js/prompts.js',
  './js/questions.js',
  './js/importer.js',
  './js/srs.js',
  './js/progress.js',
  './js/speech.js',
  './js/session.js',
  './js/backup.js',
  './js/ui.js',
  './js/app.js',
  './manifest.webmanifest',
  './icons/icon.svg',
  './icons/icon-maskable.svg'
];

self.addEventListener('install', function (e) {
  e.waitUntil(
    caches.open(CACHE)
      // addAll rejects entirely if one file 404s, so add individually.
      .then(function (c) {
        return Promise.all(SHELL.map(function (url) {
          return c.add(url).catch(function () { return null; });
        }));
      })
      .then(function () { return self.skipWaiting(); })
  );
});

self.addEventListener('activate', function (e) {
  e.waitUntil(
    caches.keys()
      .then(function (keys) {
        return Promise.all(keys.map(function (k) {
          return k === CACHE ? null : caches.delete(k);
        }));
      })
      .then(function () { return self.clients.claim(); })
  );
});

self.addEventListener('fetch', function (e) {
  var req = e.request;
  if (req.method !== 'GET') return;

  var url = new URL(req.url);
  if (url.origin !== self.location.origin) return;

  // Cache first: the shell rarely changes and offline use is the priority.
  e.respondWith(
    caches.match(req).then(function (hit) {
      if (hit) {
        // Refresh in the background so an updated file lands next launch.
        fetch(req).then(function (res) {
          if (res && res.ok) caches.open(CACHE).then(function (c) { c.put(req, res.clone()); });
        }).catch(function () {});
        return hit;
      }
      return fetch(req).then(function (res) {
        if (res && res.ok) {
          var copy = res.clone();
          caches.open(CACHE).then(function (c) { c.put(req, copy); });
        }
        return res;
      }).catch(function () {
        // Navigation requests fall back to the cached shell.
        if (req.mode === 'navigate') return caches.match('./index.html');
        return new Response('', { status: 504, statusText: 'offline' });
      });
    })
  );
});
