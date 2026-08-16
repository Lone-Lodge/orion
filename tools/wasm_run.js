// Instantiate one .wasm and run main(); print JSON {actual} or {trap}. Run as
// a child process with a timeout so a wasm that infinite-loops is caught as a
// HANG instead of freezing the whole conformance sweep.
const fs = require('fs');
const wf = process.argv[2];
function readText(mem, ptr) {
  const u = new Uint8Array(mem.buffer);
  const l = u[ptr] | (u[ptr+1]<<8) | (u[ptr+2]<<16) | (u[ptr+3]<<24);
  return Buffer.from(u.subarray(ptr+4, ptr+4+l)).toString();
}
function allocText(mem, s) {
  const b = Buffer.from(s), dv = new DataView(mem.buffer), u8 = new Uint8Array(mem.buffer);
  const p = dv.getUint32(0, true); dv.setUint32(p, b.length, true); u8.set(b, p+4);
  dv.setUint32(0, p+4+b.length, true); return p;
}
(async () => {
  let M;
  const files = {}; // in-memory sandbox, matching the playground
  const env = {
    __print: () => {}, host_sin: Math.sin, host_cos: Math.cos, host_sqrt: Math.sqrt, host_tan: Math.tan, host_exp: Math.exp, host_log: Math.log, host_pow: Math.pow, host_atan2: Math.atan2,
    __argc: () => 1, __argv: (i) => allocText(M, i === 0 ? 'prog' : ''),
    __file_write: (p, c) => { files[readText(M, p)] = readText(M, c); return 1; },
    __file_read: (p) => allocText(M, files[readText(M, p)] || ''),
  };
  try {
    const inst = await WebAssembly.instantiate(fs.readFileSync(wf), { env });
    M = inst.instance.exports.memory;
    const actual = inst.instance.exports.main();
    process.stdout.write(JSON.stringify({ actual }));
  } catch (e) {
    process.stdout.write(JSON.stringify({ trap: String(e.message).slice(0, 80) }));
  }
})();
