# orion_parse

The parser: tokens in, an AST out. Stage two of the pipeline: lex -> **parse**
-> lower -> emit.

Recursive descent, one pass, and each node is tagged with a source line so
diagnostics downstream can point at something.
