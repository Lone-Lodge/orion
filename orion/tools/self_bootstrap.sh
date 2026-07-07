#!/usr/bin/env bash
# self_bootstrap.sh — rebuild orion.exe using orion.exe itself. No lodge-orion.
#
# WHY: orion-self has out-grown lodge-orion's parser (it uses `else if` and
# other syntax lodge-orion's older parser rejects — "expected `:`, found If").
# So tools/aot_bootstrap.sh (which compiles the compiler via lodge-orion) can
# no longer parse orion-self. But the current orion.exe CAN — it's the
# self-hosted compiler. This uses it to rebuild itself:
#
#   orion.exe  bundle.or -> stage1.ll  ->  clang + orion_rt.c  ->  orion_new.exe
#   orion_new.exe  bundle.or -> stage2.ll     (the fixpoint check)
#   stage1.ll == stage2.ll  =>  install orion_new.exe as orion.exe
#
# Cross-platform: the compiler ALWAYS emits a Windows target triple (the
# setjmp/longjmp effect ABI is pinned to it). On Linux/Mac we retarget each
# emitted .ll to the host before clang links it — same trick as
# bootstrap_from_ll.sh. On a fresh non-Windows clone, run bootstrap_from_ll.sh
# first to get an initial dist/orion.exe from the seed, then run this.
#
# Fast (~1s vs lodge-orion's 30-60 min) and one dependency closer to
# archiving lodge-orion entirely.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORION="$ROOT/dist/orion.exe"
DIST="$ROOT/dist"
RT="$ROOT/runtime/orion_rt.c"
CLANG="${CLANG:-C:/Program Files/LLVM/bin/clang.exe}"
[ -x "$CLANG" ] || CLANG="$(command -v clang || echo clang)"

# --- host detection: pick target triple + datalayout mangling + link flags ---
# The seed/emitted .ll carries a Windows COFF triple (mangling `e-m:w`). ELF
# (Linux) wants `e-m:e`, Mach-O (Mac) wants `e-m:o`. Windows links natively so
# no retarget. The deep-recursing compiler needs a big stack: Windows reserves
# it at link time (/STACK); POSIX raises it at run time (ulimit).
HOST_OS="$(uname -s 2>/dev/null || echo unknown)"
RETARGET=1
STACK_LINK=""
case "$HOST_OS" in
    Linux)
        HOST_TRIPLE="x86_64-unknown-linux-gnu"; MANGLE="e" ;;
    Darwin)
        if [ "$(uname -m)" = "arm64" ]; then
            HOST_TRIPLE="arm64-apple-macosx"
        else
            HOST_TRIPLE="x86_64-apple-macosx"
        fi
        MANGLE="o" ;;
    MINGW*|MSYS*|CYGWIN*|Windows*)
        RETARGET=0; STACK_LINK="-Xlinker /STACK:67108864" ;;
    *)
        # Unknown POSIX-ish host: assume ELF/Linux conventions.
        HOST_TRIPLE="x86_64-unknown-linux-gnu"; MANGLE="e" ;;
esac
# Raise the stack for the compiler's deep recursion on POSIX hosts (no-op on
# Windows, where /STACK handles it). Best-effort: unlimited on Linux, the hard
# max on Mac (which caps main-thread stack well below unlimited).
if [ "$RETARGET" = "1" ]; then
    ulimit -s unlimited 2>/dev/null || ulimit -s 65500 2>/dev/null || true
fi

# Link an emitted .ll into a native compiler exe. On POSIX the .ll carries a
# Windows triple, so link from a RETARGETED COPY — the original .ll stays
# Windows-triple, which is what the stage1==stage2 fixpoint diff compares (the
# compiler always re-emits the Windows triple, so both sides must keep it).
# The sed is portable across GNU and BSD sed (no in-place -i, which differ).
link_stage() {
    if [ "$RETARGET" = "1" ]; then
        # Keep a .ll extension — clang dispatches on it to detect LLVM IR.
        sed -e "2s#e-m:w#e-m:${MANGLE}#" \
            -e "3s#x86_64-pc-windows-msvc[0-9.]*#${HOST_TRIPLE}#" \
            "$1" > "$1.host.ll"
        "$CLANG" "$1.host.ll" "$RT" $STACK_LINK -o "$2"
        rm -f "$1.host.ll"
    else
        "$CLANG" "$1" "$RT" $STACK_LINK -o "$2"
    fi
}

echo "==> host: $HOST_OS (retarget=$RETARGET triple=${HOST_TRIPLE:-native})"
[ -x "$ORION" ] || { echo "no dist/orion.exe — bootstrap from the seed first: bash tools/bootstrap_from_ll.sh"; exit 1; }

echo "==> bundling orbs"
bash "$ROOT/tools/bundle_orbs.sh" >/dev/null
BUNDLE="$DIST/orion_self_bundled.or"

echo "==> stage 1: current orion.exe compiles the bundle"
"$ORION" "$BUNDLE" "$DIST/orion_stage1.ll"
echo "==> link stage 1 -> orion_new.exe (big stack: the compiler recurses deep)"
link_stage "$DIST/orion_stage1.ll" "$DIST/orion_new.exe"

echo "==> stage 2: the NEW orion.exe re-compiles the bundle (fixpoint check)"
"$DIST/orion_new.exe" "$BUNDLE" "$DIST/orion_stage2.ll"

if diff -q "$DIST/orion_stage1.ll" "$DIST/orion_stage2.ll" >/dev/null; then
    cp "$DIST/orion_new.exe" "$ORION"
    rm -f "$DIST/orion_stage1.ll" "$DIST/orion_stage2.ll" "$DIST/orion_new.exe"
    echo "==> SUCCESS: orion.exe rebuilt, self-hosted, fixpoint reached (no lodge-orion)"
    exit 0
fi

# stage1 != stage2 is EXPECTED after an intentional codegen change: the old
# compiler renders the (new) bundle differently than the new compiler does.
# The new compiler must still be STABLE — compiling itself reproducibly. So
# iterate once more: build from stage2 and check stage2 == stage3.
echo "==> stage1 != stage2 (codegen changed) — iterating to confirm the new compiler is stable"
link_stage "$DIST/orion_stage2.ll" "$DIST/orion_new2.exe"
"$DIST/orion_new2.exe" "$BUNDLE" "$DIST/orion_stage3.ll"

if diff -q "$DIST/orion_stage2.ll" "$DIST/orion_stage3.ll" >/dev/null; then
    cp "$DIST/orion_new2.exe" "$ORION"
    rm -f "$DIST/orion_stage1.ll" "$DIST/orion_stage2.ll" "$DIST/orion_stage3.ll" "$DIST/orion_new.exe" "$DIST/orion_new2.exe"
    echo "==> SUCCESS: converged after codegen change (stage2 == stage3), orion.exe rebuilt"
else
    echo "==> FAILED: still diverging (stage2 != stage3) — non-deterministic compile, orion.exe NOT replaced"
    exit 1
fi
