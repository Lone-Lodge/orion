# orion_fmt

The conservative whitespace formatter, shared by `orbit fmt` and the language
server's `textDocument/formatting` - the editor's format key. One entry point:

```orion
fmt_normalize(source)
```

What it does, and nothing else: tabs become four spaces, trailing whitespace is
stripped, runs of blank lines collapse to one, and the file ends with exactly
one newline.

## Watch out for

It deliberately does not rewrite expressions or re-indent blocks. A formatter
that did would need the lexer and the parser, and would then be able to change
what a program MEANS. This one cannot, which is why it is safe to bind to a
key that fires on every save.
