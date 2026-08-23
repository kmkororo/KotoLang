/* Frequency - minimal local static server (no dependencies).
   Serving over http://localhost matters: IndexedDB and service workers are
   restricted or unavailable on file:// URLs. Binds to loopback only, so
   nothing is exposed to the network. */

var http = require('http');
var fs = require('fs');
var path = require('path');

var ROOT = __dirname;
var PORT = parseInt(process.env.PORT, 10) || 8777;

var TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.webmanifest': 'application/manifest+json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.ico': 'image/x-icon'
};

var server = http.createServer(function (req, res) {
  var urlPath = decodeURIComponent(req.url.split('?')[0]);
  if (urlPath === '/') urlPath = '/index.html';

  var filePath = path.join(ROOT, path.normalize(urlPath));
  // Refuse anything that escapes the app directory.
  if (filePath.indexOf(ROOT) !== 0) {
    res.writeHead(403); res.end('Forbidden'); return;
  }

  fs.readFile(filePath, function (err, data) {
    if (err) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('Not found: ' + urlPath);
      return;
    }
    var ext = path.extname(filePath).toLowerCase();
    res.writeHead(200, {
      'Content-Type': TYPES[ext] || 'application/octet-stream',
      'Cache-Control': 'no-cache'
    });
    res.end(data);
  });
});

server.listen(PORT, '127.0.0.1', function () {
  var url = 'http://localhost:' + PORT + '/index.html';
  console.log('Frequency running at ' + url);
  console.log('Press Ctrl+C to stop.');

  if (process.argv.indexOf('--no-open') === -1) {
    var cp = require('child_process');
    var cmd = process.platform === 'win32' ? 'start ""' :
              (process.platform === 'darwin' ? 'open' : 'xdg-open');
    try { cp.exec(cmd + ' "' + url + '"'); } catch (e) { /* open manually */ }
  }
});

server.on('error', function (err) {
  if (err.code === 'EADDRINUSE') {
    console.error('Port ' + PORT + ' is busy. Try: set PORT=8778 && node server.js');
  } else {
    console.error(err.message);
  }
  process.exit(1);
});
