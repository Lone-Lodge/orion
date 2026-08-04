#!/usr/bin/env bash
# fuzz.sh - feed the compiler damaged source and watch how it REACTS.
#
# A fuzzer does not need to know what a program means. It only needs to know
# what a healthy reaction looks like, and for a compiler there are exactly two:
#
#   * it compiles, and writes its output
#   * it refuses, with an error naming `file:line:col`
#
# Anything else is a finding: a hang, a crash, an internal trap ("list index -1
# out of range"), an error with no location, or silence with no output. Five bugs
# of exactly that shape turned up BY ACCIDENT while writing tests today - an
# unterminated interpolation hole that spun forever, an argument list with no
# no-progress guard, a match arm with no value. This looks for the rest.
#
#   bash tools/fuzz.sh            # 200 mutations (gate-sized, ~1 min)
#   ITERS=5000 bash tools/fuzz.sh # a real hunt
#   SEED=7 bash tools/fuzz.sh     # reproduce a run
#
# Findings are kept in dist/.fuzz-findings/ with the input that caused them.
# Exit code is the number of distinct findings.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORION="$ROOT/dist/orion.exe"
CORPUS="$ROOT/examples/tests/tests"
ITERS="${ITERS:-200}"
SEED="${SEED:-1}"
TIMEOUT="${FUZZ_TIMEOUT:-20}"
[ -x "$ORION" ] || { echo "no dist/orion.exe - bash tools/bootstrap.sh"; exit 1; }

WORK="$ROOT/dist/.fuzz"
FIND="$ROOT/dist/.fuzz-findings"
# Both directories: leaving old findings behind made a FIXED hang look like it
# was still there on the next run.
rm -rf "$WORK" "$FIND"; mkdir -p "$WORK" "$FIND"
RANDOM=$SEED

# Characters that mean something to the lexer and parser - the ones most likely
# to put it in a state nobody wrote code for.
CHARS='{}():[]"\|><~,.=-+*/#'"'"

seeds=()
for f in "$CORPUS"/*.or; do seeds+=("$f"); done
[ "${#seeds[@]}" -gt 0 ] || { echo "no corpus at $CORPUS"; exit 1; }

mutate() {  # $1 = source, $2 = destination
    local src="$1" dst="$2"
    local size lines op pos ch n
    size=$(wc -c < "$src")
    lines=$(wc -l < "$src")
    [ "$size" -lt 8 ] && { cp "$src" "$dst"; return; }
    op=$((RANDOM % 6))
    pos=$((RANDOM % (size - 1)))
    case "$op" in
        0)  # drop one byte
            { head -c "$pos" "$src"; tail -c "+$((pos + 2))" "$src"; } > "$dst" ;;
        1)  # duplicate one byte
            { head -c "$((pos + 1))" "$src"; head -c "$((pos + 1))" "$src" | tail -c 1; tail -c "+$((pos + 2))" "$src"; } > "$dst" ;;
        2)  # cut the file short
            head -c "$pos" "$src" > "$dst" ;;
        3)  # insert a character the parser cares about
            ch=$(printf '%s' "$CHARS" | cut -c "$((RANDOM % ${#CHARS} + 1))")
            { head -c "$pos" "$src"; printf '%s' "$ch"; tail -c "+$((pos + 1))" "$src"; } > "$dst" ;;
        4)  # delete a line
            if [ "$lines" -lt 2 ]; then cp "$src" "$dst"; else
                n=$((RANDOM % lines + 1)); sed "${n}d" "$src" > "$dst"; fi ;;
        5)  # repeat a line
            if [ "$lines" -lt 2 ]; then cp "$src" "$dst"; else
                n=$((RANDOM % lines + 1)); awk -v n="$n" '{print; if (NR == n) print}' "$src" > "$dst"; fi ;;
    esac
}

hangs=0; crashes=0; internals=0; unlocated=0; ok=0
report() {  # $1 = kind, $2 = input, $3 = detail
    local kind="$1" input="$2" detail="$3"
    local keep="$FIND/${kind}_$(basename "$input")"
    cp "$input" "$keep" 2>/dev/null
    printf "  %-9s %s\n" "$kind" "$detail"
}

echo "  fuzzing $ITERS mutations of ${#seeds[@]} seed files (seed=$SEED)"
for i in $(seq "$ITERS"); do
    seed_file="${seeds[$((RANDOM % ${#seeds[@]}))]}"
    case_file="$WORK/case_$i.or"
    mutate "$seed_file" "$case_file"

    out=$(timeout "$TIMEOUT" "$ORION" "$case_file" "$WORK/out.ll" "$ROOT/orbs" 2>&1)
    code=$?

    if [ "$code" = "124" ]; then
        hangs=$((hangs + 1)); report HANG "$case_file" "$(basename "$seed_file") -> no answer in ${TIMEOUT}s"
        continue
    fi
    case "$out" in
        *"ACCESS VIOLATION"*|*"Segmentation fault"*)
            crashes=$((crashes + 1)); report CRASH "$case_file" "$(basename "$seed_file")"; continue ;;
        *"list index"*|*"out of range"*|*"division by zero"*)
            # The compiler tripping its OWN runtime guard is an internal error:
            # a malformed program deserves a diagnostic, not a trap. But
            # `ERROR at file:line:col - division by zero` IS the diagnostic -
            # the compiler rejecting a literal `/ 0` in the input. Only the
            # unlocated form is a trap.
            if echo "$out" | grep -qE "ERROR at .+:[0-9]+:[0-9]+"; then
                ok=$((ok + 1))
            else
                internals=$((internals + 1))
                report INTERNAL "$case_file" "$(echo "$out" | grep -m1 -oE '(list index|out of range|division by zero)[^\"]*' | cut -c1-60)"
            fi
            continue ;;
    esac
    if [ "$code" = "0" ]; then
        ok=$((ok + 1)); continue
    fi
    # Rejected: it must say WHERE. `ERROR at <path>:<line>:<col>` is the healthy
    # shape; `at line 0:0` means the node carried no position.
    if echo "$out" | grep -qE "ERROR at .+:[0-9]+:[0-9]+"; then
        ok=$((ok + 1))
    elif echo "$out" | grep -qE "ERROR at line 0:0|ERROR -|ERROR -"; then
        unlocated=$((unlocated + 1)); report UNLOCATED "$case_file" "$(echo "$out" | grep -m1 "ERROR" | cut -c1-70)"
    elif [ -n "$out" ]; then
        ok=$((ok + 1))   # some other loud refusal (missing file, bad args)
    else
        internals=$((internals + 1)); report SILENT "$case_file" "exit $code, no message"
    fi
done

findings=$((hangs + crashes + internals))
echo
echo "  $ok healthy · $hangs hang · $crashes crash · $internals internal · $unlocated unlocated"
if [ "$findings" = "0" ] && [ "$unlocated" = "0" ]; then
    rm -rf "$WORK" "$FIND"
    echo "  fuzz: nothing found"
else
    echo "  inputs kept in dist/.fuzz-findings/"
fi
# Unlocated errors are a quality complaint, not a crash: they do not fail the
# run, they get counted and printed.
exit "$findings"
