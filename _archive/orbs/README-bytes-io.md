# bytes / io — retired as ORBS, kept as the only copy

`bytes_lib.or` and `io_lib.or` were the pure-Orion `bytes` and `io` orbs. Their
functions are runtime builtins now (`bytes_from_text`, `byte_at`, `read_file`,
…), so `orbs/bytes/` and `orbs/io/` no longer exist and a `use bytes` line
resolves to nothing (an unresolved `use` means "builtin", which is normal).

They sat in `dist/` — a directory of GENERATED output — where they looked like
build artifacts, still carried the retired `for`/`data` spelling, and were the
only surviving copy of that code. Moved here rather than deleted: this tree has
no git history to recover them from.
