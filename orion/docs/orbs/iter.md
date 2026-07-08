# orb `iter`

iter — functional list operations, powered by closures.

Generic over the element type `T`: map / filter / reduce / … work on a
list of ANY type — `[int]`, `[Text]`, `[[int]]`, structs. The closure
names the element type so its body can use `len` / `at` / `get`:

  doubled = map([1, 2, 3], fn(x): x * 2)              # int, no annotation
  lengths = map(words,     fn(s: Text): len(s))       # Text — annotate `s`
  evens   = filter(xs,     fn(x): if x % 2 == 0 then 1 else 0)
  total   = reduce(xs, 0,  fn(acc, x): acc + x)        # sum

`int` elements need no annotation (the default); non-int elements do.
Predicates return 1 (keep / true) or 0 (drop / false).

## Public functions

### `pub fn map<T>(xs: [T], f: fn) -> [int]`

`int` elements need no annotation (the default); non-int elements do.
Predicates return 1 (keep / true) or 0 (drop / false).
Apply `f` to every element, collecting the results.

### `pub fn filter<T>(xs: [T], pred: fn) -> [T]`

Keep the elements for which `pred(x)` is 1. Result keeps the element type.

### `pub fn reduce<T>(xs: [T], init: int, f: fn) -> int`

Fold left: acc starts at `init`, then acc = f(acc, x) for each element.

### `pub fn any<T>(xs: [T], pred: fn) -> int`

1 if `pred(x)` is 1 for at least one element, else 0.

### `pub fn all<T>(xs: [T], pred: fn) -> int`

1 if `pred(x)` is 1 for every element (vacuously 1 for an empty list).

### `pub fn find_index<T>(xs: [T], pred: fn) -> int`

Index of the first element where `pred(x)` is 1, or -1 if none match.

### `pub fn count<T>(xs: [T], pred: fn) -> int`

How many elements satisfy `pred`.

### `pub fn sum(xs: [int]) -> int`

Sum of every element (0 for an empty list). No closure — the workhorse
`reduce(xs, 0, fn(a, b): a + b)` written once.

### `pub fn max_by(xs: [int], key: fn) -> int`

The element with the largest `key(x)`. Ties keep the earlier element.
Returns 0 for an empty list.

### `pub fn min_by(xs: [int], key: fn) -> int`

The element with the smallest `key(x)`. Ties keep the earlier element.
Returns 0 for an empty list.

### `pub fn sort_by(xs: [int], less: fn) -> [int]`

Return a new list ordered so that `less(a, b) == 1` means `a` comes first.
Stable selection sort — small lists, clarity over speed.
  sorted   = sort_by(xs, fn(a, b): if a < b then 1 else 0)   # ascending
  by_score = sort_by(ps, fn(a, b): if score(a) > score(b) then 1 else 0)

