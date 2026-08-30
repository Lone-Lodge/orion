#!/usr/bin/env bash
# orb_shapes.sh - every exported type and the fields it holds, written down.
#
#   bash tools/orb_shapes.sh            # rewrite tools/shapes.txt
#   bash tools/orb_shapes.sh --check    # fail if the committed file is stale
#
# WHY WRITE IT DOWN. The compiler already knows: `orion <file> symbols` prints
# `TYPE Name|field:type,...|orb` straight off the AST, before lowering renames
# anything. Knowing is not the same as noticing. A field that changes type, a
# field that moves, a field that quietly disappears - all of it is invisible in
# a review today, and a world snapshot is bytes on disk: a fact whose shape
# drifted is a save file that no longer loads.
#
# So the shape of every type becomes a committed file, and a change to one is a
# line in a diff someone has to look at. That is the rule the README already
# states - derive it, write it down, let the change show - applied to the thing
# a serialized world is most fragile about.
#
# It does NOT judge. A shape that changed on purpose is rewritten with the
# no-argument form and committed alongside the change that caused it.
#
# One parse per orb, no lowering: `symbols` answers before type checking, so an
# orb needs neither a main nor a green build to be listed.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORION="${ORION:-$ROOT/dist/orion.exe}"
ORBS="${ORBS:-$ROOT/orbs}"
OUT="$ROOT/tools/shapes.txt"

[ -x "$ORION" ] || { echo "no $ORION - bash tools/bootstrap.sh"; exit 1; }

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

collect() {
    echo "# Every exported type and the fields it holds, derived by the compiler."
    echo "# Regenerate with: bash tools/orb_shapes.sh"
    echo "# A diff here is a change to a shape something may already have on disk."
    for dir in "$ORBS"/*/; do
        orb="$(basename "$dir")"
        [ -f "$dir/lib.or" ] || continue
        # An orb compiled as the entry carries no OrbMark, so its OWN types come
        # back with an empty orb field - which is exactly how they are told apart
        # from the types of the orbs it uses.
        "$ORION" "$dir/lib.or" symbols "$ORBS" 2>/dev/null \
            | awk -v orb="$orb" -F'|' '
                # TYPE is a record, SUM is a sum type. CONST is a value and not
                # a shape, so it is not one of these.
                /^TYPE |^SUM / && $NF == "" {
                    split($1, head, " ")
                    printf "%s %s.%s %s\n", head[1], orb, head[2], $2
                }' \
            | LC_ALL=C sort
    done
}

if [ "$CHECK" -eq 1 ]; then
    [ -f "$OUT" ] || { echo "  shapes: MISSING - run bash tools/orb_shapes.sh"; exit 1; }
    if collect | diff -q - "$OUT" >/dev/null 2>&1; then
        echo "  shapes: up to date ($(grep -cE '^(TYPE|SUM) ' "$OUT") types)"
        exit 0
    fi
    echo "  shapes: STALE - a type's shape changed. The diff:"
    collect | diff "$OUT" - | head -40
    echo "  (intended? run: bash tools/orb_shapes.sh, and commit it with the change)"
    exit 1
fi

collect > "$OUT"
echo "wrote tools/shapes.txt ($(grep -cE '^(TYPE|SUM) ' "$OUT") types)"
