#!/bin/bash
# test_workspace.sh - regression for layout-free, name-based orb resolution.
#
# Builds a throwaway workspace with a deliberately WEIRD folder layout: a
# `.orbit` marker at the root, an orb buried at libs/deep/nested/orbs/, and a
# project at games/mygame/ that references the orb BY NAME (`greeter = "*"`,
# no path). orbit must walk up to the marker, scan the tree, resolve the orb
# by name, and run. Proves any folder structure works.
set -e
ORBIT="$(cd "$(dirname "$0")/.." && pwd)/dist/orbit.exe"
[ -x "$ORBIT" ] || { echo "build orbit first: bash tools/build_orbit.sh"; exit 1; }

WS="$(mktemp -d)"
trap 'rm -rf "$WS"' EXIT
touch "$WS/.orbit"

mkdir -p "$WS/libs/deep/nested/orbs/greeter"
cat > "$WS/libs/deep/nested/orbs/greeter/lib.or" <<'EOF'
public define hello() -> text = "name-resolved"
EOF
cat > "$WS/libs/deep/nested/orbs/greeter/Orbit.toml" <<'EOF'
name = "greeter"
version = "0.0.1"
EOF

mkdir -p "$WS/games/mygame/src"
cat > "$WS/games/mygame/Orbit.toml" <<'EOF'
[package]
name = "mygame"
version = "0.0.1"

[orbs]
greeter = "*"
EOF
cat > "$WS/games/mygame/src/main.or" <<'EOF'
use greeter
define main():
    print(hello())
EOF

out="$( cd "$WS/games/mygame" && "$ORBIT" run src/main.or main 2>&1 )" || true
if printf '%s\n' "$out" | grep -q "name-resolved"; then
    echo "PASS: name-based orb resolution across an arbitrary layout"
else
    echo "FAIL: name-based resolution"; printf '%s\n' "$out"; exit 1
fi

# Second case: a project with NO workspace marker anywhere above it, and no
# path into the orion checkout. Its only dependency is the standard library by
# name (`os = "*"`), which must come from the toolchain that is running - the
# way a cloned repo builds against an installed orion.
SOLO="$(mktemp -d)"
trap 'rm -rf "$WS" "$SOLO"' EXIT

mkdir -p "$SOLO/proj/src"
cat > "$SOLO/proj/Orbit.toml" <<'EOF'
[package]
name = "solo"
version = "0.0.1"

[orbs]
os = "*"
EOF
cat > "$SOLO/proj/src/main.or" <<'EOF'
define main():
    print(if length(read_file("Orbit.toml")) > 0 then "stdlib-reached" else "no")
EOF

out="$( cd "$SOLO/proj" && "$ORBIT" run src/main.or main 2>&1 )" || true
if printf '%s\n' "$out" | grep -q "stdlib-reached"; then
    echo "PASS: the stdlib resolves outside any workspace"
else
    echo "FAIL: stdlib outside a workspace"; printf '%s\n' "$out"; exit 1
fi
