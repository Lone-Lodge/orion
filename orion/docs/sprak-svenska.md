# Orion — syntax och funktioner (svensk referens)

En kompakt genomgång av Orions syntax och inbyggda funktioner, baserad på
det som faktiskt fungerar i den självkompilerande verktygskedjan
(`orion.exe`) i dag. Se `language_status.md` och `../NEW_FEATURES.md` för
statuslistor och vad som ännu saknas.

Orion är ett *dataorienterat* språk (inte objektorienterat) med summatyper,
mönstermatchning och algebraiska effekter — modern semantik i OCaml 5-klass.

> **Om exemplen:** kör en fil interpreterat med `orbit run fil.or main`
> eller kompilera den självhostade vägen till native via LLVM.

---

## 1. Grunder

### Kommentarer

```orion
# Radkommentar — börjar med brädgård, går till radslut.
```

### Indentering

Block avgränsas med kolon `:` följt av indentering (som Python), inte med
klamrar.

```orion
fn main() -> int:
    x = 1
    x + 41
```

### Utskrift

```orion
print("hej")     # skriv ut ett värde
print(42)
print_line(msg)  # rad-utskrift (används av Log-effekten)
```

---

## 2. Funktioner (`fn`)

```orion
fn add(a: int, b: int) -> int:
    a + b                # sista uttrycket är returvärdet

pub fn dubbla(x: int) -> int:   # pub = exporteras från orben
    x * 2

extern fn os_write(fd: int, buf: Text, n: int) -> int   # FFI-deklaration
```

- Parametrar **måste** typannoteras. Returtyp anges med `-> Typ`.
- `return <uttryck>` finns för tidig retur (guard-mönster):

```orion
fn process(tile: int) -> int:
    if tile == 0:
        return 0        # tidig utgång
    tile * 10
```

### Förstaklassiga funktioner och högre ordningens funktioner

```orion
fn inc(x: int) -> int: x + 1

fn apply(f: fn, x: int) -> int:   # tar en funktion som argument
    f(x)

fn main() -> int:
    op = inc            # binder en funktionspekare
    a = op(10)          # indirekt anrop → 11
    apply(inc, a)       # → 12
```

### Generics (HM-substitution)

```orion
fn id<T>(value: T) -> T:
    value

fn pair_first<A, B>(left: A, right: B) -> A:
    left

fn main() -> int:
    id(20)              # T pinnas till Int vid anropet
```

### Lambda / closures

`|x| kropp` parsas och closures med fångade variabler fungerar i den native
kompileringsvägen (orion-self → LLVM). I interp-loopen: använd namngivna
funktioner + funktionsreferenser (samma kapacitet).

```orion
add5 = |x| x + 5        # closure som fångar omgivningens variabler (native)
```

---

## 3. Bindningar och tilldelning

```orion
x = 10                 # oföränderlig bindning
mut n = 0              # föränderlig bindning
n = n + 1              # omtilldelning
mut x: int = 5         # typad lokal bindning

n += 1                 # sammansatt tilldelning: += -= *= /=
```

---

## 4. Kontrollflöde

### if / else

```orion
if villkor:            # blockform
    gör_ett()
else:
    gör_annat()

y = if c then a else b # uttrycksform
```

### Loopar

```orion
for i in 0..<n:            # exklusivt intervall (0 .. n-1)
    print(i)

for v in lista:           # iterera över element
    print(v)

for idx, v in lista:      # med index
    print(idx)

for e with Position:      # ECS-fråga — entiteter med en komponent
    ...

loop:                     # obegränsad loop
    if klar: break
    continue
```

---

## 5. Datatyper

### `data` — poststrukturer (inte OOP)

```orion
data Point:
    x: int
    y: int
```

Rena rekordtyper — bara fält, ingen inkapsling eller metoder på typen.

### `enum` — summatyper med payload

```orion
enum Tile: Empty, Wall, Loot, Trap

enum Outcome: Ok, Err
```

Varianter kan bära payload (tagg + int-värde + text-värde). Ariteten
kontrolleras vid konstruktion.

### Mönstermatchning

```orion
match tile:
    Empty: 0
    Wall:  0
    Loot:  loot_value()
    Trap:  0 - 50
```

Uttömmande kontroll: utan wildcard krävs **alla** varianter. Matchar även
int- och text-mönster samt destrukturerar variant-payload.

### `?`-operatorn

Tidig retur vid `Err` för summatyper:

```orion
fn steg() -> Result:
    v = kan_fela()?      # returnerar Err direkt om det felar
    Ok(v)
```

---

## 6. Metod- och pipe-syntax

```orion
text.upper()           # metodanropssyntax
lista.len()

x |> f                 # pipe → f(x)
x |> f(a, b)           # → f(x, a, b)
10 |> double |> inc    # kedja: inc(double(10))
```

### Stränginterpolation

```orion
print("{name} = {value}")
```

---

## 7. Operatorer

