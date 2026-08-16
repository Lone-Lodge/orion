# Orion: syntaxreferens

Den next-gen-form vi bestämt. KISS, läsbart för en människa (verb, inte kryptik), intent- och data-drivet. Det här är målbilden; bygget pågår (teman och ordning i `../NEXTGEN-PLAN.md` i orion-roten).

---

## Så här ser koden ut

```
public define update(edit items: list of number):
    loop i in 0 until length(items):
        if items[i] is not 0:
            items[i] = items[i] * 2

define alive(hp: number) -> truth:
    hp > 0

define first given item (items: list of item) -> maybe item:
    if length(items) > 0 then some(items[0]) else none

define load(path: text) -> result text:
    read_file(path)

define total(path: text) -> result number:
    raw = try load(path)                      # fel skickas uppåt
    ok(combine(numbers_in(raw), (a, b): a + b))

define greet_user(id: number):
    choose find_user(id):
        ok(user)   then print("hi {user.name}")
        error(msg) then print(msg)
```

## Typer
- `number` - alla tal (kompilatorn väljer heltal/flyttal/bredd). `/` = riktig division, `//` = golv.
- `truth` - `true` / `false`.
- `text` - Unicode-text. En textbit av längd 1 räcker som "tecken".
- `table` - nyckel-värde. Literal `{"name": "Ada"}`, läsning `t[k]` eller `get`. Text-nycklar (andra nyckeltyper senare). Typad via generics: `get()` ger rätt typ.
- `byte` - rått tal 0-255, bara vid gränser (fil/nät).
- `list of T` - `list of enemy`, `list of number`.
- `maybe T` - ett värde eller inget: `some(v)` / `none`.
- `result T` - lyckades eller fel: `ok(v)` / `error(msg)`.
- Funktionstyp: `(number) -> number`.
- **Allt är gemener** - även egna typer och varianter:
  `type player: name: text, hp: number` (produkt)
  `type tile: empty, wall, loot` (val)
- Generisk typ introduceras med `given`, ett läsbart ord: `given item (...) -> item`.
- Krav på en generisk typ: **`requires`**. En capability är bara en record av funktioner:
  `type order given item: less: (item, item) -> truth`
  `define largest given item requires order (items: list of item) -> item:`
  Anropet skickar recorden som named argument: `largest(xs, order: number_order)`.
  Dictionary-passing synligt i koden, ingen dold resolution.
- Ingen returtyp skriven = funktionen ger inget värde.

## Funktioner
```
public define spawn(at: point, health = 100) -> enemy:
    enemy{position: at, hp: health}
```
- **`define`** definierar en funktion. (`action` är fritt för spel-domänen.)
- **`public`** exponerar den ur orben. Utan = privat.
- **Returtyp inferreras** för privata; valfri på publika som kontrakt (skrivs med `->`).
- **Named arguments** (valfria): `spawn(at: origin, health: 50)`.
- **Default-värden**: `health = 100`.
- **Anonym funktion**: `(n): n + k` - ingen keyword. `each(xs, (n): n * 2)`.
- Anrop är uniformt: `x.f()` betyder `f(x)`.
- **`uses`** - en publik funktion som rör omvärlden säger det i signaturen:
  `public define save(w: world) uses files:`
  Standard-capabilities: `console`, `files`, `net`, `clock`, `random`. Privata
  funktioner (och `main`) inferreras. Ingen klausul = ren beräkning.
  Byt handler i test i stället för att mocka; spela in svaren för replay.
- **`example`** - varje `public define` bär körbara exempel, raden under signaturen:
  `example clamp(15, 0, 10) is 10`
  Bygget kompilerar och kör dem; referenssidan visar dem. Docs kan inte ljuga.

## Muterbarhet
- Allt är oföränderligt som standard: `x = 41`.
- **`edit`** markerar en binding eller parameter som får ändras: `edit x = 0`, `define tick(edit world: world):`.
- Värde-semantik i språket; kompilatorn muterar unikt ägda värden in-place.

## Jämförelser & logik
- Likhet: **`is`** / **`is not`** - `if x is 5`, `if name is not ""`. (`is not` är EN operator; negerade ord-jämförelser finns inte - skriv `not (x < 5)` eller vänd operatorn.)
- Storlek: symboler `<` `>` `<=` `>=` ELLER ord `is less than` / `is more than` / `is at most` / `is at least`. Båda giltiga.
- Logik: **`and`** / **`or`** / **`not`**.
- Aritmetik: `+` `-` `*` `/` `//` `%`.

