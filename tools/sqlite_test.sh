#!/usr/bin/env bash
# sqlite_test.sh - the sqlite orb, end to end: create, insert (bound params,
# including a value full of SQL-injection characters), query, count, update,
# error reporting. sqlite3.c is precompiled to a .o ONCE and cached in dist/
# so the gate costs seconds, not the ~40 s amalgamation compile - and the
# cache is keyed to the vendored source's mtime, so a bumped sqlite rebuilds.
#
#   bash tools/sqlite_test.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORBIT="$ROOT/dist/orbit.exe"
[ -x "$ORBIT" ] || { echo "build orbit first: bash tools/build_orbit.sh"; exit 1; }
CLANG="${CLANG:-C:/Program Files/LLVM/bin/clang.exe}"
[ -x "$CLANG" ] || CLANG="$(command -v clang || echo clang)"
WORK="$ROOT/dist/.sqltest"
rm -rf "$WORK"; mkdir -p "$WORK/src"
np() { cygpath -m "$1" 2>/dev/null || echo "$1"; }
fail() { echo "sqlite_test: FAIL - $1"; exit 1; }

SQO="$ROOT/dist/sqlite3.o"
if [ ! -f "$SQO" ] || [ "$ROOT/vendor/sqlite3.c" -nt "$SQO" ]; then
    echo "  (compiling vendored sqlite3.c once -> dist/sqlite3.o)"
    "$CLANG" -c -Os "$ROOT/vendor/sqlite3.c" -o "$SQO" || fail "sqlite3.c did not compile"
fi

cat > "$WORK/Orbit.toml" <<EOF
name = "sqlapp"
link = "$(np "$SQO") $(np "$ROOT")/vendor/orion_sqlite.c"
[deps]
os = "path:$(np "$ROOT")/orbs/os"
sqlite = "path:$(np "$ROOT")/orbs/sqlite"
EOF
cat > "$WORK/src/main.or" <<'EOF'
use sqlite
use os
use text

define main() -> number:
    junk = remove_file("scores.db")
    db = db_open("scores.db")
    if db < 0:
        return 1
    ok1 = db_run(db, "CREATE TABLE scores(name TEXT, points INTEGER)")
    nasty = "Robert'); DROP TABLE scores;--"
    ok2 = db_run_with(db, "INSERT INTO scores VALUES (?, ?)", ["mio", "30"])
    ok3 = db_run_with(db, "INSERT INTO scores VALUES (?, ?)", [nasty, "7"])
    ok4 = db_run_with(db, "INSERT INTO scores VALUES (?, ?)", ["alva", "5"])
    inserted = ok1 and ok2 and ok3 and ok4 and db_changes(db) is 1

    rows = db_rows(db, "SELECT name, points FROM scores ORDER BY points DESC")
    top = columns(at(rows, 0))
    order_ok = length(rows) is 3 and at(top, 0) is "mio" and at(top, 1) is "30"

    kept = db_one(db, "SELECT count(*) FROM scores") is "3"
    injected = db_rows_with(db, "SELECT points FROM scores WHERE name = ?", [nasty])
    bound_ok = length(injected) is 1 and at(injected, 0) is "7"

    upd = db_run_with(db, "UPDATE scores SET points = ? WHERE name = ?", ["50", "alva"])
    sum_ok = db_one(db, "SELECT sum(points) FROM scores") is "87"

    bad = db_run(db, "SELECT * FROM saknas")
    err_ok = not bad and contains(db_error(db), "saknas")

    closed = db_close(db) is 0
    print_line("rows={length(rows)} top={at(top, 0)} err={db_error(db)}")
    p1 = if inserted then 8 else 0
    p2 = if order_ok then 8 else 0
    p3 = if kept and bound_ok then 10 else 0
    p4 = if upd and sum_ok then 8 else 0
    p5 = if err_ok and closed then 8 else 0
    p1 + p2 + p3 + p4 + p5
EOF

cd "$WORK"
"$ORBIT" run src/main.or main; code=$?
[ "$code" = "42" ] || fail "expected 42, got $code"
echo "  sqlite: create/insert/bind/query/count/update/error all hold (42)"
