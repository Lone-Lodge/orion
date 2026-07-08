# orb `num`

num — the small integer helpers every program reaches for.

  abs(-3)            ->  3
  min(4, 9)          ->  4
  max(4, 9)          ->  9
  clamp(12, 0, 10)   ->  10
  sign(-5)           ->  -1

## Public functions

### `pub fn abs(x: int) -> int`

  abs(-3)            ->  3
  min(4, 9)          ->  4
  max(4, 9)          ->  9
  clamp(12, 0, 10)   ->  10
  sign(-5)           ->  -1
Absolute value.

### `pub fn min(a: int, b: int) -> int`

The smaller of two values.

### `pub fn max(a: int, b: int) -> int`

The larger of two values.

### `pub fn clamp(x: int, lo: int, hi: int) -> int`

Constrain `x` to the range [lo, hi].

### `pub fn sign(x: int) -> int`

-1, 0, or 1 by the sign of `x`.

### `pub fn gcd(a: int, b: int) -> int`

Greatest common divisor (Euclid). gcd(0, 0) is 0.

### `pub fn parse(t: Text) -> int`

Parse a base-10 integer out of text. A leading '-' negates; digits are
read left to right and any non-digit is skipped. parse("") is 0.
  parse("42")   ->  42
  parse("-7")   ->  -7
Pairs with split: split("3,4,5", ",") then parse each piece.

### `pub fn ipow(base: int, exp: int) -> int`

Integer power (ipow): base^exp for exp >= 0. Negative exp yields 0.
  ipow(2, 10)  ->  1024

### `pub fn is_even(n: int) -> int`

1 if `n` is even, else 0.

### `pub fn is_odd(n: int) -> int`

1 if `n` is odd, else 0.

