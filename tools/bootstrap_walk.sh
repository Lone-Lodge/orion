#!/bin/bash
# bootstrap_walk.sh - rebuild dist/orion.exe when the only usable seed is an
# OLDER compiler than the sources.
#
# The compiler's own sources use builtins the compiler grew over time, so a
# seed from N weeks ago cannot compile today's tree in one step: it reports
# "unknown function `length`" and stops. The way through is the way the
# compiler actually got here - build each step with the step before it.
#
# Give it a starting binary that can build SOME commit, and it walks forward
# through the history of orbs/, taking the largest jump that still compiles,
# until it reaches the working tree.
#
#   bash tools/bootstrap_walk.sh /path/to/known-good-orion.exe
#
# Leaves the result in dist/orion.exe.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SEED="${1:?usage: bootstrap_walk.sh <known-good-orion.exe> [commit-the-seed-was-built-from]}"
CLANG="${CLANG:-C:/Program Files/LLVM/bin/clang.exe}"
[ -x "$CLANG" ] || CLANG="$(command -v clang || echo clang)"
WORK="$ROOT/dist/.walk"
rm -rf "$WORK"; mkdir -p "$WORK"
STAGE="$WORK/stage.exe"
cp "$SEED" "$STAGE"

# Every commit that touched the orbs, oldest first, plus the working tree.
cd "$ROOT"
mapfile -t ALL < <(git log --reverse --format=%H -- orbs/)
# Start at the commit the seed itself was built from, not at the beginning of
# history - a seed from August cannot build sources from March either.
FROM="${2:-}"
STEPS=()
seen=0
for c in "${ALL[@]}"; do
    if [ -z "$FROM" ] || [ $seen -eq 1 ] || [ "$c" = "$FROM" ]; then seen=1; STEPS+=("$c"); fi
done
[ ${#STEPS[@]} -eq 0 ] && STEPS=("${ALL[@]}")
STEPS+=("WORKTREE")
echo "==> ${#STEPS[@]} steps to walk"

# Can $STAGE build the sources laid out in $1? Leaves the IR at $2.
try_build() {
    # The copy INSIDE the laid-out tree, or it would bundle the main
    # tree's orbs and prove nothing.
    ( cd "$1" && bash "$1/tools/bundle_orbs.sh" >/dev/null 2>&1 ) || return 1
    "$STAGE" "$1/dist/orion_self_bundled.or" "$2" >/dev/null 2>&1 || return 1
    # A bundle that "compiles" to nothing is the runtime prelude alone: the
    # compiler silently dropped everything. Real output is megabytes.
    [ "$(stat -c%s "$2" 2>/dev/null || echo 0)" -gt 1000000 ]
}

lay_out() {   # $1 = commit or WORKTREE, $2 = dir
    rm -rf "$2"; mkdir -p "$2/dist"
    # tools/ as well as orbs/: the bundle takes the driver from there, and a
    # bundle without it compiles to a program with no main - which looks
    # exactly like a compiler that silently dropped everything.
    if [ "$1" = "WORKTREE" ]; then
        cp -r "$ROOT/orbs" "$2/orbs"; cp -r "$ROOT/tools" "$2/tools"
    else
        git archive "$1" orbs tools | tar -x -C "$2"
    fi
}

lo=0
while [ $lo -lt ${#STEPS[@]} ]; do
    # Largest jump that still builds: try the end, then halve.
    hi=$((${#STEPS[@]} - 1))
    built=""
    while [ $hi -ge $lo ]; do
        step="${STEPS[$hi]}"
        lay_out "$step" "$WORK/src"
        if try_build "$WORK/src" "$WORK/step.ll"; then
            built="$step"; break
        fi
        [ $hi -eq $lo ] && break
        hi=$(( lo + (hi - lo) / 2 ))
    done
    if [ -z "$built" ]; then
        echo "!! stuck at step $lo (${STEPS[$lo]}) - the seed cannot build even the next commit"
        exit 1
    fi
    echo "==> built ${built:0:12} (step $hi of $((${#STEPS[@]} - 1)))"
    "$CLANG" "$WORK/step.ll" "$ROOT/runtime/orion_rt.c" -Os \
        -Xlinker /STACK:67108864 -Xlinker -MANIFEST:EMBED \
        -Xlinker "-MANIFESTINPUT:$ROOT/runtime/orion.manifest" -o "$WORK/next.exe"
    mv "$WORK/next.exe" "$STAGE"
    [ "$built" = "WORKTREE" ] && break
    lo=$((hi + 1))
done

cp "$STAGE" "$ROOT/dist/orion.exe"
echo "==> dist/orion.exe rebuilt from the working tree"
