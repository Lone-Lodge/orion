# orion_emit_llvm

The backend: typed IR (`orion_ir`) in, LLVM IR text out.

```
orion_ir -> orion_emit_llvm -> .ll -> clang -> .exe
```

It always emits a Windows target triple; POSIX hosts retarget the module header
before clang links.

## Watch out for

This is the last stage, so an IR op it has no lowering for is a compile ERROR,
not a silently wrong module. Keep it that way - a backend that shrugs at an
unknown op produces a binary nobody checked.
