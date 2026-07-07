# Minimal Orion — enkelt men innovera

Resultatet av designsamtalet 2026-07-07. Mottot: **enkelt men innovera.**
Inte kort-och-kryptiskt — *enkelt* betyder få begrepp, var och en läsbar på
egen hand. Innovationen sitter i att motorn och kompilatorn gör mer osynligt,
inte i fler tecken att memorera.

**Designregeln (avgör varje strid):** *kan en nykomling gissa vad
konstruktionen gör?* Kan de inte det — som `? :`-ternären — är den för smart och
åker ut, även om den är kortare.

**Läsbarhetsregeln (lika viktig):** *en tanke per rad.* `match` är ren just för
att den staplar ett fall per rad — inte för att den är kort. Kram inte ihop
villkor, filter och kropp på samma rad; hellre några rader som var för sig är
uppenbara. Enkelt slår tätt.

## Var vi landar (beslut 2026-07-07)

**Tunn kärna + `fact` som brygga.** Orion-språket är fristående och litet:
`fn` `data` `enum` `fact` `match` `?` `for` `.metod()`. Det kan kompilera sig
självt utan någon motor. `fact` är den enda next-gen-biten i kärnan — i lat form
(räknas om vid läsning) nu, i reaktiv form (räknas om vid ändring) när motorn
finns. `when` och `system` är INTE språket — de kräver en tick och bor i
astra-lagret. Detta valdes framför en "fet kärna" (bygga in ticken i språket)
för att hålla Orion litet och självständigt — auditens linje: nyheten är motorn,
håll språket KISS.

---

## De åtta konstruktionerna

```orion
fn f(x: int) -> int:
    ...
```
```orion
data Point:
    x: int
    y: int
```
```orion
enum Tile: Empty, Wall, Loot
```
```orion
fact alive = health > 0
```
```orion
match:
    score > 100: win()
    else:        idle()
```
```orion
v = risky()?
```
```orion
ys = for x in xs where x > 0:
    x * 2
```
```orion
text.upper()
```

Sju kärn-konstruktioner (`fn` `data` `enum` `fact` `match` `?` `for`) plus
`.metod()`. Ingen `if`, ingen `loop`, ingen `map`/`filter`/`each`, ingen ternär,
ingen `|>`, ingen `defer`, ingen `move`.

`when` och `system` finns INTE här — de kräver en motor som tickar och bor i
astra-lagret (se nedan). Detta är den fristående kärnan.

---

## Kärnan (ren Orion — inget engine-beroende)

### `fn` / `data` / `enum`
Funktioner, poststrukturer, summatyper. Oförändrat.

### `match:` — den enda förgreningen
Ett verktyg ersätter `if`, `else if` och `switch`. Med subjekt matchar den
varianter (uttömmande — glömmer du ett fall = kompileringsfel). Utan subjekt är
den en villkorskedja där första sanna grenen vinner:

```orion
match tile:                match:
    Loot(v): ta(v)             health <= 0: die()
    Wall:    stop()            score > 100: win()
    Empty:   0                 else:        idle()
```

*Varför inte `if`?* `if` är bara `match` på en boolean. Ett brancher-begrepp är
enklare att lära än tre. *Varför inte `c ? a : b`?* `:` betyder "annars" men ser
inte ut så — en nykomling kan inte gissa det. Kapad.

### `?` — en betydelse: skicka fel uppåt
```orion
v = kan_fela()?      # är det Err → returnera Err direkt; annars packa upp
```
Postfix, alltid samma innebörd. (Vi övervägde att låta `?` också vara ternär —
förkastat: två betydelser för ett tecken är smart, inte enkelt.)

### `for` — innoverad: ett verktyg för all iteration
`for` bygger en lista. Använder du inte listan är det bara en loop. Det är hela
regeln. Håll filter och kropp på var sin rad — inte kramat på en:

```orion
# samlar (ersätter map):
ys = for x in xs:
    x * 2

# filtrerar + samlar (ersätter filter + map):
ys = for x in xs where x > 0:
    x * 2

# obunden → bara kör (ersätter each/loop):
for v in xs:
    draw(v)

# naket → oändligt (ersätter loop):
for:
    if_klart: break
```

`map`, `filter`, `each`, `loop` — alla uppätna av en `for` som ser ut precis som
den redan gör. `where` läses som engelska. *Subtiliteten* (den enda): bunden =
samlar, obunden = kör. Nästlar du samlande `for` — bind mellansteget istället för
att nästla på en rad:

```orion
ys = for x in xs where x > 0:
    x * 2
for v in ys:
    draw(v)
```

### `.metod()` — en anropssyntax
`text.upper()` betyder `upper(text)`. Kedjar vänster-till-höger: `xs.a().b()`.
Vi valde `.` framför `|>` — samma kraft, bekvämare att skriva. `|>` kapad.

