# Orion

A small, indentation-structured language that compiles to LLVM IR and then to a
native binary. No null, no exceptions; memory comes from scoped regions that
are checked for balance before anything runs. The compiler is written in Orion
and compiles itself.

**[Read the Field Guide](https://lone-lodge.github.io/orion/)** — everything you
need to write Orion, on one page, in ten minutes.
([svenska](https://lone-lodge.github.io/orion/sv.html))

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
is built, and the smoke suite runs. Verified on Linux and Windows by CI on
every push. The macOS paths are written but have never been run anywhere, so
treat them as untested rather than supported.

Then compile a program:

```sh
dist/orion.exe hello.or hello.ll orbs
clang hello.ll runtime/orion_rt.c -o hello
```

For anything larger than one file, use the project tool: `orbit new myapp`,
then `orbit run`, `orbit build`, `orbit test`.

## Check it

Every gate the repo owns, and what each one is for:

| | |
|---|---|
| `tools/seed_check.sh` | the committed seed can still build the compiler, so a fresh clone can bootstrap |
| `tools/test.sh` | 151 smoke tests, one feature each |
| `tools/negative_test.sh` | 23 programs that must be *rejected*, with the right message |
| `tools/combo_test.sh` | 66 pairs of features used together |
| `tools/demos_smoke.sh` | the 21 demo programs still run |
| `tools/docs_check.sh` | every code sample in the Field Guide compiles |
| `tools/lsp_test.sh` | the editor server answers the way an editor asks |
| `tools/region_shrink_test.sh` | the arena gives memory back and does not thrash |
| `tools/compile_bench.sh` | how fast the compiler runs |
| `tools/runtime_bench.sh` | how fast the code it emits runs |

CI runs all of them on Linux and Windows, starting from a checkout with no
binary on disk.

## Layout

```
orbs/       the libraries, and the compiler itself (lex, parse, ir, emit)
runtime/    the C runtime the emitted code links against
tools/      bootstrap, test harnesses, benches, the LSP, orbit
examples/   demos, the test suite
docs/       the Field Guide
```

## Status

v0.1. Self-hosting, green on Linux and Windows, reproducible: the same source
emits the same IR on either host.

Known gaps, stated plainly rather than left to be discovered:

- `x = push(x, v)` copies, so building a list in a loop is quadratic. Use
  `push_mut` for a hot accumulator. Making the copy elidable in general needs a
  uniqueness analysis, which is the next real piece of language work.
- Effects that resume (`ask` / `resume_with`) use Windows fibers. Elsewhere
  `resumable_ok()` reports 0 and `ask` refuses rather than pretending.
- Interactive terminal input (`orion_console_readline`) works on Windows and
  through a pipe anywhere; on a POSIX TTY it returns nothing.
