# orb `option`

option — Option<T>-style for representing maybe-values.

Idiomatic usage:
  m = find_user(42)
  if is_some(m):
      print_line("found {m.value}")
  else:
      print_line("not found")

Or with unwrap_or:
  user = find_user(42)
  id = unwrap_or(user, 0)

When orion-self gets true sum types with payloads, this becomes
`enum Option: Some(T), None` natively.

## Public functions

### `pub fn Some(v: int) -> Option`


### `pub fn None() -> Option`


### `pub fn is_some(o: Option) -> int`


### `pub fn is_none(o: Option) -> int`


### `pub fn unwrap(o: Option) -> int`


### `pub fn unwrap_or(o: Option, default: int) -> int`


