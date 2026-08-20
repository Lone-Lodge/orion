#!/bin/bash
# bootstrap_bridge.sh - get past a commit that renames a builtin.
#
# A rename lands in ONE commit: the parser learns to map the new spoken word
# to the old one, and every source in the tree starts using the new word. The
# compiler built from the commit BEFORE it cannot read that - it does not know
# the word yet - so the chain stops with "unknown function `length`".
#
# The way through is the one the parser itself documents: build an in-between
# compiler from the PREVIOUS sources with the NEW commit's word map lifted in.
# It is then written in the old vocabulary and can read the new one, which is
# exactly enough to compile the renaming commit.
#
#   bash tools/bootstrap_bridge.sh <stage.exe> <blocked-commit> <out.exe>
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
STAGE="${1:?usage: bootstrap_bridge.sh <stage.exe> <blocked-commit> <out.exe>}"
BLOCKED="${2:?}"
OUT="${3:?}"
CLANG="${CLANG:-C:/Program Files/LLVM/bin/clang.exe}"
[ -x "$CLANG" ] || CLANG="$(command -v clang || echo clang)"
WORK="$ROOT/dist/.bridge"
rm -rf "$WORK"; mkdir -p "$WORK/src/dist"
cd "$ROOT"

PREV=$(git rev-parse "$BLOCKED^")
git archive "$PREV" orbs tools | tar -x -C "$WORK/src"

# The new word map, taken from the commit that introduced it.
git show "$BLOCKED:orbs/orion_parse/lib.or" | sed -n '/^define psr_spoken_builtin/,/^$/p' > "$WORK/map.or"
[ -s "$WORK/map.or" ] || { echo "no psr_spoken_builtin in $BLOCKED - not a rename commit"; exit 1; }

P="$WORK/src/orbs/orion_parse/lib.or"
if grep -q "^define psr_spoken_builtin" "$P"; then
    # It already has one: replace it wholesale with the newer, longer map.
    python - "$P" "$WORK/map.or" <<'PY'
import io, re, sys
src, mapf = sys.argv[1], sys.argv[2]
s = io.open(src, encoding="utf-8", newline="").read()
new = io.open(mapf, encoding="utf-8", newline="").read().rstrip() + "\n"
s = re.sub(r"define psr_spoken_builtin\(name: text\) -> text:\n(?:.*\n)*?(?=\n)", new, s, count=1)
io.open(src, "w", encoding="utf-8", newline="").write(s)
print("map replaced")
PY
else
    # First rename in the chain: add the map and route both call sites through it.
    python - "$P" "$WORK/map.or" <<'PY'
import io, sys
src, mapf = sys.argv[1], sys.argv[2]
s = io.open(src, encoding="utf-8", newline="").read()
new = io.open(mapf, encoding="utf-8", newline="").read().rstrip()
call = '{"node": {"kind": "Call", "callee": callee_name,'
assert call in s, "call site moved"
s = s.replace(call, '{"node": {"kind": "Call", "callee": psr_spoken_builtin(callee_name),', 1)
s = s.replace('"method": field_name,', '"method": psr_spoken_builtin(field_name),', 1)
s = s + "\n\n" + new + "\n"
io.open(src, "w", encoding="utf-8", newline="").write(s)
print("map added")
PY
fi

( cd "$WORK/src" && bash tools/bundle_orbs.sh >/dev/null 2>&1 )
"$STAGE" "$WORK/src/dist/orion_self_bundled.or" "$WORK/bridge.ll"
"$CLANG" "$WORK/bridge.ll" "$ROOT/runtime/orion_rt.c" -Os \
    -Xlinker /STACK:67108864 -Xlinker -MANIFEST:EMBED \
    -Xlinker "-MANIFESTINPUT:$ROOT/runtime/orion.manifest" -o "$OUT"
echo "==> bridge built: $OUT (reads $BLOCKED, written as $PREV)"
