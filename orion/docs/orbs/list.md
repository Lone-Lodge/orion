# orb `list`

list — everyday integer-list helpers that don't need a closure.
(For map / filter / reduce and friends, see the `iter` orb.)

  range(4)              ->  [0, 1, 2, 3]
  reversed([1, 2, 3])   ->  [3, 2, 1]
  includes([1, 2], 2)   ->  1
  find([5, 6], 6)       ->  1  (index, or -1)
  first([9, 8])         ->  9
  last([9, 8])          ->  8

## Public functions

### `pub fn range(n: int) -> [int]`

  range(4)              ->  [0, 1, 2, 3]
  reversed([1, 2, 3])   ->  [3, 2, 1]
  includes([1, 2], 2)   ->  1
  find([5, 6], 6)       ->  1  (index, or -1)
  first([9, 8])         ->  9
  last([9, 8])          ->  8
[0, 1, …, n-1]. Empty for n <= 0.

### `pub fn reversed(xs: [int]) -> [int]`

A new list with the elements in reverse order.

### `pub fn includes(xs: [int], v: int) -> int`

1 if `v` appears in `xs`, else 0. (Named `includes` to avoid the built-in
`contains`, which is text-substring only.)

### `pub fn find(xs: [int], v: int) -> int`

First index of `v`, or -1 if absent.

### `pub fn first(xs: [int]) -> int`

First / last element, or 0 for an empty list.

### `pub fn last(xs: [int]) -> int`


### `pub fn max_of(xs: [int]) -> int`

(Summation lives in the `iter` orb: `sum(xs)`.)
Largest / smallest element, or 0 for an empty list. (Named *_of to avoid
num's two-argument max / min.)

### `pub fn min_of(xs: [int]) -> int`


### `pub fn avg(xs: [int]) -> int`

Integer average (sum / count), truncated. 0 for an empty list.

