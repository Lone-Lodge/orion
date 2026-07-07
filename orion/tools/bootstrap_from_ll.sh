#!/bin/bash
# Build orion.exe on Linux/Mac from the committed seed IR (tools/seed/orion.ll).
# The seed .ll is emitted by orion.exe on any platform (target-neutral logic);
# clang links it with orion_rt.c into a native binary for THIS host. This is
# how a fresh non-Windows clone gets a working compiler without a prior binary.
set -e
R="$(cd "$(dirname "$0")/.." && pwd)"
LL="$R/tools/seed/orion.ll"
[ -f "$LL" ] || { echo "no seed at tools/seed/orion.ll — emit it on any machine: orion.exe bundle.or tools/seed/orion.ll"; exit 1; }
# Retarget the module header to the host. The seed carries a Windows COFF
# triple (mangling `e-m:w`); ELF (Linux) wants `e-m:e`, Mach-O (Mac) `e-m:o`.
case "$(uname -s 2>/dev/null || echo Linux)" in
    Darwin)
        MANGLE="o"
        if [ "$(uname -m)" = "arm64" ]; then TRIPLE="arm64-apple-macosx"; else TRIPLE="x86_64-apple-macosx"; fi ;;
    *)  MANGLE="e"; TRIPLE="x86_64-unknown-linux-gnu" ;;
esac
mkdir -p "$R/dist"
# Portable across GNU and BSD sed (BSD `sed -i` needs an arg; avoid it).
sed -e "2s#e-m:w#e-m:${MANGLE}#" \
    -e "3s#x86_64-pc-windows-msvc[0-9.]*#${TRIPLE}#" \
    "$LL" > "$R/dist/host.ll"
clang "$R/dist/host.ll" "$R/runtime/orion_rt.c" -Os -o "$R/dist/orion.exe"
echo "built dist/orion.exe for $(uname -s) ($TRIPLE) — verify: printf 'fn main()->int:\\n 42\\n' > /tmp/t.or && dist/orion.exe /tmp/t.or /tmp/t.ll"