```orion
+  -  *  /             # aritmetik
-x                     # unär negation
== != < <= > >=        # jämförelse
<<  >>  &  |  ^  ~      # bitvis (skift, och, eller, xor, komplement)
```

Numeriska typer: `int` och `f64` (flyttal).

---

## 8. Kontrakt, defer, comptime

```orion
fn dela(a: int, b: int) -> int:
    require b != 0     # förvillkor (körtidskontrollerat)
    r = a / b
    ensure r * b == a  # eftervillkor
    r

fn med_resurs():
    f = open()
    defer close(f)     # körs vid blockslut och före varje return (LIFO)
    använd(f)

k = comptime 2 * 21    # konstantvikning vid kompilering
```

---

## 9. Effekter (algebraiska — ovanlig nästa-gen-funktion)

Deklarera effekt, invokera med `perform`, hantera via namnkonvention
`__handler_Effect_op`. Enskotts-kontinuationer via `resume_int` /
`resume_text`.

```orion
effect Random:
    roll: fn(max: int) -> int

effect Log:
    msg: fn(text: Text) -> Text

fn __handler_Random_roll(max: int) -> int:
    resume_int(73)     # returnera via kontinuation
    0

fn loot_value() -> int:
    perform Log.msg("rullar loot-tabell")
    roll = perform Random.roll(100)
    if roll > 95: 500 else: 0
```

---

## 10. Samtidighet

```orion
job = spawn job beräkna()   # starta jobb
r   = job.await             # invänta resultat

parallel for v in data:     # parallell loop (footprint-kontrollerad)
    ...

scope:                      # strukturerad samtidighet
    ...
```

---

## 11. Inbyggda / native-funktioner

Tillgängliga direkt (native lowering i `orion_rt.c`):

| Funktion | Effekt |
|---|---|
| `print(v)` / `print_line(t)` | utskrift |
| `at(lista, i)` | element på index |
| `time_now_ms()` | väggklocka (icke-deterministisk) |
| `monotonic_ms()` | monoton tid sedan processtart |
| `sleep_ms(n)` | ge tillbaka till OS |
| `vec_add(a,b)` `vec_sub` `vec_mul` | elementvisa int-listoperationer (SIMD) |
| `vec_dot(a,b)` | summa av produkter |
| `resume_int(v)` / `resume_text(v)` | kontinuation i effekthanterare |

---

## 12. Standardbibliotek (orbs)

Orbs är moduler i ren Orion. `pub fn` exporterar. Ett urval av de orbs som
finns i trädet:

### `text`
```orion
is_empty(t)   byte_count(t)   starts_with(t, p)   ends_with(t, s)
repeat(t, n)  reverse(t)      upper(t)            lower(t)
```

### `result`
```orion
Ok(v)   Err(msg)   is_ok(r)   is_err(r)
unwrap(r)   unwrap_or(r, d)   err_msg(r)   map_ok(r, d)
```

### `option`
```orion
Some(v)   None()   is_some(o)   is_none(o)   unwrap(o)   unwrap_or(o, d)
```

### `assert`
```orion
assert_true(cond, label)   assert_eq(a, b, label)   assert_text_eq(a, b, label)
```

### `async`
```orion
sleep_until(deadline_ms)   delay(duration_ms)   deadline_from_now(offset)
past_deadline(d)   time_left(d)
timers_new()   add_timer(ts, offset)   next_due(ts)   count_due(ts)   wait_next(ts)
```

Fler orbs i den bredare distributionen: `bytes, fs, io, time, math, random,
log, hash, json, csv, xml, regex, url, base64, hex, color, crypto, easing,
noise, format, collections, env, sysinfo, image, audio, gpu, wgsl, net`
samt kompilatorns interna orbs (`orion_lex`, `orion_parse`, `orion_ir`,
`orion_ast_to_ir`, `orion_emit_llvm`, `orion_driver`).

---

## 13. Fullständigt exempel

```orion
enum Tile: Empty, Wall, Loot, Trap

fn id<T>(value: T) -> T:
    value

fn process(tile_kind: int) -> int:
    if tile_kind == 0:
        return 0
    if tile_kind == 1:
        return 0
    if tile_kind == 2:
        25
    else:
        0 - 50

fn main() -> int:
    a = id(20)
    xs = [1, 2, 3, 4]
    ys = [10, 20, 30, 40]
    dot = vec_dot(xs, ys)          # SIMD

    total = process(2) + process(3)
    print("dot:")
    print(dot)
    a + total                      # 20 + (25 - 50) = -5
```

---

## Vad som ännu saknas

Enligt `language_status.md`: full typinferens (i dag annoterar man),
lambda-lift i interp-loopen, samt utökningar som refinement-typer, makron
och en preemptiv async-scheduler. Kärnan — självhostning, effekter med
kontinuationer, summatyper, mönstermatchning, generics-MVP — fungerar
end-to-end.
