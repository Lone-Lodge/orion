# orion_ast_to_wasm

AST to wasm codegen - the second backend.

Walks the AST produced by `orion_parse::self_parse` and emits wasm bytes via
the `orion_emit_wasm` builder API. Each `Fn` decl becomes a `WFn`; the body's
statements and expressions are linearised into a stack-machine instruction
sequence.

## Why it matters more than a second target usually does

It shares no code with the LLVM path below the language, which is what makes
the determinism proof mean anything: `rigel/tools/replaycheck.sh` and
`driftcheck.sh` run the same simulation on both and compare. Two backends that
agree by construction would prove nothing.

## Scope today

i32 arithmetic, local vars (params and bindings), if/else blocks, loops,
function calls.

No strings - those need linear memory allocation - no closures, no traits.
Those layers come once the core arithmetic pipeline runs orion-self's own
files.
