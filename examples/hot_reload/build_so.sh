#!/usr/bin/env bash
# build_so.sh <src.or> <out.so> — compile one Orion file to a shared library.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ORION="$ROOT/dist/orion.exe"
CLANG="$(command -v clang || echo clang)"
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
case "$(uname -s 2>/dev/null || echo Linux)" in
  Darwin) M="o"; if [ "$(uname -m)" = arm64 ]; then T="arm64-apple-macosx"; else T="x86_64-apple-macosx"; fi ;;
  MINGW*|MSYS*|CYGWIN*|Windows*) M=""; T="" ;;
  *) M="e"; T="x86_64-unknown-linux-gnu" ;;
esac
"$ORION" "$1" _w.ll >/dev/null 2>&1
if [ -n "$M" ]; then sed -e "2s#e-m:w#e-m:${M}#" -e "3s#x86_64-pc-windows-msvc[0-9.]*#${T}#" _w.ll > _w_host.ll; else cp _w.ll _w_host.ll; fi
[ -f _rt.o ] || "$CLANG" -c "$ROOT/runtime/orion_rt.c" -o _rt.o 2>/dev/null
"$CLANG" -shared -fPIC _w_host.ll _rt.o -o "$2" 2>/dev/null
rm -f _w.ll _w_host.ll
