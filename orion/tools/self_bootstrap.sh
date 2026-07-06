#!/usr/bin/env bash
# self_bootstrap.sh — rebuild orion.exe using orion.exe itself. No lodge-orion.
#
# WHY: orion-self has out-grown lodge-orion's parser (it uses `else if` and
# other syntax lodge-orion's older parser rejects — "expected `:`, found If").
# So tools/aot_bootstrap.sh (which compiles the compiler via lodge-orion) can
# no longer parse orion-self. But the current orion.exe CAN — it's the
# self-hosted compiler. This uses it to rebuild itself:
#
#   orion.exe  bundle.or -> stage1.ll  ->  clang + orion_rt.c  ->  orion_new.exe
#   orion_new.exe  bundle.or -> stage2.ll     (the fixpoint check)
#   stage1.ll == stage2.ll  =>  install orion_new.exe as orion.exe
#
# Fast (~1s vs lodge-orion's 30-60 min) and one dependency closer to
# archiving lodge-orion entirely.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORION="$ROOT/dist/orion.exe"
DIST="$ROOT/dist"
CLANG="${CLANG:-C:/Program Files/LLVM/bin/clang.exe}"
[ -x "$CLANG" ] || CLANG="$(command -v clang || echo clang)"

echo "==> bundling orbs"
bash "$ROOT/tools/bundle_orbs.sh" >/dev/null
BUNDLE="$DIST/orion_self_bundled.or"

echo "==> stage 1: current orion.exe compiles the bundle"
"$ORION" "$BUNDLE" "$DIST/orion_stage1.ll"
echo "==> link stage 1 -> orion_new.exe (64MB stack: the compiler recurses deep)"
"$CLANG" "$DIST/orion_stage1.ll" "$ROOT/runtime/orion_rt.c" -Xlinker /STACK:67108864 -o "$DIST/orion_new.exe"

echo "==> stage 2: the NEW orion.exe re-compiles the bundle (fixpoint check)"
"$DIST/orion_new.exe" "$BUNDLE" "$DIST/orion_stage2.ll"

if diff -q "$DIST/orion_stage1.ll" "$DIST/orion_stage2.ll" >/dev/null; then
    cp "$DIST/orion_new.exe" "$ORION"
    rm -f "$DIST/orion_stage1.ll" "$DIST/orion_stage2.ll" "$DIST/orion_new.exe"
    echo "==> SUCCESS: orion.exe rebuilt, self-hosted, fixpoint reached (no lodge-orion)"
    exit 0
fi

# stage1 != stage2 is EXPECTED after an intentional codegen change: the old
# compiler renders the (new) bundle differently than the new compiler does.
# The new compiler must still be STABLE — compiling itself reproducibly. So
# iterate once more: build from stage2 and check stage2 == stage3.
echo "==> stage1 != stage2 (codegen changed) — iterating to confirm the new compiler is stable"
"$CLANG" "$DIST/orion_stage2.ll" "$ROOT/runtime/orion_rt.c" -Xlinker /STACK:67108864 -o "$DIST/orion_new2.exe"
"$DIST/orion_new2.exe" "$BUNDLE" "$DIST/orion_stage3.ll"

if diff -q "$DIST/orion_stage2.ll" "$DIST/orion_stage3.ll" >/dev/null; then
    cp "$DIST/orion_new2.exe" "$ORION"
    rm -f "$DIST/orion_stage1.ll" "$DIST/orion_stage2.ll" "$DIST/orion_stage3.ll" "$DIST/orion_new.exe" "$DIST/orion_new2.exe"
    echo "==> SUCCESS: converged after codegen change (stage2 == stage3), orion.exe rebuilt"
else
    echo "==> FAILED: still diverging (stage2 != stage3) — non-deterministic compile, orion.exe NOT replaced"
    exit 1
fi
