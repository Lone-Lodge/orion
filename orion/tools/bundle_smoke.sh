#!/bin/bash
# bundle_smoke — kompilera en SUBSET av bundle för snabb verifikation.
# Tar de första N raderna av bundle. Catches grammar/lowering buggar utan
# att vänta 75 min på full clang.
#
# Använd så här:
#   ./tools/bundle_smoke.sh 1500   # ~3 min, täcker basics
#   ./tools/bundle_smoke.sh 3000   # ~10 min, täcker emit_llvm
#   ./tools/bundle_smoke.sh full   # full bundle, ~75 min

set -e
LINES=${1:-1500}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
# bundle_minified.sh writes here.
BUNDLE=$ROOT/dist/orion_self_bundled_min.or
DEMO=$ROOT/examples/compile_or/test_files/demo.or

if [ ! -f "$BUNDLE" ]; then
    echo "Bundle saknas på $BUNDLE — kör tools/bundle_minified.sh först"
    exit 1
fi

if [ "$LINES" = "full" ]; then
    cp "$BUNDLE" "$DEMO"
    echo "Bundle smoke: full ($(wc -l < $BUNDLE) lines)"
else
    head -n "$LINES" "$BUNDLE" > "$DEMO"
    echo "Bundle smoke: head -n $LINES"
fi

cd "$ROOT/examples/compile_or"
rm -rf target
echo "Compiling..."
START=$(date +%s)
"$ROOT/dist/orbit.exe" run src/main.or main 2>&1 | tee /tmp/bundle_smoke.log | grep -E "ERROR|FAILED|Done"
END=$(date +%s)
echo "Elapsed: $((END-START))s"

if grep -q "ERROR\|FAILED" /tmp/bundle_smoke.log; then
    echo ""
    echo "❌ FAIL — kolla /tmp/bundle_smoke.log för detaljer"
    exit 1
fi
echo "✅ PASS"
