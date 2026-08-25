#!/bin/bash
# Bake every Field Guide sample to wasm, so Run works where there is no server.
#
# The playground compiles through `node tools/playground.js`, which shells out
# to the compiler. GitHub Pages has no such thing: the POST landed on a 404
# page and the Run button died on `<html>` is not valid JSON. The samples are
# fixed, so they are compiled here and committed as docs/samples.json; the page
# uses that when the code has not been edited, and asks for the local server
# when it has.
#
# A sample the wasm backend cannot lower is baked as its error, so the page
# still shows the calm "native only" note rather than nothing at all.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ORION="$ROOT/dist/orion.exe"
[ -x "$ORION" ] || { echo "build the compiler first: bash tools/bootstrap.sh"; exit 1; }

OUT="${1:-$ROOT/docs/samples.json}"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Same extraction docs_check.sh does: `<code data-or>` blocks, entities decoded.
awk -v dir="$WORK" '
    /<code data-or>/ {
        n++; f = sprintf("%s/%02d.or", dir, n); inblk = 1
        sub(/^.*<code data-or>/, "")
        if (length($0) > 0) print > f
        next
    }
    inblk && /<\/code>/ { sub(/<\/code>.*$/, ""); if (length($0) > 0) print > f; inblk = 0; next }
    inblk { print > f }
' "$ROOT/docs/index.html"

n=0; ok=0
{
    echo "["
    first=1
    for f in "$WORK"/*.or; do
        [ -e "$f" ] || continue
        n=$((n + 1))
        sed -e 's/<span class="c">//g' -e 's/<\/span>//g' \
            -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&quot;/"/g' -e 's/&amp;/\&/g' \
            "$f" > "$f.clean"
        # The backend has split/sum/len/print as builtins; pulling those orbs in
        # drags byte primitives it cannot lower. The server drops them too.
        sed -e '/^[ \t]*use[ \t]\+\(text\|iter\|bytes\)[ \t]*$/d' "$f.clean" > "$f.or2"
        [ $first -eq 1 ] || echo ","
        first=0
        if log=$("$ORION" "$f.or2" "$f.wasm" "$ROOT/orbs" --quiet 2>&1) \
           && [ -s "$f.wasm" ] && ! printf '%s' "$log" | grep -qE 'ERROR|FAILED|FATAL'; then
            ok=$((ok + 1))
            printf '{"wasm":"%s"}' "$(base64 -w0 < "$f.wasm")"
        else
            printf '{"error":%s}' "$(printf '%s' "$log" | python -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')"
        fi
    done
    echo
    echo "]"
} > "$OUT"

echo "  playground: $ok of $n samples baked to wasm ($(wc -c < "$OUT") bytes)"
