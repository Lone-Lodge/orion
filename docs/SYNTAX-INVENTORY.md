# Orion: syntax + plan

En fil. Överst vad språket **är** idag, sedan vad som **återstår**, med rutor att bocka av.
Allt under "Byggt" är verifierat genom att kompilera ett program per påstående, inte genom att läsa den här filen.

Senast verifierad: 2026-08-19.

---

# Del 1 - Så här ser koden ut

```
public define update(edit items: list of number):
    loop i in 0 until length(items):
        if items[i] is not 0:
            items[i] = items[i] * 2

define alive(hp: number) -> truth:
    hp > 0

define spawn(at: point, health = 100) -> enemy:
    example spawn(origin).hp is 100
    enemy{position: at, hp: health}

define greet_all(scores: table):
    loop name, points in scores:
        print_line("{name}: {points}")
```

## Typer

| ord | betyder |
|---|---|
| `number` | tal. `/` riktig division, `//` golv. Kompilatorn väljer i64 eller f64 |
| `truth` | `true` / `false` |
| `text` | Unicode-text. En textbit av längd 1 räcker som tecken |
| `table` | nyckel-värde. `{"name": "Ada"}`, läses `t[k]` |
| `list of T` | `list of enemy`, `list of number`. Skrivs även `[T]` |
| `maybe T` | ett värde eller inget: `some(v)` / `none` |
| `result T` | lyckades eller fel: `ok(v)` / `error(msg)` |

`maybe` och `result` bor i `orbs/core` och finns i varje program utan `use`. De tar aldrig ett
namn ifrån dig: en egen enum, en egen variant eller en egen funktion vid samma namn vinner alltid.
Funktionerna ÖVER dem (`unwrap_or`, `is_some`, `err_msg`) ligger kvar bakom `use option` / `use result`.

En tables **element är dess nyckel**. `loop k in t:` ger nycklarna, `loop k, v in t:` ger båda,
`contains(t, k)` frågar efter nyckeln. Från en nyckel når du värdet, från ett värde når du inte nyckeln.
En table vars värden inte är samma typ vägrar `t[k]` och hänvisar till `get_int` / `get_map` / `get_list`.

Bytes är `list of number`. Ingen egen typ - `bytes_of(t)` ger en vanlig lista.

Egna typer, allt gemener:

```
type player: name: text, hp: number     # produkt
type tile: empty, wall, loot            # val
```

Generiskt med `given`, krav med `requires`. En capability är bara en record av funktioner:

```
type order given item: less: (item, item) -> truth
define largest given item requires order (items: list of item) -> item:
```

Anropet skickar recorden som named argument: `largest(xs, order: number_order)`.
Dictionary-passing syns i koden, ingen dold resolution.

## En stavning per sak

Där två stavningar fanns är den vänstra den enda som skrivs. Parsern gör samma nod av båda,
så migrationen var ren omstavning - identisk IR.

| skrivs | inte |
|---|---|
| `is` / `is not` | `==` / `!=` |
| `xs[i]` | `at(xs, i)` |
| `0 until n` | `0..<n` |
| `loop` | `for` |
| `edit` | `mut` |
| `define` | `fn` |
| `public` | `pub` |
| `choose` … `then` | `match` … `->` |
| `some` / `none` / `ok` / `error` | `Some` / `None` / `Ok` / `Err` |
| `maybe T` / `result T` | `Option<T>` / `Result<T>` |
| `collect` | `yield` |
| `length` | `len` |
| `truth` / `text` / `table` | `bool` / `Text` / `Map` |
| `part` | `slice` |

## Funktioner

- `define` definierar. `public` exponerar ur orben. Utan = privat.
- Returtyp inferreras för privata, valfri på publika som kontrakt.
- Named arguments och default-värden: `spawn(at: origin, health: 50)`, `health = 100`.
- Anonym funktion utan keyword: `(n): n + k`. `each(xs, (n): n * 2)`.
- `x.f()` betyder `f(x)`.
- `uses` säger vad en publik funktion rör: `public define save(w: world) uses files:`.
  Capabilities: `console`, `files`, `net`, `clock`, `random`. Privata och `main` inferreras.
  Ingen klausul = ren beräkning. Kompilatorn håller det.
- `example` under signaturen körs av bygget: `example clamp(15, 0, 10) is 10`.

## Muterbarhet

Allt oföränderligt som standard. `edit` markerar det som får ändras: `edit x = 0`,
`define tick(edit world: world):`. Värde-semantik i språket; kompilatorn muterar unikt ägda värden in-place.

## Kontrollflöde

- `if cond: … else: …` eller `if cond then a else b`. Allt är ett uttryck.
- `loop:` (oändlig, `break`), `loop x in xs:`, `loop i, x in xs:` (plats, värde).
  Samma två former över en `table`.
- `0 to n` till och med, `0 until n` fram till.
- `collect` samlar ur en loop, `where` filtrerar.
- `choose x:` med `pattern then body`-armar.
- Kedjor av `each`/`keep`/`collect` fuserar - inga mellanlistor.

## Fel

