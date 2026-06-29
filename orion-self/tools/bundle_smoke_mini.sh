#!/bin/bash
# bundle_smoke_mini — kompilera bara orion_ir + en mini-driver = fast smoke.
# Detta är ett SUBSET av bundle som täcker alla strukturella mönster
# (data, fn, pub, struct cons, list ops, interp, match) men är ~3% av storleken.
#
# Idé: om denna kompilerar, är vår orion-self compiler korrekt nog för minst
# en orb. Sen kan vi successivt lägga till fler.
#
# Time budget: ~5 min för ren run.

set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEMO="$ROOT/examples/compile_or/test_files/demo.or"

# Build mini-bundle: orion_ir + a driver that exercises it.
cat > "$DEMO" <<'HEADER'
# Mini smoke — exercises a subset of bundle patterns.
HEADER

# Append orion_ir/lib.or content (skip `use` lines since lodge-orion handles those).
grep -vE "^use " "$ROOT/orbs/orion_ir/lib.or" >> "$DEMO"

# Append a driver fn
cat >> "$DEMO" <<'DRIVER'

fn main() -> int:
    # Test struct cons (Inst)
    inst1 = ir_iconst(42)
    inst2 = ir_iadd(0, 1)

    # Test field access + interp
    op_text = inst1.op
    val = inst1.value

    # Test list ops
    fn0 = IRFn{name: "main", return_type: "i64", params: [], instructions: []}
    pushed = ir_fn_push(fn0, inst1)
    n_insts = len(pushed.function.instructions)

    # Test text concat + interp w/ field access (the bug we fixed!)
    msg = "iconst.{inst1.type_text} = {val}"

    # 42 + 0 + 1 - 1 = 42 if everything works
    val + n_insts - 1
DRIVER

LINES=$(wc -l < "$DEMO")
echo "Mini bundle: $LINES lines"

cd "$ROOT/examples/compile_or"
rm -rf target dist
echo "Compiling..."
START=$(date +%s)
timeout 600 E:/lone-lodge/lodge-orion/orion/target/release/orbit.exe run src/main.or main 2>&1 | tee /tmp/mini_smoke.log | grep -E "ERROR|FAILED|Done|orion-self:"
END=$(date +%s)
echo ""
echo "Elapsed: $((END-START))s"

if [ -f "dist/demo.exe" ]; then
    OUT=$(./dist/demo.exe; echo "exit=$?")
    echo "Run result: $OUT"
    if echo "$OUT" | grep -q "exit=42"; then
        echo "✅ PASS"
    else
        echo "❌ FAIL — wrong exit code"
    fi
else
    echo "❌ FAIL — no .exe produced"
fi
