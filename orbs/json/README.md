# json

Parse and build JSON. Written for the language server, which speaks JSON-RPC
over a pipe, but there is nothing LSP-specific in it.

Values map onto Orion's own dynamic shapes: an object is a `table`, an array is
a list, a string is `text`, a number and a bool are ints, null is 0. That is
exactly how the compiler's own AST is carried around, so nothing new is needed
to hold a parsed document.

## Performance is part of the contract

A `didChange` notification carries the WHOLE document, so a 100 KB file arrives
as one JSON string. Every scan here is single-pass and every string is cut with
one `bytes_slice`. The only byte-at-a-time path is unescaping, and it runs only
for strings that actually contain a backslash.

Building text with `result = result + one_byte` would be quadratic. If you edit
this orb, that is the mistake to not make.
