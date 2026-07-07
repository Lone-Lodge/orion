#!/bin/bash
# orbit test — run the smoke suite. Builds on examples/tests runner.
# Filter via first arg: `tools/test.sh sum_types` runs only matching tests.

set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
FILTER="${1:-}"
# Self-hosted orbit (built by tools/build_orbit.sh). No lodge-orion.
ORION_BIN="$ROOT/dist/orbit.exe"
[ -x "$ORION_BIN" ] || { echo "build orbit first: bash tools/build_orbit.sh"; exit 1; }

cd "$ROOT/examples/tests"

if [ -n "$FILTER" ]; then
    echo "Filter: $FILTER (only matching test files run)"
fi

rm -rf target dist build 2>/dev/null
# Stream the runner's per-test rows live (no grep pipe — a pipe both filters
# out the progress rows and block-buffers, so nothing showed until the end).
# The runner prints one line per test as it finishes, then the Pass/Fail summary.
"$ORION_BIN" run src/main.or main
