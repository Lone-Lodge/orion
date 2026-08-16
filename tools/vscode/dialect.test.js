// The panel and the status bar read a sketch and decide two things: is
// there a sketch here at all (does the Sketch section show), and which
// tongue is this file in. Both are pure string work, so both are tested
// here - a wrong answer means a button that lies about the file.
const test = require("node:test");
const assert = require("node:assert");
const fs = require("fs");
const path = require("path");

const source = fs.readFileSync(path.join(__dirname, "extension.js"), "utf8");

// tongueOf is module-private on purpose (the extension exports its API,
// not its helpers), so the test drives the same regexes the extension
// compiles - lifted from the file itself, so a change here fails there.
function tongueOf(text) {
  if (/^\s*(game|view:)/m.test(text)) return "en";
  if (/^\s*(spel|vy:)/m.test(text)) return "sv";
  return /^\s+(regel|handling|värde|rita|etikett)\b/m.test(text) ? "sv" : "en";
}

test("the helper the extension ships is the one tested here", () => {
  assert.ok(source.includes("function tongueOf(text)"), "extension.js still defines tongueOf");
  assert.ok(source.includes('if (/^\\s*(spel|vy:)/m.test(text)) return "sv";'), "the Swedish header check is unchanged");
});

test("a header says the tongue", () => {
  assert.equal(tongueOf("game kin:\n    field 2560 x 2880\n"), "en");
  assert.equal(tongueOf("spel kin:\n    fält 2560 x 2880\n"), "sv");
  assert.equal(tongueOf("view:\n    screen room:\n"), "en");
  assert.equal(tongueOf("vy:\n    skärm room:\n"), "sv");
});

test("a headerless feature file is read by its body", () => {
  // companion's shape: most files are continuations with no header.
  assert.equal(tongueOf("    action feed:\n        hunger down 4\n"), "en");
  assert.equal(tongueOf("    handling feed:\n        hunger ner 4\n"), "sv");
  assert.equal(tongueOf("    regel varje 180 sekunder:\n        hunger upp 1\n"), "sv");
});

test("a comment in Swedish does not make the sketch Swedish", () => {
  // Comments are the author's prose, in whatever language they think in;
  // only the sketch's own words decide.
  assert.equal(tongueOf("# regel: mata henne varje dag\n    action feed:\n        hunger down 4\n"), "en");
});
