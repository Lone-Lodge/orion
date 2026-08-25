"""Delete the `use` lines auto-use has made unnecessary.

Per file: try dropping the whole `use` block, and if that does not hold, drop
one line at a time. A drop holds when the program still compiles AND comes out
the same shape - every function, and inside each one the same sequence of
opcodes. Bytes are the wrong comparison here: dropping a `use` changes the
ORDER orbs are discovered in, which moves functions and string constants around
the bundle without changing the program.

The shape check is the point. `folio` wrote `use file (open_read, ...)` - a
list that deliberately left `ok` out - and dropping it made `ok(handle)` reach
file's `ok` instead of the core variant. Still compiled. Different program.

    python drop_use.py <orion.exe> <project-dir> [entry] [extra-root...]
"""
import re, subprocess, sys, io, os, shutil

ORION, ROOT = sys.argv[1], sys.argv[2]
ENTRY = sys.argv[3] if len(sys.argv) > 3 else "src/main.or"
# Extra search roots. `orbit` also sweeps the workspace so a name-only dep
# resolves wherever it lives; nothing here reads that sweep, so a project that
# leans on it (the standard library, a sibling's orbs) has to be told.
EXTRA = sys.argv[4:]
LL = os.path.join(ROOT, "build", "_dropuse.ll")
USE = re.compile(r'^use \S')

def orb_dirs():
    toml = os.path.join(ROOT, "Orbit.toml")
    out = []
    if os.path.exists(toml):
        for m in re.finditer(r'"path:([^"]+)"', io.open(toml, encoding="utf-8").read()):
            d = m.group(1)
            for c in (d, d.rsplit("/", 1)[0]):
                if c not in out: out.append(c)
    out.append("orbs")
    return out + [e for e in EXTRA if e not in out]

def sources():
    out = []
    for base in ("src", "orbs", "tools"):
        for dp, dn, fn in os.walk(os.path.join(ROOT, base)):
            dn[:] = [x for x in dn if x not in ("build", "target", "dist")]
            out += [os.path.normpath(os.path.join(dp, f)) for f in fn if f.endswith(".or")]
    return out

def read(p): return io.open(p, encoding="utf-8").read().split("\n")
def write(p, ls): io.open(p, "w", encoding="utf-8", newline="\n").write("\n".join(ls))

def shape(path):
    out, cur = {}, None
    for line in io.open(path, encoding="utf-8"):
        line = line.strip()
        if line.startswith("define "):
            cur = line.split("(")[0]; out[cur] = []
        elif line == "}":
            cur = None
        elif cur is not None and line:
            body = line.split("= ", 1)[1] if "= " in line else line
            out[cur].append(body.split(" ")[0])
    return out

DIRS = orb_dirs()
def build():
    if os.path.exists(LL): os.remove(LL)
    r = subprocess.run([ORION, ENTRY, LL] + DIRS, cwd=ROOT,
                       capture_output=True, text=True, timeout=1800)
    return os.path.exists(LL) and "FAILED" not in r.stdout

# Read at the START OF ITS OWN TURN, never as one snapshot up front. Somebody
# else may be editing this tree, and a snapshot taken minutes ago written back
# over their file is not a migration, it is a revert.
orig = {}
uses = {}
for f in sources():
    ls = read(f)
    u = [i for i, l in enumerate(ls) if USE.match(l)]
    if u: uses[f] = u
total = sum(len(u) for u in uses.values())
print(f"{total} use-rader i {len(uses)} filer")

os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
if not build():
    print("bygger inte innan - hoppar"); sys.exit(1)
REF = shape(LL)

dropped = {p: set() for p in uses}
def apply(p):
    write(p, [l for i, l in enumerate(orig[p]) if i not in dropped[p]])

def holds():
    return build() and shape(LL) == REF

gone = 0
for p in sorted(uses):
    orig[p] = read(p)
    uses[p] = [i for i, l in enumerate(orig[p]) if USE.match(l)]
    if not uses[p]:
        print(f"  {os.path.relpath(p, ROOT)}: andrad under korningen, hoppas over", flush=True)
        continue
    dropped[p] = set(uses[p]); apply(p)
    if holds():
        gone += len(uses[p])
    else:
        # The block as a whole did not hold, so grow the drop set one line at
        # a time - each candidate tested on top of what already holds.
        keepdrop = set()
        for i in uses[p]:
            dropped[p] = keepdrop | {i}; apply(p)
            if holds(): keepdrop.add(i)
        gone += len(keepdrop)
        dropped[p] = keepdrop; apply(p)
    print(f"  {os.path.relpath(p, ROOT)}: -{len(dropped[p])}/{len(uses[p])}", flush=True)

ok = holds()
print(f"borttagna: {sum(len(d) for d in dropped.values())} av {total}")
print("bygger:", ok, " samma form:", ok)
os.remove(LL)
sys.exit(0 if ok else 1)
