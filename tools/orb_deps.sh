#!/usr/bin/env bash
# orb_deps.sh - which orb uses which, derived by the compiler, not by grep.
#
#   bash tools/orb_deps.sh <entry.or> [<entry.or> ...]
#
# WHY THIS AND NOT grep: `use` lines undercount, because Orion resolves names
# across the whole composition - an orb can be a real dependency without a
# single `use` line naming it. Matching exported names overcounts, because
# `dot`, `add` and `scale` are ordinary words that hit comments and unrelated
# locals. Both failures were measured; neither method can answer the question.
#
# The compiler already knows. `orion <file> refs` prints one line per call site
#
#     REF path:line:col:written-name:resolved-name
#
# and the resolved name is orb-qualified (`iter__sort_generic`), so the edge
# caller-orb -> callee-orb falls straight out. `:lokal` is a local callee and a
# name with no `__` is a runtime builtin; neither is an orb edge.
#
# Reports, per orb: which orbs call into it, and how many call sites. An orb
# nobody calls is listed separately - that is the consumer count ORION.md wants
# to gate on, and it is the only version of it that is true.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORION="${ORION:-$ROOT/dist/orion.exe}"
# ORBS may name several roots, space separated - the compiler searches them in
# order, which is how a project outside orion (veil, a game) reaches both its
# own orbs and the shared ones.
ORBS="${ORBS:-$ROOT/orbs}"
read -r -a ORB_ROOTS <<< "$ORBS"
# The FIRST root owns the "nobody calls this" listing: that is the tree whose
# orbs the question is being asked about.
MAIN_ROOT="${ORB_ROOTS[0]}"

[ $# -ge 1 ] || { echo "usage: orb_deps.sh <entry.or> [<entry.or> ...]"; exit 2; }
[ -x "$ORION" ] || { echo "no $ORION - bash tools/bootstrap.sh"; exit 1; }

EDGES="$(mktemp)"
trap 'rm -f "$EDGES"' EXIT

for entry in "$@"; do
    [ -f "$entry" ] || { echo "skip (no such file): $entry" >&2; continue; }
    # An entry that does not compile has no call graph to report. Say so and
    # keep going - a broken example must not silently shrink the answer.
    if ! "$ORION" "$entry" refs "${ORB_ROOTS[@]}" 2>/dev/null | grep -q '^REF '; then
        echo "skip (no refs; does it compile?): $entry" >&2
        continue
    fi
    # The path is never split on ":" - a Windows path starts "C:/" and would
    # lose its head. The resolved name is what follows the LAST colon, and the
    # calling orb is read straight off the path with a regex.
    "$ORION" "$entry" refs "${ORB_ROOTS[@]}" 2>/dev/null | awk -v entry="$entry" '
        /^REF / {
            resolved = $0
            sub(/.*:/, "", resolved)
            if (resolved == "lokal") next
            if (index(resolved, "__") == 0) next          # runtime builtin
            callee = substr(resolved, 1, index(resolved, "__") - 1)
            if (callee == "prog") next                    # the app is not an orb
            caller = entry
            if (match($0, /orbs\/[^\/]+\/lib\.or/)) {
                caller = substr($0, RSTART + 5, RLENGTH - 5 - 7)
            } else {
                sub(/.*[\/\\]/, "", caller); sub(/\.or$/, "", caller)
            }
            if (caller != callee) print caller, callee
        }' >> "$EDGES"
done

[ -s "$EDGES" ] || { echo "no orb edges found"; exit 1; }

echo "== vem anropar vem =="
sort "$EDGES" | uniq -c | sort -k3,3 -k1,1nr | awk '{printf "  %-22s <- %-22s %s anropsplatser\n", $3, $2, $1}'

echo
echo "== orbar som ingen anropar (i denna komposition) =="
CALLED="$(awk '{print $2}' "$EDGES" | sort -u)"
found=0
for d in "$MAIN_ROOT"/*/; do
    orb="$(basename "$d")"
    printf '%s\n' "$CALLED" | grep -qx "$orb" || { echo "  $orb"; found=1; }
done
[ "$found" -eq 0 ] && echo "  (inga)"
exit 0
