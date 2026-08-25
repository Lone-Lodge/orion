#!/usr/bin/env bash
# value_check.sh - do valid programs still compute the RIGHT ANSWER?
#
# WHY: look at what the other gates actually measure. fuzz.sh checks how the
# compiler REACTS to damaged source (hang, crash, unlocated error). The negative
# suite checks that bad programs are refused. combo_test checks that 66 feature
# pairs COMPILE. The benches measure speed. test.sh runs 151 programs once each.
#
# Nothing asks whether a valid program that compiles gives the right answer
# under a change that must not affect it. Every wrong-answer bug found so far
# lived in exactly that gap: a loop over a map counted double, `defer` before a
# tail `match` ate the value, `defer` of an assignment did nothing at all. Each
# one compiled clean and answered wrong.
#
# The oracle is free: the suite encodes each program's expected exit code in its
# filename (test_42_foo.or must exit 42). So take those 151 programs and apply
# transformations that CANNOT legitimately change the answer. If the answer
# changes, something is wrong, and it does not matter which side.
#
#   defer   inserting a `defer` at the top of main must not change its value.
#           This is the invariant that broke: the value-preserving rewrite only
#           recognised one statement kind, so a defer above a tail `match`
#           silently became the block's value.
#   -O0     the answer must not depend on the optimiser. A disagreement between
#           -O0 and -O2 means the emitted IR relies on something undefined.
#   rerun   the same binary run twice must agree. Catches a read of memory that
#           was never written.
#
#   bash tools/value_check.sh            # every test
#   bash tools/value_check.sh interp     # only matching names
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# The compiler recurses deep; Windows reserves stack in the exe (/STACK),
# POSIX raises it here - without this, arm64 macOS segfaulted SILENTLY on
# the deepest compiles (closure combos) while linux squeaked by on 8 MB.
case "$(uname -s 2>/dev/null || echo Windows)" in
    MINGW*|MSYS*|CYGWIN*|Windows*) : ;;
    *) ulimit -s unlimited 2>/dev/null || ulimit -s 65500 2>/dev/null || true ;;
esac
ORION="$ROOT/dist/orion.exe"
TESTS="$ROOT/tests/suite/tests"
WORK="$ROOT/dist/.valuecheck"
FILTER="${1:-}"
CLANG="${CLANG:-C:/Program Files/LLVM/bin/clang.exe}"
[ -x "$CLANG" ] || CLANG="$(command -v clang || echo clang)"
[ -x "$ORION" ] || { echo "no dist/orion.exe - bash tools/bootstrap.sh"; exit 1; }

rm -rf "$WORK"; mkdir -p "$WORK"

# Same host handling as every other script here: the compiler always emits a
# Windows triple, so POSIX hosts rewrite the two header lines before clang.
case "$(uname -s 2>/dev/null || echo Linux)" in
    MINGW*|MSYS*|CYGWIN*|Windows*) MANGLE=""; TRIPLE=""; STACK="-Xlinker /STACK:67108864" ;;
    Darwin) MANGLE="o"; STACK=""
            if [ "$(uname -m)" = "arm64" ]; then TRIPLE="arm64-apple-macosx"; else TRIPLE="x86_64-apple-macosx"; fi ;;
    *)      MANGLE="e"; TRIPLE="x86_64-unknown-linux-gnu"; STACK="" ;;
esac

echo "==> pre-building the runtime once"
"$CLANG" -c -Os "$ROOT/runtime/orion_rt.c" -o "$WORK/rt.o" 2>/dev/null \
    || { echo "  runtime failed to compile"; exit 1; }

# build SRC OPT EXE -> 0 on success. Compile with orion, retarget off Windows,
# link against the prebuilt runtime.
build() {
    local src="$1" opt="$2" exe="$3" ll="$WORK/out.ll"
    "$ORION" "$src" "$ll" "$ROOT/orbs" --quiet >"$WORK/c.log" 2>&1 || return 1
    if [ -n "$MANGLE" ]; then
        sed -e "2s#e-m:w#e-m:${MANGLE}#" -e "3s#x86_64-pc-windows-msvc[0-9.]*#${TRIPLE}#" \
            "$ll" > "$ll.host.ll"
        ll="$ll.host.ll"
    fi
    "$CLANG" "$opt" "$ll" "$WORK/rt.o" $STACK -Wno-override-module -o "$exe" >"$WORK/l.log" 2>&1
}

# The expected exit code is the number after `test_` in the filename, taken
# as the OS reports it: an exit code is a byte, so test_1713 exits 177.
expected_of() {
    n=$(printf '%s' "$1" | sed -E 's/^test_([0-9]+).*/\1/')
    case "$n" in '' | *[!0-9]*) printf '%s' "$n" ;; *) printf '%s' "$((n % 256))" ;; esac
}

