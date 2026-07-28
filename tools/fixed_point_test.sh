#!/usr/bin/env bash
# Fixed-point self-host proof:
#   1. orion.exe compiles bundle.or → orion-v2.exe
#   2. orion-v2.exe compiles a tiny program → tiny.exe
#   3. Run tiny.exe — if output matches, self-host is verified
#
# Prereq: orion.exe exists at dist/orion.exe (from tools/bootstrap_from_ll.sh
# on a fresh clone, or tools/self_bootstrap.sh). See tools/self_bootstrap.sh
# for the full fixpoint rebuild.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORION="$ROOT/dist/orion.exe"
ORION_V2="$ROOT/dist/orion-v2.exe"
CLANG="${CLANG:-C:/Program Files/LLVM/bin/clang.exe}"
[ -x "$CLANG" ] || CLANG="$(command -v clang || echo clang)"
RT="$ROOT/runtime/orion_rt.c"

if [ ! -f "$ORION" ]; then
    echo "ERROR: $ORION not found. Run tools/aot_bootstrap.sh first."
    exit 1
fi

echo "==> Step 1: orion.exe compiles itself → orion-v2.exe"
"$ORION" "$ROOT/dist/orion_self_bundled.or" "$ROOT/dist/orion_v2.ll"
# Link the RUNTIME too. The emitted module defines most helpers inline, so this
# used to link without it — until the compiler called a runtime-only symbol
# (`orion_os_private_kb`, for the --perf row) and the whole script broke with an
# undefined-symbol error. Linking what the compiler actually needs is the fix.
"$CLANG" "$ROOT/dist/orion_v2.ll" "$RT" -O2 -o "$ORION_V2"
ls -la "$ORION_V2"
echo ""

echo "==> Step 2: orion-v2.exe compiles a tiny program"
cat > /tmp/orion_tiny.or <<'EOF'
fn main() -> int:
    print_line("hello from self-hosted orion")
    42
EOF
"$ORION_V2" /tmp/orion_tiny.or /tmp/orion_tiny.ll
"$CLANG" /tmp/orion_tiny.ll "$RT" -O2 -o /tmp/orion_tiny.exe
echo ""

echo "==> Step 3: run + verify"
# The program exits 42 ON PURPOSE, and `set -e` aborts the script on a nonzero
# status inside a command substitution — so this test killed itself right before
# checking anything, and reported 42 as its own exit code.
set +e
output=$(/tmp/orion_tiny.exe)
exit_code=$?
set -e
echo "  output: $output"
echo "  exit:   $exit_code"
if [ "$output" = "hello from self-hosted orion" ] && [ "$exit_code" -eq 42 ]; then
    echo ""
    echo "==> SELF-HOST PROVEN. orion.exe compiles itself and the output is correct."
    echo "    Lodge-orion is no longer needed."
else
    echo ""
    echo "==> FIXED-POINT MISMATCH. Investigate."
    exit 1
fi
