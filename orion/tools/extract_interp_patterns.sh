#!/bin/bash
# Extract every unique `{...}` pattern used in orbs/ string interpolations.
# Categorize them and report what test coverage is missing.
#
# Use to find blind spots BEFORE running 75-min bundle compile.

set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)

echo "=== Interpolation patterns in orbs/ ==="
echo ""

# Find every {pattern} occurrence inside string literals, extract just the {...}
grep -rohE '\{[^}]+\}' "$ROOT/orbs/" --include="*.or" \
    | grep -vE '^\{$|^\{\s*$' \
    | sort -u > /tmp/all_patterns.txt

TOTAL=$(wc -l < /tmp/all_patterns.txt)
echo "Total unique patterns: $TOTAL"

echo ""
echo "=== Categories ==="

# Simple ident: {name}
SIMPLE=$(grep -E '^\{[a-z_][a-z_0-9]*\}$' /tmp/all_patterns.txt | wc -l)
echo "Simple ident {name}:          $SIMPLE"

# Field access: {obj.field}
FIELD=$(grep -E '^\{[a-z_][a-z_0-9]*\.[a-z_][a-z_0-9]*\}$' /tmp/all_patterns.txt | wc -l)
echo "Field access {obj.field}:     $FIELD"

# Fn call with simple arg: {fn(x)}
CALL_SIMPLE=$(grep -E '^\{[a-z_]+\([a-z_0-9, ]+\)\}$' /tmp/all_patterns.txt | wc -l)
echo "Fn call simple {fn(arg)}:     $CALL_SIMPLE"

# Fn call with field arg: {fn(obj.field)}
CALL_FIELD=$(grep -E '^\{[a-z_]+\([a-z_]+\.[a-z_]+\)\}$' /tmp/all_patterns.txt | wc -l)
echo "Fn call w/ field {fn(o.f)}:   $CALL_FIELD"

# Nested call: {f(g(x))}
NESTED=$(grep -E '^\{[a-z_]+\([a-z_]+\([^)]*\)\)' /tmp/all_patterns.txt | wc -l)
echo "Nested call {f(g(x))}:        $NESTED"

# Arithmetic in interp
ARITH=$(grep -E '\{[^}]*[\+\-\*/][^}]*\}' /tmp/all_patterns.txt \
    | grep -vE '^\{[a-z_]+\([^)]+\)\}$' \
    | grep -vE '^\{0 - [a-z]+\}$' \
    | wc -l)
echo "Arithmetic in interp:         $ARITH"

echo ""
echo "=== Patterns we DO NOT have smoke tests for ==="
echo ""
echo "Examples of nested calls:"
grep -E '^\{[a-z_]+\([a-z_]+\([^)]*\)\)' /tmp/all_patterns.txt | head -5
echo ""
echo "Examples of arithmetic:"
grep -E '\{[^}]*[\+\-\*/][^}]*\}' /tmp/all_patterns.txt \
    | grep -vE '^\{[a-z_]+\([^)]+\)\}$' \
    | grep -vE '^\{0 - [a-z]+\}$' \
    | head -5

echo ""
echo "Full pattern list: /tmp/all_patterns.txt"
