#!/usr/bin/env bash
# whisper_test.sh - the whisper orb end to end: load a model, transcribe a
# known Swedish clip, check the words come back.
#
# The fixture is a real 16 kHz mono PCM16 wav saying
# "Lele, kolla skärmen och kör testerna." - the exact format mic_take_wav
# writes, so this gate covers the mic-to-whisper handoff too.
#
# Models are half a gigabyte and are NOT in the repo. Put one at
# dist/models/ggml-small.bin (or point WHISPER_MODEL at it) and this runs;
# without one it SKIPS rather than failing a clone that never asked for
# speech recognition.
#
#   bash tools/whisper_test.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORION="$ROOT/dist/orion.exe"
[ -x "$ORION" ] || { echo "build orion first: bash tools/build_orbit.sh"; exit 1; }
CLANG="${CLANG:-C:/Program Files/LLVM/bin/clang.exe}"
[ -x "$CLANG" ] || CLANG="$(command -v clang || echo clang)"
CLANGXX="${CLANGXX:-C:/Program Files/LLVM/bin/clang++.exe}"
[ -x "$CLANGXX" ] || CLANGXX="$(command -v clang++ || echo clang++)"
MODEL="${WHISPER_MODEL:-$ROOT/dist/models/ggml-small.bin}"
WAV="$ROOT/tools/fixtures/hear_sv.wav"
WORK="$ROOT/dist/.whispertest"
fail() { echo "whisper_test: FAIL - $1"; exit 1; }

[ -f "$MODEL" ] || { echo "  whisper: SKIP, no model at $MODEL"; exit 0; }
[ -f "$WAV" ] || fail "missing fixture $WAV"

# The library is the expensive part and caches itself.
bash "$ROOT/tools/whisper_build.sh" || fail "could not build libwhisper.a"

rm -rf "$WORK"; mkdir -p "$WORK"
cat > "$WORK/probe.or" <<'EOF'
use whisper
use text
use os

define main() -> int:
    ear = hear_open(arg(1))
    if ear < 0:
        print_line("model would not load")
        return 1
    said = hear(ear, arg(2), "sv")
    why = hear_error(ear)
    junk = hear_close(ear)
    print_line("SAID: {said}")
    print_line("ERR: {why}")
    # A missing wav must report itself rather than come back silently empty.
    missing = hear(ear, "nope.wav", "sv")
    heard_ok = contains(lower(said), "skärmen") and contains(lower(said), "testerna")
    quiet_ok = why is ""
    closed_ok = junk is 0
    gone_ok = missing is ""
    p1 = if heard_ok then 15 else 0
    p2 = if quiet_ok then 9 else 0
    p3 = if closed_ok then 9 else 0
    p4 = if gone_ok then 9 else 0
    p1 + p2 + p3 + p4
EOF

"$ORION" "$WORK/probe.or" "$WORK/probe.ll" "$ROOT/orbs" > "$WORK/log.txt" 2>&1 \
    || { cat "$WORK/log.txt"; fail "probe did not compile"; }

# orion_rt.c and orion_cli.c are C: clang++ would compile them AS C++ and
# the Windows headers then reject their own declarations over language
# linkage. Compile C with clang, link the lot with clang++ for the C++
# runtime whisper.cpp needs.
for c in orion_cli orion_rt; do
    "$CLANG" -c -O2 -D_CRT_SECURE_NO_WARNINGS "$ROOT/runtime/$c.c" -o "$WORK/$c.o" \
        > "$WORK/c.txt" 2>&1 || { cat "$WORK/c.txt"; fail "$c.c did not compile"; }
done
"$CLANG" -c -O2 -I"$ROOT/vendor/whisper/include" -I"$ROOT/vendor/whisper/ggml/include" \
    -D_CRT_SECURE_NO_WARNINGS "$ROOT/vendor/orion_whisper.c" -o "$WORK/bridge.o" \
    > "$WORK/c.txt" 2>&1 || { cat "$WORK/c.txt"; fail "orion_whisper.c did not compile"; }

"$CLANGXX" "$WORK/probe.ll" "$WORK/bridge.o" "$ROOT/dist/libwhisper.a" \
    "$WORK/orion_cli.o" "$WORK/orion_rt.o" -ladvapi32 -o "$WORK/probe.exe" \
    > "$WORK/link.txt" 2>&1 || { head -8 "$WORK/link.txt"; fail "did not link"; }

out=$(cd "$WORK" && ./probe.exe "$MODEL" "$WAV" 2>/dev/null); code=$?
[ "$code" = "42" ] || fail "expected 42, got $code
$out"
echo "  whisper: $(echo "$out" | sed -n 's/^SAID: //p') (42)"
