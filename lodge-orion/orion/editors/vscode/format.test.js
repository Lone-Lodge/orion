// Tiny smoke test for the Orion formatter. Run with: node format.test.js

const assert = require("assert");
const { formatOrion } = require("./format");

function test(name, fn) {
  try {
    fn();
    console.log("  ok  ", name);
  } catch (e) {
    console.error("  FAIL", name);
    console.error("      ", e.message);
    process.exitCode = 1;
  }
}

test("re-indents to 4-space step", () => {
  const input = "fn f() -> int:\n  x = 1\n  x\n";
  const out = formatOrion(input);
  assert.strictEqual(out, "fn f() -> int:\n    x = 1\n    x\n");
});

test("collapses multiple blank lines to one", () => {
  const input = "fn a() -> int = 1\n\n\n\nfn b() -> int = 2\n";
  const out = formatOrion(input);
  assert.strictEqual(out, "fn a() -> int = 1\n\nfn b() -> int = 2\n");
});

test("drops leading and trailing blanks; adds trailing newline", () => {
  const input = "\n\nfn f() -> int = 1\n\n";
  const out = formatOrion(input);
  assert.strictEqual(out, "fn f() -> int = 1\n");
});

test("preserves nested depth", () => {
  const input = "fn f() -> int:\n  for i in 0..<10:\n    if i > 5:\n      x = i\n    x\n";
  const out = formatOrion(input);
  assert.strictEqual(
    out,
    "fn f() -> int:\n    for i in 0..<10:\n        if i > 5:\n            x = i\n        x\n"
  );
});

test("does not touch content inside lines", () => {
  const input = 'fn f() -> Text = "hello  world  with  spaces"\n';
  const out = formatOrion(input);
  assert.strictEqual(out, 'fn f() -> Text = "hello  world  with  spaces"\n');
});

console.log("orion formatter — done.");
