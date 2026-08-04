#!/usr/bin/env bash
# seed_check.sh - can the CHECKED-IN seed still build the CURRENT compiler?
#
# WHY: tools/seed/orion.ll is the only way a fresh clone gets a first binary.
# It is a snapshot, so it rots the moment the compiler source starts using
# syntax the snapshot's parser does not know. Nothing noticed that, because
# everyday work runs self_bootstrap.sh, which starts from the dist/orion.exe
# you already have. The rot only surfaces on a machine that has no binary -
# i.e. someone else's first clone.
#
# This links the seed into a throwaway exe and asks it to compile today's
# bundle. Green means a fresh clone can bootstrap. Red means run:
#
#   bash tools/bundle_orbs.sh && dist/orion.exe dist/orion_self_bundled.or tools/seed/orion.ll
#
# and commit the refreshed seed.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SEED_LL="$ROOT/tools/seed/orion.ll"
WORK="$ROOT/dist/.seedcheck"
CLANG="${CLANG:-C:/Program Files/LLVM/bin/clang.exe}"
[ -x "$CLANG" ] || CLANG="$(command -v clang || echo clang)"

[ -f "$SEED_LL" ] || { echo "seed_check: no seed at tools/seed/orion.ll"; exit 1; }
mkdir -p "$WORK"

echo "==> bundling today's compiler source"
bash "$ROOT/tools/bundle_orbs.sh" >/dev/null
BUNDLE="$ROOT/dist/orion_self_bundled.or"

# Same host handling as bootstrap_from_ll.sh: the seed carries the Windows
# triple the compiler always emits; only Linux/Mac need retargeting.
echo "==> linking the seed into a throwaway compiler"
case "$(uname -s 2>/dev/null || echo Linux)" in
    MINGW*|MSYS*|CYGWIN*|Windows*)
        "$CLANG" "$SEED_LL" "$ROOT/runtime/orion_rt.c" -Os \
            -Xlinker /STACK:67108864 -o "$WORK/seed.exe" ;;
    Darwin)
        if [ "$(uname -m)" = "arm64" ]; then TRIPLE="arm64-apple-macosx"; else TRIPLE="x86_64-apple-macosx"; fi
        sed -e "2s#e-m:w#e-m:o#" -e "3s#x86_64-pc-windows-msvc[0-9.]*#${TRIPLE}#" \
            "$SEED_LL" > "$WORK/seed.host.ll"
        "$CLANG" "$WORK/seed.host.ll" "$ROOT/runtime/orion_rt.c" -Os -o "$WORK/seed.exe" ;;
    *)
        sed -e "2s#e-m:w#e-m:e#" -e "3s#x86_64-pc-windows-msvc[0-9.]*#x86_64-unknown-linux-gnu#" \
            "$SEED_LL" > "$WORK/seed.host.ll"
        "$CLANG" "$WORK/seed.host.ll" "$ROOT/runtime/orion_rt.c" -Os -o "$WORK/seed.exe" ;;
esac

# The compiler recurses deep; Windows reserves a big stack in the exe
# (/STACK above), POSIX raises it at run time. Without this the seed exe
# SEGFAULTS on the grown bundle and reports as "stale" - which is exactly
# what CI showed on ubuntu/macos while Windows stayed green.
case "$(uname -s 2>/dev/null || echo Windows)" in
    MINGW*|MSYS*|CYGWIN*|Windows*) : ;;
    *) ulimit -s unlimited 2>/dev/null || ulimit -s 65500 2>/dev/null || true ;;
esac

echo "==> the seed compiles today's bundle"
if "$WORK/seed.exe" "$BUNDLE" "$WORK/from_seed.ll" > "$WORK/log.txt" 2>&1; then
    rm -rf "$WORK"
    echo "==> SEED OK: a fresh clone can bootstrap from tools/seed/orion.ll"
    exit 0
fi

echo "==> SEED STALE: the committed seed can no longer build the compiler."
grep -m 5 -i 'error' "$WORK/log.txt" || tail -5 "$WORK/log.txt"
echo
echo "    Refresh it:"
echo "      bash tools/bundle_orbs.sh"
echo "      dist/orion.exe dist/orion_self_bundled.or tools/seed/orion.ll"
echo "    then re-run this check and commit tools/seed/orion.ll."
exit 1
