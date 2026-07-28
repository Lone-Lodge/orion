#!/usr/bin/env bash
# compile_bench.sh — measure COMPILE performance and compare against a baseline.
#
# The compiler already printed a human timing line ("compiled 1319 ms (lex … |
# emit …)"), which is useful while you watch it and useless the next day: there
# was no way to answer "did that change make compilation slower?". `--perf` adds
# one machine-readable row per compile; this runs a fixed set of inputs, takes
# the best of N (wall clock on a laptop is noisy), and diffs against
# tools/compile_baseline.txt.
#
#   bash tools/compile_bench.sh            # compare against the baseline
#   bash tools/compile_bench.sh --update   # record a new baseline
#   REPS=5 bash tools/compile_bench.sh     # more repetitions
#
# A case that got more than THRESHOLD% slower is a failure, and the exit code is
# the number of regressions, so this can gate.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORION="$ROOT/dist/orion.exe"
BASELINE="$ROOT/tools/compile_baseline.txt"
REPS="${REPS:-3}"
THRESHOLD="${THRESHOLD:-25}"
# GATE=0 prints the numbers and exits 0. The baseline is wall clock recorded on
# one specific machine, so it can only judge THAT machine — a CI runner is
# simply slower, and best-of-N does not fix a slower box (measured: `interp` 25
# ms on the author's laptop, 40 ms on a GitHub Windows runner, both best of 3,
# neither one a regression). Comparing across hosts turns a gate into a coin
# flip, and a gate that cries wolf gets ignored, which is worse than no gate.
# So CI reports and the machine that owns the baseline enforces.
GATE="${GATE:-1}"
UPDATE=0
[ "${1:-}" = "--update" ] && UPDATE=1
[ -x "$ORION" ] || { echo "no dist/orion.exe — bash tools/bootstrap.sh"; exit 1; }

TMP="$ROOT/dist/.bench"
rm -rf "$TMP"; mkdir -p "$TMP"

# The inputs: the compiler's own bundle is the big one (half a megabyte of
# Orion, every language feature), then a few demos that lean on different
# paths — closures/generics, pattern matching, the text stdlib.
CASES="bundle:$ROOT/dist/orion_self_bundled.or
iter:$ROOT/examples/demos/iter_functional.or
interp:$ROOT/examples/demos/interpreter.or
csv:$ROOT/examples/demos/csv_table.or"

# Make sure the bundle exists (it is generated).
[ -f "$ROOT/dist/orion_self_bundled.or" ] || bash "$ROOT/tools/bundle_orbs.sh" >/dev/null

measure() {  # $1 = source path -> best PERF row of REPS runs
    local src="$1" best_ms=999999 best_row=""
    for _ in $(seq "$REPS"); do
        row="$("$ORION" "$src" "$TMP/out.ll" "$ROOT/orbs" --perf 2>/dev/null | grep '^PERF ' | head -1)"
        [ -z "$row" ] && continue
        ms="$(printf '%s' "$row" | sed -n 's/.*total_ms=\([0-9]*\).*/\1/p')"
        if [ -n "$ms" ] && [ "$ms" -lt "$best_ms" ]; then
            best_ms="$ms"; best_row="$row"
        fi
    done
    printf '%s' "$best_row"
}

field() { printf '%s' "$1" | sed -n "s/.*$2=\([0-9]*\).*/\1/p"; }

RESULTS="$TMP/results.txt"
: > "$RESULTS"
printf "  %-8s %8s %8s %8s %8s %8s %10s\n" case total_ms lex parse ir emit ms/kloc
for entry in $CASES; do
    name="${entry%%:*}"; src="${entry#*:}"
    [ -f "$src" ] || { printf "  %-8s (missing)\n" "$name"; continue; }
    row="$(measure "$src")"
    [ -z "$row" ] && { printf "  %-8s FAILED to compile\n" "$name"; continue; }
    printf "  %-8s %8s %8s %8s %8s %8s %10s\n" "$name" \
        "$(field "$row" total_ms)" "$(field "$row" lex_ms)" "$(field "$row" parse_ms)" \
        "$(field "$row" ir_ms)" "$(field "$row" emit_ms)" "$(field "$row" ms_per_kloc)"
    echo "$name $(field "$row" total_ms) $(field "$row" lines) $(field "$row" insts) $(field "$row" rss_kb)" >> "$RESULTS"
done

if [ "$UPDATE" = "1" ]; then
    {
        echo "# compile_bench baseline: case total_ms lines insts rss_kb"
        echo "# best of $REPS runs; regenerate with: bash tools/compile_bench.sh --update"
        cat "$RESULTS"
    } > "$BASELINE"
    echo
    echo "  baseline written to tools/compile_baseline.txt"
    rm -rf "$TMP"
    exit 0
fi

if [ ! -f "$BASELINE" ]; then
    echo
    echo "  no baseline yet — record one: bash tools/compile_bench.sh --update"
    rm -rf "$TMP"
    exit 0
fi

echo
regressions=0
while read -r name ms lines insts rss; do
    case "$name" in \#*|"") continue ;; esac
    now="$(grep "^$name " "$RESULTS" | awk '{print $2}')"
    [ -z "$now" ] && continue
    # Integer percent change; guard the tiny cases where 1ms of noise is 50%.
    if [ "$ms" -gt 0 ]; then
        delta=$(( (now - ms) * 100 / ms ))
    else
        delta=0
    fi
    if [ "$now" -le 30 ] && [ "$ms" -le 30 ]; then
        verdict="noise-floor"
    elif [ "$delta" -gt "$THRESHOLD" ]; then
        verdict="SLOWER by ${delta}%"
        regressions=$((regressions + 1))
    elif [ "$delta" -lt "-$THRESHOLD" ]; then
        verdict="faster by ${delta#-}%"
    else
        verdict="within ${THRESHOLD}%"
    fi
    printf "  %-8s %5s ms vs %5s ms baseline   %s\n" "$name" "$now" "$ms" "$verdict"
done < "$BASELINE"

rm -rf "$TMP"
echo
if [ "$regressions" = "0" ]; then
    echo "  compile perf: no regressions over ${THRESHOLD}%"
elif [ "$GATE" = "0" ]; then
    echo "  compile perf: $regressions case(s) over ${THRESHOLD}% (reported, not gated:"
    echo "                the baseline belongs to another machine)"
    exit 0
else
    echo "  compile perf: $regressions case(s) slower than the baseline"
fi
exit "$regressions"
