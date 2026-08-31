# list

Everyday integer-list helpers that do not need a closure. For `map` / `filter`
/ `reduce` and friends, see the `iter` orb - the split is exactly that: if it
takes a function, it belongs there.

```orion
range(4)              # [0, 1, 2, 3]
reversed([1, 2, 3])   # [3, 2, 1]
includes([1, 2], 2)   # 1
find([5, 6], 6)       # 1, the index, or -1
first([9, 8])         # 9
last([9, 8])          # 8
filled(4, 0)          # [0, 0, 0, 0]
```

Also here: `max_of`, `min_of`, `avg`, `concat`, `unique`, `take`, `drop`.

## Watch out for

`filled(n, value)` is where the compiler's worst open bug shows up. It is
declared `-> list of number` and compiled ONCE for the whole program, so a
single call with a float locks it to f64 everywhere - and every integer call
then gets a list whose bits are integers and whose reads believe they are
floats. See F12 in `arkitektur/ISSUES.md`. Until that is fixed, do not mix
`filled(n, 0)` and `filled(n, 0.0)` in one program.
