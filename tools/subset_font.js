// Subset a TrueType font to the letters a UI actually says (plus .notdef
// and every composite component those letters pull in). The engine embeds
// its faces into every game binary, and the wasm backend pays per byte - a
// full family ships thousands of glyphs the sketches can never say.
//
//   node subset_font.js <in.ttf> <out.ttf>
//
// ASCII is not enough. A subset that stops at 126 measures "Innehåll" with
// three missing glyphs, and then the layout is wrong in every language but
// English - quietly, because a missing glyph still has a width. Latin-1 and
// a handful of typographic marks cover every language this UI is written
// in today and cost about three kilobytes.
//
// Keeps the tables the typeface orb reads (head, maxp, cmap, loca, glyf,
// hhea, hmtx) AND the three a browser insists on before it will load a
// face at all (OS/2, name, post). Without them Chrome says "OTS parsing
// error: OS/2: missing required table" and silently draws in some other
// face - so the layout is measured in one face and painted in another.
'use strict';
const fs = require('fs');
const src = fs.readFileSync(process.argv[2]);

const u16 = (b, o) => b.readUInt16BE(o), u32 = (b, o) => b.readUInt32BE(o), i16 = (b, o) => b.readInt16BE(o);
const tables = {};
for (let i = 0; i < u16(src, 4); i++) {
  const rec = 12 + i * 16;
  tables[src.toString('ascii', rec, rec + 4)] = { off: u32(src, rec + 8), len: u32(src, rec + 12) };
}
for (const t of ['head', 'maxp', 'cmap', 'loca', 'glyf', 'hhea', 'hmtx'])
  if (!tables[t]) { console.error(`subset_font: no ${t} table`); process.exit(1); }

const head = tables.head.off, maxp = tables.maxp.off, cmap = tables.cmap.off;
const loca = tables.loca.off, glyf = tables.glyf.off, hhea = tables.hhea.off, hmtx = tables.hmtx.off;
const upm = u16(src, head + 18), locFmt = i16(src, head + 50);
const nGlyphs = u16(src, maxp + 4), nH = u16(src, hhea + 34);

// cmap: find a format-4 subtable, prefer (3,1)/(0,*).
let sub = 0;
for (let i = 0; i < u16(src, cmap + 2); i++) {
  const rec = cmap + 4 + i * 8, s = cmap + u32(src, rec + 4);
  if (u16(src, s) === 4 && (sub === 0 || u16(src, rec) === 3 || u16(src, rec) === 0)) sub = s;
}
if (!sub) { console.error('subset_font: no format-4 cmap'); process.exit(1); }
function gidOf(cp) {
  const seg2 = u16(src, sub + 6);
  for (let i = 0; i < seg2 / 2; i++) {
    if (cp <= u16(src, sub + 14 + i * 2)) {
      const start = u16(src, sub + 16 + seg2 + i * 2);
      if (cp < start) return 0;
      const roPos = sub + 16 + seg2 * 3 + i * 2, ro = u16(src, roPos), delta = i16(src, sub + 16 + seg2 * 2 + i * 2);
      if (ro === 0) return (cp + delta) & 0xffff;
      const g = u16(src, roPos + ro + (cp - start) * 2);
      return g === 0 ? 0 : (g + delta) & 0xffff;
    }
  }
  return 0;
}
const locaOff = g => locFmt === 1 ? u32(src, loca + g * 4) : u16(src, loca + g * 2) * 2;

// Glyph set: .notdef, every ASCII glyph, and composite components (recursively).
const RANGES = [
  [0x20, 0x7E],      // ASCII
  [0xA0, 0xFF],      // Latin-1: åäöÅÄÖ, the accents, the degree and the times sign
  [0x2013, 0x2014],  // en dash, em dash
  [0x2018, 0x201D],  // the curly quotes
  [0x2022, 0x2022],  // bullet
  [0x2026, 0x2026],  // ellipsis
];
const keep = new Set([0]);
const cpToGid = {};
const cps = [];
for (const [lo, hi] of RANGES)
  for (let cp = lo; cp <= hi; cp++) {
    const g = gidOf(cp);
    if (!g) continue;                 // the face does not have it; nothing to keep
    cpToGid[cp] = g; keep.add(g); cps.push(cp);
  }
