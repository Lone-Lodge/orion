// Orion formatter - structure-preserving re-indentation.
//
// Orion uses the offside rule: blocks open with a trailing `:` and children
// nest by indentation. There's no AST pretty-printer (yet), so this formatter
// never reads a line's content - it re-derives nesting depth from each line's
// RELATIVE indentation and re-emits it at a canonical 4-space step. Strings,
// `=` spacing, and `[ ]` payloads can't be broken because only leading and
// trailing whitespace is touched. Blank-line runs collapse to one, leading
// and trailing blanks are dropped, and a trailing newline is guaranteed.
//
// Same approach as Astra's formatter - see astra/editors/vscode/format.js for
// the original. Limitation: normalises a structurally-valid file; it does NOT
// repair genuinely mis-nested code.

const ORION_INDENT = "    ";

function formatOrion(text) {
  const lines = text.split(/\r?\n/);
  const out = [];
  // Stack of original indent widths seen on the way down; depth = length - 1.
  const stack = [0];
  let pendingBlanks = 0;

  for (const raw of lines) {
    const line = raw.replace(/[ \t]+$/, "");
    if (line === "") {
      pendingBlanks++;
      continue;
    }
    // Leading indent width, tabs counted as 4.
    const lead = line.match(/^[ \t]*/)[0];
    let indent = 0;
    for (const ch of lead) indent += ch === "\t" ? 4 : 1;
    const content = line.slice(lead.length);

    // Dedent: pop deeper levels until we're at or above the current indent.
    while (stack.length > 1 && indent < stack[stack.length - 1]) stack.pop();
    // Indent: a strictly deeper line opens one new level.
    if (indent > stack[stack.length - 1]) stack.push(indent);
    const depth = stack.length - 1;

    // At most one blank line between blocks, and none before the first line.
    if (out.length > 0 && pendingBlanks > 0) out.push("");
    pendingBlanks = 0;

    out.push(ORION_INDENT.repeat(depth) + content);
  }

  return out.join("\n") + "\n";
}

module.exports = { formatOrion };
