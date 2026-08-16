#!/usr/bin/env bash
# Package the orion toolchain itself as a real installer:
#
#   dist/orion-<version>-win.zip        the toolchain, portable
#   dist/orion-<version>-setup.exe      double-click install: per-user,
#                                       own uninstall, and <install>\dist
#                                       joins the user PATH so `orbit`
#                                       works in every new terminal
#
# Same stub every `orbit package` app ships with - the toolchain eats its
# own installer. What ships: dist/{orbit,orion,orion-lsp}.exe, runtime/
# (the C every build links against), orbs/ (the stdlib). clang is NOT
# bundled - the first build without it says what to install.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-$(date +%Y.%m.%d)}"
STAGE="$ROOT/dist/.toolchain/orion"

rm -rf "$ROOT/dist/.toolchain"
mkdir -p "$STAGE/dist"
cp "$ROOT/dist/orbit.exe" "$ROOT/dist/orion.exe" "$STAGE/dist/"
[ -f "$ROOT/dist/orion-lsp.exe" ] && cp "$ROOT/dist/orion-lsp.exe" "$STAGE/dist/"
cp -r "$ROOT/orbs" "$STAGE/orbs"
cp -r "$ROOT/runtime" "$STAGE/runtime"

ZIP="$ROOT/dist/orion-$VERSION-win.zip"
rm -f "$ZIP"
(cd "$ROOT/dist/.toolchain" && "C:/Windows/System32/tar.exe" -a -c -f "$ZIP" orion)
rm -rf "$ROOT/dist/.toolchain"

cd "$ROOT"
./dist/orbit.exe setup orion "$VERSION" "dist/orion-$VERSION-win.zip" dist "dist/orbit.exe"
