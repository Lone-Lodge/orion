#!/usr/bin/env bash
# build_orbit.sh — build dist/orbit.exe from tools/orbit.or using orion.exe.
#
# orbit is Orion's project tool, self-hosted: orion.exe compiles it to LLVM IR,
# clang links it with the CLI runtime (orion_cli.c: process spawn, fs, exit +
# orion_rt.c: the compiler runtime's file_read/argv/print). No lodge-orion, no
# interpreter — build/run/test all shell out to orion.exe + clang (see
# cli_build / build_native_entry in tools/orbit.or).
#
#   orion.exe  tools/orbit.or -> orbit.ll  ->  clang + orion_cli.c + orion_rt.c
#
# 64MB stack: `orbit run` on the compiler bundle recurses deep.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORION="$ROOT/dist/orion.exe"
CLANG="${CLANG:-C:/Program Files/LLVM/bin/clang.exe}"
[ -x "$CLANG" ] || CLANG="$(command -v clang || echo clang)"

echo "==> compile tools/orbit.or -> orbit.ll"
"$ORION" "$ROOT/tools/orbit.or" "$ROOT/dist/orbit.ll" "$ROOT/orbs"

echo "==> link -> dist/orbit.exe"
"$CLANG" "$ROOT/dist/orbit.ll" "$ROOT/runtime/orion_cli.c" "$ROOT/runtime/orion_rt.c" \
    -Xlinker /STACK:67108864 -o "$ROOT/dist/orbit.exe"
rm -f "$ROOT/dist/orbit.ll"
echo "==> dist/orbit.exe ready ($(wc -c < "$ROOT/dist/orbit.exe") bytes)"
