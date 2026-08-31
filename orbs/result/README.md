# result

`Result<T>` - a value, or an error message. A native generic sum type. The
point is that you cannot look at the value without saying what happens in the
error case: `choose` is exhaustive, so the compiler makes you follow up.

```orion
use result

define safe_div(a: number, b: number) -> Result<number>:
    if b is 0 then Result.Err("divide by zero") else Result.Ok(a / b)

choose safe_div(10, 0):
    Ok(v) then print_line("got {v}")
    Err(m) then print_line("error: {m}")
```

Softer forms when you do not want to branch by hand:

```orion
n = unwrap_or(safe_div(10, 0), 0 - 1)   # fallback value
if let Ok(v) = safe_div(10, 2):         # only the happy path
    print_line("{v}")
```

`?` propagates: `v = safe_div(a, b)?` returns the Err out of the enclosing
function and binds `v` to the Ok payload otherwise.

## Watch out for

There is deliberately no `unwrap`. Orion has no panic, so it could only lie and
hand back a zero. Use `choose`, `if let`, `?` or `unwrap_or`.
