# iter

Functional list operations, powered by closures. Generic over the element type:
`each` / `keep` / `combine` and friends work on a list of ANY type - `[int]`,
`[text]`, `[[int]]`, structs.

```orion
doubled = each([1, 2, 3], (x): x * 2)                   # int, no annotation
lengths = each(words, function(s: text): length(s))     # text, annotate `s`
evens   = keep(xs, (x): x % 2 is 0)
total   = combine(xs, 0, (acc, x): acc + x)             # sum
```

The split against `list` is exactly this: if it takes a function, it is here.
If it does not, it is there.

## Watch out for

`int` elements need no annotation - that is the default - but non-int elements
do, because the closure's parameter type is what lets its body use `len` / `at`
/ `get`. Predicates answer 1 to keep and 0 to drop.
