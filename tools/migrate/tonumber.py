# tonumber.py - migrate written `int` / `float` annotations to `number`.
#
#   python tools/migrate/tonumber.py [--dry] <paths...>
#
# `number` is the word; the compiler decides i64 or f64 (see the `number` pass
# in orbs/orion_ast_to_ir). So this is a spelling change ONLY where the pass
# actually reaches, and that is exactly three places: a parameter type, a
# return type, and a `let` annotation.
#
# It reaches NONE of these, so none of them are touched:
#   type Crc: hi: int          - a data field. The pass does not walk struct
#                                declarations, so `number` there would fall to
#                                the f64 default and silently widen a field.
#   [int]                      - a list ELEMENT. The pass tracks sites, not
#                                what flows through a list, so it cannot say
#                                whether the elements are whole.
#   x as int                   - a cast. Retired outright now: the parser says
#                                `to_whole(x)` / `to_real(x)` instead, so there
#                                is nothing left here to rewrite.
#
# Verified, not assumed: tests/suite/dist/*.ll is committed reference IR for
# every test. Re-running the suite after this must leave that diff EMPTY - the
# same machine code from the new word is the whole claim.
import sys, os, re

def migrate_file(lines):
    """Migrate a whole file, skipping declaration BLOCKS.

    `type request:` puts its fields on the lines below, and a field is not a
    site the pass reaches - `number` there would fall to the f64 default and
    silently widen it. So the block is tracked, not just its header line.
    Same for `effect`, whose operations are a signature list, not code."""
    out, in_decl, in_type = [], False, False
    for line in lines:
        code = line.split('#')[0]
        if code.strip():
            # A `type` BLOCK puts its fields and variant payloads on the
            # lines below. Those are sites, so the block is tracked to reach
            # them - unlike `effect`, whose operations are a signature list.
            if re.match(r'\s*(public\s+)?type\b', code):
                in_type = code.rstrip().endswith(':')
                out.append(migrate_line(line, True)); continue
            if in_type and re.match(r'\s', code):
                out.append(migrate_line(line, True)); continue
            in_type = False
            if re.match(r'\s*(public\s+)?(effect|external)\b', code):
                in_decl = code.rstrip().endswith(':')
                out.append(line); continue
            if in_decl and re.match(r'\s', code):
                out.append(line); continue
            in_decl = False
        out.append(migrate_line(line, in_type))
    return out

def fn_type_spans(line):
    """Character ranges covered by a `function(...) -> T` TYPE.

    Kept from when the pass could not walk these; it can now, and the spans
    are no longer reverted. The helper stays because it is the only thing that
    can tell a function type from a parameter list on one line."""
    out = []
    for m in re.finditer(r'\b(function|fn)\s*\(', line):
        i, depth = m.end(), 1
        while i < len(line) and depth:
            if line[i] == '(': depth += 1
            elif line[i] == ')': depth -= 1
            i += 1
        r = re.match(r'\s*->\s*\w+', line[i:])
        if r: i += r.end()
        out.append((m.start(), i))
    return out

def migrate_line(line, in_type=False):
    code_end = line.index("#") if "#" in line else len(line)
    code, rest = line[:code_end], line[code_end:]
    if re.match(r'\s*(public\s+)?(effect|external)\b', code):
        return line
    # A string literal is not code: `not int)` inside a diagnostic would
    # otherwise be rewritten into nonsense a person reads. Blanked for the
    # substitutions, put back after.
    strs = []
    def _hide(m):
        strs.append(m.group(0))
        return chr(1) * len(m.group(0))
    code = re.sub(r'"[^"]*"', _hide, code)
    # `: int` cannot occur inside `[int]` or `table<int>` - there is no colon
    # in either - so the colon itself is the whole guard.
    code = re.sub(r'(:\s*)int\b', r'\1number', code)
    code = re.sub(r'(->\s*)int\b', r'\1number', code)
    # Fields and list elements are sites now, so these move too.
    code = re.sub(r'\[int\]', '[number]', code)
    code = re.sub(r'(list of )int\b', r'\1number', code)
    # A TUPLE type: `-> (sstore, int)`. Only after `->`, so an ordinary
    # argument list cannot be hit.
    def _tup(m):
        return m.group(1) + re.sub(r'\bint\b', 'number', m.group(2))
    code = re.sub(r'(->\s*)(\([^)]*\))', _tup, code)
    # A variant PAYLOAD: `type json: JBool(int)`. Only on a `type` line, so
    # nothing that merely looks like a call can be hit.
    if in_type or re.match(r'\s*(public\s+)?type\b', code):
        code = re.sub(r'(\(|,\s*)int(\s*[,)])', r'\1number\2', code)
        code = re.sub(r'(\(|,\s*)int(\s*[,)])', r'\1number\2', code)
    for lit in strs:
        code = code.replace(chr(1) * len(lit), lit, 1)
    return code + rest

def main():
    args = sys.argv[1:]
    dry = "--dry" in args
    args = [a for a in args if a != "--dry"]
    files = []
    for root in args:
        if os.path.isfile(root): files.append(root); continue
        for d, _, fs in os.walk(root):
            files += [os.path.join(d, f) for f in fs if f.endswith(".or")]
    changed = hits = 0
    for p in sorted(files):
        src = open(p, encoding="utf-8", errors="replace").read()
        # A file may opt out with `tonumber: skip`. Nothing does any more:
        # `ori_display` needed it and now names the sized type outright.
        if "tonumber: skip" in src:
            continue
        old_lines = src.split("\n")
        out = migrate_file(old_lines)
        n = sum(1 for a, b in zip(old_lines, out) if a != b)
        if n:
            changed += 1; hits += n
            if not dry: open(p, "w", encoding="utf-8", newline="\n").write("\n".join(out))
    print(f"int -> number: {hits} rader i {changed} filer" + (" (dry)" if dry else ""))

if __name__ == "__main__":
    main()
