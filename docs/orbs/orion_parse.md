# orb `orion_parse`

orion_self_parse — Orion parser written in Orion. STEP 4 PROOF.

Consumes the token list produced by `self_lex` and produces an AST as
a Map tree. This is a *proof of concept* — it parses fn declarations
with typed params, return types, and tail-expression bodies. The full
Orion grammar (data decls, if/else, for/loop, mut, multi-statement
bodies, generics, ownership annotations) is another ~800 lines of
similar machinery.

AST shape this proof emits:
  { "kind": "Program", "decls": [<Fn>...] }
  Fn:    { "kind": "Fn", "name": Text, "params": [Param], "ret": Type, "body": Expr }
  Param: { "name": Text, "type": Type }
  Type:  { "kind": "Named", "name": Text }
        | { "kind": "List", "elem": Type }
  Expr:  { "kind": "Ident",  "name": Text }
        | { "kind": "Int",    "value": Text }
        | { "kind": "Binary", "op": Text, "left": Expr, "right": Expr }
        | { "kind": "Call",   "callee": Text, "args": [Expr] }

Cursor positions are passed through every helper as a plain int — Orion
doesn't have references so we return a new cursor in a {"node": …,
"next": …} pair (same pattern as the lexer's scanners).

## Public functions

### `pub fn self_parse(tokens: [Map]) -> Map`


