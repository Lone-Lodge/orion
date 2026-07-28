#!/usr/bin/env bash
# docs_check.sh — compile every code sample in the Field Guide.
#
# WHY: a documented feature that no longer exists is the same failure as a
# stale seed. It reads fine, nobody runs it, and it is wrong for months.
# tests/test_38_defer.or says it in its own header: `defer` was documented as
# a core feature and had silently stopped parsing, because nothing tested it.
# Prose about a language cannot be trusted unless the compiler has read it.
#
# So every <code data-or> block in docs/ is a WHOLE program, and this compiles
# each one. It also checks that the two translations carry the same set of
# samples: the prose may differ, the code may not, which is the standing risk
# with a second language.
#
#   bash tools/docs_check.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORION="$ROOT/dist/orion.exe"
WORK="$ROOT/dist/.docscheck"
PAGES="index.html sv.html"

[ -x "$ORION" ] || { echo "no dist/orion.exe — bash tools/bootstrap.sh"; exit 1; }
rm -rf "$WORK"; mkdir -p "$WORK"

# Pull the samples out of one page into $2/NN.or, one file per block.
# The guide marks them `<code data-or>`; anything else (shell commands) is
# skipped. Inline <span> markup for comments is stripped, then the four HTML
# entities are turned back into the characters Orion actually uses — `&amp;`
# LAST, or an escaped `&amp;lt;` would decode twice.
extract() {
    local page="$1" dir="$2"
    mkdir -p "$dir"
    # The tags share a line with code — `<code data-or>type Player: ...` — so
    # take the remainder of the opening line and the part before the closing
    # tag, rather than dropping both lines whole.
    awk -v dir="$dir" '
        /<code data-or>/ {
            n++; f = sprintf("%s/%02d.or", dir, n); inblk = 1
            sub(/^.*<code data-or>/, "")
            if (length($0) > 0) print > f
            next
        }
        inblk && /<\/code>/ {
            sub(/<\/code>.*$/, "")
            if (length($0) > 0) print > f
            inblk = 0; next
        }
        inblk { print > f }
    ' "$page"
    for f in "$dir"/*.or; do
        [ -e "$f" ] || continue
        sed -e 's/<span class="c">//g' -e 's/<\/span>//g' \
            -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&quot;/"/g' -e 's/&amp;/\&/g' \
            "$f" > "$f.clean" && mv "$f.clean" "$f"
    done
}

fail=0
count=0

for page in $PAGES; do
    [ -f "$ROOT/docs/$page" ] || { echo "  missing docs/$page"; fail=$((fail + 1)); continue; }
    extract "$ROOT/docs/$page" "$WORK/${page%.html}"
done

# Same samples in every translation, byte for byte.
first=""
for page in $PAGES; do
    dir="$WORK/${page%.html}"
    if [ -z "$first" ]; then first="$dir"; continue; fi
    if diff -r "$first" "$dir" > "$WORK/drift.txt" 2>&1; then
        echo "  samples match across translations"
    else
        echo "  SAMPLES DRIFTED between translations:"
        sed 's/^/    /' "$WORK/drift.txt" | head -20
        fail=$((fail + 1))
    fi
done

# Every sample must compile. The guide promises whole programs, so anything
# that needs a wrapper to build is a sample the reader cannot actually run.
echo
for f in "$WORK/$(echo "$PAGES" | awk '{print $1}' | sed 's/\.html//')"/*.or; do
    [ -e "$f" ] || continue
    count=$((count + 1))
    name="$(basename "$f")"
    if "$ORION" "$f" "$WORK/out.ll" "$ROOT/orbs" > "$WORK/log.txt" 2>&1; then
        printf "  %-8s ok\n" "$name"
    else
        printf "  %-8s FAILED\n" "$name"
        grep -i 'error' "$WORK/log.txt" | sed 's/^/      /' | head -4
        sed 's/^/      | /' "$f" | head -20
        fail=$((fail + 1))
    fi
done

echo
if [ "$fail" = "0" ]; then
    echo "  docs: $count sample(s) compile, translations agree"
    rm -rf "$WORK"
    exit 0
fi
echo "  docs: $fail problem(s) — samples left in $WORK"
exit 1
