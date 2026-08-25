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
const TESTS = path.join(ROOT, 'tests/suite/tests');
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
  const src = fs.readFileSync(path.join(TESTS, f), 'utf8');
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

// Regression gate (only when run over the whole suite, i.e. no filter). The
// wasm backend is secondary and has known-unsupported features, so we do NOT
// require 100%. Instead: the OK count must not drop below a baseline, and there
// must be no MISMATCH (wrong answer) or FAIL (compile/link crash). Expected
// runtime aborts (divide-by-zero, out-of-range, require) land in TRAP and are
// tolerated. Bump BASELINE_OK when real coverage rises.
// 163 -> 164 on 2026-08-21: a real reaching a binding widens it.
// 162 -> 163 on 2026-08-21: mixed whole/real if-branches.
// 161 -> 162 on 2026-08-20: a real number into an effect.
// 160 -> 161 on 2026-08-20: a truth says true.
// 159 -> 160 on 2026-08-20: exponent literals.
// 158 -> 159 on 2026-08-20: a text counts in characters.
// 157 -> 158 on 2026-08-19: byte reads straight off a text.
// 156 -> 157 on 2026-08-19: the effect real carrier.
// 154 -> 156 on 2026-08-19: a LIST parameter records its element type here
// too, so a `[float]` argument is walked eight bytes at a time rather than
// four. That was a standing gap; `number` on a list is what walked into it.
// 141 -> 154 on 2026-08-19: the spoken maybe/result surface reaches this
// backend, and the four tests for it pass here too. Thirteen tests of slack
// in the number is not a baseline, it is a place for a regression to hide.
// 142 -> 141 on 2026-08-04: test_42_general_floor gained copy/move/cwd and
// moved OK -> UNSUPPORTED (honestly native-only). Not a lost capability.
const BASELINE_OK = 164;
// Tests that are correct natively but rely on an idiom the wasm backend does
// not share, each with a tracked reason. They must NOT silently count as
// regressions, but they are listed loudly so the set cannot grow unnoticed.
const KNOWN_GAPS = {
  // The native backend prints the SHORTEST decimal that reads back as the same
  // double (snprintf %.*g, precision 1..17, checked with strtod). The wasm
  // backend has its own hand-written formatter and rounds differently. Closing
  // it needs an f64-taking host import - wasm imports are i32-only today - so
  // the host's own String(x), which is already the shortest form, can answer.
  'test_43_float_text.or': 'wasm writes six decimals and trims them; native prints the SHORTEST decimal that reads back, so 0.1 + 0.2 differs. Whole numbers and simple decimals agree now',
};
if (!filter) {
  const isGap = (line) => Object.keys(KNOWN_GAPS).some((f) => line.startsWith(f));
  const unexpected = [...cats.MISMATCH, ...cats.FAIL].filter((x) => !isGap(x));
  const okCount = cats.OK.length;
  const regressed = okCount < BASELINE_OK;
  if (Object.keys(KNOWN_GAPS).length) {
    console.log('\n-- known wasm gaps (tolerated, tracked) --');
    for (const [f, why] of Object.entries(KNOWN_GAPS)) console.log(`  ${f}: ${why}`);
  }
  if (regressed) console.log(`\nREGRESSION: OK ${okCount} < baseline ${BASELINE_OK}`);
  if (unexpected.length) {
    console.log(`\nREGRESSION: ${unexpected.length} unexpected MISMATCH/FAIL (must be 0):`);
    unexpected.forEach((x) => console.log('  ' + x));
  }
  if (regressed || unexpected.length) process.exit(1);
  console.log(`\nwasm gate OK: ${okCount} pass (>= ${BASELINE_OK}), no unexpected mismatch/fail`);
}
