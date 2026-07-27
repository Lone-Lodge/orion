#!/usr/bin/env bash
# runtime_bench.sh — measure what the GENERATED code costs, per primitive.
#
# tools/compile_bench.sh gates compile time. This gates the other half: a
# codegen change that makes the compiler faster and the compiled program
# slower is not a win, and until now nothing in the repo would have said so.
#
#   bash tools/runtime_bench.sh            # compare against the baseline
#   bash tools/runtime_bench.sh --update   # record a new baseline
#   REPS=5 bash tools/runtime_bench.sh     # more repetitions
#
# examples/bench/runtime.or prints one `BENCH <case> <ms> <ops>` row per case,
# each sized to ~100ms. Best of REPS runs (wall clock on a laptop is noisy).
# A case more than THRESHOLD% slower than the baseline is a failure, and the
# exit code is the number of regressions, so this can gate.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORION="$ROOT/dist/orion.exe"
SRC="$ROOT/examples/bench/runtime.or"
BASELINE="$ROOT/tools/runtime_baseline.txt"
REPS="${REPS:-3}"
THRESHOLD="${THRESHOLD:-25}"
CLANG="${CLANG:-C:/Program Files/LLVM/bin/clang.exe}"
[ -x "$CLANG" ] || CLANG="$(command -v clang || echo clang)"
UPDATE=0
[ "${1:-}" = "--update" ] && UPDATE=1
[ -x "$ORION" ] || { echo "no dist/orion.exe — bash tools/bootstrap.sh"; exit 1; }

TMP="$ROOT/dist/.rtbench"
mkdir -p "$TMP"

# -O2, the same flags a real build uses (examples/tests/src/main.or, orbit).
# Anything measured at -O0 would be measuring the wrong binary.
echo "  building examples/bench/runtime.or (-O2)"
"$ORION" "$SRC" "$TMP/runtime.ll" "$ROOT/orbs" >/dev/null || { echo "  compile FAILED"; exit 1; }
[ -f "$TMP/orion_rt.o" ] || "$CLANG" -c -Os "$ROOT/runtime/orion_rt.c" -o "$TMP/orion_rt.o"
"$CLANG" "$TMP/runtime.ll" "$TMP/orion_rt.o" -O2 -Wno-override-module -o "$TMP/runtime.exe" || {
    echo "  link FAILED"; exit 1; }

# Best (lowest ms) per case across REPS runs.
RESULTS="$TMP/results.txt"
: > "$RESULTS"
RAW="$TMP/raw.txt"
: > "$RAW"
for _ in $(seq "$REPS"); do
    "$TMP/runtime.exe" | grep '^BENCH ' >> "$RAW"
done
awk '{ if (!($2 in best) || $3 < best[$2]) { best[$2] = $3; ops[$2] = $4 } }
     END { for (c in best) print c, best[c], ops[c] }' "$RAW" | sort > "$RESULTS"

printf "  %-12s %8s %12s %10s\n" case ms ops ns/op
while read -r name ms ops; do
    if [ "$ops" -gt 0 ]; then nsop=$(( ms * 1000000 / ops )); else nsop=0; fi
    printf "  %-12s %8s %12s %10s\n" "$name" "$ms" "$ops" "$nsop"
done < "$RESULTS"

if [ "$UPDATE" = "1" ]; then
    {
        echo "# runtime_bench baseline: case best_ms ops"
        echo "# best of $REPS runs; regenerate with: bash tools/runtime_bench.sh --update"
        cat "$RESULTS"
    } > "$BASELINE"
    echo
    echo "  baseline written to tools/runtime_baseline.txt"
    exit 0
fi

if [ ! -f "$BASELINE" ]; then
    echo
    echo "  no baseline yet — record one: bash tools/runtime_bench.sh --update"
    exit 0
fi

echo
regressions=0
while read -r name ms ops; do
    case "$name" in \#*|"") continue ;; esac
    now="$(awk -v n="$name" '$1 == n { print $2 }' "$RESULTS")"
    [ -z "$now" ] && continue
    if [ "$ms" -gt 0 ]; then delta=$(( (now - ms) * 100 / ms )); else delta=0; fi
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
    printf "  %-12s %5s ms vs %5s ms baseline   %s\n" "$name" "$now" "$ms" "$verdict"
done < "$BASELINE"

echo
if [ "$regressions" = "0" ]; then
    echo "  runtime perf: no regressions over ${THRESHOLD}%"
else
    echo "  runtime perf: $regressions case(s) slower than the baseline"
fi
exit "$regressions"
