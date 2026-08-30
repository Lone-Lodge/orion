#!/usr/bin/env bash
# fp_determinism_test.sh - the float arithmetic a replay depends on stays
# exactly what IEEE-754 says, on every target.
#
#   bash tools/fp_determinism_test.sh
#
# A deterministic simulation needs `+ - * / sqrt` to be correctly rounded and
# to STAY that way. Two things break it, and neither announces itself:
#
#   FUSION   `a * b + c` compiled to one fma rounds ONCE instead of twice.
#            Faster, more accurate, and a different number - so native and
#            wasm (which has no fma) disagree and a replay diverges.
#   FAST-MATH  reassociation, reciprocals, flushed denormals. Same story,
#            worse, and it can arrive as one flag in a build script.
#
# Both are currently impossible, and NOT because a flag forbids them: the
# emitter writes bare `fmul` and `fadd` with no fast-math flags at all, and
# LLVM may only fuse instructions that carry `contract`. Measured: even
# `-mfma -ffp-contract=fast` produces no fma from this IR, because the
# command line cannot grant permission the instructions did not ask for.
#
# That is a good property held up by nothing. This gate holds it up. If the
# emitter ever learns to write `fmul fast` - as an optimisation, innocently -
# this goes red the same day instead of the day a replay stops matching.
#
# Condition 3 (no transcendentals in simulation code) has its own gate:
# tests/suite/negative/det_libm.or. Condition 4 (reduction order) is a
# property of the parallel runtime, not of the emitted IR, and is not here.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORION="${ORION:-$ROOT/dist/orion.exe}"
CLANG="${CLANG:-C:/Program Files/LLVM/bin/clang.exe}"
[ -x "$CLANG" ] || CLANG="$(command -v clang || echo clang)"
[ -x "$ORION" ] || { echo "no $ORION - bash tools/bootstrap.sh"; exit 1; }

WORK="$ROOT/dist/.fpdet"
rm -rf "$WORK"; mkdir -p "$WORK"
SRC="$WORK/fp.or"
LL="$WORK/fp.ll"

cat > "$SRC" <<'ORION_SRC'
# Every shape a fusion or a reassociation would like to eat.
define mix(a: number, b: number, c: number) -> number:
    a * b + c

define scaled(a: number, b: number, c: number, d: number) -> number:
    a * b + c * d

define rooted(a: number, b: number) -> number:
    sqrt(a * a + b * b)

define divided(a: number, b: number, c: number) -> number:
    a / b + c

define main() -> number:
    print_line("{mix(1.5, 2.5, 3.5)} {scaled(1.5, 2.5, 3.5, 4.5)} {rooted(3.0, 4.0)} {divided(7.0, 2.0, 1.25)}")
    0
ORION_SRC

fail=0

"$ORION" "$SRC" "$LL" "$ROOT/orbs" --quiet >/dev/null 2>&1 || {
    echo "  fp: FAIL - the probe did not compile"
    exit 1
}

# 1. No fast-math flag on any float instruction. LLVM writes them directly
#    after the opcode and BEFORE the type - `fmul contract double`, not
#    `fmul double contract`, which is the way this check had it wrong at
#    first and passed a doctored file it should have caught.
BAD="$(grep -nE '= *(fadd|fsub|fmul|fdiv|frem|fneg|fcmp) +(fast|contract|nnan|ninf|nsz|arcp|afn|reassoc)\b' "$LL" || true)"
if [ -n "$BAD" ]; then
    echo "  fp: FAIL - the emitter wrote a fast-math flag:"
    printf '%s\n' "$BAD" | head -5
    fail=1
else
    echo "  fp ok  no fast-math flag on any float instruction"
fi

# 2. No fusion, even when the target has the instruction AND the command line
#    asks for it. This is the property that makes native and wasm agree.
if "$CLANG" -S -O2 -mfma -ffp-contract=fast "$LL" -o "$WORK/fp.s" -Wno-override-module >/dev/null 2>&1; then
    FMA="$(grep -ciE 'vfmadd|vfmsub|[^a-z]fmadd|[^a-z]fmsub' "$WORK/fp.s" || true)"
    if [ "$FMA" != "0" ]; then
        echo "  fp: FAIL - $FMA fused multiply-add(s) under -mfma -ffp-contract=fast"
        fail=1
    else
        echo "  fp ok  no fma even under -mfma -ffp-contract=fast"
    fi
else
    # A target without -mfma (arm, or a clang that rejects it) cannot fuse the
    # x86 way; check 1 is the portable half and it already ran.
    echo "  fp ..  -mfma not accepted here, skipping the instruction check"
fi

# 3. The answers themselves, so a change that alters a number is caught even
#    if it arrives by some route this gate did not imagine.
if "$CLANG" "$LL" "$ROOT/runtime/orion_rt.c" "$ROOT/runtime/orion_cli.c" "$ROOT/runtime/net_min.c" \
      -O2 -o "$WORK/fp.exe" -Wno-override-module >/dev/null 2>&1; then
    GOT="$("$WORK/fp.exe" | tr -d '\r')"
    # 1.5*2.5+3.5, 1.5*2.5+3.5*4.5, sqrt(9+16), 7/2+1.25
    WANT="7.25 19.5 5 4.75"
    if [ "$GOT" = "$WANT" ]; then
        echo "  fp ok  $GOT"
    else
        echo "  fp: FAIL - answers changed: got '$GOT', want '$WANT'"
        fail=1
    fi
else
    echo "  fp ..  could not link the probe, skipping the answer check"
fi

rm -rf "$WORK"
[ "$fail" -eq 0 ] || exit 1
echo "  fp: float arithmetic is unfused and unflagged"
