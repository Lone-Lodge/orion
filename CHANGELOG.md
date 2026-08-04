# Changelog

Notable changes to Orion. The format follows
[Keep a Changelog](https://keepachangelog.com/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Removed
- The `scheduler` orb and the async orb's deadline/timer-queue block
  (sleep_until, delay, deadline_from_now, past_deadline, time_left,
  timers_new/add_timer/next_due/count_due/wait_next). All of it was the
  pre-task workaround; nothing used any of it once real tasks landed. The
  scheduler orb is archived under _archive/orbs/.

### Fixed
- **A local binding now shadows a same-named const.** Const inlining used
  to substitute num's `e` (2.718...) into any body with its own `e`, so
  `e = e + 1` failed with "cannot reassign: int vs float". The pass now
  skips names a fn binds itself (parameters, bindings, loop variables).
- The LSP's diagnostic parser kept a byte offset sized for the old wide
  dash after the message separator narrowed; the first two characters of
  every diagnostic were eaten.

### Added
- **Debugger v1**: `orbit debug prog.or` runs with a call trail - every
  define's entry is recorded (last 64 kept) and a crash, a `require`/index
  trap, or a `breakpoint()` placed in the source prints them newest-first.
  `breakpoint()` names its enclosing function and pauses on a terminal
  (Enter continues, q quits); piped, it reports and continues, so a
  forgotten one never hangs a gate. The instrumentation is opt-in
  (`--trace` at the compiler level): a plain build pays nothing.
- **A file watcher**: `orbit run tools/orbwatch.or main <dir> <command>`
  reruns the command whenever a source file under `<dir>` changes, and a
  change DURING a run stops the stale run and starts a fresh one (built on
  `stop_command`). The mechanics live in the new `watch` orb (`scan_tree` /
  `snapshot` / `first_change`) so they are test-proven. New primitives it
  drove out: `modified_at(path)` in `os` (there was no mtime), and
  `int_from_text` in `text` (there was no public text-to-int).
- **Child processes the scheduler can wait on** (`os` orb):
  `start_command` / `start_command_to_file` begin a command and return a job
  id at once; `finished_within` parks the calling TASK until the child exits
  or a deadline passes (the same bargain as the net orb's `readable_within`,
  one level up); `command_result` reaps the exit code once; `stop_command`
  kills a job that blew its deadline; `cpu_count()` sizes a worker pool.
  Children are real OS processes, so they run in parallel while the
  single-threaded scheduler coordinates the waiting. Proven by the test
  runner itself: it now links and runs every test through one worker task
  per hardware thread - the suite's ~79 s of serial compile became a
  ~17 s total wall.
- **Traits as explicit dictionaries.** A struct whose fields are functions is a
  dictionary of operations, and `o.method(args)` now calls the fn-typed field
  `method` on the struct value `o` (instead of desugaring to a UFCS global
  `method(o, args)`). So a comparator, a printer, an `Ord` - any bundle of
  behavior - is a plain struct value you build and pass by hand, with no
  implicit resolution: you can always see which dictionary is passed. Builds on
  typed function values.
- A **WebAssembly backend**: `orion prog.or prog.wasm orbs` compiles to a
  self-contained `.wasm` module. The host (JS) supplies capabilities via
  `extern fn` imports; Orion owns its memory (a bump allocator in linear
  memory). Covered: i32 and f64 (scalars, mixed structs, lists), maps, tuples,
  sum types with pattern matching, `?`, non-capturing closures, list
  comprehensions, `require`/`defer`, text with interpolation, `print_line`,
  first-class functions (`call_indirect`), a `par_run` that reduces its workers
  in order, one-shot algebraic effects (`perform`/`resume`/`handle`, compiled to
  a handler call and a `return`), and a stubbed OS-IO sandbox. The async
  scheduler (`spawn`/`await` with parked tasks) stays native (a browser has no
  stack switching).
- A **WebAssembly conformance gate** (`tools/wasm_conformance.sh`): compiles
  every smoke test through the wasm backend, runs it in node, and compares the
  answer to the native expectation, reporting OK / MISMATCH / UNSUPPORTED /
  TRAP / HANG. It turned "the 12 Field Guide samples run" into a measured
  131-of-160, now wired into CI as a regression gate (the OK count must hold and
  there must be no unexpected wrong answer; known gaps are allowlisted). It drove
  the backend past the old number: correct match dispatch
  (int/text/binding/guard patterns) and text equality, the C-like vs boxed enum
  distinction, void `if let` / `loop let`, `break` inside a match, `const`
  inlining, environment-capturing closures, higher-order calls via
  `call_indirect`, maps read/write/`has`, `contains`/`index_of`/`slice`, the
  `bytes_*` family, struct spread, and a signed-LEB encoder fix. What stays
  native: the async scheduler and real threads (no browser stack-switch or
  thread model) and the compiler's own `slot_*` state. (i64 values are
  supported in wasm; addressing is i32.)
