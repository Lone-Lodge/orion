# orb `dict`

dict — friendly names for the map built-ins a newcomer reaches for.

  keys(m)            ->  ["a", "b"]      (map keys are text)
  size(m)            ->  2
  has_key(m, "a")    ->  1
  values(m)          ->  [1, 2]          (int-valued maps)

`has(m, k)` and `get_or(m, k, default)` are already built in.

## Public functions

### `pub fn keys(m: Map) -> [Text]`

`has(m, k)` and `get_or(m, k, default)` are already built in.
The keys of `m`, as a list of text.

### `pub fn size(m: Map) -> int`

Number of entries.

### `pub fn has_key(m: Map, k: Text) -> int`

1 if `k` is present, else 0.

### `pub fn values(m: Map) -> [int]`

The values of an int-valued map, in key order.