## Kontrollflöde
- **`if cond: ... else: ...`** eller inline **`if cond then a else b`** - allt är ett uttryck, ger värde.
- **`loop:`** (oändlig, `break`), **`loop x in xs:`**.
- Intervall: **`0 to n`** = till och med n, **`0 until n`** = fram till n (som engelskan läser dem). Bara i loop-position.
- Samla ur en loop: **`collect`** - `doubled = loop x in xs: collect x * 2`. Filtrera: `where` (eller villkorlig collect).
- Kedjor av `each`/`keep`/`collect` fuserar - inga mellanlistor byggs. Samma svar som steg-för-steg; evalueringen ägs av kompilatorn.
- **`choose x:`** med fall, mönstermatchning. Arm-form: **`pattern then body`**.
```
choose first(items):
    some(x) then x
    none    then 0
```
- `break` / `continue` / `return` (return bara för tidig retur; sista uttrycket är annars värdet).

## Fel
- Fel är data. `result T` med `ok(v)` / `error(msg)`. Inga exceptions, inget try/catch, inga dolda hopp.
- Propagera uppåt: **`x = try risky()`** - packar upp `ok`, skickar `error` vidare uppåt.
- Ingen auto-wrap: en funktion som ger `result T` avslutar med `ok(...)` eller `error(...)` (eller värdet från ett annat result-anrop).
- Hantera: `choose r: ok(v) then ... error(m) then ...`.
- `parse("abc")` och liknande ger `maybe number`, aldrig odefinierat.

## Kontrakt & effekter
- **`require cond`** / **`ensure cond`** - för- och eftervillkor, toolchain jagar motexempel.
- **`defer expr`** - kör vid utträde (LIFO).
- Effekter (språkets kraft, ersätter exceptions/async/generatorer):
```
effect clock:
    now: () -> number

handle clock.now():
    resume(1000)

perform clock.now()
```
- **`deterministic`** markerar ren, reproducerbar beräkning - och den är bit-exakt: i deterministisk kod väljer kompilatorn fixed-point för bråktal, så samma program + input + seed ger samma output på varje plattform. (Utanför deterministic lovas inte float-bitar cross-platform.)

## Builtins (ingen `use`)
- Samlingar: `len`, `append`, `xs[i]`, `slice`, `contains`, `each`, `keep`, `combine`, `get`/`set`/`has`.
- Text/utskrift: `print`, `print_line`, textinterpolation `"{uttryck}"`.
- Tal: `abs` `min` `max` `clamp` `floor` `ceil` `round` `sqrt` `sin` `cos` ... (en uppsättning, inga `f`-varianter).
- Konvertering: `to_number`, `to_text`, `parse` (ger `maybe`). Formattering via named args + defaults: `to_text(3.14159, decimals: 2)`.
- Program: `arguments` (en `list of text`).
- Test: `assert(cond)`.

## Data (state som databas, inte objektgraf)
- Program-state formas som platta stores av värden med id:n. Värde-semantiken gör pekargrafer omöjliga - inget delas i smyg.
- **`store`-orben** är entitets-lagret: `use store`, sen
  `id = insert(enemies, e)` · `remove(enemies, id)` · `get(enemies, id)` -
  och `loop e in enemies where e.hp < 10: ...` ÄR queryn.
- Spel kallar det ECS, affärssystem kallar det relationer - samma idé. Kompilatorn får äga lagringslayouten (SoA/AoS) som senare optimering; koden ändras inte.

## Moduler
- **`orb`** = modul. **`use text`** importerar. En ensam `.or` kör utan projektfil.
- `type` deklarerar typer, `external` för C-interop.
- Konstanter behöver inget nyckelord: en toppnivå-binding `max_players = 8` ÄR en konstant (allt är oföränderligt by default). Const korsar orb-gränser (`num.pi` är ett värde, inte ett anrop).
- **`define main():`** är programmets startpunkt. Ingen returtyp - fel rapporteras via `result`/effekter, inte exit-koder.

---

Referens genererad ur parser + compiler, inte docs. Strukturell riktning (effekter som ryggrad, determinism, lazy iterators, docs-som-tester): `../NEXTGEN-PLAN.md`.

## Ord som bytt namn (2026-08-13)

Ytan säger hela ordet. Båda stavningarna parsas idag - parsern
översätter den talade formen till den backends känner
(`psr_spoken_builtin` / `psr_spoken_type` i `orbs/orion_parse`), så en
framtida omdöpning kostar en rad där plus en mekanisk omskrivning.

| förr | nu | varför |
|---|---|---|
| `len` | `length` | förkortning |
| `fn` | `function` | förkortning (typordet, `Game{rules: function}`) |
| `slice` | `part` | "en del av listan", inte CPU-tänk |
| `to_int` | `to_whole` | `int` finns inte i ytan; talen heter `number` |
| `to_float` | `to_real` | samma, och `/` kallas redan riktig division |
| `bytes_from_text` | `bytes_of` | familjen blev symmetrisk |
| `bytes_to_text` | `text_of` | |
| `bytes_length` | `bytes_count` | `byte_count` var upptaget av text-orben |
| `bytes_slice` | `bytes_part` | följer `part` |

`app`-orbens `text_of(body) -> response` heter nu `text_response` - den
byggde ett svar, inte en text, och namnet behövdes.
