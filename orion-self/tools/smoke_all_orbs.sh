#!/bin/bash
# smoke_all_orbs — compile each orb individually as a fast smoke.
# If all 5 pass, we know the language layer + grammar is correct.
# Total time: ~10 min sequential (vs 5h for bundle).
#
# Each orb gets its own driver that exercises core patterns.

set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEMO="$ROOT/examples/compile_or/test_files/demo.or"

ORION_BIN="E:/lone-lodge/lodge-orion/orion/target/release/orbit.exe"

compile_orb() {
    local orb=$1
    local driver=$2
    local label=$3

    cat > "$DEMO" <<HEADER
# Smoke for $label
HEADER
    grep -vE "^use " "$ROOT/orbs/$orb/lib.or" >> "$DEMO"
    echo "" >> "$DEMO"
    echo "$driver" >> "$DEMO"

    local lines=$(wc -l < "$DEMO")
    echo "─── $label ─── ($lines lines)"

    cd "$ROOT/examples/compile_or"
    rm -rf target dist
    local start=$(date +%s)
    "$ORION_BIN" run src/main.or main 2>&1 | grep -E "ERROR|FAILED|Done|orion-self:" | head -3
    local end=$(date +%s)
    echo "  elapsed: $((end - start))s"

    if [ -f "dist/demo.exe" ]; then
        local result=$(./dist/demo.exe; echo "exit=$?")
        echo "  $result"
        if echo "$result" | grep -q "exit=42"; then
            echo "  ✅ PASS"
            return 0
        fi
    fi
    echo "  ❌ FAIL"
    return 1
}

mut_pass=0
mut_fail=0

# ─── orion_ir ───
DRIVER=$(cat <<'EOF'
fn main() -> int:
    inst1 = ir_iconst(42)
    fn0 = IRFn{name: "main", return_type: "i64", params: [], instructions: []}
    pushed = ir_fn_push(fn0, inst1)
    n = len(pushed.function.instructions)
    inst1.value + n - 1
EOF
)
if compile_orb "orion_ir" "$DRIVER" "orion_ir"; then mut_pass=$((mut_pass+1)); else mut_fail=$((mut_fail+1)); fi

# ─── orion_lex ───
DRIVER=$(cat <<'EOF'
fn main() -> int:
    src = "42 + 0"
    toks = self_lex(src)
    len(toks) * 14
EOF
)
if compile_orb "orion_lex" "$DRIVER" "orion_lex"; then mut_pass=$((mut_pass+1)); else mut_fail=$((mut_fail+1)); fi

echo ""
echo "──────────────────────────"
echo "Result: $mut_pass passed, $mut_fail failed"
