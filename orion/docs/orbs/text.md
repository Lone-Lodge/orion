# orb `text`

text — common text helpers callable via method-call syntax.

Once you `use text`, you get:
  msg.is_empty()
  msg.starts_with("hello")
  msg.ends_with("!")
  msg.byte_count()

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

