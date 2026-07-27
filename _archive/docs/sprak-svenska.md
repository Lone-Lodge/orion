# Orion — syntax och funktioner (svensk referens)

En kompakt genomgång av Orions syntax och inbyggda funktioner, baserad på
det som faktiskt fungerar i den självkompilerande verktygskedjan
(`orion.exe`) i dag. Se `language_status.md` för statuslistan och för vad som
ännu saknas.

Orion är ett *dataorienterat* språk (inte objektorienterat) med summatyper,
mönstermatchning och algebraiska effekter — modern semantik i OCaml 5-klass.

> **Om exemplen:** det finns ingen interpretator. `orbit run fil.or main`
> KOMPILERAR filen (LLVM IR -> clang -> native exe) och kör resultatet;
> lodge-orion, den gamla Rust-interpretatorn, är borta ur trädet.

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

**En** lambdaform: `fn(x): kropp`. Closures fångar omgivningens variabler by
value och fungerar i varje position (bindning, returnerad, inline-argument,
nästlat block, escapande) med int / text / list / map-fångster.

```orion
add5 = fn(n): n + 5           # fångar omgivningen by value
apply(fn(s: Text): len(s), t) # typad parameter när den behövs
```

`|x| kropp` finns INTE (det var den gamla formen och står kvar i äldre texter);
`|` i uttrycksposition ger nu ett tydligt fel som pekar på `fn(x):`.

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
loop i in 0..<n:            # exklusivt intervall (0 .. n-1)
    print(i)

loop v in lista:           # iterera över element
    print(v)

loop idx, v in lista:      # med index
    print(idx)

loop:                     # obegränsad loop
    if klar: break
    continue

loop parallel i in 0..<n:  # en OS-tråd per iteration
    ut[i] = tungt(i)
```

`loop` är det enda loop-nyckelordet — modifieraren avgör formen. `for` är
pensionerat (kompileringsfel som pekar på `loop`). ECS-frågan (`v with
Position:`) finns inte i språket; den hör hemma i motorlagret.

---

## 5. Datatyper

`type` deklarerar alla typer. Formen efter namnet avgör vilken sorts typ det
blir. (`data` och `enum` är pensionerade — kompileringsfel som pekar på `type`.)

### Produkttyper — poststrukturer (inte OOP)

```orion
type Point: x: int, y: int      # på en rad

type Box:                       # eller en rad per fält
    w: int
    h: int
```

Rena rekordtyper — bara fält, ingen inkapsling eller metoder på typen.

### Summatyper med payload

```orion
type Tile: Empty, Wall, Loot, Trap

type Outcome: Ok, Err

type Meters = int               # alias
```

En summatyp där ingen variant bär payload ÄR en heltalsuppräkning: taggen,
`Tile.Wall` och det obundna `Wall` är samma värde.

Varianter kan bära payload (tagg + int-värde + text-värde). Ariteten
kontrolleras vid konstruktion.

### Mönstermatchning

```orion
match tile:
    Empty -> 0
    Wall  -> 0
    Loot  -> loot_value()
    Trap  -> 0 - 50
```

Armarna är `Mönster -> värde` (inte kolon). En arm kan också vara en inline-
tilldelning (`Num(v) -> total += v`) eller ett indenterat block, där sista
uttrycket är armens värde.

Uttömmande kontroll: utan wildcard krävs **alla** varianter. Matchar även
int- och text-mönster, guards (`x if x > 0 ->`), tupler och nästlade mönster,
samt destrukturerar variant-payload.

### `?`-operatorn

Tidig retur vid `Err` för summatyper:

```orion
fn steg() -> Result:
    v = kan_fela()?      # returnerar Err direkt om det felar
    Ok(v)
```

---

## 6. Metodsyntax

```orion
text.upper()           # x.f(a) betyder f(x, a) — inget annat
lista.len()
xs.slice(1, 3)
```

Det finns INGEN pipe-operator. `x |> f` ger ett fel som säger just det: mellan-
variabler är den enda kedjan, och det är medvetet (en tanke per rad).

```orion
steg1 = double(10)
steg2 = inc(steg1)
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

## 8. Kontrakt och defer

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

const K = 2 * 21       # kompileringstidskonstant (folds vid varje läsning)
```

---

## 9. Effekter (algebraiska — ovanlig nästa-gen-funktion)

Deklarera effekten, hantera operationen med `handle`, invokera med `perform`.
Kontinuationen är enskotts och skickas tillbaka med `resume(v)` (int eller text
avgörs av värdet).

```orion
effect Random:
    roll: fn(max: int) -> int

effect Log:
    msg: fn(text: Text) -> Text

handle Random.roll(max: int) -> int:
    resume(73)         # tillbaka till perform-stället med 73

handle Log.msg(text: Text) -> Text:
    resume("ok")

fn loot_value() -> int:
    perform Log.msg("rullar loot-tabell")
    roll = perform Random.roll(100)
    if roll > 95 then 500 else 0
```

En operation tar 0 till 4 argument av valfri blandning av typer
(`perform Mix.at("abc", 7)`), och fel antal mot handleraren är ett
kompileringsfel.

Den gamla namnkonventionen `fn __handler_Effect_op(...)` fungerar fortfarande
(`handle` är sockret ovanpå den), men `resume_int` / `resume_text` finns inte som
namn att anropa: det är `resume` som gäller.

---

## 10. Samtidighet

Det som FAKTISKT kör på trådar är `loop parallel:` — en OS-tråd per iteration,
ovanpå primitiven `par_run`:

```orion
loop parallel i in 0..<n:   # en arbetartråd per iteration
    ut[i] = tungt(i)
```

Fångster sker by value, så en yttre lokal som skrivs i kroppen escapar inte,
medan en delad lista skriven via index gör det (det är det avsedda mönstret:
varje iteration skriver sin egen plats). Två iterationer som skriver samma
plats är en race, och inget kontrollerar det åt dig.

```orion
job = spawn job beräkna()   # RESERVERAT — ingen lowering
r   = job.await             # RESERVERAT
scope:                      # RESERVERAT
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
type Tile: Empty, Wall, Loot, Trap

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
