# Orion

A small, self-hosting programming language with an LLVM backend — **Orion
compiles Orion**. The compiler is written in Orion, emits LLVM IR, and links to
a native binary via clang. It's deliberately KISS: one obvious way to do a
thing, no cryptic one-symbol operators, and a compiler that *fails loudly*
rather than miscompiling silently.

```orion
fn main() -> int:
    xs = [3, 4, 5]
    total = 0
    for x in xs:
        total = total + x
    total            # 12
```

## Quick start

The repo ships a committed seed (`tools/seed/orion.ll`), so you can build the
compiler from scratch with just clang — no prior binary needed:

```bash
bash tools/bootstrap_from_ll.sh     # seed .ll -> dist/orion.exe
bash tools/self_bootstrap.sh        # rebuild orion.exe with itself (fixpoint)
bash tools/build_orbit.sh           # build the project tool (dist/orbit.exe)
bash tools/test.sh                  # run the smoke suite (118 tests)
bash tools/demos_smoke.sh           # compile every examples/demos/*.or
```

Compile a single file:

```bash
dist/orion.exe path/to/prog.or out.ll     # emit LLVM IR (Windows triple)
# on POSIX, retarget the two header lines then clang out.ll runtime/orion_rt.c
```

## What it can do

Closures, generics (erasure), sum types with pattern matching, algebraic
effects with one-shot continuations, a small readable standard library,
compile-time and runtime safety checks, character literals, `move` (linear)
bindings, and **hot reload** (recompile gameplay code and swap it into a
running program — see `examples/hot_reload/`).

Full picture: **[docs/syntax.md](docs/syntax.md)** (the whole syntax on one
page) and **[docs/language_status.md](docs/language_status.md)** (what works,
what's missing — honestly).

## Repo layout

| Path | What |
|---|---|
| `orbs/` | The compiler, stage by stage (`orion_lex` → `orion_parse` → `orion_ir` → `orion_ast_to_ir` → `orion_emit_llvm` → `orion_driver`), plus the stdlib orbs (`text`, `num`, `list`, `dict`, `iter`, `option`, `result`, …). All pure Orion. |
| `examples/` | `demos/` (runnable programs), `tests/` (the smoke suite), `hot_reload/` (live-reload demo). |
| `tools/` | Build + bootstrap scripts, the `orbit` project tool, and `seed/orion.ll` (the committed bootstrap seed). |
| `runtime/` | The C runtime (`orion_rt.c`: alloc, text, lists, timing; `orion_cli.c`: process + fs). |
| `docs/` | Syntax, status, and the Swedish design specs (`*-svenska.md`). |

## How self-hosting works

`orion.exe` compiles its own bundle to a native binary; running the result on
the same source reproduces byte-identical IR (`stage1 == stage2` — the fixpoint
check in `tools/self_bootstrap.sh`). The compiler always emits a Windows target
triple; POSIX builds retarget the two module-header lines before clang. After a
codegen change, regenerate the seed so a fresh clone reproduces the new
compiler exactly:

```bash
bash tools/bundle_orbs.sh
dist/orion.exe dist/orion_self_bundled.or tools/seed/orion.ll
```
