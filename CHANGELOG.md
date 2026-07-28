# Changelog

Notable changes to Orion. The format follows
[Keep a Changelog](https://keepachangelog.com/), and versions follow
[Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-07-28

First public release.

Orion is a small, indentation-structured language that compiles through LLVM IR
to a native binary, with no null, no exceptions, and no garbage collector:
allocation goes through an arena whose scopes the compiler checks for balance
before anything runs. The compiler (lexer, parser, lowering, LLVM backend, and
driver) is written in Orion and rebuilds itself to a fixpoint; the only external
dependency is clang.

### Included
- The self-hosting compiler and the `orbit` project tool.
- A standard library of orbs (list, text, num, json, option, result, iter, and
  more) and a Language Server.
- The Field Guide: the whole language on one page, with every sample compiled in
  CI, so a documented feature that stops existing fails the build.

### Verified
- Green on Linux and Windows: a bare-checkout bootstrap from the committed seed,
  a 151-program suite, a negative suite, a feature-combination matrix, and a
  value gate that checks valid programs still answer correctly under changes
  that must not affect them.

### Known gaps
- `x = push(x, v)` copies, so building a list in a loop is quadratic; use
  `push_mut` for a hot accumulator until a uniqueness analysis makes the copy
  elidable.
- Resumable effects use Windows fibers; elsewhere they refuse rather than
  pretend.
- The macOS build paths are written but untested.

[0.1.0]: https://github.com/Lone-Lodge/orion/releases/tag/v0.1.0
