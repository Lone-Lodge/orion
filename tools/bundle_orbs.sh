#!/usr/bin/env bash
# Bundle all orion-self orbs + a driver into one self-contained .or file.
# Output: dist/orion_self_bundled.or — compiles standalone via orion-self.
#
# We strip `use X` lines (the bundle is self-contained — no orb resolution
# needed) and concatenate in dependency order: ir → lex → parse →
# ast_to_ir → emit_llvm → driver.
#
# After bundling: `orbit run dist/orion_self_bundled.or main <input>.or`
# compiles a .or file via the bundled pipeline.

set -e

OUT="dist/orion_self_bundled.or"
ROOT="$(dirname "$0")/.."
ORBS="$ROOT/orbs"
DRIVER="$ROOT/tools/orion_driver.or"

mkdir -p "$ROOT/dist"
: > "$OUT"

strip_uses() {
    # Strip `use orion_*` (bundle resolves these internally). Keep
    # `use bytes`/`use io` — lodge-orion will load them from target/.
    grep -v '^use orion_' "$1" || true
}

# Hoist all surviving `use` directives to the top, dedup. lodge-orion is
# picky about `use` placement (must be before fn decls).
hoist_uses() {
    grep '^use ' "$OUT" | sort -u > "$OUT.uses"
    grep -v '^use ' "$OUT" > "$OUT.body"
    cat "$OUT.uses" "$OUT.body" > "$OUT"
    rm "$OUT.uses" "$OUT.body"
}

echo "# Auto-generated bundle of orion-self." >> "$OUT"
echo "# Concatenated: ir → lex → parse → ast_to_ir → emit_llvm → driver" >> "$OUT"
echo "" >> "$OUT"

for orb in orion_ir orion_lex orion_parse orion_ast_to_ir orion_emit_llvm orion_emit_wasm orion_ast_to_wasm orion_driver; do
    echo "# ===== $orb =====" >> "$OUT"
    strip_uses "$ORBS/$orb/lib.or" >> "$OUT"
    echo "" >> "$OUT"
done

echo "# ===== driver =====" >> "$OUT"
cat "$DRIVER" >> "$OUT"

hoist_uses
wc -l "$OUT"