const queue = [...keep];
while (queue.length) {
  const g = queue.pop();
  const o0 = locaOff(g), o1 = locaOff(g + 1);
  if (o1 <= o0) continue;
  const gp = glyf + o0;
  if (i16(src, gp) >= 0) continue; // simple glyph
  let pos = gp + 10;
  for (;;) {
    const flags = u16(src, pos), cgid = u16(src, pos + 2);
    if (!keep.has(cgid)) { keep.add(cgid); queue.push(cgid); }
    pos += 4;
    pos += (flags & 1) ? 4 : 2;              // ARG_1_AND_2_ARE_WORDS
    if (flags & 8) pos += 2;                 // WE_HAVE_A_SCALE
    else if (flags & 64) pos += 4;           // X_AND_Y_SCALE
    else if (flags & 128) pos += 8;          // TWO_BY_TWO
    if (!(flags & 32)) break;                // MORE_COMPONENTS
  }
}
const oldGids = [...keep].sort((a, b) => a - b);
const newGid = new Map(oldGids.map((g, i) => [g, i]));

// glyf + loca (long): copy records, patch component gids in composites.
const glyphChunks = [];
const locaOut = Buffer.alloc((oldGids.length + 1) * 4);
let glyfLen = 0;
oldGids.forEach((g, i) => {
  locaOut.writeUInt32BE(glyfLen, i * 4);
  const o0 = locaOff(g), o1 = locaOff(g + 1);
  if (o1 > o0) {
    const rec = Buffer.from(src.subarray(glyf + o0, glyf + o1));
    if (rec.readInt16BE(0) < 0) {
      let pos = 10;
      for (;;) {
        const flags = rec.readUInt16BE(pos);
        rec.writeUInt16BE(newGid.get(rec.readUInt16BE(pos + 2)), pos + 2);
        pos += 4;
        pos += (flags & 1) ? 4 : 2;
        if (flags & 8) pos += 2; else if (flags & 64) pos += 4; else if (flags & 128) pos += 8;
        if (!(flags & 32)) break;
      }
    }
    glyphChunks.push(rec);
    glyfLen += rec.length;
    if (glyfLen % 4) { const pad = Buffer.alloc(4 - glyfLen % 4); glyphChunks.push(pad); glyfLen += pad.length; }
  }
});
locaOut.writeUInt32BE(glyfLen, oldGids.length * 4);
const glyfOut = Buffer.concat(glyphChunks, glyfLen);

// hmtx: every kept glyph gets its own (aw, lsb) pair.
const hmtxOut = Buffer.alloc(oldGids.length * 4);
oldGids.forEach((g, i) => {
  const m = Math.min(g, nH - 1);
  hmtxOut.writeUInt16BE(u16(src, hmtx + m * 4), i * 4);
  hmtxOut.writeInt16BE(g < nH ? i16(src, hmtx + g * 4 + 2) : i16(src, hmtx + nH * 4 + (g - nH) * 2), i * 4 + 2);
});

// cmap: one format-4 subtable. Runs of consecutive codepoints become
// segments; every segment reads its glyphs out of one shared glyphIdArray,
// so a gap in the face costs a segment and nothing else.
const runs = [];
for (const cp of cps) {
  const back = runs[runs.length - 1];
  if (back && cp === back[1] + 1) back[1] = cp; else runs.push([cp, cp]);
}
const glyphIds = [];
const bases = runs.map(([lo, hi]) => {
  const at = glyphIds.length;
  for (let cp = lo; cp <= hi; cp++) glyphIds.push(newGid.get(cpToGid[cp]));
  return at;
});
const segs = runs.length + 1;                      // plus the 0xFFFF sentinel
const subLen = 16 + segs * 8 + glyphIds.length * 2;
const cmapOut = Buffer.alloc(12 + subLen);
cmapOut.writeUInt16BE(0, 0); cmapOut.writeUInt16BE(1, 2);
cmapOut.writeUInt16BE(3, 4); cmapOut.writeUInt16BE(1, 6); cmapOut.writeUInt32BE(12, 8);
const o = 12;
cmapOut.writeUInt16BE(4, o); cmapOut.writeUInt16BE(subLen, o + 2); cmapOut.writeUInt16BE(0, o + 4);
const segX2 = segs * 2;
cmapOut.writeUInt16BE(segX2, o + 6);
const pow2 = 2 ** Math.floor(Math.log2(segs));
cmapOut.writeUInt16BE(pow2 * 2, o + 8);
cmapOut.writeUInt16BE(Math.log2(pow2), o + 10);
cmapOut.writeUInt16BE(segX2 - pow2 * 2, o + 12);
const endBase = o + 14, startBase = endBase + segX2 + 2, deltaBase = startBase + segX2, roBase = deltaBase + segX2;
runs.forEach(([lo, hi], i) => {
  cmapOut.writeUInt16BE(hi, endBase + i * 2);
  cmapOut.writeUInt16BE(lo, startBase + i * 2);
  cmapOut.writeInt16BE(0, deltaBase + i * 2);
  // Where this segment's glyph ids sit, measured from this very slot -
  // which is what makes idRangeOffset the one field nobody gets right.
  cmapOut.writeUInt16BE(2 * (segs - i + bases[i]), roBase + i * 2);
});
const last = runs.length;
cmapOut.writeUInt16BE(0xFFFF, endBase + last * 2);
cmapOut.writeUInt16BE(0xFFFF, startBase + last * 2);
cmapOut.writeInt16BE(1, deltaBase + last * 2);
cmapOut.writeUInt16BE(0, roBase + last * 2);
glyphIds.forEach((g, i) => cmapOut.writeUInt16BE(g, roBase + segs * 2 + i * 2));

