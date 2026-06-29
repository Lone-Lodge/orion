# Orion

A next-gen, intent-driven, data-oriented systems language — and a working compiler
for it, written in Rust. See [`ORION.md`](ORION.md) for the full language design.

> Status: **working v1.** Lexer → parser → checker → tree-walking interpreter →
> two native backends (JIT + AOT object) → parallel ECS → SIMD/AoSoA codegen.
> ~5800 lines of Rust, 50+ tests, **no LLVM**.

## Quick start

```sh
cargo run --bin orion -- run   examples/m2.or fib 10        # interpret a function
cargo run --bin orion -- jit   examples/m4.or fib 30        # JIT to native, run it
cargo run --bin orion -- aot   examples/m4.or fib out.o     # AOT → native object file
cargo run --bin orion -- footprint examples/m5.or           # infer reads/writes + parallel batches
cargo run --bin orion -- simd  examples/m7.or integrate 5000000 0.016   # SIMD kernel
cargo test                                                  # the whole suite
```

`orbit` is the project tool (the Cargo-equivalent):

```sh
cargo run --bin orbit -- new spel       # scaffold a project
cargo run --bin orbit -- test           # run contract-bearing test_* functions
cargo run --bin orbit -- run add 2 3    # build + evaluate
```

## The pipeline (and where to read it)

| Stage | File | What it does |
|---|---|---|
| Lex | `src/lexer.rs`, `src/token.rs` | text → tokens (offside columns) |
| Parse | `src/parser/`, `src/ast.rs` | tokens → AST |
| Check | `src/check.rs` | scope, mutability (bind vs reassign), arity |
| Interpret | `src/interp.rs`, `src/value.rs` | run the AST directly |
| Store | `src/store.rs` | the relational entity world |
| JIT / AOT | `src/jit.rs`, `src/aot.rs` | Cranelift native codegen (shared, generic over `Module`) |
| Footprint | `src/footprint.rs` | infer reads/writes → parallel batches |
| Layout | `src/layout.rs`, `src/select.rs` | SoA/AoS/AoSoA decision (measured) |
| Parallel | `src/parallel.rs` | data-parallel ECS over SoA columns |
| SIMD / AoSoA | `src/simd.rs`, `src/aosoa.rs` | vectorised (F64X2) kernels |

## CLI commands (`orion <cmd> <file.or> …`)

`lex` · `parse` · `check` · `run <fn> [args]` · `jit <fn> [int args]` ·
`aot <fn> [out.o]` · `footprint` · `layout` · `select <system>` ·
`parbench <fn> <n>` · `parrun <system> <n>` · `simd <system> <n>` ·
`aosoa <system> <n>` · `gatherbench [n] [reads]`

## Honest performance findings

Real measurements, reported straight — including the ones that contradicted the
textbook:

- **JIT vs interpreter:** `fib(35)` ≈ **400× faster** native than tree-walked.
- **Thread parallelism:** JIT'd `fib` across cores ≈ **27×**.
- **SIMD (F64X2):** vectorised `integrate` ≈ **7×** over the interpreted scalar
  baseline (native + 2-lane SIMD combined).
- **AoSoA on streaming:** ~**3× slower** than SoA — sequential per-column streams
  prefetch better. (Textbook said AoSoA should help; it didn't here.)
- **AoS on random gather:** ~**20× slower** than SoA — the "AoS wins gather" rule
  also failed (likely SoA's independent read streams give more memory-level
  parallelism).

**Takeaway:** layout performance defies rules of thumb, which is exactly why the
compiler should *own and measure* the layout decision (`select::choose_measured`)
rather than the programmer hard-coding it in a `struct`. That is the core argument
for layout-polymorphism, validated by data.

## What's intentionally not done (honest boundaries)

- **LLVM backend** — possible but its own large project; not needed for native or
  standalone binaries (Cranelift covers those). Its value is max optimization and
  *automatic* vectorization of arbitrary code.
- **Gather kernels in the grammar**, **link `.o` → `.exe`**, **determinism-
  constrained codegen**, **richer type inference / error spans**, `match`, query
  `order`/`group`/aggregates. See `ORION.md` §19.
