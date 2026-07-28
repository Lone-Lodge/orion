#!/usr/bin/env bash
# build_lsp.sh — build dist/orion-lsp.exe from tools/orion_lsp.or.
#
# Same recipe as build_orbit.sh: orion.exe compiles the entry point, clang links
# it with the CLI runtime (orion_cli.c gives the server `capture_stdout`, which
# is how it runs the compiler for diagnostics) plus orion_rt.c.
#
# The old orion-lsp was a Rust binary from the deleted crate. This one is Orion
# source in the tree, so it can never again be a build nobody can reproduce.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORION="$ROOT/dist/orion.exe"
CLANG="${CLANG:-C:/Program Files/LLVM/bin/clang.exe}"
[ -x "$CLANG" ] || CLANG="$(command -v clang || echo clang)"
[ -x "$ORION" ] || { echo "no dist/orion.exe — bash tools/bootstrap.sh"; exit 1; }

case "$(uname -s 2>/dev/null || echo unknown)" in
    Linux)  HOST_TRIPLE="x86_64-unknown-linux-gnu"; MANGLE="e"; RETARGET=1; STACK_LINK="" ;;
    Darwin)
        if [ "$(uname -m)" = "arm64" ]; then HOST_TRIPLE="arm64-apple-macosx"; else HOST_TRIPLE="x86_64-apple-macosx"; fi
        MANGLE="o"; RETARGET=1; STACK_LINK="" ;;
    MINGW*|MSYS*|CYGWIN*|Windows*) RETARGET=0; STACK_LINK="-Xlinker /STACK:67108864" ;;
    *)      HOST_TRIPLE="x86_64-unknown-linux-gnu"; MANGLE="e"; RETARGET=1; STACK_LINK="" ;;
esac

echo "==> compile tools/orion_lsp.or -> orion-lsp.ll"
"$ORION" "$ROOT/tools/orion_lsp.or" "$ROOT/dist/orion-lsp.ll" "$ROOT/orbs"

LINK_LL="$ROOT/dist/orion-lsp.ll"
if [ "$RETARGET" = "1" ]; then
    sed -e "2s#e-m:w#e-m:${MANGLE}#" \
        -e "3s#x86_64-pc-windows-msvc[0-9.]*#${HOST_TRIPLE}#" \
        "$ROOT/dist/orion-lsp.ll" > "$ROOT/dist/orion-lsp.host.ll"
    LINK_LL="$ROOT/dist/orion-lsp.host.ll"
fi

echo "==> link -> dist/orion-lsp.exe"
"$CLANG" "$LINK_LL" "$ROOT/runtime/orion_cli.c" "$ROOT/runtime/orion_rt.c" \
    $STACK_LINK -o "$ROOT/dist/orion-lsp.exe"
rm -f "$ROOT/dist/orion-lsp.ll" "$ROOT/dist/orion-lsp.host.ll"
echo "==> dist/orion-lsp.exe ready ($(wc -c < "$ROOT/dist/orion-lsp.exe") bytes)"
