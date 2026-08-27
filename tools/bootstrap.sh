#!/usr/bin/env bash
# bootstrap.sh - bring a fresh clone to a working, tested toolchain from the
# checked-in seed. No lodge-orion, no Rust. See tools/seed/README.md.
#
#   seed/orion.exe -> dist/orion.exe -> self-compile (fixpoint) -> orbit -> test
#
# The seed may be a BINARY (tools/seed/orion.exe) or the committed seed IR
# (tools/seed/orion.ll, linked here by clang). The .ll is what the repo actually
# carries, so this used to stop on a fresh clone with "no seed" even though a
# perfectly good seed was sitting next to it.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SEED="$ROOT/tools/seed/orion.exe"
SEED_LL="$ROOT/tools/seed/orion.ll"
DIST="$ROOT/dist"

mkdir -p "$DIST"
if [ -f "$SEED" ]; then
    cp "$SEED" "$DIST/orion.exe"
    chmod +x "$DIST/orion.exe" 2>/dev/null || true
    echo "==> seeded dist/orion.exe from tools/seed/orion.exe"
elif [ -f "$SEED_LL" ]; then
    echo "==> no binary seed; linking tools/seed/orion.ll"
    bash "$ROOT/tools/bootstrap_from_ll.sh"
else
    echo "no seed in tools/seed/ - needs orion.exe or orion.ll"
    echo "(see tools/seed/README.md). Until then a fresh clone cannot bootstrap."
    exit 1
fi

echo "==> self-compile to fixpoint"
bash "$ROOT/tools/self_bootstrap.sh"

echo "==> build orbit (project tool)"
bash "$ROOT/tools/build_orbit.sh"

echo "==> run tests"
# The outcome is READ. It used to be discarded, and the line below then
# announced green whatever happened - which is how a suite that passed
# nothing at all still ended with "tests green".
if ! bash "$ROOT/tools/test.sh"; then
    echo "==> bootstrap FAILED: orion.exe self-hosts, but the suite is not green" >&2
    exit 1
fi

echo "==> bootstrap complete: orion.exe self-hosts, tests green"
