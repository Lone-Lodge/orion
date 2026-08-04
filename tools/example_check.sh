#!/usr/bin/env bash
# example_check.sh - docs that cannot lie, all the way down.
#
# Every `example EXPR` line in an orb is a CLAIM (`example double(21) is 42`).
# This extracts each one, wraps it in a probe program (`use <orb>` + main
# returning 0 when the claim holds), compiles it with the real compiler and
# RUNS it. A false example fails the gate exactly like a failing test.
# It also reports how many public defines still lack an example - the
# mandatory-coverage ratchet tightens as the stdlib gets documented.
#
#   bash tools/example_check.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORION="$ROOT/dist/orion.exe"
CLANG="${CLANG:-C:/Program Files/LLVM/bin/clang.exe}"
[ -x "$CLANG" ] || CLANG="$(command -v clang || echo clang)"
WORK="$ROOT/dist/.examples"
rm -rf "$WORK"; mkdir -p "$WORK"
case "$(uname -s 2>/dev/null || echo Windows)" in
    MINGW*|MSYS*|CYGWIN*|Windows*) LIBM="" ;;
    *) LIBM="-lm" ;;
esac

fail=0; count=0; nodoc=0; excused=0
for orbdir in "$ROOT"/orbs/*/; do
    orb=$(basename "$orbdir")
    lib="$orbdir/lib.or"
    [ -f "$lib" ] || continue
    # Coverage counts the STDLIB - the orbs a user writes against. The
    # compiler's own orbs (orion_*) are internals: they are covered by the
    # test suite and the fixpoint, not by user-facing examples, and counting
    # them made the number say nothing.
    # Per FUNCTION, not per file: a public define is covered when its own body
    # carries an `example`, and excused when it carries `# no example: reason`.
    # Some functions cannot have one honestly - they write files, run commands,
    # sleep, print, or need a live peer - and those are proven by TESTS. Making
    # the excuse explicit is what lets "uncovered" mean "could and should, but
    # doesn't", i.e. a number that can actually reach zero.
    case "$orb" in orion_*) : ;; *)
        read -r c_pub c_ex c_no <<EOF
$(awk '
    /^public define / { if (started) { if (!has) miss++ } started=1; has=0; pub++; next }
    /^define |^external define |^type |^public type / { if (started) { if (!has) miss++; started=0 } next }
    started && /^[[:space:]]*example / { has=1; ex++ }
    started && /^[[:space:]]*# no example:/ { has=1; no++ }
    END { if (started && !has) miss++; print pub+0, ex+0, no+0 }
' "$lib")
EOF
        # A `# no example:` marker counts whether it sits INSIDE the body or on
        # the line just above the signature - both read naturally, so both are
        # accepted (the short form `define f() = expr` has no body to put it in).
        missing=$(awk '
            /^public define / { if (started && !has) miss++; started=1; has=(prev_marker?1:0); prev_marker=0; next }
            /^define |^external define |^type |^public type / { if (started && !has) { miss++ }; started=0; prev_marker=0; next }
            /^[[:space:]]*# no example:/ { prev_marker=1; if (started) has=1; next }
            started && /^[[:space:]]*example / { has=1 }
            { prev_marker=0 }
            END { if (started && !has) miss++; print miss+0 }
        ' "$lib")
        nodoc=$((nodoc + missing))
        excused=$((excused + c_no))
    ;; esac
    n=0
    grep '^[[:space:]]*example ' "$lib" | sed 's/^[[:space:]]*example //' | while IFS= read -r expr; do
        n=$((n + 1))
        probe="$WORK/${orb}_$n.or"
        {
            echo "use $orb"
            echo "define main() -> int:"
            echo "    if $expr:"
            echo "        0"
            echo "    else:"
            echo "        1"
        } > "$probe"
        if ! "$ORION" "$probe" "$WORK/p.ll" "$ROOT/orbs" > "$WORK/log.txt" 2>&1; then
            printf "  %-28s COMPILE FAILED\n" "$orb #$n"; echo FAIL >> "$WORK/fails"
            continue
        fi
        # -lm: the num orb's transcendentals need libm on Linux. NOT on
        # Windows - lld-link then demands an m.lib that does not exist.
        if ! "$CLANG" "$WORK/p.ll" "$ROOT/runtime/orion_cli.c" "$ROOT/runtime/orion_rt.c" $LIBM -o "$WORK/p.exe" > /dev/null 2>&1; then
            printf "  %-28s LINK FAILED\n" "$orb #$n"; echo FAIL >> "$WORK/fails"
            continue
        fi
        if "$WORK/p.exe"; then
            :
        else
            printf "  %-28s FALSE: example %s\n" "$orb #$n" "$expr"
            echo FAIL >> "$WORK/fails"
        fi
        echo x >> "$WORK/count"
    done
done
count=$( [ -f "$WORK/count" ] && wc -l < "$WORK/count" || echo 0 )
fail=$( [ -f "$WORK/fails" ] && wc -l < "$WORK/fails" || echo 0 )
echo "  examples: $count ran, $fail false/broken; $nodoc stdlib define(s) uncovered, $excused excused (proven by tests)"
[ "$fail" = "0" ]
