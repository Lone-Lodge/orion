#!/bin/bash
# Compile a project and print its program SHAPE: every function, and inside
# each one the sequence of opcodes. Bytes are the wrong comparison across a
# spelling change - `number` picks the same machine type but function ORDER in
# the bundle can move - so this is what a migration is proven against.
#
#   verify_shape.sh <project-dir> <entry> [extra-root...]
set -e
P="$1"; ENTRY="$2"; shift 2
ORION="$(cd "$(dirname "$0")/../.." && pwd)/dist/orion.exe"
cd "$P"
D=$(grep -oE 'path:[^"]+' Orbit.toml 2>/dev/null | sed 's/path://' | while read d; do echo "$d"; echo "${d%/*}"; done | awk '!seen[$0]++' | tr '\n' ' ')
mkdir -p build
"$ORION" "$ENTRY" build/_shape.ll $D orbs "$@" > /dev/null 2>&1 || { echo "BYGGER INTE"; exit 1; }
awk '/^define /{n=$0; sub(/\(.*/,"",n); print "FN " n; next} /^}/{next} NF{s=$0; sub(/.*= /,"",s); split(s,a," "); print a[1]}' build/_shape.ll
rm -f build/_shape.ll
