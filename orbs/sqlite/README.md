# sqlite

A real SQL database in one file, no server.

```orion
db = db_open("game.db")
db_run(db, "CREATE TABLE IF NOT EXISTS scores(name TEXT, points INTEGER)")
db_run_with(db, "INSERT INTO scores VALUES (?, ?)", ["mio", "42"])
loop row in db_rows(db, "SELECT name, points FROM scores ORDER BY points DESC"):
    cells = columns(row)
```

## Linking

The engine is the vendored sqlite3 amalgamation. A project that uses this orb
names BOTH C files in its `Orbit.toml`:

```
link = "vendor/sqlite3.c vendor/orion_sqlite.c"
```

Copy them from `orion/vendor/`. Or precompile `sqlite3.c` to a `.o` once with
`clang -c -Os` and name the `.o` instead - it takes the ~30 s sqlite compile
out of every build.

## Watch out for

Parameters ALWAYS bind through `?` placeholders. Never paste values into the
SQL text; that is how injection happens. They bind as text, and the column's
declared type converts numbers on the way in.
