#!/usr/bin/env bash
# Every `define test_` in every orb actually runs.
#
#   bash tools/orb_test.sh
#
# `example_check.sh` already runs every `example` line, and that covers the
# one-line claims. It does NOT cover the test functions, and nobody noticed:
# thirty of them sit in eight orbs and not one had ever run in CI. A test that
# is never run is worse than no test, because it reads like a promise.
#
# `orbit test` only runs tests in orbs the PROJECT owns (`[orbs]` with a
# `path:`), not in stdlib orbs it merely uses - so this builds one throwaway
# project per orb that adopts it, which is also what keeps a failure named
# after the orb it came from.
#
# KNOWN_RED is a ratchet, not a mute. A test named there is allowed to fail -
# and is also REQUIRED to fail. The day it starts passing, this gate goes red
# and says to take it off the list. That is the difference between a known bug
# and a bug that quietly came back to life.
set -e
cd "$(dirname "$0")/.."
ORBIT="$PWD/dist/orbit.exe"
[ -x "$ORBIT" ] || ORBIT="$PWD/dist/orbit"

# Tests that cannot pass until a compiler bug is fixed. One per line:
#     <orb>/<test name>
#
# raster/test_sprites_sample_and_respect_depth: a texel read out of
# `Texture.pixels` comes back as the i64 bits read as a double - 111 arrives as
# 5.5e-322 - and no annotation cures it, because the value is already wrong
# before raster can touch it. ISSUES.md F12. The fix is type arguments in the
# compiler, not a patch here.
KNOWN_RED="raster/test_sprites_sample_and_respect_depth"

work="build/__orbtest"
rm -rf "$work"
mkdir -p "$work"

fail=0
total=0
tested=0
revived=""

for lib in orbs/*/lib.or; do
    orb=$(basename "$(dirname "$lib")")
    grep -q "^define test_\|^public define test_" "$lib" || continue
    n=$(grep -c "^define test_\|^public define test_" "$lib")
    total=$((total + n))
    tested=$((tested + 1))

    proj="$work/$orb"
    mkdir -p "$proj/src"
    printf '[package]\nname = "orbtest_%s"\nversion = "0.0.1"\n\n[orbs]\n%s = "path:../../../orbs/%s"\n' "$orb" "$orb" "$orb" > "$proj/Orbit.toml"
    printf 'use %s\n\ndefine main() -> number:\n    0\n' "$orb" > "$proj/src/main.or"

    out=$( (cd "$proj" && "$ORBIT" test) 2>&1 ) || true

    # Which test was running when it stopped. `orbit test` prints the name, the
    # failure on the same line, and then stops - so there is at most one.
    broke=$(printf '%s\n' "$out" | grep -E '\.\.\. .*(require failed|panicked)' | sed 's/[[:space:]]*\.\.\..*//' | head -1)

    if [ -n "$broke" ]; then
        if printf '%s\n' "$KNOWN_RED" | grep -qx "$orb/$broke"; then
            echo "  $orb: $broke red as expected (ISSUES.md F12)"
            # The run stops there, so the tests after it never ran. Say that
            # rather than counting tests that were skipped.
            echo "        the rest of $orb was not reached"
        else
            echo "  $orb: FAIL"
            printf '%s\n' "$out" | grep -E '\.\.\. ' | sed 's/^/    /'
            fail=1
        fi
    else
        echo "  $orb: $n ok"
        for known in $KNOWN_RED; do
            case "$known" in "$orb"/*) revived="$revived $known" ;; esac
        done
    fi
done

rm -rf "$work"
echo

if [ -n "$revived" ]; then
    echo "orb tests: RED -$revived passes now."
    echo "  Good news. Take it out of KNOWN_RED in this file so it stays fixed."
    exit 1
fi
if [ "$fail" != "0" ]; then
    echo "orb tests: RED"
    exit 1
fi
all=$(ls -d orbs/*/ | wc -l | tr -d ' ')
# The second number is the more interesting one, and it is why this line prints
# it: most orbs have no test function at all. They are not untested - every
# `example` line is a claim `example_check.sh` runs - but a test function is
# where the cases an example cannot show go, and 40 orbs have none.
echo "orb tests: $total in $tested orbs ($all exist), 1 known red"
