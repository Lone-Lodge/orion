# core

The two types every program is allowed to assume: `maybe T` is a value or
nothing, `result T` is a value or a message.

They live here rather than in `option` and `result` because the syntax
reference lists them among the types, next to `text` and `table` - and a type
you have to import first is not one of those.

```orion
define find(k: number) -> maybe number:
    if k > 0 then some(k * 10) else none

choose div(84, 2):
    ok(v)    then v
    error(m) then print_line(m)
```

`some` / `none` / `ok` / `error` are the spoken names; `Some` / `None` / `Ok` /
`Err` are what the variants are declared as, and both read. The spoken ones
resolve LAST, so a function of your own by that name keeps its meaning -
`file.ok(handle)` still asks whether a handle is open.

The FUNCTIONS over these types are still `use option` and `use result`. Only
the types are free, because only the types are what the surface calls core.
The two orbs share the name `unwrap_or`, and making both visible everywhere
would make that one name ambiguous in every program.

## Watch out for

The whole file is two declarations on purpose. Anything added here is added to
every program in the language.
