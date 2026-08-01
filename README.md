# Orion

A small, indentation-structured language that compiles to LLVM IR and then to a
native binary. No null, no exceptions, no garbage collector: allocation goes
through an arena the compiler checks for balanced scopes before anything runs.
You do not write regions yourself; there is no such keyword. The compiler is
written in Orion and compiles itself.

**[Read the Field Guide](docs/index.html)** — everything you need to write
Orion, on one page, in ten minutes. ([svenska](docs/sv.html))

It is a plain HTML page: clone and open `docs/index.html`, no server needed.
Not published yet — GitHub Pages needs the repository to be public, or the
organisation to be on a paid plan.

```
fn main() -> int:
    name = "world"
    print_line("hello {name}")
    0
```

## Build it

You need `clang`. Nothing else — no Rust, no Node, no package manager.

```sh
bash tools/bootstrap.sh
```

That goes from a bare checkout to a working toolchain: the checked-in seed IR
builds a first compiler, that compiler rebuilds itself to a fixpoint, `orbit`
is built, and the smoke suite runs. Verified on Linux, Windows and macOS by CI
on every push; macOS is the one leg that exercises the arm64/Mach-O retarget and
the tight main-thread stack. I do not develop on a Mac, so mac-only regressions
are caught by CI rather than hand-verified.

Then compile a program:

```sh
orbit run hello.or          # compile, link, run
orbit build hello.or        # leaves ./hello beside the source
```

No project file, no output path to name, no clang line to write. For something
larger, `orbit new myapp` scaffolds a project and the same `run`, `build` and
`test` work inside it.

## Check it

Every gate the repo owns, and what each one is for:

| | |
|---|---|
| `tools/seed_check.sh` | the committed seed can still build the compiler, so a fresh clone can bootstrap |
| `tools/test.sh` | 155 smoke tests, one feature each |
| `tools/negative_test.sh` | 26 programs that must be *rejected*, with the right message |
| `tools/combo_test.sh` | 66 pairs of features used together |
| `tools/demos_smoke.sh` | the 21 demo programs still run |
| `tools/docs_check.sh` | every code sample in the Field Guide compiles |
| `tools/wasm_conformance.sh` | the wasm backend does not regress (OK count holds, no unexpected wrong answers; known gaps allowlisted) |
| `tools/lsp_test.sh` | the editor server answers the way an editor asks |
| `tools/region_shrink_test.sh` | the arena gives memory back and does not thrash |
| `tools/compile_bench.sh` | how fast the compiler runs |
| `tools/runtime_bench.sh` | how fast the code it emits runs |

CI runs all of them on Linux, Windows and macOS, starting from a checkout with
no binary on disk.

## WebAssembly

Orion also compiles to WebAssembly, so Orion code can run in a browser. An
output path ending in `.wasm` uses the wasm backend instead of LLVM:

```
orion prog.or prog.wasm orbs
```

The `.wasm` is self-contained — the host (JavaScript) provides only capabilities
(draw, input, `print`), never data-structure semantics. `examples/wasm_demo/`
compiles a small program to wasm and animates it on a canvas.

The **Field Guide playground** makes every sample runnable in the browser: run
`node tools/playground.js` and open `http://localhost:8100`. It compiles each
snippet to wasm on demand and runs it in place, with a "Try Orion" editor at the
top.

The wasm backend covers the core language: i32 and f64, structs, lists, maps,
tuples, sum types with pattern matching, `?`, closures, comprehensions, text and
interpolation, first-class functions, a `par_run` that reduces its workers in
order, one-shot algebraic effects (`perform`/`resume`), the full control flow,
and an in-browser IO sandbox. All 12 Field Guide samples run in the browser. The
async scheduler (`spawn`/`await` with parked tasks) needs real stack switching
and stays native.

It is a secondary backend, not a mirror of the native one: `tools/wasm_conformance.sh`
runs the whole smoke suite through wasm and currently gets the right answer on
131 of them, with the rest either using an unsupported feature or being a
must-fail runtime test that aborts. CI gates it against regression, not against
100%. One known gap: a "bytes" value is a `[int]` list natively but a packed
buffer in wasm, so code that builds bytes from computed ints (e.g. the `encoding`
orb) is native-verified and awaits a `bytes_from_ints` primitive for wasm.

## Layout

```
orbs/       the libraries, and the compiler itself (lex, parse, ir, emit, wasm)
runtime/    the C runtime the emitted code links against
tools/      bootstrap, test harnesses, benches, the LSP, orbit, the playground
examples/   demos (incl. wasm_demo), the test suite
docs/       the Field Guide (with an in-browser playground)
```

## Status

v0.1. Self-hosting, green on Linux and Windows, reproducible: the same source
emits the same IR on either host.

Known gaps, stated plainly rather than left to be discovered:

- `x = push(x, v)` copies. The compiler proves when `x` is uniquely owned and
  then pushes in place automatically, so the common `mut x = []` build-in-a-loop
  is linear with no annotation. When uniqueness cannot be proven (x is aliased,
  stored, or captured) it stays a copy; reach for `push_mut` there if the copy
  shows up in a profile.
- Effects come in two tiers. One-shot (`perform` / `handle` / `resume`, resume
  exactly once, synchronously) is the supported core and works everywhere.
  Multi-shot (`ask` / `resume_with`, a handler that outlives its own resume) is
  **experimental**: it is the same machinery async needs, and it runs on Windows
  fibers. Elsewhere `resumable_ok()` reports 0 and `ask` refuses rather than
  pretending. Do not build on it until it is cross-platform.
- Interactive terminal input (`orion_console_readline`) works on Windows and
  through a pipe anywhere; on a POSIX TTY it returns nothing.

## License

Orion is licensed under the Apache License, Version 2.0. Copyright 2026 Lone
Lodge. See [LICENSE](LICENSE) for the full text and [NOTICE](NOTICE) for
attribution.
