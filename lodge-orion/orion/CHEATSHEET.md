# Orion Cheatsheet

> En sida. All syntax du behöver. Bokmarka.

## Värden & typer

```orion
n = 42                    # int
price = 9.95              # float (f64)
name = "Orion"            # Text
ok = true                 # bool (true/false)
items = ["a", "b", "c"]   # List
config = {"port": 8080}   # Map
```

## Mutation

```orion
mut count = 0             # mutable binding
count = count + 1         # reassign
count += 1                # compound: += -= *= /=
```

> Vanlig binding (`=`) är **omutbar**. Använd `mut` när du måste ändra.

## Funktioner

```orion
fn add(a: int, b: int) -> int = a + b           # expr body (one-liner)

fn greet(name: Text) -> Text:                   # block body
    "Hello, " + name + "!"

fn untyped(x):                                  # types are optional
    x * 2

pub fn exported() -> int = 1                    # pub = export
```

> Sista uttrycket är returvärdet. **Inget `return`-keyword.**

## Kontroll

```orion
# inline if-expression
sign = if n > 0 then "pos" else "neg"

# block if/else
if user.is_admin:
    grant_access()
else:
    deny()

# match (int + string + wildcard)
# FUNGERAR som SISTA uttrycket i en fn (tail position):
fn day_value(day: Text) -> int:
    match day:
        "mon" -> 1
        "sat" -> 2
        "sun" -> 2
        _     -> 0

# FUNGERAR EJ idag som binding (workaround: lägg i egen fn):
# n = match day: "mon" -> 1; _ -> 0   ← parse-fel

# range loop (2026 syntax: 0..<N)
for i in 0..<10:
    print_line("{i}")

# list iteration
for item in cart:
    print_line(item)

# with index
for idx, item in cart:
    print_line("[{idx}] {item}")

# unconditional loop
loop:
    if done: break
    work()
```

## Strängar

```orion
greeting = "Hello"
message = greeting + " world"              # concat
interp  = "Hello, {name}, you have {n}"    # interpolation
```

> Interpolering ringer auto `to_text(var)` — text passerar igenom, int/float fmt:as automatiskt.

## Listor & Maps

```orion
xs = [1, 2, 3]
len(xs)                # 3
at(xs, 0)              # 1
push(xs, 4)            # [1,2,3,4]

config = {"port": 8080, "host": "localhost"}
get(config, "port")    # 8080
has(config, "ssl")     # false
set(config, "ssl", true)
```

## String/text indexing

```orion
# ⚠️ s[0] returnerar HELA strängen, INTE första tecknet (bug i lodge-orion 2026-06)
# Använd bytes_from_text istället:

use bytes
b = bytes_from_text("abc")
b0 = at(b, 0)          # 97 ('a')
b1 = at(b, 1)          # 98 ('b')

# Längd:
length = len(s)        # antal bytes

# Digit-lookup via tabell-array:
digits = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
d = at(digits, n % 10)
```

## Typade strukturer — `data`

```orion
# INLINE syntax (multiline data: STÖDS EJ idag)
data Point: x: int, y: int
data Player: name: Text, hp: int, hp_max: int

# Skapa instans
p = Point{x: 10, y: 20}
hero = Player{name: "Alyx", hp: 100, hp_max: 100}

# Läs fält — typat, inget get() behövs
p.x                          # 10
hero.name                    # "Alyx"

# Lista av structs funkar
items = [Point{x: 1, y: 2}, Point{x: 3, y: 4}]
first = at(items, 0)
first.x                      # 1

# Returnera struct från fn
fn make_player(name: Text) -> Player:
    Player{name: name, hp: 100, hp_max: 100}
```

> **Reserverade keywords** kan inte vara fältnamn: `fn`, `if`, `else`, `mut`, `for`, `loop`, `match`, `data`, `pub`, `use`, `return`, `break`.
> Använd alternativ: `function`, `condition`, `iteration`, etc.

## Print & IO

```orion
print_line("hello")          # newline
print("no newline")
print_line(42)               # auto-fmt for ints
eprint("error")              # stderr

src = read_file("input.txt")
write_file("output.txt", "data")
```

## Spawn & Spawn-with (ECS)

```orion
spawn Bullet{velocity: 200.0, owner: player}

# iterera entiteter med komponenter
for bullet with Velocity, Position:
    bullet.Position.x += bullet.Velocity.dx
```

## Kontrakt

```orion
fn divide(a: int, b: int) -> int:
    require b != 0                       # pre-condition
    result = a / b
    ensure result * b == a               # post-condition
    result
```

## Importera

```orion
use math                     # standard orb
use orion_native             # native compiler (orion-self)
use io
use fs
```

## Operatorpriroriteter (höga binder hårdast)

```
.field   [index]   (call)    # postfix
*  /  %                       # multiplicativ
+  -                          # additiv
<  <=  >  >=  ==  !=          # jämförelse
and                           # logisk OCH
or                            # logisk ELLER
```

## Kommandoradsverktyg

```sh
orbit run path/to/main.or main        # tolka via lodge-orion (snabb iter)
orbit jit path/to/main.or main        # JIT till native
orbit build                           # builder för riktiga targets
```

## Hela 2026-stilen på en rad

```orion
for idx, item in cart:
    print_line("{idx}: {item} -> {final_price(item)}")
```

**Inte OOP. Inte boilerplate. Bara intent.**

## Kända begränsningar (2026-06)

| Vad | Status | Workaround |
|---|---|---|
| **`text[i]`** | **Returnerar hela strängen, inte tecknet** | `bytes_from_text(s)` + `at(b, i)` ger int (byte-värde) |
| **Multi-line `data`** | Saknas | Inline-syntax: `data X: a: int, b: Text` |
| **`match` bunden till variabel** (`n = match ...`) | Saknas | Lägg match i egen fn, kalla den |
| **`match` med text-patterns utanför tail position** | Saknas | If-kedja eller egen fn |
| **List comprehensions** (`[for i in 0..<N: f(i)]`) | Saknas | for-loop + push |
| **`fn` som fältnamn** | Reserverat | Använd `function` eller annat |
| **Map.get returnerar Unknown i strict-position** | Idag | Använd `data` struct istället för Map för typsäkerhet |
| **Interp `"{call(...)}"`** | Native: bug | Spara i variabel först: `c = call(); "{c}"` |
