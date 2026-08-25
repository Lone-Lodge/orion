#!/bin/bash
# Every gate under tests/ that needs a project of its own.
#
# The smoke suite is 228 single files a runner feeds to the compiler. These
# are not: each proves something about how a PROJECT is built - a keyword the
# compiler has to certify across a whole call graph, an orb boundary that only
# exists when two orbs are compiled together. They were written, they passed,
# and then nothing ran them again for a month. This script is why that stops.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ORBIT="$ROOT/dist/orbit.exe"
[ -x "$ORBIT" ] || { echo "build orbit first: bash tools/build_orbit.sh"; exit 1; }

fail=0
for dir in "$ROOT"/tests/*/; do
    [ -f "$dir/Orbit.toml" ] || continue
    name=$(basename "$dir")
    # suite is the smoke runner; tools/test.sh drives that one.
    [ "$name" = "suite" ] && continue
    if ( cd "$dir" && "$ORBIT" run src/main.or main ); then
        :
    else
        echo "  FAIL  $name"
        fail=$((fail + 1))
    fi
done

echo
if [ "$fail" -gt 0 ]; then
    echo "  $fail project gate(s) FAILED"
    exit 1
fi
echo "  project gates: green"
