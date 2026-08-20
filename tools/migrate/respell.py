# respell.py - one mechanical spelling migration over .or sources.
#
#   python tools/migrate/respell.py <axis> [--comments] [--dry] <paths...>
#
#   until   `0..<n`     -> `0 until n`
#   is      `==` / `!=` -> `is` / `is not`
#   index   `at(x, i)`  -> `x[i]`
#
# Every line gets a MASK first: which characters may be rewritten. String TEXT
# and (by default) comments may not; a `{...}` span inside a string may, because
# that is interpolated code. `op is "=="` has an `==` that must go and one that
# must stay, on the same line, and the mask is what tells them apart. Paren
# matching for `at(...)` reads the mask too, so a `)` inside a string literal
# argument does not close the call.
import sys, os, re

def build_mask(line, comments_ok):
    """-> list[bool], True where a rewrite is allowed."""
    m, i, n = [False] * len(line), 0, len(line)
    while i < n:
        c = line[i]
        if c == '"':
            i += 1                                  # opening quote: protected
            while i < n and line[i] != '"':
                if line[i] == "\\" and i + 1 < n:
                    i += 2; continue
                if line[i] == "{":                  # interpolation: code again
                    depth, j = 1, i + 1
                    while j < n and depth:
                        if line[j] == "{": depth += 1
                        elif line[j] == "}": depth -= 1
                        j += 1
                    for k in range(i + 1, min(j - 1, n)): m[k] = True
                    i = j; continue
                i += 1
            i += 1; continue                        # closing quote
        if c == "#":
            for k in range(i, n): m[k] = comments_ok
            return m
        m[i] = True; i += 1
    return m

def sub_masked(line, mask, pattern, repl):
    """Apply `pattern` right-to-left, only where the whole match is rewritable."""
    for mt in reversed(list(re.finditer(pattern, line))):
        if all(mask[k] for k in range(mt.start(), mt.end())):
            line = line[:mt.start()] + repl + line[mt.end():]
    return line

def ax_until(line, mask):
    return sub_masked(line, mask, r'\s*\.\.<\s*', ' until ')

def ax_is(line, mask):
    line = sub_masked(line, mask, r'\s*!=\s*', ' is not ')
    return sub_masked(line, build_mask(line, mask_comments[0]), r'\s*==\s*', ' is ')

def ax_index(line, mask):
    """at(A, B) -> A[B]. Innermost-last so nesting collapses in one sweep."""
    while True:
        starts = [mt for mt in re.finditer(r'(?<![A-Za-z0-9_.])at\s*\(', line)
                  if all(mask[k] for k in range(mt.start(), mt.end()))]
        if not starts: return line
        mt = starts[-1]
        depth, j, comma, n = 1, mt.end(), -1, len(line)
        while j < n:
            ch = line[j]
            if not mask[j]: j += 1; continue        # inside a string: not syntax
            if ch in "([{": depth += 1
            elif ch in ")]}":
                depth -= 1
                if depth == 0: break
            elif ch == "," and depth == 1: comma = j
            j += 1
        if j >= n or comma < 0: return line         # malformed - leave it alone
        a, b = line[mt.end():comma].strip(), line[comma+1:j].strip()
        line = line[:mt.start()] + a + "[" + b + "]" + line[j+1:]
        mask = build_mask(line, mask_comments[0])

def sample_mask(line):
    """True only where a v1 WORD is code rather than English.

    A doc comment mixes both. `Map a parser type-node ...` and `-1 if there is
    no match` are prose - rewriting those words turns the sentence into
    nonsense. Code lives in two places: inside `backticks`, and on a sample
    line, which is a comment indented three or more spaces that carries at
    least one of ( = : - the punctuation English does not use that way."""
    m = [False] * len(line)
    if '#' not in line: return m
    cut = line.index('#')
    com = line[cut:]
    if re.match(r'#\s{3,}\S', com) and re.search(r'[(=:]', com):
        for k in range(cut, len(line)): m[k] = True
        return m
    for mt in re.finditer(r'`[^`]*`', line):        # inside backticks
        if mt.start() >= cut:
            for k in range(mt.start() + 1, mt.end() - 1): m[k] = True
    return m

