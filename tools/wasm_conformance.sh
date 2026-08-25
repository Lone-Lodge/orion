#!/bin/bash
# WebAssembly conformance gate: compile every smoke test (tests/suite/tests)
# through the wasm backend, run each in node, and compare the answer to the
# native expectation encoded in the filename. Categories: OK, MISMATCH (wrong
# answer), UNSUPPORTED (backend refuses to lower), TRAP, HANG (infinite loop,
# caught by a per-test timeout). Optional first arg filters by substring.
#
# Needs node and a built dist/orion.exe. Runs in CI (green.yml) as a REGRESSION
# gate: no filter -> the OK count must hold at its baseline and there must be no
# unexpected MISMATCH/FAIL (known gaps are allowlisted in wasm_conformance.js);
# exits non-zero otherwise. With a filter arg it only reports, never gates.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
# The compiler recurses deep; Windows reserves stack in the exe (/STACK),
# POSIX raises it here - without this, arm64 macOS segfaulted SILENTLY on
# the deepest compiles (closure combos) while linux squeaked by on 8 MB.
case "$(uname -s 2>/dev/null || echo Windows)" in
    MINGW*|MSYS*|CYGWIN*|Windows*) : ;;
    *) ulimit -s unlimited 2>/dev/null || ulimit -s 65500 2>/dev/null || true ;;
esac
[ -x "$ROOT/dist/orion.exe" ] || { echo "build orion first (bash tools/bootstrap.sh)"; exit 1; }
node "$ROOT/tools/wasm_conformance.js" "$ROOT" "$1"
