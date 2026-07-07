# Orion conventions

What idiomatic Orion looks like, and why. Use this as the reference when writing a new orb, reviewing a change, or onboarding someone to the language.

Examples are real — every snippet below comes from `orbs/`, mostly the pure-Orion ports of `base64`, `hash`, `compress`, `format`, `url`, `crypto`, and `hex`.

---

## 1. Philosophy

Orion is meant to **be** Rust, not wrap it. Same semantics — wrapping `i64` arithmetic, ownership, traits, monomorphisation — without the syntactic baggage. Specifically:

- No `let`. `mut`/no-`mut` already encodes the only useful bit.
- No `;`. Newlines + indentation define structure (offside rule, same as Python and Astra).
- No `return`. Tail expressions are the return value, like Rust without the semicolon.
- No `{}` for blocks. `:` opens a block; indentation defines its body.
- Type annotations live at boundaries (`fn` signatures, `data` fields, `extern fn` decls). Locals use inference.

If you find yourself reaching for ceremony, ask whether Orion's design already handles it. Usually it does.

---

## 2. Bindings

```orion
# Immutable. New binding to `value`. No keyword needed.
value = byte_at(bytes, index)

# Mutable. Required when you intend to reassign.
mut output = bytes_zeros(0)

# Reassignment. Only legal because `output` was declared `mut`.
output = push(output, hex_digit(value >> 4))

# `+=` and `-=` on mut bindings.
sum += amount
```

**Why no `let`?** `mut`/no-`mut` is the only useful signal. Adding `let` would just be keyword-as-noise; Orion's checker already catches "reassigning a name that wasn't declared `mut`" so there is no ambiguity to disambiguate.

**Don't:**
```orion
let value = byte_at(bytes, index)   # `let` doesn't exist
value: int = byte_at(bytes, index)  # types are inferred on locals
```

---

## 3. Type annotations

**Annotate at boundaries. Infer everywhere else.**

```orion
# Function signature: parameter types AND return type are explicit.
pub fn hex_encode(bytes: [int]) -> Text:
    mut output = bytes_zeros(0)       # type inferred ([int])
    n = bytes_length(bytes)           # type inferred (int)
    ...
```

```orion
# data: fields are typed (contracts).
data Health:
    hp: int
    max: int
```

```orion
# extern fn: the whole point is announcing the type to the host.
pub extern fn bytes_zeros(n: int) -> [int]
```

**Why?** Types document contracts. A function's signature is a contract with its callers. A local binding's type is obvious from its RHS — annotating it twice doubles the maintenance burden without adding information.

---

## 4. Returns

The last expression in a block is the return value. There is no `return` keyword.

```orion
# Single-expression body — pure expression form.
fn double(x: int) -> int = x * 2

# Block body — tail expression returned.
pub fn hex_encode(bytes: [int]) -> Text:
    mut output = bytes_zeros(0)
    for index in 0..<bytes_length(bytes):
        b = byte_at(bytes, index)
        output = push(output, hex_digit(b >> 4))
        output = push(output, hex_digit(b & 15))
    bytes_to_text(output)              # ← this line IS the return value
```

If you want to bail out early, restructure with `if`. Orion doesn't have early-return on purpose — it forces clearer control flow.

---

## 5. Conditionals

Two forms. Same word, different position.

**Expression-form** — produces a value, used inline:

```orion
fn hex_digit(value: int) -> int:
    if value < 10 then value + 48
    else value + 87

fn clamp(v: int, lo: int, hi: int) -> int:
    if v < lo then lo
    else if v > hi then hi
    else v
```

**Statement-form** — runs blocks for their side effects (or for their tail value):

```orion
pub fn hex_decode(text: Text) -> [int]:
    input = bytes_from_text(text)
    length = bytes_length(input)

    if length % 2 != 0:
        bytes_zeros(0)
    else:
        mut output = bytes_zeros(0)
        for pair_index in 0..<(length / 2):
            ...
        output
```

Both forms return values. Pick by readability — expression-form for short ternaries, statement-form when the branches are multi-line.

There is no `else if` *statement* form — you nest with `else: if ...:`. Or use expression-form chains.

---

## 6. Loops

```orion
# Counted loop. Range is half-open (..<) or inclusive (...).
for index in 0..<n:
    ...

# Unbounded loop with explicit break condition.
loop:
    if done:
        break
    ...

# Iterate a list.
for item in items:
    ...

# Iterate entities by component (ECS).
for e with Position, Velocity:
    e.Position.x += e.Velocity.dx
```

There is no `while`. Use `loop:` + `break`. The first iteration's exit condition is always at the top of the body — this is more honest about what the loop does.

---

## 7. Numeric literals

```orion
# Decimal.
n = 100
pi = 3.14159

# Hex, octal, binary. Underscores allowed between digits.
mask = 0xFFFF_FFFF
flags = 0b0010_1100
mode = 0o755

# Large 64-bit constants — the lexer falls back from i64 to u64-as-i64.
fnv_prime = 0xCBF2_9CE4_8422_2325
```

