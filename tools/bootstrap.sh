#!/usr/bin/env bash
# bootstrap.sh — bring a fresh clone to a working, tested toolchain from the
# checked-in seed. No lodge-orion, no Rust. See tools/seed/README.md.
#
#   seed/orion.exe -> dist/orion.exe -> self-compile (fixpoint) -> orbit -> test
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SEED="$ROOT/tools/seed/orion.exe"
DIST="$ROOT/dist"

if [ ! -x "$SEED" ] && [ ! -f "$SEED" ]; then
    echo "no seed at tools/seed/orion.exe — drop a known-good orion.exe there"
    echo "(see tools/seed/README.md). Until then a fresh clone cannot bootstrap."
    exit 1
fi

mkdir -p "$DIST"
cp "$SEED" "$DIST/orion.exe"
chmod +x "$DIST/orion.exe" 2>/dev/null || true
echo "==> seeded dist/orion.exe from tools/seed/"

echo "==> self-compile to fixpoint"
bash "$ROOT/tools/self_bootstrap.sh"

echo "==> build orbit (project tool)"
bash "$ROOT/tools/build_orbit.sh"

echo "==> run tests"
bash "$ROOT/tools/test.sh"

echo "==> bootstrap complete: orion.exe self-hosts, tests green"
