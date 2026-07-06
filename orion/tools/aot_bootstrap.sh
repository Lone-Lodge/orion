#!/usr/bin/env bash
# DEPRECATED — do not use. This bootstrapped orion.exe *through lodge-orion*,
# but orion-self has since outgrown lodge-orion's parser (`else if` etc.), so
# lodge-orion can no longer parse the compiler. Use tools/self_bootstrap.sh,
# which rebuilds orion.exe with orion.exe itself (fixpoint-checked, ~1s, no
# lodge-orion). Kept only as a record of the original bootstrap.
echo "aot_bootstrap.sh is DEPRECATED — use tools/self_bootstrap.sh instead." >&2
exit 1

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="$ROOT/dist/orion_self_bundled.or"
COMPILE_DIR="$ROOT/examples/compile_or"
ORION_OUT="$ROOT/dist/orion.exe"
LODGE="E:/lone-lodge/lodge-orion/orion/target/release/orbit.exe"

echo "==> Step 1: bundle orbs"
bash "$ROOT/tools/bundle_orbs.sh"
ls -la "$BUNDLE"
echo ""

echo "==> Step 2: feed bundle to compile_or pipeline"
cp "$BUNDLE" "$COMPILE_DIR/test_files/demo.or"
cd "$COMPILE_DIR"
rm -rf target dist
echo "    (lodge-orion will interpret orion-self's compiler logic against the bundle source)"
echo "    expected time: 30-60 min"
time "$LODGE" run src/main.or main 2>&1 | tail -20
echo ""

echo "==> Step 3: install orion.exe"
if [ -f "dist/demo.exe" ]; then
    cp "dist/demo.exe" "$ORION_OUT"
    ls -la "$ORION_OUT"
    echo ""
    echo "==> SUCCESS: orion.exe ready at $ORION_OUT"
    echo "    Test: $ORION_OUT some_input.or output.ll"
else
    echo "==> FAILED: dist/demo.exe not produced"
    exit 1
fi
