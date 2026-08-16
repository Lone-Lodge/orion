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
for item in extension.js format.js format.test.js dialect.test.js lsp-smoke.test.js language-configuration.json astra-language-configuration.json package.json readme.md syntaxes snippets icons bin; do
    # A running orion-lsp locks bin/ - skip what is in use, the reload
    # picks up everything else and the binary is refreshed next quiet run.
    [ -e "$HERE/$item" ] && { cp -r "$HERE/$item" "$DEST/" 2>/dev/null || echo "  skipped $item (in use)"; }
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
# Modern VS Code only loads what extensions.json lists - a copied folder
# alone is invisible. Point the registry entry at this version (or add
# one), keeping every other extension untouched.
REG="${VSCODE_EXT_DIR:-$HOME/.vscode/extensions}/extensions.json"
VERSION="${NAME#lonelodge.orion-}"
if [ -f "$REG" ]; then
    node -e "
const fs=require('fs');
const p=process.argv[1], name=process.argv[2], version=process.argv[3];
const j=JSON.parse(fs.readFileSync(p,'utf8'));
const winPath=('/'+name.replace(/\\\\/g,'/')).replace(/^\/([A-Z]):/,(m,d)=>'/'+d.toLowerCase()+':');
const entry={identifier:{id:'lonelodge.orion'},version,
  location:{\$mid:1,path:winPath,scheme:'file'},
  relativeLocation:name.split('/').pop(),
  metadata:{installedTimestamp:Date.now(),pinned:true,source:'vsix'}};
const out=j.filter(e=>e.identifier.id!=='lonelodge.orion');
out.push(entry);
fs.writeFileSync(p,JSON.stringify(out));
" "$REG" "$(cd "$DEST" && pwd -W 2>/dev/null || pwd)" "$VERSION"
    echo "registry -> lonelodge.orion@$VERSION"
fi
echo "installed -> $DEST"
