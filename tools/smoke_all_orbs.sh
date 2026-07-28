#!/bin/bash
# smoke_all_orbs — compile a compiler orb on its own, with a small driver, as a
# fast check that the language layer still swallows it. Two orbs today
# (orion_ir, orion_lex); the header used to claim five.
#
# Each driver must exit 42. Say what you are asserting: the lex driver used to
# encode its expectation as `len(toks) * 14`, which stopped meaning "3 tokens"
# the moment the lexer started emitting newline/eof tokens, and then reported
# exit 70 — indistinguishable at a glance from Orion's runtime trap code.

set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEMO="$ROOT/examples/compile_or/test_files/demo.or"

ORION_BIN="$ROOT/dist/orbit.exe"

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
    first = at(toks, 0)
    # `42` `+` `0` plus the newline/eof the lexer appends. Assert the shape that
    # matters (an int token first, at least the three real ones), not a count.
    ok = if len(toks) >= 3 and get(first, "value") == "42" and get(first, "kind") == "int" then 1 else 0
    ok * 42
EOF
)
if compile_orb "orion_lex" "$DRIVER" "orion_lex"; then mut_pass=$((mut_pass+1)); else mut_fail=$((mut_fail+1)); fi

echo ""
echo "──────────────────────────"
echo "Result: $mut_pass passed, $mut_fail failed"
