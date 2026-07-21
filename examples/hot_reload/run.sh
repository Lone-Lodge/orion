#!/usr/bin/env bash
# Demonstrate Orion-native hot reload: compile two versions of gameplay code to
# shared libraries, then run an Orion host that loads v1, accumulates state,
# and hot-swaps v2 in mid-run — state survives, behavior changes, no restart.
#
#   bash examples/hot_reload/run.sh
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ORION="$ROOT/dist/orion.exe"
[ -x "$ORION" ] || { echo "build the compiler first: bash tools/bootstrap_from_ll.sh"; exit 1; }
CLANG="$(command -v clang || echo clang)"
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

# Host detection (the compiler always emits a Windows triple; retarget on POSIX).
case "$(uname -s 2>/dev/null || echo Linux)" in
    Darwin) MANGLE="o"; if [ "$(uname -m)" = arm64 ]; then TRIPLE="arm64-apple-macosx"; else TRIPLE="x86_64-apple-macosx"; fi ;;
    MINGW*|MSYS*|CYGWIN*|Windows*) MANGLE=""; TRIPLE="" ;;
    *) MANGLE="e"; TRIPLE="x86_64-unknown-linux-gnu" ;;
esac
retarget() { # in.ll out.ll
    if [ -n "$MANGLE" ]; then
        sed -e "2s#e-m:w#e-m:${MANGLE}#" -e "3s#x86_64-pc-windows-msvc[0-9.]*#${TRIPLE}#" "$1" > "$2"
    else cp "$1" "$2"; fi
}

# Build the runtime object once (defines orion_list_*, text, etc.).
$CLANG -c "$ROOT/runtime/orion_rt.c" -o orion_rt.o 2>/dev/null

build_so() { # src.or  out.so
    "$ORION" "$1" _p.ll >/dev/null 2>&1
    retarget _p.ll _p_host.ll
    $CLANG -shared -fPIC _p_host.ll orion_rt.o -o "$2" 2>/dev/null
}
build_bin() { # src.or  out
    "$ORION" "$1" _h.ll "$ROOT/orbs" >/dev/null 2>&1
    retarget _h.ll _h_host.ll
    $CLANG _h_host.ll orion_rt.o -ldl -o "$2" 2>/dev/null
}

echo "==> compiling gameplay v1 and v2 to shared libraries"
build_so plugin_v1.or plugin_v1.so
build_so plugin_v2.or plugin_v2.so
echo "==> compiling the Orion host"
build_bin reload.or reload
echo "==> running (watch state survive the swap):"
rc=0
./reload || rc=$?
rm -f _p.ll _p_host.ll _h.ll _h_host.ll orion_rt.o plugin_v1.so plugin_v2.so reload
echo "==> done — final state $rc (1,2,3 then a hot swap to 13,23,33)"
