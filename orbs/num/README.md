# num

The small integer helpers every program reaches for.

```orion
abs(-3)            # 3
min(4, 9)          # 4
max(4, 9)          # 9
clamp(12, 0, 10)   # 10
sign(-5)           # -1
```

For floats, the language already gives you f64 arithmetic and the math
builtins - `sqrt sin cos tan exp log log2 floor ceil round atan2 pow` - with no
import at all. This orb adds what those leave out: the real constants `pi` and
`e`, the four above lifted to floats, and `parse_float`, because the int-only
`parse` cannot read a decimal.
