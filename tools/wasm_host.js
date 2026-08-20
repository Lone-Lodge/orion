// The host half of a wasm Orion program: everything the module imports.
//
// wasm keeps no state that outlives a call and cannot read a clock, so the
// slot store is a Map here and monotonic_ms is the clock here. That is the
// whole of the "state" import group - and it is what lets a UI framework run
// in a page, because its layout cache, its motion store and every "how long
// has this been hovered" live in slots.
//
//   node tools/wasm_host.js <module.wasm> [--time N]
//
// --time N calls main() N times and reports the milliseconds each took.
const fs = require('fs');

// The slot store: a byte-keyed table.
//
// Measured, the call across the seam is free. What a lookup cost was turning
// the key's bytes into a JS string so a Map could hash it - eighty four per
// cent of it, for a string nobody reads. The bytes are hashed where they lie
// and compared where they lie instead, and text VALUES are kept as bytes, so
// nothing on the path a frame takes allocates. 0.25 microseconds a lookup
// down to 0.04, and a veil frame asks two and a half thousand times.
function makeStore(memOf) {
  let U = null, seen = null;
  const bytes = () => { const b = memOf().buffer; if (seen !== b) { seen = b; U = new Uint8Array(b); } return U; };
  const table = new Map();
  const same = (u, at, n, k) => { if (k.length !== n) return false; for (let i = 0; i < n; i++) if (k[i] !== u[at + i]) return false; return true; };
  const len = (u, p) => u[p] | (u[p+1] << 8) | (u[p+2] << 16) | (u[p+3] << 24);
  // The module hands over the key's HASH, and leaves the key's address at
  // mem[8] for the one thing a hash cannot do: tell two keys apart that
  // landed on the same number.
  const keyAt = (u) => len(u, 8);
  const find = (h) => {
    const hit = table.get(h >>> 0);
    if (hit === undefined) return undefined;
    const u = bytes(), p = keyAt(u), n = len(u, p);
    if (!Array.isArray(hit)) return same(u, p + 4, n, hit.k) ? hit : undefined;
    for (const e of hit) if (same(u, p + 4, n, e.k)) return e;
    return undefined;
  };
  const put = (h, v) => {
    const u = bytes(), p = keyAt(u), n = len(u, p);
    h = h >>> 0;
    const hit = table.get(h);
    if (hit === undefined) { table.set(h, { k: u.slice(p + 4, p + 4 + n), v }); return; }
    if (!Array.isArray(hit)) {
      if (same(u, p + 4, n, hit.k)) { hit.v = v; return; }
      table.set(h, [hit, { k: u.slice(p + 4, p + 4 + n), v }]);
      return;
    }
    for (const e of hit) if (same(u, p + 4, n, e.k)) { e.v = v; return; }
    hit.push({ k: u.slice(p + 4, p + 4 + n), v });
  };
  const grab = (p) => { const u = bytes(), n = len(u, p); return u.slice(p + 4, p + 4 + n); };
  return {
    find, put, grab,
    get size() { let n = 0; for (const v of table.values()) n += Array.isArray(v) ? v.length : 1; return n; },
  };
}

