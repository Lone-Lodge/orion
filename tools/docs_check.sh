#!/usr/bin/env bash
# docs_check.sh - compile every code sample in the Field Guide.
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
# The compiler recurses deep; Windows reserves stack in the exe (/STACK),
# POSIX raises it here - without this, arm64 macOS segfaulted SILENTLY on
# the deepest compiles (closure combos) while linux squeaked by on 8 MB.
case "$(uname -s 2>/dev/null || echo Windows)" in
    MINGW*|MSYS*|CYGWIN*|Windows*) : ;;
    *) ulimit -s unlimited 2>/dev/null || ulimit -s 65500 2>/dev/null || true ;;
esac
ORION="$ROOT/dist/orion.exe"
WORK="$ROOT/dist/.docscheck"
# One guide, one language for it. sv.html is archived; a second translation of
# the same samples drifts by construction.
PAGES="index.html"

[ -x "$ORION" ] || { echo "no dist/orion.exe - bash tools/bootstrap.sh"; exit 1; }
rm -rf "$WORK"; mkdir -p "$WORK"

# Pull the samples out of one page into $2/NN.or, one file per block.
# The guide marks them `<code data-or>`; anything else (shell commands) is
# skipped. Inline <span> markup for comments is stripped, then the four HTML
# entities are turned back into the characters Orion actually uses - `&amp;`
# LAST, or an escaped `&amp;lt;` would decode twice.
extract() {
    local page="$1" dir="$2"
    mkdir -p "$dir"
    # The tags share a line with code - `<code data-or>type Player: ...` - so
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

# --- the baked playground ---------------------------------------------------
# docs/samples.json is what makes Run work on a static host. It is generated
# from the very samples above, so it goes stale the moment one of them changes.
# Same promise the reference page gets: regenerate and compare.
echo
BAKE_TMP=$(mktemp)
if bash "$ROOT/tools/playground_bake.sh" "$BAKE_TMP" > /dev/null 2>&1; then
    if cmp -s "$BAKE_TMP" "$ROOT/docs/samples.json"; then
        echo "  playground: baked samples up to date with the guide"
    else
        echo "  playground: FAIL - docs/samples.json is stale, run tools/playground_bake.sh"
        fail=$((fail + 1))
    fi
else
    echo "  playground: FAIL - could not bake the samples"
    fail=$((fail + 1))
fi
rm -f "$BAKE_TMP"

# --- contrast -------------------------------------------------------------
# The guide claims WCAG AA, and a claim nobody measures is decoration. Read
# the palette straight out of style.css and check every pair that carries
# meaning: 4.5:1 for text, 3:1 for the accent, which is a link and a keyword
# both. dots' hairline is 1.2:1 and is not checked - it is decoration, and the
# code card is told apart by its tone and its radius, the way dots does it.
# The first value of each variable is the light theme, the second the dark one,
# which is how the file is laid out.
#
# Done in awk on purpose. This repo builds with clang and nothing else, and a
# contrast check is not worth a second language runtime.
echo
awk '
    function hexv(s,   i, c, n, d) {
        n = 0
        for (i = 1; i <= length(s); i++) {
            c = tolower(substr(s, i, 1))
            d = index("0123456789abcdef", c) - 1
            n = n * 16 + d
        }
        return n
    }
    function lin(c) { c = c / 255; return (c <= 0.03928) ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4 }
    function lum(h) { return 0.2126 * lin(hexv(substr(h, 2, 2))) \
                          + 0.7152 * lin(hexv(substr(h, 4, 2))) \
                          + 0.0722 * lin(hexv(substr(h, 6, 2))) }
    function ratio(a, b,   x, y, hi, lo) {
        x = lum(a); y = lum(b)
        hi = (x > y) ? x : y; lo = (x > y) ? y : x
        return (hi + 0.05) / (lo + 0.05)
    }
    function check(label, fg, bg, need,   r) {
        if (fg == "" || bg == "") { printf "  MISSING  %s\n", label; bad++; return }
        r = ratio(fg, bg)
        printf "  %-7s %-16s %5.2f:1  (needs %d)\n", (r >= need ? "ok" : "FAIL"), label, r, need
        if (r < need) bad++
    }
    /--[a-z-]+: *#[0-9a-fA-F]{6}/ {
        name = $0; sub(/^[^-]*--/, "", name); sub(/:.*$/, "", name)
        val = $0; sub(/^[^#]*#/, "#", val); sub(/[^0-9a-fA-F#].*$/, "", val)
        if (!(name in light)) light[name] = val; else if (!(name in dark)) dark[name] = val
    }
    END {
        check("light body",      light["fg"],   light["bg"],      4.5)
        check("light code",      light["fg"],   light["code-bg"], 4.5)
        check("light comment",   light["dim"],  light["code-bg"], 4.5)
        check("light accent",    light["link"], light["bg"],      3)
        check("dark body",       dark["fg"],    dark["bg"],       4.5)
        check("dark code",       dark["fg"],    dark["code-bg"],  4.5)
        check("dark comment",    dark["dim"],   dark["code-bg"],  4.5)
        check("dark accent",     dark["link"],  dark["bg"],       3)
        # Syntax highlighting: a token hue paints words that are already
        # readable as shapes, so it is held to 3:1 - the accent itself is
        # 4.3:1 on the card and dots ships exactly that.
        split("tok-k tok-t tok-s tok-n tok-f tok-x", toks, " ")
        for (t in toks) {
            check("light " toks[t], light[toks[t]], light["code-bg"], 3)
            check("dark "  toks[t], dark[toks[t]],  dark["code-bg"],  3)
        }
        exit (bad > 0)
    }
' "$ROOT/docs/style.css" || fail=$((fail + 1))

# --- library reference ----------------------------------------------------
# docs/reference.html is generated from the orbs. A generated file that is
# committed by hand goes stale the moment someone adds a `pub fn` and forgets
# to regenerate - the same failure the samples above guard against. So build
# it fresh and compare: if it differs, the committed page is out of date.
echo
if bash "$ROOT/tools/orb_reference.sh" --stdout > "$WORK/reference.html" 2> "$WORK/reflog.txt"; then
    # Compare with line endings normalized: a CI checkout with autocrlf=true
    # hands us a CRLF copy of the committed page and the freshly generated
    # one is LF - same content, and that must not read as "stale".
    tr -d '\r' < "$ROOT/docs/reference.html" > "$WORK/ref_committed.norm"
    tr -d '\r' < "$WORK/reference.html" > "$WORK/ref_fresh.norm"
    if diff -q "$WORK/ref_committed.norm" "$WORK/ref_fresh.norm" > /dev/null 2>&1; then
        echo "  reference: up to date with orbs/"
    else
        echo "  reference: STALE - run bash tools/orb_reference.sh"
        fail=$((fail + 1))
    fi
else
    echo "  reference: generator failed"
    sed 's/^/    /' "$WORK/reflog.txt" | head -10
    fail=$((fail + 1))
fi

echo
if [ "$fail" = "0" ]; then
    echo "  docs: $count sample(s) compile, contrast is AA, reference up to date"
    rm -rf "$WORK"
    exit 0
fi
echo "  docs: $fail problem(s) - samples left in $WORK"
exit 1
