#!/bin/bash
# WebAssembly conformance gate: compile every smoke test (examples/tests/tests)
# through the wasm backend, run each in node, and compare the answer to the
# native expectation encoded in the filename. Categories: OK, MISMATCH (wrong
# answer), UNSUPPORTED (backend refuses to lower), TRAP, HANG (infinite loop,
# caught by a per-test timeout). Optional first arg filters by substring.
#
# Needs node and a built dist/orion.exe. This is a dev gate, not part of the
# clang-only bootstrap.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
[ -x "$ROOT/dist/orion.exe" ] || { echo "build orion first (bash tools/bootstrap.sh)"; exit 1; }
node "$ROOT/tools/wasm_conformance.js" "$ROOT" "$1"
