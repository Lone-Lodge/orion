# Known compiler bugs (not yet fixed)

These were found by the auto-coverage smoke. Add expected-fail tests once
we have an xfail framework.

## ~~Match as expression — broken~~ FIXED 2026-06-28

Extracted `psr_parse_match_node` into a shared helper and wired it into
`psr_parse_primary` so `match` can be used in expression position too:

```orion
result = match scrut:
    1 -> "one"
    _ -> "other"
```

## ~~Match with int patterns, text branches~~ FIXED 2026-06-28

Fixed via the flat-dispatch refactor in `ast_match_to_ir` (orion_ast_to_ir
lines 1043+). The deeply nested `if is_wildcard: ... else: if pat_kind: ...`
hit the nesting bug — replaced with phased boolean-flag dispatch.

## Arithmetic in interpolation

```orion
sum = "{x + y}"  # captures `x + y` as a single ident name
```

Not supported. Workaround: bind to a temp first.

Root: `psr_interpolate_str` only handles ident, field, single-level call. To
support arithmetic would need re-lexing+parsing inside `{...}`. Low priority
since temp-var workaround is fine.
