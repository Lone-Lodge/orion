#!/usr/bin/env bash
# Auto watch-and-reload: run the Orion watcher, then EDIT the gameplay source
# while it runs. The watcher detects the change, invokes the compiler, and
# hot-swaps the new code into itself - state preserved, no restart.
#
#   bash examples/hot_reload/run_watch.sh
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ORION="$ROOT/dist/orion.exe"
[ -x "$ORION" ] || { echo "build the compiler first: bash tools/bootstrap_from_ll.sh"; exit 1; }
CLANG="$(command -v clang || echo clang)"
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
case "$(uname -s 2>/dev/null || echo Linux)" in
  Darwin) M="o"; if [ "$(uname -m)" = arm64 ]; then T="arm64-apple-macosx"; else T="x86_64-apple-macosx"; fi ;;
  MINGW*|MSYS*|CYGWIN*|Windows*) M=""; T="" ;;
  *) M="e"; T="x86_64-unknown-linux-gnu" ;;
esac

# gameplay code, version 1
printf 'fn tick(state: int) -> int:\n    state + 1\n' > plugin.or

# build the watcher (needs the CLI runtime for run_command + libdl for dlopen)
"$CLANG" -c "$ROOT/runtime/orion_rt.c"  -o _rt.o  2>/dev/null
"$CLANG" -c "$ROOT/runtime/orion_cli.c" -o _cli.o 2>/dev/null
"$ORION" watch.or _watch.ll "$ROOT/orbs" >/dev/null 2>&1
if [ -n "$M" ]; then sed -e "2s#e-m:w#e-m:${M}#" -e "3s#x86_64-pc-windows-msvc[0-9.]*#${T}#" _watch.ll > _watch_host.ll; else cp _watch.ll _watch_host.ll; fi
"$CLANG" _watch_host.ll _rt.o _cli.o -ldl -o _watch 2>/dev/null

echo "==> launching watcher; editing plugin.or live in ~1.4s"
./_watch & WPID=$!
sleep 1.4
printf 'fn tick(state: int) -> int:\n    state + 10\n' > plugin.or   # the live edit
echo ">>> edited plugin.or:  state + 1  ->  state + 10"
rc=0; wait $WPID || rc=$?
rm -f _rt.o _cli.o _watch.ll _watch_host.ll _watch _w.ll _w_host.ll _rt.o plugin_gen*.so plugin.or
echo "==> done - final state $rc (climbed by 1, then by 10 after the hot swap)"
