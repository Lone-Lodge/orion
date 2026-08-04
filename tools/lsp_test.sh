#!/usr/bin/env bash
# lsp_test.sh — drive the language server over a pipe and check its answers.
#
# The old extension shipped `lsp-smoke.test.js`, a node test against a binary
# nobody could rebuild. This talks to dist/orion-lsp.exe the way an editor does:
# real Content-Length framing on stdin, responses read back off stdout.
#
#   bash tools/lsp_test.sh
#
# Exit code is the number of failed checks.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LSP="$ROOT/dist/orion-lsp.exe"
# The server SPAWNS the compiler, so the path it gets has to be one a native
# process understands: MSYS's `/c/Users/...` is not.
ORION="$(cygpath -m "$ROOT/dist/orion.exe" 2>/dev/null || echo "$ROOT/dist/orion.exe")"
WORBS="$(cygpath -m "$ROOT/orbs" 2>/dev/null || echo "$ROOT/orbs")"
[ -x "$LSP" ] || { echo "no dist/orion-lsp.exe — bash tools/build_lsp.sh"; exit 1; }

TMP="$ROOT/dist/.lsp-test"
rm -rf "$TMP"; mkdir -p "$TMP"
DOC="$TMP/sample.or"
# A file with ONE deliberate error on line 6: `oops` is not defined.
cat > "$DOC" <<'ORION'
type Point: x: int, y: int

define area(p: Point) -> int:
    p.x * p.y

define broken() -> int:
    oops

define main() -> int:
    area(Point{x: 2, y: 3})
ORION
# The URI must carry the path the OS understands, not the shell's view of it: an
# MSYS `/c/Users/...` means nothing to a native binary. `cygpath -m` gives
# `C:/Users/...`, and the drive colon is then percent-encoded the way a real
# editor sends it — which is exactly the case uri_to_path has to handle.
WDOC="$(cygpath -m "$DOC" 2>/dev/null || echo "$DOC")"
case "$WDOC" in
    ?:/*) URI="file:///$(printf '%s' "$WDOC" | sed 's|^\(.\):|\1%3A|')" ;;
    /*)   URI="file://$WDOC" ;;
    *)    URI="file:///$WDOC" ;;
esac
DOC_TEXT="$(sed 's/\\/\\\\/g; s/"/\\"/g' "$DOC" | awk '{printf "%s\\n", $0}')"

msg() {  # $1 = json body
    printf 'Content-Length: %s\r\n\r\n%s' "${#1}" "$1"
}

REQ_FILE="$TMP/requests"
{
    msg "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"initializationOptions\":{\"compiler\":\"$ORION\",\"orbs\":\"$WORBS\"}}}"
    msg "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"$URI\",\"text\":\"$DOC_TEXT\"}}}"
    msg "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"textDocument/documentSymbol\",\"params\":{\"textDocument\":{\"uri\":\"$URI\"}}}"
    msg "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"textDocument/definition\",\"params\":{\"textDocument\":{\"uri\":\"$URI\"},\"position\":{\"line\":9,\"character\":5}}}"
    msg "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"textDocument/hover\",\"params\":{\"textDocument\":{\"uri\":\"$URI\"},\"position\":{\"line\":9,\"character\":5}}}"
    msg "{\"jsonrpc\":\"2.0\",\"id\":6,\"method\":\"textDocument/completion\",\"params\":{\"textDocument\":{\"uri\":\"$URI\"},\"position\":{\"line\":9,\"character\":4}}}"
    # Line 3 is `    p.x * p.y` — asking right after `p.` must give what belongs
    # to a Point (its fields, and the fns that take one first), not every name.
    msg "{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"textDocument/completion\",\"params\":{\"textDocument\":{\"uri\":\"$URI\"},\"position\":{\"line\":3,\"character\":6}}}"
    msg "{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"shutdown\",\"params\":{}}"
    msg "{\"jsonrpc\":\"2.0\",\"method\":\"exit\",\"params\":{}}"
} > "$REQ_FILE"

OUT="$TMP/out"
timeout 90 "$LSP" < "$REQ_FILE" > "$OUT" 2>"$TMP/err" || true

pass=0; fail=0
check() {  # $1 = label, $2 = pattern
    if grep -qF "$2" "$OUT"; then
        printf "  %-34s ok\n" "$1"; pass=$((pass + 1))
    else
        printf "  %-34s FAILED (no match for: %s)\n" "$1" "$2"; fail=$((fail + 1))
    fi
}

check "initialize -> capabilities"      '"documentSymbolProvider":true'
check "server identifies itself"        '"name":"orion-lsp"'
check "diagnostics published"           '"method":"textDocument/publishDiagnostics"'
check "the real error is reported"      'unknown identifier `oops`'
check "diagnostic is on line 6 (0-based 5)" '"line":5'
check "outline: the type"               '"name":"Point","kind":23'
check "outline: a function"             '"name":"area","kind":12'
check "go-to-definition answers"        '"id":3,"result":{"uri"'
check "hover shows the declaration"     'define area(p: Point) -> int:'
check "shutdown answered"               '"id":5,"result":null'
# Completion is declaration-based: names from this file, from the orbs, and the
# keywords. It does NOT claim to know which would type-check at the cursor.
check "completion: own declaration"     '"label":"area","kind":3,"detail":"this file"'
check "completion: a stdlib orb name"   '"detail":"orb text"'
check "completion: a keyword"           '"label":"loop","kind":14'
# Type-aware: after `p.` where p is a Point, the FIELDS of Point and the
# functions whose first parameter is a Point — `x.f()` is `f(x)`, so both are
# things you can actually write there.
check "after a dot: the type's field"   '"label":"x","kind":5,"detail":"field: int"'
check "after a dot: a fn taking it"     '"label":"area","kind":2,"detail":"Point.area() -> int"'

# A diagnostic must NOT be attributed to the temp file the server compiles, nor
# leak the compiler's own orb paths into the document's diagnostics.
if grep -qF 'orion-lsp-check' "$OUT"; then
    printf "  %-34s FAILED (temp path leaked)\n" "no temp path in output"; fail=$((fail + 1))
else
    printf "  %-34s ok\n" "no temp path in output"; pass=$((pass + 1))
fi

:
echo
if [ "$fail" = "0" ]; then
    echo "  lsp: all $pass checks ok"
else
    echo "  lsp: $fail of $((pass + fail)) FAILED"
fi
exit "$fail"
