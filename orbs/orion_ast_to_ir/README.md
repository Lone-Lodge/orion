# orion_ast_to_ir

Lowering: the AST in, typed IR (`orion_ir`) out. The compiler's largest stage
at 8000 lines, and the one that does most of the thinking.

Names resolve here, types are checked here, and the desugarings run here as
ordered AST passes - const folding, `defer`, lambda lift - before the tree is
shaped into IR.

Diagnostics carry a source line, and a reported error stops output downstream:
a stage that produced a module after reporting an error would hand clang
something nobody had checked.

## Watch out for

`number` is resolved here, and it is resolved ONCE for the whole program. That
is the root of ISSUES.md F12: a function declared `-> list of number` is
compiled once, so a single call with a float locks it to f64 everywhere, and
every integer call then reads bits that are integers as if they were floats.
Nothing converts, because to this stage it is one type.

That is the largest open bug in the language, and this is the file it lives in.
