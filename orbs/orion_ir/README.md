# orion_ir

The typed IR for orion-self.

- **SSA form.** Each instruction PRODUCES exactly one value.
- Other instructions REFERENCE values by id, an index into the function's
  instruction list.
- **Typed.** Every value has a type: `i64`, `ptr`, `truth`, `void`.

Its place in the pipeline:

```
lex -> parse -> AST -> IR -> orion_emit_llvm -> .ll -> clang -> .exe
```