Fel är data. Inga exceptions, inget try/catch, inga dolda hopp.
`try risky()` packar upp och skickar felet uppåt. Hantera med `choose`.

## Kontrakt, effekter, determinism

- `require` / `ensure` - för- och eftervillkor.
- `defer expr` - kör vid utträde (LIFO).
- `effect` / `handle` / `perform` / `resume` - ersätter exceptions, async och generatorer.
- `deterministic` - ren och reproducerbar, bit-exakt: fixed-point för bråktal.

## Builtins (ingen `use`)

- Samlingar: `length`, `append`, `xs[i]`, `part`, `each`, `keep`, `combine`, `get`/`set`/`has`.
- `contains(x, y)` - text: delsträng. table: nyckeln. Lista: `includes(xs, v)` ur `list`.
- Utskrift: `print`, `print_line`, interpolation `"{uttryck}"`.
- Tal: `abs` `min` `max` `clamp` `floor` `ceil` `round` `sqrt` `sin` `cos` … en uppsättning.
- Konvertering: `to_number`, `to_text`, `parse`. Formattering via named args: `to_text(x, decimals: 2)`.
- Program: `arguments` (en `list of text`, ett värde - inte ett anrop).
- Test: `assert(villkor)`. Etiketten är valfri.

## Data som databas, inte objektgraf

Program-state är platta stores av värden med id:n. Värde-semantiken gör pekargrafer omöjliga.
`store`-orben: `insert` / `remove` / `get`, och `loop e in enemies where e.hp < 10:` ÄR queryn.
Spel kallar det ECS, affärssystem kallar det relationer.

`int` finns kvar på ett ställe där det är **rätt**: `external define` mot C. Där beskriver
ordet en främmande ABI, och den tar en int oavsett vad Orion tycker.

## Moduler

`orb` = modul. En ensam `.or` kör utan projektfil.

**`use` behövs sällan.** Ett namn som exakt en orb på sökvägen exporterar hämtas åt dig -
kompilatorn visste redan vilket orb det var: felet sa *it is exported by `text`*.
Två orbar som exporterar samma namn är fortfarande ett fel som namnger båda, och `use` är
svaret på det. Det är den enda uppgift `use` har kvar.

Reglerna, i ordning: det du själv deklarerar vinner. Sedan det du själv importerat.
Sist auto-import, och bara för namn i **anropsposition** - en lokal variabel som heter
`first` hämtar ingenting. Kärnorden `some` / `none` / `ok` / `error` hämtar aldrig heller,
annars hade `log.error` tagit `error(m)` ifrån varje program som skriver det.
Bara den primära orb-katalogen indexeras; systerprojekt namnger du själv.

En toppnivå-binding ÄR en konstant. `define main():` är startpunkten - ingen returtyp,
fel går via `result`/effekter, inte exit-koder.

---

# Del 2 - Byggt

- [x] Sized types `i8..u64` som **wrap-semantik** (`u8` wrappar vid 256), `x as T`,
      literal-range-check. Lagringen är i64 för alla heltal och f64 för alla flyttal -
      backenden har ingen smal representation, och `f32` betyder därför f64
- [x] `Result<T>` / `Option<T>` som riktiga generiska sumtyper, `?`-propagering
- [x] Effekter: one-shot `perform` / `handle` / `resume`
- [x] `number` som ytord, `/` riktig division, `//` golv
- [x] Gemena typer, varianttyper, `given`, `requires`
- [x] Named arguments, default-värden, lätt lambda `(n):`, if som uttryck
- [x] `uses`-klausulen, och kompilatorn håller den
- [x] `example`-rader som bygget kör
- [x] `require` / `ensure` / `defer` / `deterministic`
- [x] `store`-orben
- [x] `main` utan exit-kod, ett `print`, `x.f()`, `xs[i] = v`
- [x] En stavning per sak (tabellen ovan) - hela korpusen migrerad
- [x] `arguments` som `list of text`
- [x] Ett `assert(villkor)`
- [x] `each` / `keep` / `combine` / `assert` utan `use`
- [x] `loop k in t:` och `loop k, v in t:` över en table
- [x] `contains` på table; blandad table vägrar `t[k]` i stället för att segfaulta
- [x] Stdlib-kommentarerna slutar lära ut retirerade ord
- [x] `then` som enda arm-stavning
- [x] `maybe` / `result` som kärntyper i `orbs/core` - inget `use`, och de skuggar aldrig ditt eget
- [x] **Auto-`use`**: ett namn som exakt en orb exporterar hämtas åt dig. `use` svarar bara på *vilken*
- [x] **`number` väljer i64 eller f64** genom helprogramsanalys - ett ord, kompilatorn väljer maskinen
- [x] Hela korpusen skriver `number`: parametrar, returer, let-annoteringar, datafält,
      listelement, varianters nyttolast, funktionstyper och **tupelpositioner**.
      Det enda `int` en användare skriver är mot C: `external define`. Verifierat genom byte-identisk IR för 204 testprogram och fyra korpusprojekt
- [x] Den talade ytan på wasm också - grindens baseline höjd från 141 till 154

# Del 3 - Återstår

## Talas om men finns inte