- The **Field Guide playground** (`tools/playground.js`, `docs/playground.js`):
  a "Try Orion" editor plus a Run button on every sample, compiling to wasm and
  running in place. All 12 Field Guide samples run in the browser; a construct
  the wasm backend cannot lower (e.g. the parked-task scheduler) shows a clear
  "native only" note.
- `examples/wasm_demo/`: an Orion program compiled to wasm, animated on a canvas.
- A **library reference page** (`docs/reference.html`, generated by
  `tools/orb_reference.sh`): every `pub fn` and exported type in `orbs/`, taken
  from the source so it cannot drift. `tools/docs_check.sh` regenerates it and
  fails if the committed page is stale.

### Changed
- A `fn(A, B) -> R` **parameter now carries its signature**. A call through it
  with the wrong number of arguments is a compile error (instead of silently
  ignoring extras or reading past the given ones), and each argument's shape is
  checked against the declared parameter type with the same conservative rule as
  a direct call (a concrete pointer kind passed where a different one is
  declared fails; i64/generic wildcards are skipped so erased values never
  false-positive). The checker records the signature in `ast_fn_to_ir`, stamped
  per fn so a same-named param elsewhere never matches. The declared **return
  type is propagated** through the call too, normalized to its storage class
  (pointer / f64 / i64), so `f(x)` on a `fn(int) -> Text` or `fn(int) -> [int]`
  or `fn(int) -> f64` yields that type instead of collapsing to i64 - function
  values are now typed end to end.
- `result` and `option` are **native generic sum types**, not struct
  conventions: `Result<T>: Ok(T) | Err(Text)` and `Option<T>: Some(T) | None`.
  They work across an orb boundary, carry any payload type (`Result<Text>`),
  are read by an exhaustiveness-checked `match` or `if let`, and propagate with
  `?`. `unwrap_or` now takes and returns `T` instead of `int`.
  The lying `unwrap` (which handed back a zero on the error case) is **gone** -
  Orion has no panic, so it could not be written honestly. Use `match`,
  `if let`, `?` or `unwrap_or`.
- Effects are documented in two tiers: one-shot (`perform` / `handle` /
  `resume`) is the supported core and runs everywhere; multi-shot (`ask` /
  `resume_with`) is marked **experimental** - it is the machinery async needs
  and currently rides on Windows fibers.
- A collecting `loop` now takes an **indented body**, under one rule that spans
  one-liner and block: the body's trailing expression is collected (the same
  "last value is the value" every block uses), and `yield expr` collects
  additional values mid-body. So `loop x in xs:` then `if x > 2: yield x` is the
  filter, a block that ends in a bare expression collects it, and computing
  intermediates or yielding more than once per step are both fine. Collecting
  loops nest (each owns its accumulator). The `where` filter clause is
  **removed**; `if ...: yield` replaces it.

### Fixed
- A **closure call inside a short-circuit `and`/`or`** (or any branch tail)
  generated invalid LLVM ("instruction does not dominate all uses"). A
  `closure_call` is one IR instruction that expands into several LLVM blocks at
  emit time, and the phi-predecessor tracking named the branch's entry block
  instead of the closure's merge block. `if valid(x) and o.check(y)` and similar
  now compile. Pre-existing; surfaced by trait-dictionary method calls.

## [0.1.0] - 2026-07-28

First public release.

Orion is a small, indentation-structured language that compiles through LLVM IR
to a native binary, with no null, no exceptions, and no garbage collector:
allocation goes through an arena whose scopes the compiler checks for balance
before anything runs. The compiler (lexer, parser, lowering, LLVM backend, and
driver) is written in Orion and rebuilds itself to a fixpoint; the only external
dependency is clang.

### Included
- The self-hosting compiler and the `orbit` project tool.
- A standard library of orbs (list, text, num, json, option, result, iter, and
  more) and a Language Server.
- The Field Guide: the whole language on one page, with every sample compiled in
  CI, so a documented feature that stops existing fails the build.

### Verified
- Green on Linux and Windows: a bare-checkout bootstrap from the committed seed,
  a 151-program suite, a negative suite, a feature-combination matrix, and a
  value gate that checks valid programs still answer correctly under changes
  that must not affect them.

### Known gaps
- `x = push(x, v)` copies, so building a list in a loop is quadratic; use
  `push_mut` for a hot accumulator until a uniqueness analysis makes the copy
  elidable.
- Resumable effects use Windows fibers; elsewhere they refuse rather than
  pretend.
- The macOS build paths are written but untested.

[0.1.0]: https://github.com/Lone-Lodge/orion/releases/tag/v0.1.0