# Insert `defer print_line("")` as the first statement of main. A defer must
# never change the value of the block it sits in -- that is the whole contract.
# Only the multi-line form is rewritten; a single-line main is reported as
# skipped rather than quietly passed.
# The indentation has to be COPIED from the file, not assumed. Injecting four
# spaces into a body indented with two makes a deeper block, and the harness
# then reports its own malformed program as a language bug -- which it did,
# once, on test_42_loop_mut_hoist.
inject_defer() {
    awk '
        seen && !done && /^[ \t]*[^ \t]/ {
            match($0, /^[ \t]*/)
            indent = substr($0, 1, RLENGTH)
            print indent "defer print_line(\"__deferred__\")"
            done = 1
        }
        /^define main\(\) *-> *number: *$/ { seen = 1 }
        { print }
        END { exit(done ? 0 : 1) }
    ' "$1" > "$2"
}

pass=0; fail=0; skip=0; nobuild=0; checks=0; trapped=0
FAILED=""

for src in "$TESTS"/*.or; do
    name="$(basename "$src")"
    case "$name" in *.or) ;; *) continue ;; esac
    [ -n "$FILTER" ] && case "$name" in *"$FILTER"*) ;; *) continue ;; esac
    want="$(expected_of "$name")"
    case "$want" in ''|*[!0-9]*) continue ;; esac

    # The untouched program first. Some tests need the full runtime (file_mtime,
    # file_size) and cannot link against orion_rt.c alone; those are not this
    # gate's business, and blaming the defer transformation for them read as a
    # defer bug that was not there.
    if ! build "$src" "-O0" "$WORK/t2.exe"; then
        nobuild=$((nobuild + 1))
        continue
    fi

    # ---- transformation 1: a defer that must not change the answer ----
    if inject_defer "$src" "$WORK/deferred.or"; then
        if build "$WORK/deferred.or" "-O2" "$WORK/t1.exe"; then
            "$WORK/t1.exe" >"$WORK/t1.out" 2>&1; got=$?
            checks=$((checks + 1))
            if [ "$got" != "$want" ]; then
                printf "  %-38s defer   want=%s got=%s\n" "$name" "$want" "$got"
                FAILED="$FAILED $name(defer)"; fail=$((fail + 1))
            else
                pass=$((pass + 1))
            fi
            # The value surviving is only half the contract: the deferred
            # statement also has to RUN. Checking the exit code alone cannot
            # tell a working defer from one that was silently dropped, and
            # silently dropped is a real failure mode here -- `defer n += 1`
            # parses, is accepted, and does nothing.
            #
            # Unless the program TRAPPED. A failed require, a divide by zero or
            # an out-of-range index prints `orion: ...` and leaves through
            # exit(), which is an abort, and an abort is entitled to skip
            # deferred work. Counted as untested rather than passed.
            if grep -q '^orion: ' "$WORK/t1.out"; then
                trapped=$((trapped + 1))
            else
                checks=$((checks + 1))
                if grep -q '__deferred__' "$WORK/t1.out"; then
                    pass=$((pass + 1))
                else
                    printf "  %-38s defer   never ran\n" "$name"
                    FAILED="$FAILED $name(defer-dropped)"; fail=$((fail + 1))
                fi
            fi
        else
            printf "  %-38s defer   did not build\n" "$name"
            FAILED="$FAILED $name(defer-build)"; fail=$((fail + 1))
        fi
    else
        skip=$((skip + 1))
    fi

    # ---- transformation 2: the optimiser must not change the answer ----
    # ---- transformation 3: nor must running it a second time ----
    "$WORK/t2.exe" >/dev/null 2>&1; got=$?
    checks=$((checks + 1))
    if [ "$got" != "$want" ]; then
        printf "  %-38s -O0     want=%s got=%s\n" "$name" "$want" "$got"
        FAILED="$FAILED $name(O0)"; fail=$((fail + 1))
    else
        pass=$((pass + 1))
        "$WORK/t2.exe" >/dev/null 2>&1; again=$?
        checks=$((checks + 1))
        if [ "$again" != "$got" ]; then
            printf "  %-38s rerun   first=%s second=%s\n" "$name" "$got" "$again"
            FAILED="$FAILED $name(rerun)"; fail=$((fail + 1))
        else
            pass=$((pass + 1))
        fi
    fi
done

echo
# Say what was not covered. A harness that hides its own gaps reads as
# "everything passed" when it means "everything I looked at passed".
[ "$skip" -gt 0 ] && echo "  $skip file(s) have no multi-line \`define main() -> number:\` - not defer-checked"
[ "$nobuild" -gt 0 ] && echo "  $nobuild file(s) did not build at -O0 - not value-checked"
[ "$trapped" -gt 0 ] && echo "  $trapped program(s) trap at run time - an abort may skip its defers, not checked"
if [ "$fail" = "0" ]; then
    echo "  values: $checks assertion(s) hold across $((pass)) run(s)"
    rm -rf "$WORK"
    exit 0
fi
echo "  values: $fail of $checks assertion(s) FAILED -$FAILED"
echo "  artifacts left in $WORK"
exit 1
