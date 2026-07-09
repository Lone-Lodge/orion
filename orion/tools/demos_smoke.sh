#!/bin/bash
# demos_smoke — compile (and link) every examples/demos/*.or and report
# pass/fail. Guards the demos against orb renames and compiler changes.
#
#   bash tools/demos_smoke.sh
#
# net_demo.or is skipped by default: it needs a networking runtime
# (tcp_connect) that isn't on the default orb path. Pass `--all` to
# include it.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ORION="$ROOT/dist/orion.exe"
RT="$ROOT/runtime/orion_rt.c"
TMP=$(mktemp -d)
INCLUDE_NET=0
[ "${1:-}" = "--all" ] && INCLUDE_NET=1

[ -x "$ORION" ] || { echo "no dist/orion.exe — run tools/bootstrap_from_ll.sh first"; exit 1; }

# The compiler always emits a Windows triple; on POSIX retarget to the host.
case "$(uname -s 2>/dev/null || echo Linux)" in
    Darwin) MANGLE="o"; if [ "$(uname -m)" = "arm64" ]; then TRIPLE="arm64-apple-macosx"; else TRIPLE="x86_64-apple-macosx"; fi ;;
    MINGW*|MSYS*|CYGWIN*|Windows*) MANGLE=""; TRIPLE="" ;;
    *) MANGLE="e"; TRIPLE="x86_64-unknown-linux-gnu" ;;
esac
CLANG="$(command -v clang || echo clang)"

pass=0; fail=0
for f in "$ROOT"/examples/demos/*.or; do
    base=$(basename "$f")
    if [ "$base" = "net_demo.or" ] && [ "$INCLUDE_NET" = "0" ]; then
        echo "skip  $base (needs networking; --all to include)"
        continue
    fi
    ll="$TMP/d.ll"; bin="$TMP/d.bin"
    rm -f "$ll" "$bin"
    if ! "$ORION" "$f" "$ll" "$ROOT/orbs" >/dev/null 2>"$TMP/err"; then
        echo "FAIL  $base (compile): $(grep -i error "$TMP/err" | head -1)"
        fail=$((fail + 1)); continue
    fi
    src="$ll"
    if [ -n "$MANGLE" ]; then
        sed -e "2s#e-m:w#e-m:${MANGLE}#" -e "3s#x86_64-pc-windows-msvc[0-9.]*#${TRIPLE}#" "$ll" > "$TMP/d.host.ll"
        src="$TMP/d.host.ll"
    fi
    if "$CLANG" "$src" "$RT" -o "$bin" >/dev/null 2>&1; then
        echo "ok    $base"
        pass=$((pass + 1))
    else
        echo "LINK  $base"
        fail=$((fail + 1))
    fi
done
rm -rf "$TMP"
echo "-----"
echo "demos: $pass ok, $fail failed"
[ "$fail" = "0" ]
