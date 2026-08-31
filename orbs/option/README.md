# option

`Option<T>` - a value, or nothing. A native generic sum type; the same idea as
`result` without the message. You cannot read the payload without saying what
the empty case does.

```orion
use option

define find(k: number) -> Option<number>:
    if k > 0 then Option.Some(k * 10) else Option.None

choose find(4):
    Some(v) then print_line("found {v}")
    None then print_line("not found")
```

Softer forms:

```orion
id = unwrap_or(find(0), 0)      # fallback value
if let Some(v) = find(4):       # only the present case
    print_line("{v}")
```

`?` propagates: `v = find(k)?` returns None out of the enclosing function when
there is nothing, and binds `v` otherwise.

## Watch out for

There is no `unwrap`, on purpose. Orion has no panic, so an `unwrap` could only
lie and hand back a zero. Use `choose`, `if let`, `?` or `unwrap_or`.
