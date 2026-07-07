#!/bin/bash
# Build orion.exe on Linux/Mac from the committed seed IR (tools/seed/orion.ll).
# The seed .ll is emitted by orion.exe on any platform (target-neutral logic);
# clang links it with orion_rt.c into a native binary for THIS host. This is
# how a fresh non-Windows clone gets a working compiler without a prior binary.
set -e
R="$(cd "$(dirname "$0")/.." && pwd)"
LL="$R/tools/seed/orion.ll"
[ -f "$LL" ] || { echo "no seed at tools/seed/orion.ll — emit it on any machine: orion.exe bundle.or tools/seed/orion.ll"; exit 1; }
cp "$LL" "$R/dist/host.ll"
# Retarget the module header to the host (seed is emitted with a Windows triple).
sed -i '2s#e-m:w#e-m:e#; 3s#x86_64-pc-windows-msvc[0-9.]*#x86_64-unknown-linux-gnu#' "$R/dist/host.ll" 2>/dev/null || true
clang "$R/dist/host.ll" "$R/runtime/orion_rt.c" -Os -o "$R/dist/orion.exe"
echo "built dist/orion.exe for $(uname -s) — verify: printf 'fn main()->int:\\n 42\\n' > /tmp/t.or && dist/orion.exe /tmp/t.or /tmp/t.ll"
