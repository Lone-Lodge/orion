# orion_driver

The self-hosted driver - the top of the graph, and the program the rest of the
compiler is a library to.

```
orion_self <input.or> [output.ll] [orb-root...]
```

## Multi-orb

It scans the entry file for `use NAME` lines, resolves each name to an orb
source (`NAME/lib.or` under a set of search roots), recursively discovers that
orb's own uses, and compiles everything as one program. That replaced
`tools/bundle_orbs.sh`: no bash, one command builds a whole dependency graph.

Resolution roots, first hit wins:

```
any extra argv paths
<entry-dir>/orbs/
<entry-dir>/../orbs/
<entry-dir>/../../orbs/
orbs/
../orbs/
```

Unresolved names print a note and are skipped, because builtins - bytes, io,
fs and friends - live in the compiler and not in orb files.

## Watch out for

Declaration order does not matter: `ast_program_to_ir` collects all signatures
before lowering any body, so orbs concatenate in discovery order with the entry
last.

Fail-fast: any `compile_error()` during lowering or emit means no output and a
non-zero exit.
