# dict

Friendly names for the map built-ins a newcomer reaches for. Nothing here is
new capability - `keys`, `length`, `has_key` and `values` are names for things
the language already does, put where somebody looking for them will find them.

```orion
keys(m)            # ["a", "b"]   map keys are text
length(m)          # 2
has_key(m, "a")    # 1
values(m)          # [1, 2]       int-valued maps
```

`has(m, k)` and `get_or(m, k, default)` are already built in and are not
repeated here.
