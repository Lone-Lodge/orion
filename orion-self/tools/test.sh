#!/bin/bash
# orbit test — run the smoke suite. Builds on examples/tests runner.
# Filter via first arg: `tools/test.sh sum_types` runs only matching tests.

set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
FILTER="${1:-}"
ORION_BIN="E:/lone-lodge/lodge-orion/orion/target/release/orbit.exe"

cd "$ROOT/examples/tests"

if [ -n "$FILTER" ]; then
    echo "Filter: $FILTER (only matching test files run)"
fi

rm -rf target dist 2>/dev/null
"$ORION_BIN" run src/main.or main 2>&1 | grep -E "Pass:|Fail:|FAIL"
