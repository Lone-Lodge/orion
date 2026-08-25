# Orions syntax

Varje ord och form som språket har, på en sida. Fältguiden
(`docs/index.html`) lär ut språket; den här filen är uppslagsverket.


```python
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
| `truth` | `true` / `false`. Skrivs ut som orden. `has`, `contains`, `includes` svarar med dem |
| `text` | Unicode-text. **Räknas i tecken**: `length`, `part` och `index_of` går på tecken, `bytes_count` / `byte_at` / `bytes_part` på bytes |
| `table of T` | nyckel-värde. `{"name": "Ada"}`, läses `t[k]`. Bar `table` vägrar `t[k]` |
| `list of T` | `list of enemy`, `list of number`. Skrivs även `[T]` |
| `maybe T` | ett värde eller inget: `some(v)` / `none` |
| `result T` | lyckades eller fel: `ok(v)` / `error(msg)` |

`maybe` och `result` bor i `orbs/core` och finns i varje program utan `use`. De tar aldrig ett
namn ifrån dig: en egen enum, en egen variant eller en egen funktion vid samma namn vinner alltid.
Funktionerna ÖVER dem (`unwrap_or`, `is_some`, `err_msg`) ligger kvar bakom `use option` / `use result`.

En tables **element är dess nyckel**. `table of T` säger vad värdena är, precis som
`list of T` säger vad elementen är. En **bar `table` vägrar `t[k]`**: den gissade `text`,
så att läsa ett tal ur en gav programmet en pekare byggd av talet. `loop k in t:` ger nycklarna, `loop k, v in t:` ger båda,
`contains(t, k)` frågar efter nyckeln. Från en nyckel når du värdet, från ett värde når du inte nyckeln.
En table vars värden verkligen skiljer sig vägrar också, och hänvisar till
`get_int` / `get_map` / `get_list`. Det är kompilatorns egen AST, inte vanlig kod.

En text är tecken, inte bytes. `length("räksmörgås")` är 10, `bytes_count` är 13, och
`part(s, index_of(s, "ö"), index_of(s, "ö") + 1)` ger `"ö"`. Det var byte överallt förut,
och då komponerade de tre inte: `part` kunde skära en bokstav mitt itu.

Bytes är `list of number`. Ingen egen typ - `bytes_of(t)` ger en vanlig lista.
Men **`byte_at`, `bytes_count` och `part` läser en `text` direkt**, för en text redan ÄR den
packade formen. `bytes_of` behövs bara när du vill `loop`a eller `append`a - och den kopierar
varje byte till en åtta byte stor plats, så en megabyte från disk blir åtta i minnet.

Egna typer, allt gemener:

```python
type player: name: text, hp: number     # produkt
type tile: empty, wall, loot            # val
```

Generiskt med `given`, krav med `requires`. En capability är bara en record av funktioner:

```python
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
| `slot_get_number` | `slot_get_int` |
| `x as text` | `to_text(x)` |
| `length(t)` (tecken) | `characters(t)` |
| `as number` / `to_whole` / `to_real` | `as int` / `as float` |

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
- Uppgifter: `spawn` / `await` / `yield_now` / `run_all`. En timer är en uppgift:
  `every(200, tick)`, `after(1000, f)`. Ingen update-loop matar dem.
- `deterministic` - ren och reproducerbar, bit-exakt: fixed-point för bråktal.

## Builtins (ingen `use`)

- Samlingar: `length`, `append`, `xs[i]`, `part`, `each`, `keep`, `combine`, `get`/`set`/`has`.
- `contains(x, y)` - text: delsträng. table: nyckeln. Lista: `includes(xs, v)` ur `list`.
- Utskrift: `print`, `print_line`, interpolation `"{uttryck}"`.
- Tal: `abs` `min` `max` `clamp` `floor` `ceil` `round` `sqrt` `sin` `cos` … **en** uppsättning.
  Det fanns en `f*`-familj bredvid (`fmin`, `fabs`, …) med identiska kroppar; `number` gör den överflödig.
- Konvertering. **Ett `as` byter TYP, en funktion väljer REPRESENTATION:**
  `x as text`, `"7" as number`, `x as u8`. `to_whole(x)` / `to_real(x)` när du måste
  bestämma helt eller reellt själv. `int` och `float` går inte att skriva - kompilatorn
  väljer maskinen, och `as int` / `as float` / `to_text(x)` säger vad du ska skriva i stället.
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

Ett anrop i ett **interpolationshål** räknas. Lexern ger en enda strängtoken för
`"{min(3, 7)}"`, så hålets namn syntes inte förut: samma rad med och utan hål gav två
olika svar på om funktionen fanns.

Reglerna, i ordning: det du själv deklarerar vinner. Sedan det du själv importerat.
Sist auto-import, och bara för namn i **anropsposition** - en lokal variabel som heter
`first` hämtar ingenting. Kärnorden `some` / `none` / `ok` / `error` hämtar aldrig heller,
annars hade `log.error` tagit `error(m)` ifrån varje program som skriver det.
Funktioner OCH typer hämtas. Sökvägen har två halvor: **nära** är det projektet deklarerat
plus verktygskedjan och katalogerna runt entryn, **fjärran** är `orbit`s svep över hela
arbetsytan som får `namn = "*"` att lösa sig var det än ligger. Båda går att `use`:a; bara
de nära hämtas åt dig. Gränsen behövs för att ett typnamn är en **global layout-nyckel**:
utan den drog kompilatorns egen `Param` in ett systerprojekts `Param` och bygget länkade inte.

Kvar för `use`: svara på **vilken** av två orbar som exporterar samma namn.
astra gick från 26 rader till 1, folio från 6 till 2, orions egna orbar och verktyg
från 70 till 1 - `use net` i `setup_stub`, för `local_port` finns i mer än en orb.

En toppnivå-binding ÄR en konstant. `define main():` är startpunkten - ingen returtyp,
fel går via `result`/effekter, inte exit-koder.

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