Bit-ops (`<<`, `>>`, `&`, `|`, `^`, `~`) wrap on i64 with Rust's semantics. Multiply (`*`) and add (`+`) wrap too. This is intentional — algorithm code (FNV-1a, SHA-256, hashing) relies on modular int math.

Float ↔ int conversion via the `to_int(x)` and `to_float(x)` built-ins (no `as` casts):

```orion
n = len(xs)                           # n: int
mean = stats_sum(xs) / to_float(n)    # n promoted to f64 for division
rank = (p / 100.0) * to_float(n - 1)  # int → f64
lo = to_int(floor(rank))              # f64 → int (for indexing)
```

Runtime type dispatch via `type_of(value)` returning `"int"`/`"float"`/`"text"`/`"bool"`/`"list"`/`"map"`/`"none"`/`"unit"`/`"entity"`/`"enum"`/`"data"`. Plus `map_keys(m)` and `map_values(m)` for iterating Maps. These power generic serializers like `json_stringify`.

**Watch out for `{` / `}` in string literals.** They start interpolation. To embed a literal brace, escape: `"\{"` and `"\}"`. The lexer's diagnostic is "unterminated `{` in string interpolation" — sometimes reported far from the actual line because the lexer scans ahead.

---

## 8. Naming

```orion
# Functions: snake_case.
fn hex_encode(bytes: [int]) -> Text: ...
fn bytes_from_text(s: Text) -> [int]: ...

# Types: PascalCase.
data Position: x: f32, y: f32
enum Shape: Circle(f32) | Rectangle(f32, f32)

# Constants: SCREAMING_SNAKE_CASE — but actually we use lowercase fns for them.
fn sha256_h0() -> [int]:
    [0x6a09e667, 0xbb67ae85, ...]
```

**Avoid 1-letter variables.** Locals don't carry type annotations, so the name has to do double duty. `for i in 0..<n: b = byte_at(bytes, i)` makes the reader work for no payoff. Spell it out:

```orion
# Idiomatic
for pair_index in 0..<(length / 2):
    high = hex_value(byte_at(input, pair_index * 2))
    low = hex_value(byte_at(input, pair_index * 2 + 1))
    output = push(output, high * 16 + low)
```

```orion
# Don't
for i in 0..<n:
    h = hex_value(byte_at(input, i * 2))
    l = hex_value(byte_at(input, i * 2 + 1))
    out = push(out, h * 16 + l)
```

2-letter conventional names (`xs`, `lo`, `hi`, `acc`) are also weaker than the spelled form (`values`, `lowest`, `highest`, `sum_of_squares`). Use the longer form.

**The one legitimate exception**: bit-twiddling working variables that match the algorithm's own notation (SHA-256's `a`, `b`, ..., `hh`; FNV's `h`). When the literature uses those letters, code that uses them is easier to cross-reference, not harder.

---

## 9. Orb structure

Every orb is a folder under `orbs/`:

```
orbs/
  hex/
    Orbit.toml      # name, version, deps
    lib.or          # the implementation
  bytes/
    Orbit.toml
    lib.or
```

`Orbit.toml` for a pure-Orion orb that uses bytes:

```toml
name = "hex"
version = "0.0.1"
description = "orion stdlib orb: hex encode/decode for byte arrays"
license = "MIT"

[orbs]
bytes = { built-in = true }
```

`lib.or` declares only what's needed:

```orion
# hex — lowercase hex encode/decode for byte arrays.

fn hex_digit(value: int) -> int:
    if value < 10 then value + 48
    else value + 87

pub fn hex_encode(bytes: [int]) -> Text:
    ...
```

Built-in stdlib orbs also have a `orion/src/stdlib/<name>.rs` shim that bundles `lib.or` via `include_str!` and registers any native fns. Pure-Orion orbs have an empty `register()`:

```rust
//! `hex` — lowercase hex encode/decode for byte arrays.
//!
//! Pure Orion. Lives in `orbs/hex/lib.or`.

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/hex/lib.or");

pub fn register(_interp: &Interp) {}
```

The orb must also be added to the `ORBS` array in `orion/src/stdlib/mod.rs`, with its `deps` listed (so the LSP and isolation tests know what to prepend).

---

## 10. What stays in Rust

The bar for keeping something in Rust is high: it must be **irreducibly** unable to express itself in Orion.

| Stays in Rust | Why |
|---|---|
| Parser, lexer, VM, JIT | Bootstrap. The language compiles itself eventually but not yet. |
| OS syscalls (`fs.read_file`, `time.now`, `net.connect`) | Kernel boundary. |
| Allocator, atomics, FFI to C ABIs | Hardware-level primitives. |
| `fmt_float`, `json_parse`, `csv_parse`, `regex` | Could port; large effort, not yet done. |
| `random`, `uuid` | Need thread-local mutable state — primitive doesn't exist yet. |

Everything else — base64, hash, compress, format, url, crypto/SHA-256, hex — **is pure Orion**. The pattern is clear: if it's pure logic, it belongs in `lib.or`.

