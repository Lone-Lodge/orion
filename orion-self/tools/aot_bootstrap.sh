#!/usr/bin/env bash
# AOT-bootstrap pipeline:
#   1. Bundle all 5 orbs + driver into one .or
#   2. Use lodge-orion to compile the bundle → orion.exe (slow, last time!)
#   3. orion.exe is the self-hosted compiler — no more lodge-orion needed
#
# Run from orion-self/ root.

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
