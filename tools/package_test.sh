#!/usr/bin/env bash
# package_test.sh - the package system, end to end, against LOCAL git repos
# (no network). Proves: `orbit get` fetches a git dep into orbs_pkg/ and pins
# it in Orbit.lock; a tag ref stays on the tag; a transitive git dep (a
# package's own Orbit.toml) is fetched flat without the app naming it; a
# second `get` holds the lock even when the remote moved; `orbit update`
# moves to the ref's newest commit and rewrites the lock.
#
#   bash tools/package_test.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORBIT="$ROOT/dist/orbit.exe"
[ -x "$ORBIT" ] || { echo "build orbit first: bash tools/build_orbit.sh"; exit 1; }
WORK="$ROOT/dist/.pkgtest"
rm -rf "$WORK"; mkdir -p "$WORK"
# orbit hands these to git.exe via CreateProcess, which needs C:/-style
# paths, not the shell's /c/-style. cygpath -m exists on git-bash/msys;
# elsewhere the paths are already native.
np() { cygpath -m "$1" 2>/dev/null || echo "$1"; }
fail() { echo "package_test: FAIL - $1"; exit 1; }
G() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}"; }

# --- package c: a leaf orb nobody's app names directly
CPKG="$WORK/cpkg"; mkdir -p "$CPKG"
cat > "$CPKG/lib.or" <<'EOF'
public define c_base() -> number:
    example c_base() is 15
    15
EOF
G "$CPKG" init -q -b main; G "$CPKG" add -A; G "$CPKG" commit -qm one

# --- package a: depends on cpkg through its OWN Orbit.toml (transitive)
APKG="$WORK/apkg"; mkdir -p "$APKG"
cat > "$APKG/lib.or" <<'EOF'
use cpkg
public define a_answer() -> number:
    example a_answer() is 20
    c_base() + 5
EOF
cat > "$APKG/Orbit.toml" <<EOF
name = "apkg"
[deps]
cpkg = "git:$(np "$CPKG")"
EOF
G "$APKG" init -q -b main; G "$APKG" add -A; G "$APKG" commit -qm one

# --- package b: tagged v1, then moved PAST the tag (get@v1 must not see it)
BPKG="$WORK/bpkg"; mkdir -p "$BPKG"
cat > "$BPKG/lib.or" <<'EOF'
public define b_answer() -> number:
    example b_answer() is 21
    21
EOF
G "$BPKG" init -q -b main; G "$BPKG" add -A; G "$BPKG" commit -qm one; G "$BPKG" tag v1
cat > "$BPKG/lib.or" <<'EOF'
public define b_answer() -> number:
    example b_answer() is 99
    99
EOF
G "$BPKG" add -A; G "$BPKG" commit -qm two

# --- the consumer app: names a (branch) and b (tag v1); never names c
APP="$WORK/app"; mkdir -p "$APP/src"
cat > "$APP/Orbit.toml" <<EOF
name = "app"
[deps]
os = "path:$(np "$ROOT")/orbs/os"
apkg = "git:$(np "$APKG")"
bpkg = "git:$(np "$BPKG")@v1"
EOF
cat > "$APP/src/main.or" <<'EOF'
use apkg
use bpkg
define main() -> number:
    a_answer() + b_answer()
EOF

cd "$APP"
"$ORBIT" get || fail "orbit get errored"
[ -f Orbit.lock ] || fail "no Orbit.lock written"
[ -f orbs_pkg/apkg/lib.or ] || fail "apkg not fetched"
[ -f orbs_pkg/bpkg/lib.or ] || fail "bpkg not fetched"
[ -f orbs_pkg/cpkg/lib.or ] || fail "transitive cpkg not fetched"
grep -q '^cpkg ' Orbit.lock || fail "transitive dep missing from lock"

"$ORBIT" run src/main.or main >/dev/null 2>&1; code=$?
[ "$code" = "41" ] || fail "expected 20+21=41 after get, got $code"

# the remote moves: a_answer 20 -> 21. A locked project must NOT follow.
cat > "$APKG/lib.or" <<'EOF'
use cpkg
public define a_answer() -> number:
    example a_answer() is 21
    c_base() + 6
EOF
G "$APKG" add -A; G "$APKG" commit -qm two
"$ORBIT" get >/dev/null || fail "second get errored"
"$ORBIT" run src/main.or main >/dev/null 2>&1; code=$?
[ "$code" = "41" ] || fail "lock did not hold after remote moved, got $code"

# update apkg: now it follows - 21+21=42. The tag pin stays where it is.
"$ORBIT" update apkg >/dev/null || fail "orbit update errored"
[ -f orbs_pkg/apkg/lib.or ] || fail "apkg gone after update"
"$ORBIT" run src/main.or main >/dev/null 2>&1; code=$?
[ "$code" = "42" ] || fail "expected 21+21=42 after update, got $code"

echo "  packages: get/lock/transitive/update all hold (41 -> 41 -> 42)"
