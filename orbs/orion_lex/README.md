# orion_lex

The Orion lexer, written in Orion. Stage one of the pipeline: **lex** -> parse
-> lower -> emit.

Tokenizes `.or` source text into a list of token maps:

```orion
{"kind": text, "value": text, "line": number, "col": number}
```

## Token kinds

| kind | what it is |
|---|---|
| `ident` | names and keywords (keyword? is looked up later) |
| `int` | integer literal |
| `float` | float literal |
| `str` | string literal, escapes resolved, `\{` and `\}` kept raw |
| `symbol` | operator or punctuation; `value` is the operator text |
| `newline` | line break, one per consecutive run |
| `eof` | end of input |

## Watch out for

`value` is ALWAYS text. Number tokens encode their value as text to keep the
token type uniform, and the parser converts them.
