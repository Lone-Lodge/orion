// Field Guide playground server. Serves docs/ and compiles Orion snippets to
// wasm on demand (POST /api/run) by running dist/orion.exe. Run from anywhere:
//   node tools/playground.js   ->   http://localhost:8100/playground.html
const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFile } = require('child_process');

const ROOT = path.join(__dirname, '..');
const DOCS = path.join(ROOT, 'docs');
const ORION = path.join(ROOT, 'dist', 'orion.exe');
const ORBS = path.join(ROOT, 'orbs');
const PORT = 8100;
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.wasm': 'application/wasm' };

function compile(source, done) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'orionpg-'));
  const src = path.join(dir, 'prog.or');
  const wasm = path.join(dir, 'prog.wasm');
  // The wasm backend provides split/sum/len/print etc. as builtins, so pulling
  // in the text/iter/bytes orbs (which use byte primitives the backend does not
  // support) is both unnecessary and fatal. Drop those use lines.
  source = source.replace(/^[ \t]*use[ \t]+(text|iter|bytes)[ \t]*\r?$/gm, '');
  fs.writeFileSync(src, source);
  execFile(ORION, [src, wasm, ORBS, '--quiet'], { timeout: 15000 }, (err, stdout, stderr) => {
    let result;
    const log = (stdout || '') + (stderr || '');
    if (fs.existsSync(wasm) && !/ERROR|FAILED|FATAL/.test(log)) {
      result = { ok: true, wasm: fs.readFileSync(wasm).toString('base64') };
    } else {
      result = { ok: false, error: log.trim() || String(err) };
    }
    fs.rmSync(dir, { recursive: true, force: true });
    done(result);
  });
}

http.createServer((req, res) => {
  if (req.method === 'POST' && req.url === '/api/run') {
    let body = '';
    req.on('data', c => { body += c; if (body.length > 200000) req.destroy(); });
    req.on('end', () => {
      let source = '';
      try { source = JSON.parse(body).source || ''; } catch {}
      compile(source, result => {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(result));
      });
    });
    return;
  }
  let rel = decodeURIComponent((req.url || '/').split('?')[0]);
  if (rel === '/') rel = '/index.html';
  const file = path.join(DOCS, rel);
  if (!file.startsWith(DOCS)) { res.writeHead(403); res.end(); return; }
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end('not found'); return; }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(PORT, () => console.log('playground on http://localhost:' + PORT + '/playground.html'));