// head/maxp/hhea: patched copies.
const headOut = Buffer.from(src.subarray(head, head + tables.head.len));
headOut.writeUInt32BE(0, 8);        // checkSumAdjustment: unused by our parser
headOut.writeInt16BE(1, 50);        // long loca
const maxpOut = Buffer.from(src.subarray(maxp, maxp + tables.maxp.len));
maxpOut.writeUInt16BE(oldGids.length, 4);
const hheaOut = Buffer.from(src.subarray(hhea, hhea + tables.hhea.len));
hheaOut.writeUInt16BE(oldGids.length, 34);

// The three a browser insists on. OS/2 and name are the source's own - it
// is the same face, so its own metrics and its own name are the honest
// answer. post is written fresh as version 3.0: thirty-two bytes that say
// "no glyph names", instead of the thirty-two kilobytes of names nobody
// here reads.
const os2Out = tables['OS/2'] ? Buffer.from(src.subarray(tables['OS/2'].off, tables['OS/2'].off + tables['OS/2'].len)) : null;
if (os2Out) {
  os2Out.writeUInt16BE(cps[0], 64);                       // usFirstCharIndex
  os2Out.writeUInt16BE(Math.min(0xFFFF, cps[cps.length - 1]), 66);  // usLastCharIndex
}
const nameOut = tables.name ? Buffer.from(src.subarray(tables.name.off, tables.name.off + tables.name.len)) : null;
const postOut = Buffer.alloc(32);
postOut.writeUInt32BE(0x00030000, 0);
if (tables.post) {
  postOut.writeInt32BE(src.readInt32BE(tables.post.off + 4), 4);    // italicAngle
  postOut.writeInt16BE(i16(src, tables.post.off + 8), 8);           // underlinePosition
  postOut.writeInt16BE(i16(src, tables.post.off + 10), 10);         // underlineThickness
}

// sfnt assembly: directory + padded bodies, plain checksums. The directory
// is sorted by tag, which is what the format asks for and what a browser
// checks.
const out = [['OS/2', os2Out], ['cmap', cmapOut], ['glyf', glyfOut], ['head', headOut], ['hhea', hheaOut],
             ['hmtx', hmtxOut], ['loca', locaOut], ['maxp', maxpOut], ['name', nameOut], ['post', postOut]]
            .filter(([, buf]) => buf).sort((a, b) => (a[0] < b[0] ? -1 : 1));
const dir = Buffer.alloc(12 + out.length * 16);
dir.writeUInt32BE(0x00010000, 0);
dir.writeUInt16BE(out.length, 4);
const pow = Math.floor(Math.log2(out.length));
dir.writeUInt16BE(16 * 2 ** pow, 6); dir.writeUInt16BE(pow, 8); dir.writeUInt16BE(out.length * 16 - 16 * 2 ** pow, 10);
let off = dir.length;
const bodies = [];
out.forEach(([tag, buf], i) => {
  const padded = buf.length % 4 ? Buffer.concat([buf, Buffer.alloc(4 - buf.length % 4)]) : buf;
  let sum = 0;
  for (let p = 0; p < padded.length; p += 4) sum = (sum + padded.readUInt32BE(p)) >>> 0;
  const rec = 12 + i * 16;
  dir.write(tag, rec, 'ascii');
  dir.writeUInt32BE(sum, rec + 4);
  dir.writeUInt32BE(off, rec + 8);
  dir.writeUInt32BE(buf.length, rec + 12);
  bodies.push(padded);
  off += padded.length;
});
fs.writeFileSync(process.argv[3], Buffer.concat([dir, ...bodies]));
console.log(`subset_font: ${process.argv[2]} ${src.length} -> ${process.argv[3]} ${off} bytes, ${oldGids.length} glyphs`);
