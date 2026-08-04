#!/usr/bin/env bash
# link_test.sh - the `[native] link` seam, end to end. A project vendors a C
# file, declares an extern, names the file in Orbit.toml, and orbit links it.
# This seam is the door to the C ecosystem (sqlite, TLS, compression): if it
# holds for one vendored file it holds for them all.
#
#   bash tools/link_test.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORBIT="$ROOT/dist/orbit.exe"
[ -x "$ORBIT" ] || { echo "build orbit first: bash tools/build_orbit.sh"; exit 1; }
WORK="$ROOT/dist/.linktest"
rm -rf "$WORK"; mkdir -p "$WORK/src" "$WORK/vendor"
np() { cygpath -m "$1" 2>/dev/null || echo "$1"; }
fail() { echo "link_test: FAIL - $1"; exit 1; }

cat > "$WORK/vendor/answer.c" <<'EOF'
long long vendored_answer(long long n) { return n * 6; }
EOF
cat > "$WORK/Orbit.toml" <<EOF
name = "linkapp"
link = "vendor/answer.c"
[deps]
os = "path:$(np "$ROOT")/orbs/os"
EOF
cat > "$WORK/src/main.or" <<'EOF'
external define vendored_answer(n: int) -> int
define main() -> int:
    vendored_answer(7)
EOF

cd "$WORK"
"$ORBIT" run src/main.or main; code=$?
[ "$code" = "42" ] || fail "expected the vendored C to answer 42, got $code"
echo "  link seam: a vendored C file links and answers (42)"