### `fact` — beskriv sanning, räkna inte ut den (bryggan)
`fact` är den ENDA reaktiva biten som lever i kärnan, för den behöver ingen tick:

```orion
fact alive = health > 0        # alive följer health
```

- **I kärnan (lat form):** `alive` räknas om när du *läser* den — bara socker för
  `fn alive(): health > 0`. Ingen motor krävs.
- **Med motorn (reaktiv form):** `alive` räknas om bara när `health` *ändras*
  (det reaktiva nätet). Samma syntax, snabbare motor under.

Med motorn får `fact` också namespaces — och ersätter då fem nyckelord med ett:
```orion
fact reach = score > 100  in goal         # = gamla goal
fact enemy = 3  in belief:Guard  conf 73  # = gamla belief + confidence
```

### Övrigt i kärnan
`x =` / `mut n =` / `+= -= *= /=` (bindningar), generics `fn id<T>(x: T)`,
`"{x}"`-interpolation (`{}` = "klistra in värdet av"), `require`/`ensure`
(kontrakt).

---

## Astra-lagret (kräver en motor som tickar — INTE ren Orion)

`when` och `system` är det som gör *spel* next-gen — men de behöver en värld med
en tick-loop och ett entitets-lager. En ren kompilator (som Orion kompilerar sig
själv med) kan inte använda dem. De bor i astra/atlas, inte i språkkärnan.

### `when` — reaktiv regel
```orion
when health <= 0:
    player becomes dead        # motorn fyrar i ögonblicket det slår om

when door is Shut and knock:
    door becomes Open
```
Skillnad mot `match`: `match` körs *en gång, nu*; `when` bevakas *för alltid* och
fyrar på kanten. Olika tidsaxlar, inte dubbletter.

### `system` — ECS-lag utan synlig loop
```orion
system move over Position, Velocity:
    Position becomes Position + Velocity
```
Du skriver lagen för EN entitet; motorn mappar den över alla som matchar.
**Innovation:** `over Position, Velocity` avslöjar exakt footprinten, så motorn
kör alla entiteter parallellt och deterministiskt (via de hazard-fria batchar
`orbit schedule` redan räknar ut) — utan att du ber om det.

---

## Vad som kapades och varför

| Kapad | Ersatt av | Varför |
|---|---|---|
| `if` (block + `then/else`) | `match:` | ett brancher-begrepp räcker |
| `c ? a : b` (ternär) | `match:` | `:` = "annars" är inte gissningsbart |
| `loop` | `for:` | två iterations-ord är ett för många |
| `map` / `filter` / `each` | `for` (uttryck + `where`) | ett verktyg, samma läsbarhet |
| `\|>` | `.metod()` | bekvämare, samma kraft |
| `defer` | auto scope-städning (senare) | nisch — regioner frigör minne ändå |
| `move` | inferreras, syns aldrig | säkerhet ska härledas, inte skrivas |
| `derive`/`goal`/`constraint`/`belief`/`confidence` | `fact ... in NS conf N` | fem → ett |

---

## De tre innovationerna (osynliga, inte kryptiska)

1. **`for` som uttryck** — ytan blir enklare (ett begrepp istället för fyra).
2. **Inferrerad säkerhet** — region-escape och alias fångas av kompilatorn; inga
   `move`/livstids-annoteringar. Rust skriver det; Orion härleder det.
3. **Osynlig parallellism** — `system` (och `for` när skrivningarna är bevisat
   disjunkta) körs parallellt utan ny syntax. "Fast is a feature of the language."

Alla tre följer samma linje: **enkelt på ytan, next-gen under huven.** Ingen av
dem lägger till ett tecken en nykomling måste memorera.

---

## Ärliga kostnader

- **Ovant.** Ett språk utan `if`/`loop`/ternär är främmande för alla som kommer
  från C/Rust/Python. Det är ett medvetet vägval: optimera för *maskinskrivbarhet
  + få fel*, inte för bekantskap. Det matchar "AI-vanligt", men det är ett avsteg.
- **`for`-subtiliteten.** "Bunden samlar, obunden kör" är en regel att lära — den
  enda i annars gissningsbar syntax.
- **Kram inte på en rad.** Innovationen får inte fresta till täta en-radare
  (`for x in xs where x>0: x*2`). En tanke per rad, som `match` — det är därför
  `match` känns ren. Läsbarhet slår korthet.
- **Två lager.** `fact`/`when`/`system` kräver motorn (astra/atlas). Kärnan
  (`fn`/`match`/`for`/`?`) står fristående. Blanda inte ihop dem.

## Byggblockerare (samma som `nextgen-svenska.md`)

Det mesta av detta bor i **astra**/**atlas** (separata repon) eller kräver en
`dist/orion.exe` som inte finns i en web-session. Så detta dokument är
*beslutet*, inte en byggd feature. Att implementera kräver antingen astra/atlas
i sessionen eller en seed-`orion.exe` incheckad (se `nextgen-svenska.md`).