def ax_v1(line, mask):
    """The retired v1 words, for DOC COMMENTS that still teach them."""
    # `len(` is always code - no English sentence writes it. The rest are
    # ordinary English words too, so they only move inside a sample or
    # backticks.
    line = sub_masked(line, build_mask(line, True), r'\blen\(', 'length(')
    rules = [
        (r'\bpub fn\s+(?=[a-z_])', 'public define '),
        (r'\bfn\s+(?=[a-z_][A-Za-z0-9_]*\s*\()', 'define '),
        (r'\bpub\s+(?=define|fn|[a-z_])', 'public '),
        (r'\bmut\s+(?=[a-z_])', 'edit '),
        (r'\bmatch\b', 'choose'),
        (r'\byield\b', 'collect'),
        (r'\bText\b', 'text'),
        (r'\bMap\b', 'table'),
        (r'\bbool\b', 'truth'),
    ]
    for pat, rep in rules:
        line = sub_masked(line, sample_mask(line), pat, rep)
    return line

def file_arm(lines):
    """`Pat -> value` becomes `Pat then value`, but ONLY inside a `choose`.

    An arrow in a comment usually means YIELDS - `split(s, sep) -> [a]`,
    `define f() -> int:`, `function(T) -> R`. Only the arms under a
    `choose ...:` line carry the match-arm arrow, so that is the only place
    this touches. State resets at the first line that is not an indented
    comment, which is what ends a sample block."""
    out, in_choose = [], False
    for line in lines:
        if '#' not in line:
            in_choose = False; out.append(line); continue
        cut = line.index('#')
        head, com = line[:cut], line[cut:]
        if re.search(r'\b(choose|match)\b.*:', com):
            in_choose = True; out.append(line); continue
        if re.match(r'#\s{4,}\S', com) is None:
            in_choose = False; out.append(line); continue
        if in_choose and '->' in com:
            out.append(head + re.sub(r'\s*->\s*', ' then ', com)); continue
        out.append(line)
    return out

def file_codearm(lines):
    """`Pat -> value` becomes `Pat then value` in CODE, inside a `choose`.

    The arrow means three different things in this language: a match arm, a
    return type (`define f() -> int:`), and a function type (`function(T) ->
    R`). Only the first one is being retired, and only the arms under a
    `choose ...:` line are it. Tracking that block is the whole job - a line
    that declares anything ends it, and so does leaving the indentation.
    """
    out, arm_col = [], -1
    for line in lines:
        code = line.split('#')[0]
        if not code.strip():
            out.append(line); continue
        indent = len(code) - len(code.lstrip())
        if re.search(r'\bchoose\b.*:\s*$', code):
            arm_col = indent; out.append(line); continue
        if arm_col < 0 or indent <= arm_col:
            arm_col = -1
        if arm_col < 0 or '->' not in code:
            out.append(line); continue
        if re.search(r'\b(define|external|function|effect|type)\b', code):
            out.append(line); continue
        # Rewrite only outside strings, so a `->` inside a literal stays.
        m = build_mask(line, False)
        out.append(sub_masked(line, m, r'\s*->\s*', ' then '))
    return out

FILE_AXES = {'arm': file_arm, 'codearm': file_codearm}

AXES = {"until": ax_until, "is": ax_is, "index": ax_index, "v1": ax_v1}
mask_comments = [False]

def rewrite(line, axis, comments_ok=False):
    mask_comments[0] = comments_ok
    return AXES[axis](line, build_mask(line, comments_ok))

def main():
    args = sys.argv[1:]
    axis = args.pop(0)
    comments_ok = "--comments" in args; args = [a for a in args if a != "--comments"]
    dry = "--dry" in args; args = [a for a in args if a != "--dry"]
    files = []
    for root in args:
        if os.path.isfile(root): files.append(root); continue
        for d, _, fs in os.walk(root):
            files += [os.path.join(d, f) for f in fs if f.endswith(".or")]
    changed = lines_changed = 0
    for p in sorted(files):
        src = open(p, encoding="utf-8", errors="replace").read()
        old_lines = src.split("\n")
        if axis in FILE_AXES:
            new = FILE_AXES[axis](old_lines)
            hits = sum(1 for a, b in zip(old_lines, new) if a != b)
        else:
            new, hits = [], 0
            for line in old_lines:
                r = rewrite(line, axis, comments_ok)
                if r != line: hits += 1
                new.append(r)
        if hits:
            changed += 1; lines_changed += hits
            if not dry: open(p, "w", encoding="utf-8", newline="\n").write("\n".join(new))
    print(f"{axis}: {lines_changed} rader i {changed} filer" + (" (dry)" if dry else ""))

if __name__ == "__main__":
    main()
