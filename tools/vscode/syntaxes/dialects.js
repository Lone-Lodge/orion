// dialects.js - teach the astra grammar every tongue the engine knows.
//
// The grammar is written once, in canonical English. This walks its
// `match` regexes and widens each KEYWORD in place - `(game)` becomes
// `(game|spel)`, `(seconds|ticks)` becomes `(seconds|sekunder|ticks|tick)`
// - so a Swedish sketch highlights exactly like an English one and the
// capture groups (which the scopes are numbered against) never move.
//
//   node syntaxes/dialects.js            rewrite astra.tmLanguage.json
//   node syntaxes/dialects.js --check    fail if it is out of date
//
// The word table is the engine's own (atlas0.0.1/orbs/dialect/vocabulary.txt),
// so highlighting cannot drift from what the compiler accepts. Adding a
// language means adding a column there and running this once.
"use strict";
const fs = require("fs");
const path = require("path");

const HERE = __dirname;
const GRAMMAR = path.join(HERE, "astra.tmLanguage.json");

// Every place the engine might sit relative to this extension.
function vocabularyPaths() {
  const roots = [
    path.resolve(HERE, "../../../../atlas0.0.1"),
    path.resolve(HERE, "../../../atlas0.0.1"),
  ];
  return roots.map((r) => path.join(r, "orbs", "dialect", "vocabulary.txt"));
}

function readVocabulary() {
  for (const file of vocabularyPaths()) {
    if (!fs.existsSync(file)) continue;
    const pairs = new Map();
    for (const line of fs.readFileSync(file, "utf8").split("\n")) {
      const [canonical, dialect] = line.trim().split("|");
      if (!canonical || !dialect || canonical === "canonical") continue;
      if (canonical !== dialect) pairs.set(canonical, dialect);
    }
    return pairs;
  }
  return null;
}

// Widen one regex: a bare word that is a keyword grows its twin beside
// it. Only whole words are touched, and only inside a group or an
// alternation - the shape every keyword in this grammar already has.
function widen(source, pairs) {
  return source.replace(/[A-Za-z_][A-Za-z0-9_]*/g, (word, at) => {
    if (!pairs.has(word)) return word;
    const before = source[at - 1];
    const after = source[at + word.length];
    const grouped = before === "(" || before === "|" || before === ":";
    const closed = after === ")" || after === "|";
    if (!grouped || !closed) return word;
    // Already widened (idempotent, so --check is meaningful).
    if (source.slice(at + word.length).startsWith("|" + pairs.get(word))) return word;
    return word + "|" + pairs.get(word);
  });
}

function widenNode(node, pairs) {
  if (Array.isArray(node)) return node.map((n) => widenNode(n, pairs));
  if (node && typeof node === "object") {
    const out = {};
    for (const [key, value] of Object.entries(node))
      out[key] = (key === "match" || key === "begin" || key === "end") && typeof value === "string"
        ? widen(value, pairs)
        : widenNode(value, pairs);
    return out;
  }
  return node;
}

function main() {
  const pairs = readVocabulary();
  if (!pairs) {
    console.error("dialects: no vocabulary.txt found - is atlas0.0.1 beside orion?");
    process.exit(1);
  }
  const before = fs.readFileSync(GRAMMAR, "utf8");
  const widened = widenNode(JSON.parse(before), pairs);
  const after = JSON.stringify(widened, null, "\t") + "\n";
  if (process.argv.includes("--check")) {
    if (before !== after) {
      console.error("dialects: astra.tmLanguage.json is out of date - run: node syntaxes/dialects.js");
      process.exit(1);
    }
    console.log(`dialects: grammar speaks ${pairs.size} translated words`);
    return;
  }
  fs.writeFileSync(GRAMMAR, after);
  console.log(`dialects: astra.tmLanguage.json now speaks ${pairs.size} translated words`);
}

if (require.main === module) main();
module.exports = { widen, readVocabulary };
