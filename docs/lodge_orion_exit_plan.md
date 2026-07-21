# Lodge-orion exit — DONE (for the compiler/language)

## Outcome

The Orion **compiler and language no longer depend on lodge-orion**. The
Rust interpreter has been removed from the tree (recoverable from git
history). Proven end-to-end: with `lodge-orion/` physically deleted, the
full chain still works —

```
tools/bootstrap_from_ll.sh   # seed IR → dist/orion.exe (clang only)
tools/self_bootstrap.sh      # orion.exe rebuilds itself → fixpoint (stage1 == stage2)
```

Everything the compiler needs — `print_line`, `len`, `at`, `push`, `get`,
`set`, `bytes_*`, `read_file`/`write_file`, `run_command`, timing — is
provided natively by `runtime/orion_rt.c` + `runtime/orion_cli.c` and
emitted through the LLVM path. All 93 tests pass on a self-built compiler.

## Why the old plan is obsolete

The original plan (below, kept for the record) targeted a Cranelift-based
`orion link` **inside lodge-orion** that failed at "cannot call print". That
whole path was superseded: the compiler is now self-hosted and emits LLVM IR
→ clang → native PE. The "missing builtins" gap it described (Tier 1/2) is
closed in the LLVM runtime.

## What is NOT part of this (separate concern)

The downstream **graphics/audio runtime** for the game projects
(atlas / cubsy — `window_*`, `gpu_*`, `audio_*`, "Tier 3") lives in their own
repos and is tracked there. Freeing those products from the interpreter is
independent of the compiler being self-hosted, which it now is.

---

## Original recon (archived)

Goal was: move atlas/cubsy/astra runtime from lodge-orion to `orion link`,
then move lodge-orion to legacy. First failure was
`orion link hello.or main hello.exe → codegen: cannot call print`, because
the old Cranelift native codegen never populated stdlib builtins. Estimated
at 3-4 focused weeks across Tiers 1-4. Superseded by the LLVM self-hosting
architecture; the compiler half is complete.
