# Orion Tutorial — bygg en checkout

> Genom att bygga en kassa lär du dig det som faktiskt finns. Inte abstrakt teori, inte "hello world", utan ett program du skulle kunna shippa.

Varje steg lägger till EN ny feature. Du ser exakt vad varje koncept tillför.

## 0. Förkrav

Du har orion-binären (`orbit` eller `orion`). Den interpreterar Orion-källkod direkt — eller bygger till native binär.

```sh
orbit run main.or main
```

---

## 1. Första funktionen

`tutorial.or`:

```orion
fn main() -> int:
    print_line("checkout v0")
    0
```

Kör:

```sh
orbit run tutorial.or main
```

**Du har lärt dig**: `fn`, blockkropp med `:`, sista uttrycket är värdet (här `0`), `print_line`, ingen `return`.

---

## 2. Lägg till data

```orion
fn main() -> int:
    cart = ["coffee", "bread", "milk"]
    for item in cart:
        print_line(item)
    len(cart)
```

`len(cart)` blir exit-koden (`3`). Kör med `echo $?` efter.

**Nytt**: list literal `[...]`, `for x in list:`, sista uttrycket blir returvärdet.

---

## 3. Lägg till priser

```orion
fn price(item: Text) -> int:
    match item:
        "coffee" -> 30
        "bread"  -> 25
        "milk"   -> 18
        _        -> 0

fn main() -> int:
    cart = ["coffee", "bread", "bread", "milk"]
    mut total = 0
    for item in cart:
        total = total + price(item)
    print_line("total:")
    print_line(total)
    0
```

Kör. Får `total: 98`.

**Nytt**:
- Funktion med parameter och returtyp (`Text`, `int`)
- `match` med string-pattern och `_` wildcard
- `mut total = 0` — mutbar variabel
- `print_line(total)` — auto-konverterar int till text

---

## 4. String interpolation — Orion-stil

Klassiskt språk:
```orion
print_line("price of " + item + ": " + fmt_int(price(item)))   # 🤮
```

Orion 2026:
```orion
print_line("price of {item}: {price(item)}")                   # ✨
```

Hela kassan:

```orion
fn price(item: Text) -> int:
    match item:
        "coffee" -> 30
        "bread"  -> 25
        "milk"   -> 18
        _        -> 0

fn main() -> int:
    cart = ["coffee", "bread", "bread", "milk"]
    mut total = 0
    for item in cart:
        line_price = price(item)
        print_line("{item}: {line_price}")
        total = total + line_price
    print_line("total: {total}")
    0
```

> Allt mellan `{}` blir auto-konverterat till text. Text passerar igenom, tal formatteras.

---

## 5. Rabatter — kontrakt med discount

```orion
fn discount(item: Text) -> int:
    match item:
        "premium" -> 30
        "regular" -> 10
        _         -> 0

fn final_price(item: Text, base: int) -> int:
    pct = discount(item)
    base - base * pct / 100

fn main() -> int:
    items = ["premium", "regular", "regular", "trial"]
    prices = [100, 50, 50, 0]
    mut total = 0
    for idx, item in items:
        base = at(prices, idx)
        final = final_price(item, base)
        print_line("{item} {base} -> {final}")
        total = total + final
    print_line("total: {total}")
    0
```

**Nytt**:
- Funktion som tar 2 args och anropar annan funktion
- `for idx, item in items:` — index-och-värde i samma loop
- `at(prices, idx)` — list indexing
- Tidigare manuell `mut idx = 0; idx = idx + 1` är **borta**

Kör. Output:
```
premium 100 -> 70
regular 50 -> 45
regular 50 -> 45
trial 0 -> 0
total: 160
```

---

## 6. Spara historiken till fil

```orion
use io
use fs

fn discount(item: Text) -> int:
    match item:
        "premium" -> 30
        "regular" -> 10
        _         -> 0

fn final_price(item: Text, base: int) -> int:
    pct = discount(item)
    base - base * pct / 100

fn main() -> int:
    items = ["premium", "regular", "milk"]
    prices = [100, 50, 18]
    mut report = "checkout report\n---\n"
    mut total = 0
    for idx, item in items:
        base = at(prices, idx)
        final = final_price(item, base)
        line = "{item} {base} -> {final}\n"
        report = report + line
        total = total + final
    report = report + "---\ntotal: {total}\n"
    write_file("checkout.txt", report)
    print_line("wrote checkout.txt")
    0
```

**Nytt**: `use io` / `use fs`, `write_file(path, content)`, ackumulera text via `mut report`.

Öppna `checkout.txt` — där har du hela rapporten.

---

## 7. Kompilera till native binär (orion-self)

Hittills har du kört via interpretern. För riktig native binär:

```orion
use orion_native
use io
use fs

fn main() -> int:
    mkdir_all("dist")
    src = read_file("checkout.or")
    compile_to_exe(src, "dist/checkout.exe")
    0
```

Spara som `build.or` och kör:

```sh
orbit run build.or main
./dist/checkout.exe
```

**Nu har du en standalone Windows-binär. Ingen Rust, ingen runtime, bara `.exe`.**

---

## 8. Nästa steg

Du kan nu det viktigaste:
- Funktioner, mut, match, for/range, for/in/list, for/idx
- String interpolation, auto-printing
- Listor och list-indexing
- Filsystem och native build

För djupare djupdyk:
- [`CHEATSHEET.md`](CHEATSHEET.md) — all syntax på en sida
- [`STDLIB.md`](STDLIB.md) — index över alla orbs (`base64`, `json`, `regex`, ...)
- [`ORION.md`](ORION.md) — språkets fulla design och varför

**Filosofin**: säg vad du menar (intent), inte hur. Programmet du nyss byggde läses som en specifikation.
