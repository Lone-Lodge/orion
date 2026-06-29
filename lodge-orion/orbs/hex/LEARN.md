# Bygga en orb från noll — `hex` som lärande-exempel

`hex` är det första pure-Orion-orbet skrivet **från-noll** av en person som lärde sig språket genom att göra. Implementationen i [`lib.or`](lib.or) är klar (~40 rader) och alla 7 tester i [`orion/tests/hex.rs`](../../orion/tests/hex.rs) är gröna.

Den här filen finns kvar som **referens när du författar nästa orb**. Den fångar Orion-syntax och praktiska tips ur ett "noll till körande implementation"-perspektiv. För djupare språkdesign, se [CONVENTIONS.md](../../CONVENTIONS.md) i repo-roten.

---

## Vad orben gör

```orion
pub fn hex_encode(bytes: [int]) -> Text     # [int] → lowercase hex Text
pub fn hex_decode(text: Text) -> [int]      # Text → [int], case-insensitive
```

Exempel:
```orion
hex_encode([72, 105])      = "4869"          # "Hi" → 0x48, 0x69
hex_encode([255, 0, 171])  = "ff00ab"        # alltid lowercase
hex_decode("4869")         = [72, 105]
hex_decode("FF00aB")       = [255, 0, 171]   # accepterar både cases
hex_decode("4")            = []              # odd length → tom lista
```

---

## Primitiverna du jobbar mot

Från `bytes`-orben (deklarerat som dep i [`Orbit.toml`](Orbit.toml)):

| Fn | Beteende |
|---|---|
| `bytes_from_text(s: Text) -> [int]` | UTF-8 byte codes från en string |
| `bytes_to_text(b: [int]) -> Text` | Bygger string från byte codes |
| `bytes_length(b: [int]) -> int` | Antal bytes |
| `byte_at(b: [int], i: int) -> int` | Bytenvärdet på position `i` (0..=255), 0 vid OOB |
| `bytes_zeros(n: int) -> [int]` | `n` nollor — perfekt som tom buffert |

Inbyggda i Orion (ingen orb-import krävs):

| Fn | Beteende |
|---|---|
| `push(list, val) -> list` | Appendar och returnerar ny lista (immutable + mut bindings funkar) |
| `len(s)` | Längd på Text eller [T] |
| `at(list, i)` | Indexering (panic vid OOB) |
| `print(x)` | Debug-print |

Plus bit-ops på `int`: `<<`, `>>`, `&`, `|`, `^`, `~`. Och hex/oct/bin-literaler med `_`-separator: `0xFF_00_AB`.

---

## ASCII-koder du kommer behöva

```
'0' = 48        '9' = 57
'A' = 65        'F' = 70
'a' = 97        'f' = 102
```

Mappningarna mellan nibble-värde och ASCII är:

| Nibble | Lowercase | Uppercase |
|---|---|---|
| 0..=9 | `+ 48` (→ '0'..'9') | `+ 48` (→ '0'..'9') |
| 10..=15 | `+ 87` (→ 'a'..'f', eftersom `'a'-10=87`) | `+ 55` (→ 'A'..'F', eftersom `'A'-10=55`) |

Omvänt:

| ASCII | → nibble |
|---|---|
| '0'..'9' | `c - 48` |
| 'a'..'f' | `c - 87` |
| 'A'..'F' | `c - 55` |

---

## Orion-syntax snabb-referens

**Funktionsdefinition** — single-expression:
```orion
fn double(n: int) -> int = n * 2
```

**Funktionsdefinition** — block med tail-expression som return:
```orion
fn ascii_a_to_z() -> int:
    a = 65
    z = 90
    z - a + 1
```

**Mutable binding + reassignment**:
```orion
mut sum = 0
sum = sum + 1
sum += 1            # samma sak
```

**For-loop** (exclusive range):
```orion
for i in 0..<10:
    print(i)
```

**Loop + break** (Orion har inget `while`):
```orion
mut i = 0
loop:
    if i >= 10:
        break
    i += 1
```

**Conditional expression** — returnerar value:
```orion
abs = if x < 0 then 0 - x else x
```

**Conditional statement** — block för side-effects, tail-expression är return value:
```orion
if filled == 4:
    out = push(out, value)
    filled = 0
```

**Nested else-if** (statement-form — Orion har inget `else if` direkt, måste nesta):
```orion
if x < 10:
    print("small")
else:
    if x < 100:
        print("medium")
    else:
        print("big")
```

**Nested else-if** (expression-form — vanligare och renare):
```orion
result =
    if x < 10 then "small"
    else if x < 100 then "medium"
    else "big"
```

---

## Strukturen som faktiskt löste det

Två små hjälpfns + två publika fns:

```orion
fn hex_digit(value: int) -> int:        # 0..15 → ASCII lowercase
    if value < 10 then value + 48
    else value + 87

fn hex_value(character: int) -> int:    # ASCII → 0..15, eller -1 invalid
    if character >= 48 and character <= 57 then character - 48
    else if character >= 97 and character <= 102 then character - 87
    else if character >= 65 and character <= 70 then character - 55
    else -1
```

`hex_encode` itererar bytes och pushar två hex-tecken per byte. `hex_decode` itererar par via `pair_index` och kombinerar två nibbles.

Se [`lib.or`](lib.or) för hela implementationen.

---

## Hur du testar din orb

```bash
cargo test --manifest-path orion/Cargo.toml --test hex
```

Alla 7 tester ska vara gröna. Om något fallerar — läs felmeddelandet noga; LSP:n i VS Code visar samma diagnos live medan du skriver.

---

## Sneek-peek på vad inferensen visar

När du hovrar på lokala bindings i VS Code (med `lonelodge.orion@0.0.10+` installerad) ska du se:

| Hovrar på | Visar |
|---|---|
| `value` (`value = byte_at(bytes, index)`) | `value: int  # local in fn hex_encode` |
| `output` (`mut output = bytes_zeros(0)`) | `mut output: [int]  # local in fn hex_encode` |
| `index` (`for index in 0..<...`) | `for index: int in ...  # loop variable in fn hex_encode` |
| `bytes` (parameter) | `bytes: [int]  # parameter of fn hex_encode` |
| `byte_at` (funktionsanrop) | `pub extern fn byte_at(b: [int], i: int) -> int` |

Hover är där du hittar typer när lokaler inte har explicit annotation — och det är **idiomatiskt** att inte annotera lokaler.

---

## Möjliga utvidgningar (icke obligatoriska)

Tre saker som vore värdefulla men inte är gjorda:

1. **`hex_encode_upper`** — uppercase variant. 1-rads-ändring i `hex_digit` (`d + 55` istället för `d + 87` när `d >= 10`).
2. **`hex_decode_strict`** — returnerar tom lista om något tecken är invalid (`hex_value` returnerar -1). Lägg till en `is_valid_hex(text)` helper, kalla den först.
3. **Docstring-comments** — Orion har inga formella docstrings än, men `#`-kommentarer ovanför en `pub fn` syns när nästa hover-iteration extraherar dem.

Säg till om du vill implementera någon — eller bara använd hex som referens när du skriver `stats`-orben själv från noll.

---

## Vidare läsning

- [`CONVENTIONS.md`](../../CONVENTIONS.md) — full Orion best practices, 14 sektioner
- [`orbs/base64/lib.or`](../base64/lib.or) — relaterat encoder-mönster, något mer komplex (padding)
- [`orbs/hash/lib.or`](../hash/lib.or) — pure int-math med wrapping arithmetic
- [`orbs/crypto/lib.or`](../crypto/lib.or) — riktig algoritm (SHA-256), ~140 rader Orion