When you find yourself writing a `register_extern("foo", |args| { ... })` for something algorithmic, stop. Port the algorithm to Orion instead.

---

## 11. Style — quick reference

### Indent
Four spaces. Never tabs. The formatter (`Shift-Alt-F` in VS Code) normalises this from any input.

### Blank lines
One blank line between top-level decls. Use them sparingly *inside* functions — only where they group conceptually distinct sections of work:

```orion
pub fn hex_encode(bytes: [int]) -> Text:
    n = bytes_length(bytes)
    mut output = bytes_zeros(0)

    for index in 0..<n:
        b = byte_at(bytes, index)
        output = push(output, hex_digit(b >> 4))
        output = push(output, hex_digit(b & 15))

    bytes_to_text(output)
```

### Comments
`#` line comments. No block comments — they're not parsed.

Default to **no comments** in code. Names should carry the meaning. Add a comment when the WHY is non-obvious:

```orion
# FNV-1a 64-bit prime. Magic constant from the algorithm spec.
fnv_prime = 0x0000_0100_0000_01B3

# Pad until length % 64 == 56 (FIPS 180-4 §5.1.1).
loop:
    if bytes_length(padded) % 64 == 56:
        break
    padded = push(padded, 0)
```

Not:

```orion
# Add 1 to i        ← don't say what the code says
i += 1
```

### `pub` selectivity
Only mark things `pub` if you mean for callers from other files/orbs to use them. Internal helpers stay private:

```orion
# Private helper — only used inside this orb.
fn hex_digit(value: int) -> int:
    if value < 10 then value + 48
    else value + 87

# Public API.
pub fn hex_encode(bytes: [int]) -> Text:
    ...
```

### Short fns vs long fns
Both are fine. Single-expression fns are very Orion-idiomatic for math and helpers:

```orion
fn ease_in_quad(t: f64) -> f64 = t * t
fn ease_out_quad(t: f64) -> f64 = 1.0 - (1.0 - t) * (1.0 - t)
```

Long pipeline fns are fine too — see `crypto/lib.or` for a 100-line SHA-256 compressor. The constraint is clarity per line, not line count.

---

## 12. Idiomatic vs unidiomatic — side by side

### Counting in a loop

```orion
# Idiomatic
mut total = 0
for i in 0..<n:
    total += value_at(i)
total
```
```orion
# Unidiomatic — Java-style accumulator with redundant ceremony
let mut total: int = 0
for (i: int = 0; i < n; i++):
    total = total + value_at(i)
return total
```

### Returning conditionally

```orion
# Idiomatic — expression-form chain
fn sign(x: f64) -> int:
    if x < 0.0 then -1
    else if x > 0.0 then 1
    else 0
```
```orion
# Unidiomatic — early returns / statement form for value
fn sign(x: f64) -> int:
    if x < 0.0:
        return -1
    if x > 0.0:
        return 1
    return 0
```

### Building a byte buffer

```orion
# Idiomatic — mut + push in a loop, tail returns
pub fn hex_encode(bytes: [int]) -> Text:
    mut output = bytes_zeros(0)
    for i in 0..<bytes_length(bytes):
        b = byte_at(bytes, i)
        output = push(output, hex_digit(b >> 4))
        output = push(output, hex_digit(b & 15))
    bytes_to_text(output)
```
```orion
# Unidiomatic — explicit return, redundant let, while-loop
pub fn hex_encode(bytes: [int]) -> Text:
    let mut output: [int] = bytes_zeros(0)
    let mut i: int = 0
    while i < bytes_length(bytes):
        let b: int = byte_at(bytes, i)
        output = push(output, hex_digit(b >> 4))
        output = push(output, hex_digit(b & 15))
        i = i + 1
    return bytes_to_text(output)
```

The Orion version isn't shorter for shortness' sake — it's shorter because each removed token wasn't pulling its weight.

---

## 13. Tooling cues

- **VS Code**: install `lonelodge.orion`. Syntax highlighting, LSP (hover, go-to-def, outline, diagnostics), snippets, Orbit CLI commands.
- **Hover**: shows parameter types, local binding form, and signatures of orb-dep functions. If a name shows nothing on hover, it's either a keyword, an operator, or a typo — check the diagnostic.
- **Format Document** (Shift+Alt+F): re-indents to 4-space step, collapses blank-line runs to one. Doesn't reformat code structure.
- **Snippets**: `fn`, `pfn` (pub fn), `efn` (extern fn), `data`, `enum`, `trait`, `impl`, `for`, `ifb`, `loop`, `mut`, `match`.

---

## 14. When in doubt

Read an existing pure-Orion orb. `orbs/base64/lib.or` and `orbs/hash/lib.or` are short and complete. `orbs/crypto/lib.or` is the longest and shows what a real algorithm looks like in idiomatic Orion. `orbs/hex/lib.or` is the most recent and was written learning these conventions from the start.

If the existing orbs disagree about something — file an issue or PR to update this doc. The conventions document evolves with the language.
