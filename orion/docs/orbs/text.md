# orb `text`

text — common text helpers callable via method-call syntax.

Once you `use text`, you get:
  msg.is_empty()
  msg.starts_with("hello")
  msg.ends_with("!")
  msg.byte_count()
  split("a,b,c", ",")   ->  ["a", "b", "c"]
  join(parts, ", ")     ->  "a, b, c"

All thanks to MethodCall desugar: `msg.starts_with("x")` lowers to
`starts_with(msg, "x")`.

## Public functions

### `pub fn is_empty(t: Text) -> int`

All thanks to MethodCall desugar: `msg.starts_with("x")` lowers to
`starts_with(msg, "x")`.

### `pub fn byte_count(t: Text) -> int`


### `pub fn starts_with(t: Text, prefix: Text) -> int`


### `pub fn ends_with(t: Text, suffix: Text) -> int`


### `pub fn repeat(t: Text, n: int) -> Text`

Repeat `t` `n` times. Returns "" if n <= 0.

### `pub fn reverse(t: Text) -> Text`

Reverse the bytes (ASCII-safe only).

### `pub fn upper(t: Text) -> Text`

Convert ASCII letters to upper case (in place, ASCII only).

### `pub fn lower(t: Text) -> Text`

Convert ASCII letters to lower case.

### `pub fn trim(t: Text) -> Text`

Remove leading and trailing ASCII whitespace (space, tab, newline, CR).
  trim("  hi  ")  ->  "hi"

### `pub fn join(parts: [Text], sep: Text) -> Text`

Join a list of pieces with `sep` between them.
  join(["a", "b", "c"], "-")  ->  "a-b-c"

### `pub fn split(t: Text, sep: Text) -> [Text]`

Split `t` on every occurrence of `sep`, returning the pieces.
  split("a,b,c", ",")  ->  ["a", "b", "c"]
An empty `sep` yields the whole string as a single piece.

### `pub fn replace(t: Text, from: Text, to: Text) -> Text`

Replace every occurrence of `from` with `to` — split on `from`, rejoin
with `to`. An empty `from` returns `t` unchanged.
  replace("a,b,c", ",", "; ")  ->  "a; b; c"

### `pub fn index_of(t: Text, sub: Text) -> int`

First byte index of `sub` in `t`, or -1 if absent. Empty `sub` -> 0.

### `pub fn pad_left(t: Text, width: int, pad: Text) -> Text`

Pad `t` on the left with `pad` until it is at least `width` bytes wide.

### `pub fn pad_right(t: Text, width: int, pad: Text) -> Text`

Pad `t` on the right with `pad` until it is at least `width` bytes wide.

### `pub fn lines(t: Text) -> [Text]`

Split `t` into lines on '\n'.

