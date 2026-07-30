# Changelog

Notable changes to Orion. The format follows
[Keep a Changelog](https://keepachangelog.com/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
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
- The **Field Guide playground** (`tools/playground.js`, `docs/playground.js`):
  a "Try Orion" editor plus a Run button on every sample, compiling to wasm and
  running in place. All 12 Field Guide samples run in the browser; a construct
  the wasm backend cannot lower (e.g. the parked-task scheduler) shows a clear
  "native only" note.
- `examples/wasm_demo/`: an Orion program compiled to wasm, animated on a canvas.

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
