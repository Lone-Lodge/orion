#!/usr/bin/env bash
# negative_test.sh - the things that must NOT compile.
#
# The positive suite (tools/test.sh) can only prove properties that produce a
# runnable binary, so every "this is a hard compile error" claim went unchecked:
# nothing failed if the check silently stopped working. Each file here carries
# its own expectation on line 1:
#
#     # expect: <substring the compiler must print>
#
# A case passes when the compiler FAILS and its output contains that substring.
#
#   bash tools/negative_test.sh
#
# Exit code is the number of failing cases.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORION="$ROOT/dist/orion.exe"
DIR="$ROOT/examples/tests/negative"
[ -x "$ORION" ] || { echo "no dist/orion.exe - bash tools/bootstrap.sh"; exit 1; }

TMP="$(mktemp -d)"
pass=0; fail=0
# `negative/orbs/` holds deliberately broken library code (see orb_line.or).
# It is passed as an EXTRA root, ahead of the real one, and nothing else in the
# tree compiles it.
for f in "$DIR"/*.or; do
    name="$(basename "$f")"
    want="$(head -1 "$f" | sed -E 's/^# expect: ?//')"
    # TIMEOUT, not just an exit code: a parser that cannot make progress used to
    # spin forever (an unterminated interpolation hole did exactly that), and a
    # hang in the compiler is worse than a bad message. A case that does not
    # finish in 30s is a failure.
    # macOS ships no `timeout` (coreutils calls it gtimeout) - without this
    # probe every fixture "failed" with `timeout: command not found`.
    TO="$(command -v timeout || command -v gtimeout || true)"
    out="$(${TO:+"$TO" 30} "$ORION" "$f" "$TMP/out.ll" "$DIR/orbs" "$ROOT/orbs" 2>&1)"
    code=$?
    if [ "$code" = "124" ]; then
        printf "  %-22s HUNG (30s timeout)\n" "$name"
        fail=$((fail + 1))
        continue
    fi
    if [ "$code" = "0" ]; then
        printf "  %-22s COMPILED (must fail)\n" "$name"
        fail=$((fail + 1))
    elif echo "$out" | grep -qF "$want"; then
        printf "  %-22s ok\n" "$name"
        pass=$((pass + 1))
    else
        printf "  %-22s WRONG ERROR (want: %s)\n" "$name" "$want"
        echo "$out" | grep -i error | head -2 | sed 's/^/      /'
        fail=$((fail + 1))
    fi
done
rm -rf "$TMP"

if [ "$fail" = "0" ]; then
    echo "  negative: all $pass rejected as expected"
else
    echo "  negative: $fail of $((pass + fail)) wrong"
fi
exit "$fail"
