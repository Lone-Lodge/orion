# Orion

[På svenska](README.sv.md)

A small, indentation-structured language that compiles to LLVM IR and then to a
native binary. No null, no exceptions, no garbage collector: allocation goes
through an arena the compiler checks for balanced scopes before anything runs.
The compiler is written in Orion and compiles itself.

```python
define main() -> number:
    name = "world"
    print_line("hello {name}")
    0
```

**[Field Guide](https://lone-lodge.github.io/orion/)** - the whole language on
one page, in ten minutes, every sample runnable in the browser.
**[Library reference](https://lone-lodge.github.io/orion/reference.html)** -
every orb and every function it exports, generated from the source so it cannot
drift. Both are plain HTML in [docs/](docs/) as well: open the file, no server
and no network needed.

## Build

You need `clang`. Nothing else - no Rust, no Node, no package manager.

```sh
bash tools/bootstrap.sh
```

From a bare checkout to a working toolchain: the checked-in seed IR builds a
first compiler, that compiler rebuilds itself to a fixpoint, `orbit` is built,
and the smoke suite runs.

```sh
orbit run hello.or      # compile, link, run
orbit build hello.or    # leaves ./hello beside the source
orbit new myapp         # a project; run / build / test work inside it
```

No project file, no output path to name, no clang line to write.

## Check

| gate | what it proves |
|---|---|
| `tools/seed_check.sh` | the committed seed still builds the compiler, so a fresh clone can bootstrap |
| `tools/test.sh` | 228 smoke tests, one feature each |
| `tools/project_test.sh` | the gates that need a project: the deterministic certificate, orb visibility |
| `tools/negative_test.sh` | 37 programs that must be *rejected*, with the right message |
| `tools/combo_test.sh` | every pair of features used together |
| `tools/demos_smoke.sh` | the 23 demo programs still run |
| `tools/docs_check.sh` | every code sample in the Field Guide compiles |
| `tools/wasm_conformance.sh` | the wasm backend does not regress |
| `tools/lsp_test.sh` | the editor server answers the way an editor asks |
| `tools/region_shrink_test.sh` | the arena gives memory back and does not thrash |
| `tools/compile_bench.sh` | how fast the compiler runs |
| `tools/runtime_bench.sh` | how fast the code it emits runs |

CI runs all of them on Linux, Windows and macOS, from a checkout with no binary
on disk. It is manual: run it from the Actions tab, because a push does not need
a runner to repeat what these already said.

## WebAssembly

An output path ending in `.wasm` uses the wasm backend instead of LLVM:

```sh
orion prog.or prog.wasm orbs
```

The module is self-contained: the host provides capabilities (draw, input,
`print`), never data-structure semantics. `node tools/playground.js` serves the
Field Guide with every sample runnable in the browser.

It is a secondary backend, not a mirror of the native one. The smoke suite run
through wasm gets the right answer on 164 of 228; the rest use a feature it does
not have. CI gates against regression, not against 100%. The async scheduler
(`spawn`/`await` with parked tasks) needs real stack switching and stays native.

## Layout

```
orbs/       the libraries, and the compiler itself (lex, parse, ir, emit, wasm)
runtime/    the C runtime the emitted code links against
vendor/     third-party C an orb links against: sqlite, whisper.cpp
tools/      bootstrap, test harnesses, benches, the LSP, orbit, the playground
tests/      the smoke suite, the negatives, and the gates that need a project
examples/   demos, drivers, the wasm gallery
docs/       the Field Guide, the library reference, the syntax, how to port Orion
```

## Status

v0.1. Self-hosting, green on Linux, Windows and macOS. The same source emits the
same IR on either host.

Known gaps:

- **`x = push(x, v)` copies** when the compiler cannot prove `x` is uniquely
  owned. The common `mut x = []` build-in-a-loop is proven and pushes in place;
  a list that is aliased, stored or captured stays a copy. `push_mut` is the
  way out.
- **Multi-shot effects are experimental.** One-shot (`perform` / `handle` /
  `resume`) is the supported core and works everywhere. `ask` / `resume_with`
  runs on Windows fibers only; elsewhere `resumable_ok()` reports 0 and `ask`
  refuses rather than pretending.
- **Interactive terminal input** works on Windows and through a pipe anywhere.
  On a POSIX TTY, `orion_console_readline` returns nothing.

## License

Apache 2.0. Copyright 2026 Lone Lodge. See [LICENSE](LICENSE) and
[NOTICE](NOTICE).
