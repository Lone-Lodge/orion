#!/usr/bin/env bash
# debug_test.sh — debugger v1, end to end. Proves: `orbit debug` builds with
# the call trail and a trapped run (index out of range here) prints the last
# calls newest-first; breakpoint() reports its enclosing function and, with
# stdin at EOF, continues instead of hanging; a plain `orbit run` of the same
# program prints NO trail (the instrumentation is opt-in).
#
# stdin comes from /dev/null on purpose: on a terminal breakpoint() waits for
# Enter, which is right for a human and wrong for a gate.
#
#   bash tools/debug_test.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORBIT="$ROOT/dist/orbit.exe"
[ -x "$ORBIT" ] || { echo "build orbit first: bash tools/build_orbit.sh"; exit 1; }
WORK="$ROOT/dist/.dbgtest"
rm -rf "$WORK"; mkdir -p "$WORK"
fail() { echo "debug_test: FAIL — $1"; exit 1; }

cat > "$WORK/prog.or" <<'EOF'
define inner(n: int) -> int:
    breakpoint()
    xs = [1, 2, 3]
    at(xs, n)

define middle(n: int) -> int:
    inner(n + 2)

define main() -> int:
    a = middle(0)
    b = middle(5)
    a + b
EOF

cd "$WORK"
"$ORBIT" debug prog.or < /dev/null > debug.txt 2>&1
code=$?
[ "$code" = "70" ] || fail "traced run should trap with 70, got $code"
grep -q 'breakpoint in `inner`' debug.txt || fail "breakpoint did not name its function"
grep -q 'last 5 call(s), newest first' debug.txt || fail "no call trail printed"
grep -q 'list index 7 out of range' debug.txt || fail "the trap itself is missing"
# newest-first: the line right after the trap's trail header is `inner`
after=$(grep -A1 'last 5 call(s)' debug.txt | sed -n 2p)
echo "$after" | grep -q 'inner' || fail "trail is not newest-first (got: $after)"

"$ORBIT" run prog.or < /dev/null > plain.txt 2>&1
code=$?
[ "$code" = "70" ] || fail "plain run should still trap with 70, got $code"
grep -q 'last 5 call(s)' plain.txt && fail "untraced run printed a trail"
grep -q 'breakpoint in' plain.txt || fail "breakpoint() should still report in an untraced run"

echo "  debugger: trail on trap + breakpoint + opt-in instrumentation all hold"
