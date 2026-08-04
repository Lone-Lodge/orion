#!/usr/bin/env bash
# install.sh - copy this extension into the local VS Code extensions dir.
#
# The extension SOURCE lives here, in the repo. It used to live only in the
# installed copy under ~/.vscode/extensions, which is how its grammar and its
# language server drifted a year behind the compiler with nobody able to rebuild
# either. Edit here, run this, reload the window.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="lonelodge.orion-$(grep -o '"version": *"[^"]*"' "$HERE/package.json" | head -1 | sed 's/.*"\([0-9.]*\)"/\1/')"
DEST="${VSCODE_EXT_DIR:-$HOME/.vscode/extensions}/$NAME"
mkdir -p "$DEST"
# node_modules stays in the installed copy: the client library is a dependency,
# not source. Everything else is overwritten from the repo.
for item in extension.js format.js format.test.js lsp-smoke.test.js language-configuration.json package.json readme.md syntaxes snippets icons bin; do
    [ -e "$HERE/$item" ] && cp -r "$HERE/$item" "$DEST/"
done
if [ ! -d "$DEST/node_modules" ]; then
    PREV="$(ls -d "${VSCODE_EXT_DIR:-$HOME/.vscode/extensions}"/lonelodge.orion-* 2>/dev/null | grep -v "$NAME\$" | tail -1 || true)"
    if [ -n "$PREV" ] && [ -d "$PREV/node_modules" ]; then
        cp -r "$PREV/node_modules" "$DEST/"
        echo "  reused node_modules from $(basename "$PREV")"
    else
        echo "  NOTE: no node_modules - run 'npm install vscode-languageclient' in $DEST"
    fi
fi
echo "installed -> $DEST"