function makeHost() {
  let M = null;
  const slots = makeStore(() => M);
  const started = process.hrtime.bigint();

  const readText = (ptr) => {
    const u = new Uint8Array(M.buffer);
    const l = u[ptr] | (u[ptr + 1] << 8) | (u[ptr + 2] << 16) | (u[ptr + 3] << 24);
    return Buffer.from(u.subarray(ptr + 4, ptr + 4 + l)).toString();
  };
  // Text lives in linear memory with a 4-byte length in front, allocated from
  // the bump pointer the module keeps at address 0.
  const allocBytes = (b) => {
    const dv = new DataView(M.buffer);
    const u8 = new Uint8Array(M.buffer);
    const p = dv.getUint32(0, true);
    dv.setUint32(p, b.length, true);
    u8.set(b, p + 4);
    dv.setUint32(0, p + 4 + b.length, true);
    return p;
  };
  const allocText = (s) => allocBytes(Buffer.from(s));

  const EMPTY = new Uint8Array(0);
  const files = {};
  const env = {
    __print: (p, nl) => process.stdout.write(readText(p) + (nl ? '\n' : '')),
    __argc: () => 1,
    __argv: (i) => allocText(i === 0 ? 'prog' : ''),
    __file_write: (p, c) => { files[readText(p)] = readText(c); return 1; },
    __file_read: (p) => allocText(files[readText(p)] || ''),
    host_sin: Math.sin, host_cos: Math.cos, host_tan: Math.tan,
    host_sqrt: Math.sqrt, host_exp: Math.exp, host_log: Math.log,
    host_pow: Math.pow, host_atan2: Math.atan2,
    // --- state: a map and a clock ---
    __slot_set: (k, v) => { slots.put(k, v); return 0; },
    __slot_set_text: (k, v) => { slots.put(k, slots.grab(v)); return 0; },
    __slot_get_int: (k) => { const e = slots.find(k); return (e !== undefined && typeof e.v === 'number') ? e.v : 0; },
    __slot_get: (k) => { const e = slots.find(k); return allocBytes((e !== undefined && e.v instanceof Uint8Array) ? e.v : EMPTY); },
    __slot_has: (k) => (slots.find(k) !== undefined ? 1 : 0),
    __now: () => Number((process.hrtime.bigint() - started) / 1000000n),
    // A number said as text. The orb declares it `external`, so it is the
    // host's job on every backend - native links a C one, a page brings its
    // own.
    fmt_float: (x, places) => allocText(Number(x).toFixed(places >>> 0)),
    // There is no arena and no persist region in a page: one linear memory,
    // a bump pointer, and a host that owns the rest. Switching between them
    // is a no-op that answers 0, which is what "not in an arena" means.
    orion_persist_on: () => 0,
    orion_persist_off: () => 0,
    orion_arena_off: () => 0,
    orion_arena_on: () => 0,
    orion_arena_active: () => 0,
  };
  // The bump pointer lives at address 0 and never frees, so a program that
  // is called over and over walks off the end of memory. Everything one call
  // allocates is dead the moment its answer has been read, which is what a
  // FRAME region is - and here it costs one number: remember where the bump
  // pointer stood after start-up, put it back between calls.
  let floor = 0;
  return {
    env,
    bind: (mem) => { M = mem; floor = new DataView(M.buffer).getUint32(0, true); },
    markFloor: () => { floor = new DataView(M.buffer).getUint32(0, true); },
    resetFrame: () => { new DataView(M.buffer).setUint32(0, floor, true); },
    slots,
  };
}

(async () => {
  const file = process.argv[2];
  const timeAt = process.argv.indexOf('--time');
  const runs = timeAt > 0 ? Number(process.argv[timeAt + 1] || 1) : 0;
  const host = makeHost();
  const inst = await WebAssembly.instantiate(fs.readFileSync(file), { env: host.env });
  host.bind(inst.instance.exports.memory);
  // --whichever exported entry point was asked for, so one module can be
  // timed at more than one thing.
  const pick = process.argv.indexOf('--call');
  const name = pick > 0 ? process.argv[pick + 1] : 'main';
  const main = inst.instance.exports[name] || inst.instance.exports.main;

  if (!runs) {
    console.log(JSON.stringify({ actual: main() }));
    return;
  }
  main();                                   // warm: caches fill on the first pass
  host.markFloor();                         // and whatever they kept is the floor
  // How much linear memory ONE call takes: the bump pointer before and
  // after. Allocation is invisible until you look at it this way.
  const dv0 = new DataView(inst.instance.exports.memory.buffer);
  const before = dv0.getUint32(0, true);
  main();
  const grew = dv0.getUint32(0, true) - before;
  host.resetFrame();
  const t0 = process.hrtime.bigint();
  for (let i = 0; i < runs; i++) { main(); host.resetFrame(); }
  const each = Number(process.hrtime.bigint() - t0) / 1e6 / runs;
  const used = new DataView(inst.instance.exports.memory.buffer).getUint32(0, true);
  console.log(JSON.stringify({ runs, msEach: +each.toFixed(3), bytesPerCall: grew, slots: host.slots.size }));
})();
