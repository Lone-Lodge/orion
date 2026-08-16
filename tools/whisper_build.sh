#!/usr/bin/env bash
# whisper_build.sh - compile vendor/whisper once into dist/libwhisper.a.
#
# whisper.cpp is not an amalgamation like sqlite: it is ~24 translation
# units of C and C++. Compiling them on every build would cost a minute
# every time, so this caches the archive in dist/ and rebuilds only when
# a vendored source is newer - same trick sqlite_test.sh uses for its .o.
#
# SIMD is the whole ballgame. Without -mavx2 -mfma -mf16c ggml falls back
# to scalar code and a four second clip takes THIRTY THREE seconds; with
# them it takes two. The baseline here is Haswell (2013) rather than
# -march=native, so the archive still runs on any machine the repo is
# cloned to.
#
#   bash tools/whisper_build.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V="$ROOT/vendor/whisper"
OUT="$ROOT/dist/libwhisper.a"
WORK="$ROOT/dist/.whisper"
CLANG="${CLANG:-C:/Program Files/LLVM/bin/clang.exe}"
[ -x "$CLANG" ] || CLANG="$(command -v clang || echo clang)"
CLANGXX="${CLANGXX:-C:/Program Files/LLVM/bin/clang++.exe}"
[ -x "$CLANGXX" ] || CLANGXX="$(command -v clang++ || echo clang++)"
AR="${AR:-C:/Program Files/LLVM/bin/llvm-ar.exe}"
[ -x "$AR" ] || AR="$(command -v llvm-ar || command -v ar || echo ar)"

[ -d "$V" ] || { echo "whisper_build: no vendor/whisper - nothing to build"; exit 1; }

# Up to date? Newest vendored source vs the archive.
if [ -f "$OUT" ]; then
    newest=$(find "$V" -type f \( -name '*.c' -o -name '*.cpp' -o -name '*.h' \) -newer "$OUT" -print -quit)
    [ -z "$newest" ] && { echo "  libwhisper.a is up to date"; exit 0; }
fi

VER="1.9.2"
# An array, not a string: the version defines carry embedded quotes and
# any eval/word-splitting round trip strips them, which lands as the
# baffling `invalid suffix '.2' on floating constant`.
FLAGS=(
    -I"$V/ggml/include" -I"$V/ggml/src" -I"$V/ggml/src/ggml-cpu"
    -I"$V/include" -I"$V/src"
    -mavx -mavx2 -mfma -mf16c -mbmi2
    -DGGML_USE_CPU -DNDEBUG -D_CRT_SECURE_NO_WARNINGS
    -D_SILENCE_ALL_CXX17_DEPRECATION_WARNINGS
    -DGGML_VERSION="\"$VER\"" -DGGML_COMMIT="\"vendored\""
    -DWHISPER_VERSION="\"$VER\""
)

CSRC="ggml/src/ggml.c ggml/src/ggml-alloc.c ggml/src/ggml-quants.c
      ggml/src/ggml-cpu/ggml-cpu.c ggml/src/ggml-cpu/quants.c
      ggml/src/ggml-cpu/arch/x86/quants.c"
XSRC="ggml/src/ggml.cpp ggml/src/ggml-backend.cpp ggml/src/ggml-backend-reg.cpp
      ggml/src/ggml-backend-meta.cpp ggml/src/ggml-backend-dl.cpp
      ggml/src/ggml-opt.cpp ggml/src/ggml-threading.cpp ggml/src/gguf.cpp
      ggml/src/ggml-cpu/ggml-cpu.cpp ggml/src/ggml-cpu/binary-ops.cpp
      ggml/src/ggml-cpu/unary-ops.cpp ggml/src/ggml-cpu/ops.cpp
      ggml/src/ggml-cpu/repack.cpp ggml/src/ggml-cpu/traits.cpp
      ggml/src/ggml-cpu/vec.cpp ggml/src/ggml-cpu/arch/x86/repack.cpp
      ggml/src/ggml-cpu/arch/x86/cpu-feats.cpp src/whisper.cpp"

rm -rf "$WORK"; mkdir -p "$WORK"
echo "  compiling vendor/whisper -> dist/libwhisper.a (a minute, once)"
fail=0
for f in $CSRC; do
    o="$WORK/$(echo "$f" | tr '/' '_').o"
    "$CLANG" -c -O3 "${FLAGS[@]}" "$V/$f" -o "$o" 2> "$WORK/e.txt" \
        || { echo "  FAILED: $f"; head -5 "$WORK/e.txt"; fail=1; }
done
for f in $XSRC; do
    o="$WORK/$(echo "$f" | tr '/' '_').o"
    "$CLANGXX" -c -O3 -std=c++17 "${FLAGS[@]}" "$V/$f" -o "$o" 2> "$WORK/e.txt" \
        || { echo "  FAILED: $f"; head -5 "$WORK/e.txt"; fail=1; }
done
[ "$fail" = "0" ] || { echo "whisper_build: FAIL"; exit 1; }

rm -f "$OUT"
"$AR" rcs "$OUT" "$WORK"/*.o || { echo "whisper_build: archive failed"; exit 1; }
rm -rf "$WORK"
echo "  dist/libwhisper.a ready ($(du -h "$OUT" | cut -f1))"