- [ ] **Den namngivna funktionstyp-formen.** `function(max: number) -> number` parsas som
      TVÅ parametrar - `max` som en okänd typ och `number` - så anropet felar med "expects 3
      argument(s)". Formen `function(number) -> number` fungerar. Felet är högt, inte tyst,
      men ordet `max` läser som dokumentation och borde få vara det.

- [ ] **Bredder.** `number` väljer heltal eller flyttal; det väljer ännu inte i32, u8 eller
      f32. Att smalna ett helt tal till en bredd som rymmer det är en *optimering* som aldrig
      ändrar ett svar, till skillnad från valet helt-eller-reellt som är semantik. Kräver
      intervallanalys.
- [ ] **Bredder som lagring.** `number` väljer helt eller reellt; ingenting i språket väljer
      i32, u8 eller f32 som *lagring*. `u8` är en i64 med en mask, och det gäller de explicita
      typerna lika mycket som `number`. Att smalna kräver intervallanalys OCH smal lagring i
      båda backends - och det är en optimering, inte semantik: i64 är alltid ett korrekt svar
      för ett helt tal inom sitt intervall. Två ställen där det ändå spelar roll: minneslayout
      för stora listor, och `external define` mot C där ABI:n är given.
- [ ] **En enum får ett svar för alla sina `number`-nyttolaster.** Det är därför `ori_display`
      medvetet behåller `int`: ett bråktal någonstans breddar varje koordinat i listan.
      Regeln finns för att en `choose`-arm lämnar tillbaka en bar nyttolast utan konvertering.
      Fixas den i sänkningen kan nyttolasterna avgöras var för sig.
- [ ] **`given` som enda generic-stavning** - `<T>` används på 29 ställen, `given` på 9

## Ett ord per begrepp

- [ ] **Sex läsare för en operation.** `get` 743, `get_map` 378, `get_int` 284, `get_list` 236,
      `get_or` 7, `get_text_list` 4, `get_int_list` 1. `t[k]` bär redan typen genom, även nästlat.
      De typade läsarna behövs bara för blandade tabeller - kompilatorns egen AST.
- [ ] Tre tids/task-system (`async` + `scheduler` + `timer`) → ett
- [ ] Dubbelt JSON-API (`j*` sumtyp vs `json_*` table) → ett
- [ ] `closure`-orben läcker env+fn_id som API fast språket har lambdas → radera
- [ ] `pi()` som funktion → const som korsar orb-gräns
- [ ] Rå mekanik på ytan: `ptr`, `call_ptr`, `struct_field_int/text`, `slot_get/set/has`,
      `vec_add` / `vec_madd` / `vec_dot` (handanropad SIMD) → göm

## Saknas

- [ ] **`set`** - `contains` på en lista är O(n), och det är därför folk missbrukar en table som mängd
- [ ] `table` med icke-`text`-nycklar
- [ ] Typade fel: `Result<T, E>` med strukturellt E
- [ ] Unicode: `upper` / `lower` / `reverse` / `index_of` är byte-baserade
- [ ] Lazy iterators - allt `loop` samlar eagert
- [ ] Nätverk: `net` är en stub. Sockets → TLS/HTTP
- [ ] Datum/tid-typer
- [ ] Float-formattering i interpolation

## Effekter hela vägen (identiteten)

Routa IO/rand/tid/nät genom effektsystemet i stället för builtins. Låser upp tre saker
inget mainstream har: test utan mocks (byt handler), capability-säkerhet, record/replay.
Tids-systemen måste unifieras först.

- [ ] rand + tid
- [ ] nät
- [ ] file + print

## Resurser och samtidighet (design låst, bygg när net landar)

- [ ] Handtag ägs av sitt `handle`-block - scope-utträde stänger, strukturellt i stället för defer
- [ ] `scope:` med cancellation och timeout som scope-egenskaper (`scope timeout 100:`)
- [ ] Fibrer, aldrig futures. Streams = lazy fusion + kanaler. Actors: nej

---

# Regler vi håller

1. **Ytan säger hela ordet.** Inga förkortningar, inget CPU-tänk. Verb, inte kryptik.
2. **En stavning per sak.** Två stavningar är sämre än vilken som helst av dem ensam:
   läsaren måste kunna båda och kan aldrig lita på att den ena betyder något särskilt.
   En omdöpning är inte klar förrän korpusen är omskriven.
3. **Docs kan inte ljuga.** `example`-rader körs av bygget, fältguidens exempel kompileras
   av `docs_check`, referenssidan genereras ur `orbs/`.
4. **Tyst fel är det värsta utfallet.** Hellre ett kompileringsfel som säger vad man ska
   skriva i stället, än ett svar som råkar bli fel.
5. **Fel är data.** Inga exceptions, ingen panic, inga dolda hopp.
6. **Värde-semantik.** Inga pekargrafer, inget delas i smyg. Kompilatorn äger layouten.

---

Omskrivningsverktyget för en stavningsmigration: `tools/migrate/respell.py`.
Det maskar varje rad i kod / sträng / kommentar innan det rör något, och interpolation räknas som kod.
