#!/usr/bin/env bash
# mic_test.sh - the mic orb, both backends.
#
# The binding chain (orb extern -> LLVM declare -> C symbol) is the part
# that actually breaks, and it breaks identically with or without a sound
# card - so the null backend gets its own phase and runs everywhere.
#
# The real phase links wasapi_min.c and asserts frames ARRIVED. A live
# capture device produces frames in a silent room too, so this proves the
# ring is filling without anyone having to talk to the build.
#
#   bash tools/mic_test.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORION="$ROOT/dist/orion.exe"
[ -x "$ORION" ] || { echo "build orion first: bash tools/build_orbit.sh"; exit 1; }
CLANG="${CLANG:-C:/Program Files/LLVM/bin/clang.exe}"
[ -x "$CLANG" ] || CLANG="$(command -v clang || echo clang)"
WORK="$ROOT/dist/.mictest"
rm -rf "$WORK"; mkdir -p "$WORK"
fail() { echo "mic_test: FAIL - $1"; exit 1; }

cat > "$WORK/probe.or" <<'EOF'
use mic

define main() -> number:
    if not mic_open(16000):
        print_line("frames=-1 wrote=-1 (no capture device)")
        return 7
    rate = mic_rate()
    sleep_ms(1200)
    frames = mic_buffered()
    secs = mic_seconds()
    level = mic_level()
    wrote = mic_take_wav("heard.wav")
    left = mic_buffered()
    mic_close()
    print_line("frames={frames} wrote={wrote} rate={rate} secs={secs} level={level}")
    # The contract, true with a card and without: the rate is what we asked
    # for, a take never claims more than was buffered, and taking drains.
    rate_ok = rate is 16000
    take_ok = wrote <= frames
    drained = left < frames or frames is 0
    closed = mic_rate() is 0
    p1 = if rate_ok then 12 else 0
    p2 = if take_ok then 10 else 0
    p3 = if drained then 10 else 0
    p4 = if closed then 10 else 0
    p1 + p2 + p3 + p4
EOF

"$ORION" "$WORK/probe.or" "$WORK/probe.ll" "$ROOT/orbs" > "$WORK/log.txt" 2>&1 \
    || { cat "$WORK/log.txt"; fail "probe did not compile"; }

# --- phase 1: null backend (no wasapi_min.c). Runs on any machine.
"$CLANG" "$WORK/probe.ll" "$ROOT/runtime/orion_cli.c" "$ROOT/runtime/orion_rt.c" \
    -o "$WORK/null.exe" > "$WORK/link.txt" 2>&1 \
    || { cat "$WORK/link.txt"; fail "null backend did not link"; }
out=$(cd "$WORK" && ./null.exe); code=$?
[ "$code" = "42" ] || fail "null backend: expected 42, got $code ($out)"
case "$out" in
    *"frames=0 wrote=0"*) : ;;
    *) fail "null backend should hear nothing, got: $out" ;;
esac
echo "  mic null   : contract holds, silent as designed (42)"

# --- phase 2: the real WASAPI backend.
"$CLANG" "$WORK/probe.ll" "$ROOT/runtime/orion_cli.c" "$ROOT/runtime/orion_rt.c" \
    "$ROOT/runtime/wasapi_min.c" -lole32 \
    -o "$WORK/real.exe" > "$WORK/link2.txt" 2>&1 \
    || { cat "$WORK/link2.txt"; fail "wasapi backend did not link"; }
out=$(cd "$WORK" && ./real.exe); code=$?
if [ "$code" = "7" ]; then
    echo "  mic wasapi : SKIP, no capture device on this machine"
    exit 0
fi
[ "$code" = "42" ] || fail "wasapi backend: expected 42, got $code ($out)"
frames=$(echo "$out" | sed -n 's/.*frames=\([0-9-]*\).*/\1/p')
wrote=$(echo "$out" | sed -n 's/.*wrote=\([0-9-]*\).*/\1/p')
[ "${frames:-0}" -gt 8000 ] || fail "expected ~1.2 s of frames at 16 kHz, got $frames"
[ "${wrote:-0}" -gt 8000 ] || fail "take_wav wrote $wrote frames"
[ -s "$WORK/heard.wav" ] || fail "heard.wav is empty"
echo "  mic wasapi : $frames frames captured, $wrote written to wav (42)"
