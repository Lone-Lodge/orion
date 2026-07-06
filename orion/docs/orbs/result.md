# orb `result`

result — Result<T,E>-style error handling for Orion.

Idiomatic usage:
  res = safe_div(10, 2)
  if is_ok(res):
      print_line("got {res.value}")
  else:
      print_line("error: {res.err}")

Or with the helper unwrap_or:
  result = safe_div(10, 0)
  print_line(unwrap_or(result, 0 - 1))

This is a CONVENTION orb — values are plain data structs, not sum types.
When orion-self gets true sum types with payloads, this orb can be replaced
with `enum Result: Ok(int), Err(Text)` for free.

## Public functions

### `pub fn Ok(v: int) -> Result`

Construct a success result.

### `pub fn Err(msg: Text) -> Result`

Construct an error result.

### `pub fn is_ok(r: Result) -> int`

Check if a result is successful.

### `pub fn is_err(r: Result) -> int`

Check if a result is an error.

### `pub fn unwrap(r: Result) -> int`

Get value or panic-equivalent (returns 0 — convention).

### `pub fn unwrap_or(r: Result, default: int) -> int`

Get value or fallback.

### `pub fn err_msg(r: Result) -> Text`

Get error message (empty if Ok).

### `pub fn map_ok(r: Result, default_on_err: int) -> Result`

Map a successful value through a function; propagate errors unchanged.

