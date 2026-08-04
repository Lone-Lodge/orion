#!/usr/bin/env bash
# build_orbit.sh - build dist/orbit.exe from tools/orbit.or using orion.exe.
#
# orbit is Orion's project tool, self-hosted: orion.exe compiles it to LLVM IR,
# clang links it with the CLI runtime (orion_cli.c: process spawn, fs, exit +
# orion_rt.c: the compiler runtime's file_read/argv/print). No lodge-orion, no
# interpreter - build/run/test all shell out to orion.exe + clang (see
# cli_build / build_native_entry in tools/orbit.or).
#
#   orion.exe  tools/orbit.or -> orbit.ll  ->  clang + orion_cli.c + orion_rt.c
#
# Cross-platform: orion.exe always emits a Windows triple, so off Windows we
# retarget orbit.ll to the host before clang (same as tools/self_bootstrap.sh).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORION="$ROOT/dist/orion.exe"
CLANG="${CLANG:-C:/Program Files/LLVM/bin/clang.exe}"
[ -x "$CLANG" ] || CLANG="$(command -v clang || echo clang)"

# Host detection: target triple + datalayout mangling + link flags (see
# self_bootstrap.sh for the rationale). POSIX retargets the emitted IR;
# Windows links it natively with a /STACK reserve for deep recursion.
case "$(uname -s 2>/dev/null || echo unknown)" in
    Linux)  HOST_TRIPLE="x86_64-unknown-linux-gnu"; MANGLE="e"; RETARGET=1; STACK_LINK="" ;;
    Darwin)
        if [ "$(uname -m)" = "arm64" ]; then HOST_TRIPLE="arm64-apple-macosx"; else HOST_TRIPLE="x86_64-apple-macosx"; fi
        MANGLE="o"; RETARGET=1; STACK_LINK="" ;;
    MINGW*|MSYS*|CYGWIN*|Windows*) RETARGET=0; STACK_LINK="-Xlinker /STACK:67108864" ;;
    *)      HOST_TRIPLE="x86_64-unknown-linux-gnu"; MANGLE="e"; RETARGET=1; STACK_LINK="" ;;
esac

echo "==> compile tools/orbit.or -> orbit.ll"
"$ORION" "$ROOT/tools/orbit.or" "$ROOT/dist/orbit.ll" "$ROOT/orbs"

LINK_LL="$ROOT/dist/orbit.ll"
if [ "$RETARGET" = "1" ]; then
    # Line-targeted (only the two module-header lines) - never touch a triple
    # string that appears as a program constant. Keep the .ll extension.
    sed -e "2s#e-m:w#e-m:${MANGLE}#" \
        -e "3s#x86_64-pc-windows-msvc[0-9.]*#${HOST_TRIPLE}#" \
        "$ROOT/dist/orbit.ll" > "$ROOT/dist/orbit.host.ll"
    LINK_LL="$ROOT/dist/orbit.host.ll"
fi

echo "==> link -> dist/orbit.exe"
# -O2 so orbit itself runs fast (override with OPT=-O0 for a quick dev build).
OPT="${OPT:--O2}"
"$CLANG" $OPT "$LINK_LL" "$ROOT/runtime/orion_cli.c" "$ROOT/runtime/orion_rt.c" \
    $STACK_LINK -o "$ROOT/dist/orbit.exe"
rm -f "$ROOT/dist/orbit.ll" "$ROOT/dist/orbit.host.ll"
echo "==> dist/orbit.exe ready ($(wc -c < "$ROOT/dist/orbit.exe") bytes)"
