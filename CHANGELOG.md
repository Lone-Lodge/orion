# Changelog

Notable changes to Orion. Format follows [Keep a Changelog](https://keepachangelog.com/),
versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **`whisper` orb** - speech to text over the vendored whisper.cpp 1.9.2, four
  calls, wav in. Takes exactly what `mic_take_wav` writes.
- **`mic` orb** - capture on its own thread into a 30-second ring, downmixed and
  decimated on the way in. Headless builds link a null backend and still run the
  whole path.
- **`sqlite` orb** - a real SQL database in one file, no server. Bound `?` params
  are the injection-safe path, proven by a hostile string in the gate.
- **Width-exact sized-integer arithmetic on both backends.** `x: u8 = 200` then
  `x + 100` is 44 natively too (it used to answer 300). This was the last known
  correctness gap between the two backends.
- **The general-software floor** - `env`, `interrupted()`, `secure_bytes`, a
  `time` orb, an `http` orb, and `link = "vendor/x.c"` in Orbit.toml for
  vendored C.
- **Debugger v1** - `orbit debug prog.or` keeps a call trail (last 64 entries)
  and prints it newest-first on a crash, a trap, or a `breakpoint()`.
  Instrumentation is opt-in; a plain build pays nothing.
- **A file watcher** - `orbwatch` reruns a command on change and kills the stale
  run. Drove out `modified_at` in `os` and `int_from_text` in `text`.
- **Child processes the scheduler can wait on** - `start_command`,
  `finished_within`, `command_result`, `stop_command`, `cpu_count()`. The test
  runner uses them: the suite went from ~79 s serial to ~17 s wall.
- **Traits as explicit dictionaries.** `o.method(args)` calls the fn-typed field
  `method` on the struct value. No implicit resolution: you can see which
  dictionary is passed.
- **A WebAssembly backend** - `orion prog.or prog.wasm orbs` emits a
  self-contained module. The host supplies capabilities through imports; Orion
  owns its memory. The async scheduler stays native.
- **A WebAssembly conformance gate** - every smoke test run through wasm in node
  and compared to the native answer. Wired into CI as a regression ratchet.
- **The Field Guide playground** - a Run button on every sample, compiled to
  wasm in place. A construct wasm cannot lower says "native only".
- **A library reference page** (`docs/reference.html`), generated from `orbs/`
  so it cannot drift. `docs_check.sh` fails if the committed page is stale.

### Changed
- **A `fn(A, B) -> R` parameter carries its signature.** Wrong argument count is
  a compile error, each argument's shape is checked, and the declared return
  type propagates through the call. Function values are typed end to end.
- **`result` and `option` are native generic sum types**, not struct
  conventions. They cross an orb boundary, carry any payload, and propagate with
  `?`. The lying `unwrap` is gone: Orion has no panic, so it could not be written
  honestly.
- **Effects come in two tiers.** One-shot (`perform` / `handle` / `resume`) is
  the supported core. Multi-shot (`ask` / `resume_with`) is experimental and
  rides on Windows fibers.
- **A collecting `loop` takes an indented body.** The trailing expression is
  collected and `yield expr` collects more mid-body. The `where` clause is gone;
  `if ...: yield` replaces it.

### Fixed
- **A local binding shadows a same-named const.** Const inlining used to
  substitute `num`'s `e` into any body with its own `e`.
- **A closure call inside a short-circuit `and`/`or`** generated invalid LLVM.
  The phi-predecessor tracking named the branch's entry block instead of the
  closure's merge block.
- The LSP ate the first two characters of every diagnostic after the message
  separator narrowed.

### Removed
- The `scheduler` orb and the async orb's timer-queue block. All of it was the
  pre-task workaround; nothing used it once real tasks landed.

## [0.1.0] - 2026-07-28

First public release. A self-hosting compiler, the `orbit` project tool, a
standard library of orbs, a Language Server, and the Field Guide with every
sample compiled in CI.

Green on Linux and Windows: a bare-checkout bootstrap from the committed seed,
a 151-program suite, a negative suite, and a feature-combination matrix.

Known gaps at the time: `push` copied, resumable effects were Windows-only, and
the macOS paths were written but untested.

[0.1.0]: https://github.com/Lone-Lodge/orion/releases/tag/v0.1.0
