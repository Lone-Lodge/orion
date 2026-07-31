// Measure the smoke suite through the wasm backend. Each tests/test_<N>_*.or
// must exit with code N natively; here we compile it to wasm, run it in node,
// and compare main()'s return to N. Categories: OK, MISMATCH (wasm gives a
// different answer than native -> a real codegen bug), UNSUPPORTED (the backend
// refuses to lower something -> a known gap), FAIL (other compile error), TRAP,
// HANG (wasm runs but never returns -> a control-flow bug). Each wasm runs in a
// child process with a timeout so an infinite loop is caught, not fatal.
// Args: <root> [comma,separated,filter substrings]
const fs = require('fs'), cp = require('child_process'), path = require('path');
const ROOT = process.argv[2] || '.';
const TESTS = path.join(ROOT, 'examples/tests/tests');
const ORION = path.join(ROOT, 'dist/orion.exe');
const RUNNER = path.join(__dirname, 'wasm_run.js');
const TMP = path.join(ROOT, 'dist/.wasmconf');
try { fs.mkdirSync(TMP, { recursive: true }); } catch {}

function expectedOf(name) {
  const m = name.match(/^test_(\d+)/);
  return m ? parseInt(m[1], 10) : null;
}

const filter = process.argv[3] ? process.argv[3].split(',') : null;
let files = fs.readdirSync(TESTS).filter(f => f.endsWith('.or')).sort();
if (filter) files = files.filter(f => filter.some(s => f.includes(s)));

const cats = { OK: [], MISMATCH: [], UNSUPPORTED: [], FAIL: [], TRAP: [], HANG: [] };
const feats = {};
for (const f of files) {
  const exp = expectedOf(f);
  if (exp === null) continue;
  let src = fs.readFileSync(path.join(TESTS, f), 'utf8');
  src = src.replace(/^[ \t]*use[ \t]+(text|iter|bytes)[ \t]*\r?$/gm, '');
  const sf = path.join(TMP, f), wf = sf.replace(/\.or$/, '.wasm');
  try { fs.unlinkSync(wf); } catch {}
  fs.writeFileSync(sf, src);
  const r = cp.spawnSync(ORION, [sf, wf, 'orbs', '--quiet'], { encoding: 'utf8', timeout: 20000 });
  const err = (r.stdout || '') + (r.stderr || '');
  if (!fs.existsSync(wf) || /FAILED/.test(err)) {
    if (/does not support/.test(err)) {
      cats.UNSUPPORTED.push(f);
      for (const m of err.matchAll(/does not support `([^`]+)`|calling `([A-Za-z_]+)`/g)) {
        const k = (m[1] || m[2]); feats[k] = (feats[k] || 0) + 1;
      }
    } else cats.FAIL.push(f + '  :: ' + (err.trim().split('\n').pop() || '').slice(0, 90));
    continue;
  }
  // Run in a child with a 5s timeout so an infinite loop is a HANG, not a freeze.
  const run = cp.spawnSync('node', [RUNNER, wf], { encoding: 'utf8', timeout: 5000 });
  if (run.error || run.status === null) { cats.HANG.push(f); continue; }
  let out;
  try { out = JSON.parse(run.stdout); } catch { cats.TRAP.push(f + '  :: bad runner output'); continue; }
  if (out.trap) cats.TRAP.push(f + '  :: ' + out.trap);
  else if (out.actual === exp) cats.OK.push(f);
  else cats.MISMATCH.push(`${f}  expected ${exp} got ${out.actual}`);
}
const shown = files.length;
console.log(`\n=== wasm conformance: ${shown} test(s) ===`);
for (const k of ['OK', 'MISMATCH', 'UNSUPPORTED', 'FAIL', 'TRAP', 'HANG'])
  console.log(`${k.padEnd(12)} ${cats[k].length}`);
if (Object.keys(feats).length) {
  console.log('\n-- unsupported features (count) --');
  Object.entries(feats).sort((a,b)=>b[1]-a[1]).forEach(([k,v]) => console.log(`  ${String(v).padStart(3)}  ${k}`));
}
for (const k of ['MISMATCH', 'TRAP', 'HANG', 'FAIL']) {
  if (cats[k].length) { console.log(`\n-- ${k} --`); cats[k].slice(0, 50).forEach(x => console.log('  ' + x)); }
}
if (cats.UNSUPPORTED.length && filter) {
  console.log('\n-- UNSUPPORTED --'); cats.UNSUPPORTED.forEach(x => console.log('  ' + x));
}
