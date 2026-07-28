#!/bin/bash
# Build orion.exe from the committed seed IR (tools/seed/orion.ll) on ANY host.
# The seed .ll is emitted by orion.exe (target-neutral logic); clang links it
# with orion_rt.c into a native binary for THIS host. This is how a fresh clone
# gets a working compiler without a prior binary.
#
# Windows note: the seed already carries the Windows triple the compiler always
# emits, so there it is linked AS IS — retargeting it to ELF (what this script
# used to do on MINGW, since it fell into the catch-all case) produced a broken
# binary. Only Linux/Mac retarget.
set -e
R="$(cd "$(dirname "$0")/.." && pwd)"
LL="$R/tools/seed/orion.ll"
[ -f "$LL" ] || { echo "no seed at tools/seed/orion.ll — emit it on any machine: orion.exe bundle.or tools/seed/orion.ll"; exit 1; }
CLANG="${CLANG:-C:/Program Files/LLVM/bin/clang.exe}"
[ -x "$CLANG" ] || CLANG="$(command -v clang || echo clang)"
mkdir -p "$R/dist"
# Retarget the module header to the host. The seed carries a Windows COFF
# triple (mangling `e-m:w`); ELF (Linux) wants `e-m:e`, Mach-O (Mac) `e-m:o`.
case "$(uname -s 2>/dev/null || echo Linux)" in
    MINGW*|MSYS*|CYGWIN*|Windows*)
        # Native triple already: link it, with the big stack the compiler's
        # recursion needs (Windows reserves stack in the exe at link time).
        "$CLANG" "$LL" "$R/runtime/orion_rt.c" -Os -Xlinker /STACK:67108864 -o "$R/dist/orion.exe"
        echo "built dist/orion.exe for Windows (native triple) — verify: printf 'fn main()->int:\\n 42\\n' > /tmp/t.or && dist/orion.exe /tmp/t.or /tmp/t.ll"
        exit 0 ;;
    Darwin)
        MANGLE="o"
        if [ "$(uname -m)" = "arm64" ]; then TRIPLE="arm64-apple-macosx"; else TRIPLE="x86_64-apple-macosx"; fi ;;
    *)  MANGLE="e"; TRIPLE="x86_64-unknown-linux-gnu" ;;
esac
# Portable across GNU and BSD sed (BSD `sed -i` needs an arg; avoid it).
sed -e "2s#e-m:w#e-m:${MANGLE}#" \
    -e "3s#x86_64-pc-windows-msvc[0-9.]*#${TRIPLE}#" \
    "$LL" > "$R/dist/host.ll"
"$CLANG" "$R/dist/host.ll" "$R/runtime/orion_rt.c" -Os -o "$R/dist/orion.exe"
echo "built dist/orion.exe for $(uname -s) ($TRIPLE) — verify: printf 'fn main()->int:\\n 42\\n' > /tmp/t.or && dist/orion.exe /tmp/t.or /tmp/t.ll"
