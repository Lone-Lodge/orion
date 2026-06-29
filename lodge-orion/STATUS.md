# lodge-orion — reference implementation

**Status:** Reference / bootstrap. The active codebase is **`../orion-self/`**.

## What this is

The original Rust-implemented Orion compiler + interpreter + JIT. It bootstrapped Orion itself — `orion-self/` is now a self-hosted compiler that produces a native `orion.exe` (~289KB) that compiles real Orion programs.

## Why kept

This crate still powers `orbit` — the test-runner CLI used by `tools/test.sh`, the bundler that produces `orion.exe`, and the runtime that hosts orbs like `net`. Removing it before `orion.exe` is fully standalone would break the bootstrap chain.

## When this goes away

When `orion.exe` can:
- Compile its own orb bundles (no Rust)
- Provide all stdlib runtimes (net, fs, gpu, etc.) natively
- Run `orbit test` and `orbit run` end-to-end

Track progress in [task #151](../orion-self/MEMORY.md).

## What to use instead

- New language features → add to `orion-self/orbs/orion_lex/`, `orion_parse/`, `orion_ast_to_ir/`, `orion_emit_llvm/`
- New stdlib orbs → `orion-self/orbs/<name>/`
- Bug fixes in core compile flow → `orion-self/`

Lodge-orion only takes patches that unblock the bootstrap chain or fix tooling.
