# Orion

> Ett next-gen systemspråk. Intent-drivet, data-drivet, inte OOP. Tänkt att ersätta
> C++/Rust/C för spelmotorn — och allt annat som behöver rå prestanda utan att vara
> komplext.

Status: **designfas.** Det här dokumentet är levande och fångar besluten vi enats om,
inte en färdig spec. Allt här är ändringsbart, men inget är godtyckligt — varje val har
ett *därför*.

---

## 1. Vision

Orion ska vara **bäst** — snabbast, renast, mest begriplig — och sen får Atlas dra
nytta av samma idéer. Fyra krav styr allt:

- **Intent** — du säger *vad* och *varför*, kompilatorn väljer *hur*.
- **Prestanda** — C++/Rust-klass. Ingen GC. Lågnivå när du vill.
- **Begriplig & inte för komplex** — liten konceptbudget, en sak görs på ett sätt.
- **Powerful** — kraften faller *ut* ur de få koncepten, den staplas inte på som extra ytor.

Och en röd tråd genom allt: **AI-vänligt.** De val som gör språket clean (lokalitet,
deklarativt, kontrakt som maskinläsbar spec) gör det också lätt för en modell att skriva
korrekt kod i.

### Förhållande till Astra & Atlas
- **Astra** = den lilla narrativa DSL:en (regler/vyer, host föreslår effekter). Orion ärver
  dess *filosofi* (intent → härledning, data inte objekt, `reads`-fotavtryck), inte dess
  kod eller skala.
- **Atlas** = motorn. Idag en relationell EAV-databas med opt-in SoA-kolumner valda av
  statisk analys (`hot_columns`). Det är **embryot till Orions fotavtrycks-idé, redan i
  produktion.** Orion generaliserar och formaliserar det.

---

## 2. De sju koncepten (hela vokabulären)

Ett clean språk definieras av hur *få* koncept det har. Orion har sju. Allt annat
(parallellism, SoA-layout, cache, tester) *faller ut* ur dessa — det är inte ytor du
måste lära dig separat.

| Koncept | Vad | Ersätter |
|---|---|---|
| `data` | en rad / ett schema (kolumner) | klasser, structs |
| `fn` | funktion; fotavtryck via `mut`/`take` | metoder, `&mut`/livstider |
| `system` | en query + en kropp som kör över världen | ECS-system, manuella loopar |
| `query` | förstklassig deklarativ urval | manuell iteration |
| `require` / `ensure` | kontrakt → tester + körnings-checkar | asserts, separata tester |
| fotavtryck | `reads` / `writes`, **härlett** av kompilatorn | manuell schemaläggning |
| `region` | explicit minnesarena | allokatorer, `unsafe` |

(Ett 8:e koncept — `trait` — finns för generisk kod, men är opt-in och rör inte vanlig kod. Se §14.)

---

## 3. Inte OOP — vad vi förkastar och vad som ersätter det

OOP är fyra sammanvävda idéer. Orion byter var och en mot något snabbare *och* enklare
*och* mer AI-vänligt.

| OOP-pelare | Vad den ger | Orion istället |
|---|---|---|
| **Data + metoder ihop** | bekvämt, men kopplar beteende till en typ | `data` och `fn` är separata. Data har inga metoder. |
| **Inkapsling** (privat state) | döljer data | data är transparent (rader i en tabell). Skydd = **fotavtryck** (vem får `write`), inte gömmor. |
| **Arv / is-a-hierarki** | återanvändning via subtypning | **komposition**: en entitet *har* Position, Health. Has-a-fakta, ingen hierarki. |
| **Virtuell dispatch** (vtables) | polymorfism via dolda pekare | **polymorfism via struktur**: queryn väljer på vilka komponenter en entitet har. |
| **Pekar-identitet** (aliasing) | objekt = pekare | identitet = **nyckel** (Entity-id); värde-semantik lokalt. |

---

## 4. Minnesmodell

> **Status: genomförd.** Move-checkaren (`src/ownership.rs`) tvingar `take`-semantiken
> statiskt — använd ett flyttat värde och du får ett kompileringsfel med caret. Inga
> livstider behövs (se nedan varför).

Här ligger den centrala insikten som gör att Orion kan vara *både* C++-snabbt *och* clean:

> **Den relationella datamodellen ÄR den storskaliga minnessäkerheten.**

Cross-entity-referenser är **nycklar, inte pekare** (`owner: Entity` = ett id). Att följa
en referens = en lookup = `Option`. En inaktuell handle ger en **missad lookup (`None`)**,
inte en use-after-free. Det finns inga pekare mellan entiteter → den svåra aliasing-grafen
som gör Rusts borrow-checker jobbig **existerar inte** på den nivån.

Därför behöver minnesmodellen bara styra det **lilla**: beräkningen *inuti* ett system och
lagrets interna allokering. Där använder vi **value-semantik med lokala konventioner**
(inspirerat av Hylo/Val, men utan jargongen):

```orion
fn name_of(e: Entity) -> Text          # läsning = default, ingen keyword (90% av all kod)
fn heal(target: mut Health, n: i32)    # mut  = muterar på plats   (Hylos "inout")
fn equip(item: take Item)              # take = förbrukar/tar över  (Hylos "sink")
```

- Markera bara när du gör **mer än att läsa**. Läsning är osynlig.
- Kontrollen är **lokal** (per funktion) → inga livstidsannoteringar, ingen helprograms-
  inferens. Det är *därför* det är enklare än Rust.
- Codegen är identisk med Rust: `mut` → `&mut`, `take` → move, läsning → `&`. **Noll
  prestanda offrad.** Det enda Hylo-modellen kostar är mognad (forskningsstadium) — vi
  mildrar med en `raw`-flykt.

### Flyktvägar
- **`region frame { … }`** — explicit arena för frame-allokering och heta loopar, där du
  *väljer* manuell kontroll.
- **`raw`** — Rusts `unsafe`-motsvarighet: råa pekare för FFI mot C och intrusiva grafer.
  Värsta utfallet är "skriv lite `raw`", inte "kör fast".

---

## 5. Datamodell & layout

**Relationell, inte ECS.** Entiteter = rader, `data` = kolumner/relationer, refs = nycklar,
`system` = query. Det matchar Atlas, matchar 2026-tänket ("en ECS är egentligen en
in-memory-databas"), och är AI-vänligt (queries planeras som av en databas-optimizer).

### Layout-polymorfism (edgen över C++)
Det avgörande: **logiskt schema ≠ fysisk layout.**

```orion
data Position: x: f32, y: f32     # du skriver schemat EN gång
```

Kompilatorn väljer fysiken **per åtkomstmönster**, utifrån fotavtrycket:
- **SoA** (struct-of-arrays) för kolumn-iteration (klassiska system-loopen, SIMD-vänlig).
- **AoS** när hela entiteten rörs åt gången.
- **AoSoA** (block matchade mot SIMD-bredd) för heta loopar — det fysikmotorer skriver för
  hand idag.

I C++/Rust *är* din `struct` låst till AoS för alltid — representationen *är* språket. I
Orion är den ett kompilatorbeslut. Det är så du slår *typisk* C++/Rust: språket behåller
den semantiska informationen som C++ kastar bort.

`hot_columns`-hooken som Atlas redan har blir en **förstklassig kompilatorfas**, inte en
sidoанalys.

---

### Default-representation (beslutat)
Logiskt schema är fast; **fysiken väljer kompilatorn.** Default-modellen:
- **Arketyp-kolumnär** som grund — entiteter grupperas efter sin komponent-mängd i
  tabeller, varje komponent en tät SoA-kolumn. Bäst iterations-prestanda (det vanliga
  fallet), precis som Bevy/Flecs.
- **AoSoA-blockning** inom kolumner för heta SIMD-loopar (kompilatorn väljer, du skriver
  inget).
- **Sparse-set** för komponenter med hög churn (mycket add/remove) — upptäcks via
  användning/fotavtryck.

Du deklarerar `data` en gång; valet ovan är aldrig ditt om du inte vill (en hint finns,
men behövs sällan). `repr(c)` (§16) låser layouten för FFI-typer.

## 6. Fotavtryck → parallellism, layout, cache

Varje `fn`/`system`/`query` har ett **härlett fotavtryck**: vilka `data`-kolumner den läser
och skriver. Det står aldrig i koden men driver tre saker:

```orion
system move(dt: f32):
    for e with Position, Velocity:
        e.Position.x += e.Velocity.dx * dt
        e.Position.y += e.Velocity.dy * dt
    # kompilatorn härleder: reads {Velocity}, writes {Position}
```

1. **Parallellism** — schemaläggaren bygger konfliktgrafen ur fotavtrycken. Två system vars
   läs/skriv-mängder inte krockar kör parallellt. Det Bevy gör i runtime gör Orion i
   kompilering. (Atlas sköt upp parallellism — fotavtrycket är exakt det som låser upp den
   säkert.)
2. **Layout** — kompilatorn materialiserar de kolumner ett system rör (SoA), väljer AoSoA
   för SIMD-loopar.
3. **Cache / inkrementell omräkning** — vet man vad som lästes vet man när det måste räknas
   om. Driver också `orbit`s inkrementella build/test.

**`mut`/`take` på parameternivå och `reads`/`writes` på systemnivå är samma koncept på två
skalor.** Minnesmodellen och parallellitetsmodellen blir samma maskineri.

---

## 7. Kontrakt — intent som tester + garantier

```orion
fn damage(target: Entity, amount: i32):
    require amount > 0                  # → auto-genererat NEGATIVT test
    mut h = target.Health
    h.hp = max(0, h.hp - amount)
    ensure h.hp >= 0                   # → kontrakt + auto-genererat POSITIVT test
```

- `require` = förvillkor. `ensure` = eftervillkor.
- En rad är samtidigt **dokumentation, test och körnings-garanti**.
- `orbit test` kör de härledda kontrakttesterna tillsammans med dina skrivna.
- Edgen över Rust: fångar **logikfel**, inte bara minnesfel. Rust säger "pekaren är giltig";
  Orion kan dessutom säga "hp går aldrig under noll" — och verifiera det.

---

## 8. Numerik

Smart by default, exakt kontroll när du vill. Tre lager:

1. **Två defaults för 90 % av koden:** `int` (= `i64`) och `float` (= `f64`). Du tänker
   aldrig på bredd för vanlig kod.
2. **Kontext-styrda literaler, inga suffix:** `let r: u8 = 200` — literalen blir u8 och
   kompilatorn kollar att den får plats (200 ✓, 300 → kompileringsfel). Ingen `200u8`.
3. **Range/intent-typer (next-gen-draget):** deklarera *mening*, kompilatorn väljer
   maskintypen, fångar overflow och packar optimalt.

```orion
data Pixel:  r: 0...255, g: 0...255, b: 0...255   # → u8, tätt packat
data Person: age: 0...150                          # → u8, overflow statiskt fångad
data Health: hp: 0...1000                          # → u16
```

`i8`/`u32`/`f32`/… finns kvar för FFI, nätverkspaket, SIMD — men syns annars aldrig.

**Overflow-semantik** (det enda som inte går att lösa helt automatiskt): aritmetik på `int`
breddar/checkar by default; `wrapping`/`saturating` opt-in:as explicit när du faktiskt vill
ha det.

---

## 9. Determinism — en opt-in-egenskap, inte ett globalt läge

Floats *är* deterministiska per operation (IEEE 754). Icke-determinismen kommer från
kompilatorn (omassociering, FMA-kontraktion, fast-math, transcendentaler). Så vi begränsar
codegen där det behövs istället för att förbjuda float:

```orion
deterministic system physics_step(dt: f32):
    # kompilatorn förbjuder icke-reproducerbara float-ops här
    # (ingen omassociering, ingen FMA-kontraktion, mjukvaru-transcendentaler)
    # → lockstep-säkert för netcode/replay
    ...

system particles(dt: f32):     # ingen markör = full fart, fast-math tillåtet
    ...
```

`deterministic` är en **effekt kompilatorn spårar** — "detta system får bara anropa
deterministiska ops" är statiskt checkbart. Kraftfullare än Atlas (fart *och* determinism,
där du vill ha vardera) och renare (samma intent-maskineri). Atlas kan sen släppa sin
int-only-låsning och adoptera detta.

---

## 10. UFCS & comptime

- **UFCS — metod-syntax utan OOP.** `damage(target, 5)` och `target.damage(5)` är samma
  sak. Läsbar chaining utan ett enda objekt:
  ```orion
  target.damage(5).heal(2)     # = heal(damage(target, 5), 2)
  ```
- **Comptime istället för makron.** Metaprogrammering = vanlig Orion-kod som körs vid
  kompilering (Zig-stil). Ett mentalt språk, inte två.

(Iteration, fel-hantering, moduler och övrig syntax-smak: se §11.)

## 11. Bas-syntax

Offside-regel: indentering bestämmer block, inga klammrar, inga semikolon — samma smak
som Astras vyer.

### Bindningar & mutabilitet — inget `let`
`mut` är den enda modifieraren och betyder samma sak överallt (bindningar, parametrar,
fält). Immutabelt är default.

```orion
x = 5              # immutabel bindning (inget keyword)
mut y = 0          # muterbar
y = y + 1          # omtilldelning — ok, y är mut
x = 6              # FEL: x är immutabel
count: u8 = 200    # typ-annotering när du vill pinna den (annars härledd)
```

Kompilatorn skiljer bindning från omtilldelning på om namnet finns och är `mut`. Att
återanvända ett namn i *samma* scope är ett fel (typo-skydd); shadowing i nästlat scope
är ok.

### Funktioner — uttrycks- eller block-form, named + default args
```orion
fn double(x: int) -> int = x * 2          # uttrycks-form för enradare

fn damage(target: Entity, amount: int):   # block-form (offside)
    require amount > 0
    mut h = target.Health
    h.hp = max(0, h.hp - amount)

fn spawn(x: int, y: int, hp: int = 100)    # default-argument
spawn(x = 3, y = 4)                         # named call → hp blir 100
```

Named + default args *överallt* ersätter overloading, builder-pattern och
argument-ordnings-buggar — och gör anropet självdokumenterande.

### Uttryck & operatorer
```orion
a + b   a - b   a * b   a / b   a % b
a == b  a != b  a < b   a <= b
a and b   a or b   not a          # ord, inte && || ! → läsbart, AI-vänligt
0..<n     # exklusivt range (Swift-stil)    0...n   # inklusivt
"hp = {h.hp}, namn = {p.name}"              # sträng-interpolation
```

**Range är både värde och typ** — samma syntax:
```orion
for i in 0..<255:          # range som värde (iteration)
data Pixel: r: 0...255     # range som typ (begränsning → kompilatorn väljer u8)
```

### Kontrollflöde — `if` som uttryck, exhaustivt `match`, `for`/`loop`
```orion
label = if hp > 0 then "vid liv" else "död"     # if är ett uttryck

match state:                                    # exhaustivt
    Idle       -> wait()
    Walking d  -> step(d)
    Dead       -> despawn(e)
    # kompilatorn KRÄVER alla fall — missar du ett blir det kompileringsfel

for i in 0..<10:           # begränsad loop (range eller data — se nedan)
    ...

loop:                      # äkta obegränsad loop (event-loopar etc.)
    e = next_event() else break
    if e.handled: continue
    handle(e)
```

`for` är alltid begränsad. `loop:` är den enda obegränsade formen och kräver `break`.
`break`/`continue` finns i båda. Inget `while` — `loop: … break` täcker det och håller
formerna få.

### ⭐ Den enade comprehensionen — `for` = query = aggregat
En enda spine — `X with C where P` (eller `X in range`) — driver loopar, listor, queries
*och* aggregat:

```orion
# 1. system-loop (sidoeffekter via mut)
for e with Position, Velocity:
    e.Position.x += e.Velocity.dx * dt

# 2. lista (projektion)
names = [p.name for p with Player]

# 3. filtrerad lista
wounded = [e for e with Health where e.Health.hp < 100]

# 4. aggregat — samma spine, annat huvud
total = sum p.gold for p with Player
teams = sum p.gold for p with Player group by p.team    # → {Team: int}

# 5. range — samma spine
squares = [i * i for i in 0..<10]
```

En **query** är en namngiven, återanvändbar comprehension som planeraren får optimera
(markören = "read-only + planerbar"):
```orion
query wounded() -> [Entity] =
    [e for e with Health where e.Health.hp < e.Health.max / 4]
```

### Relationer — joins är fält-access
```orion
data Item: name: Text, owner: Entity     # owner = en nyckel = en relation
owner_name = item.owner.Player.name      # följ nyckeln med . (en implicit join, en lookup)
```
En "join" är att följa en nyckel med `.`. Eftersom det är en nyckel (inte en pekare) ger
`item.owner` på en borttagen entitet `none`, inte krasch.

### Optionals & fel — ingen null, inget dolt kontrollflöde
```orion
fn find(name: Text) -> Entity?           # ? i typen = kan saknas

e  = find("Kaelen") else return          # hantera på plats
hp = e?.Health.hp                        # ?. kortsluter till none
n  = parse(input) else 0                 # default-värde

match parse(input):                      # eller fullt match
    some v -> use(v)
    none   -> warn("ogiltigt")
```
Null avskaffat; fel är värden i signaturen, inte exceptions som hoppar osynligt genom
stacken.

### Moduler — fil = modul
```orion
use physics                  # importera en modul
use physics.collide          # eller en specifik del
pub fn step(dt: f32): ...    # pub = synlig utanför modulen (annars privat)
```
En fil *är* en modul, en mapp *är* ett paket. Ingen `mod.rs`, ingen `mod foo;` att hålla
synkad.

### Var vi är smartare
| Område | Andras problem | Orion |
|---|---|---|
| Bindningar | `let`/`var`/`const`-soppa | inget keyword; bara `mut`, konsekvent överallt |
| Iteration | `for`/`while`/`map`/`filter`/query | **en** comprehension-spine + `loop` för obegränsat |
| Range | separat från typer | range = både värde och typ |
| Numerik | manuell bit-bredd | range-typer → kompilatorn väljer |
| Args | overloading + builders | named + default args |
| Fel | null + exceptions | optionals + fel-som-värden |
| Joins | separat query-språk | följ en nyckel med `.` |
| Logik | `&& \|\| !` | `and`/`or`/`not` |
| Moduler | `mod.rs`/`mod foo;` | fil = modul |
| Matchning | `switch`-fallthrough | exhaustivt, fel vid kompilering |

---

## 12. Entiteter & världsmutation

```orion
e = spawn Position{x: 0, y: 0}, Velocity{dx: 1, dy: 0}   # skapa entitet med komponenter
e += Health{hp: 100, max: 100}                            # lägg till komponent
e -= Velocity                                             # ta bort komponent
destroy e                                                 # ta bort entiteten
```

- `spawn` returnerar en `Entity` (en nyckel). Komponenter ges som `data`-literaler.
- `+=` / `-=` lägger till / tar bort komponenter (strukturell ändring → kan flytta
  entiteten mellan arketyp-tabeller).
- Alla mutationer går genom **event-loggen** (Atlas-arvet): deterministisk replay,
  time-travel och fotavtrycks-driven inkrementell omräkning faller ut gratis.
- Inom ett `deterministic`-system är spawn-id deterministiska.

## 13. Query-språket

Hjärtat i motorn. Deklarativt → en **planerare** (som en databas-optimizer) väljer index,
filter-ordning och materialisering. Fotavtrycket driver parallell schemaläggning.

### Klausuler
```orion
all e with A, B          # urval: entiteter som HAR A och B
        without C        # ... men INTE C
        maybe D          # D valfri → e.D blir optional
where  <pred>            # filter
order by <expr> [desc]
take N    skip N         # begränsning
group by <expr>          # → en map
```

### Aggregat — samma comprehension-spine
```orion
count e with Enemy
sum   p.gold for p with Player
min / max / avg <expr> for ...
```

### Joins = följ nycklar
```orion
# "alla items och deras ägares namn"
[(i.name, i.owner.Player.name) for i with Item]
```
Planeraren använder Atlas reverse-index (`by_ref`) → joins blir O(matchningar), ingen scan.

### Change-detection (gratis ur event-loggen)
```orion
for e with added(Velocity):     # entiteter som FICK Velocity denna tick
for e with changed(Health):     # entiteter vars Health ändrats sedan förra körningen
```
Eftersom lagret är event-sourcat är "vad ändrades?" en billig fråga — grunden för reaktiv
och inkrementell omräkning.

### Planeraren
Du skriver *vad*; planeraren väljer *hur*: mest selektiva filtret först, rätt index
(`by_kind` / `by_tag` / `by_ref`), och om en kolumn ska materialiseras (SoA). Fotavtrycket
(`reads {Item.owner}`) → queryn kan köras parallellt med allt som inte skriver det.

## 14. Traits — generik utan hierarki

Den enda polymorfismen vi behöver, och den är opt-in. Inte arv, inte state-i-interface —
*ad-hoc polymorfism* (Rust traits / Haskell typeclasses), default **statiskt dispatchad**
(noll kostnad).

```orion
trait Drawable:
    fn sprite(self) -> Sprite          # krav

impl Drawable for Position:            # implementera för en data-typ
    fn sprite(self) -> Sprite = ...

fn render(x: impl Drawable):           # generisk → monomorfiseras → noll kostnad
    draw(x.sprite())

things: [dyn Drawable]                 # runtime-dispatch NÄR du vill (opt-in vtable)
```

`impl Drawable for Position` är *inte* OOP — det buntar inte data med beteende, det säger
"den här datatypen uppfyller den här förmågan". Default monomorfiseras; `dyn` ger
runtime-dispatch bara när du explicit ber om det.

## 15. Concurrency

Tre nivåer, **ingen `async`/`await`-färgning** (function-coloring-problemet undviks helt):

1. **Implicit system-parallellism** — schemaläggaren kör system med disjunkta fotavtryck
   parallellt automatiskt. Du skriver inget.
2. **`parallel for`** — explicit data-parallellism inom ett system; säkert för att
   fotavtrycket garanterar att iterationerna inte krockar:
   ```orion
   parallel for e with Position, Velocity:
       e.Position.x += e.Velocity.dx * dt
   ```
3. **Strukturerad concurrency** för bakgrundsjobb (IO, laddning):
   ```orion
   scope:
       a = spawn job load("level.dat")
       b = spawn job load("sounds.dat")
       use(a.await, b.await)        # alla jobb joinas när scope avslutas
   ```

**Ordning mellan system** härleds default ur databeroenden (fotavtryck); explicit
`before` / `after` när du behöver en ordning trots disjunkta data:
```orion
system ai() before movement: ...
```

## 16. FFI & raw

Table stakes för att ersätta C++ och återanvända C-bibliotek:
```orion
extern "c" fn sqrtf(x: f32) -> f32           # anropa C
pub extern "c" fn orion_step(dt: f32)        # exportera till C

data Vec3 repr(c): x: f32, y: f32, z: f32    # C-kompatibel layout (låser layout-polymorfism)

raw:                                          # råa pekare, FFI, intrusiva grafer
    p = alloc(64)
    ...
```
`raw` är inneslutet (som Rusts `unsafe`); allt utanför förblir säkert. Värsta utfallet är
"skriv lite `raw`", inte "kör fast".

## 17. Verktyg — `orbit`

Cargo är halva anledningen folk älskar Rust. Orion måste ha motsvarigheten: **ett verktyg**,
**en manifest**, en lockfil, konventioner över konfig.

```
orbit new spelet      orbit build      orbit run
orbit test            orbit fmt        orbit add fysik@1.2
```

Två intent-drivna bonusar Cargo inte har:
- **`orbit test`** kör de auto-genererade kontrakttesterna (från `require`/`ensure`)
  tillsammans med dina skrivna — ett testbatteri gratis ur intentet.
- **Fotavtrycks-medveten inkrementell build/test** — bara det som faktiskt påverkas byggs om
  och testas om.

**Filändelse:** `.or`. **Paket-term:** en *orb* (det som ligger i omloppsbana runt Orion).
`orbit add fysik` hämtar en orb. (Båda bikeshed-bara, men beslutade.)

---

## 18. Sammanhängande exempel

```orion
# data, inte objekt — schemat skrivs EN gång
data Position: x: f32, y: f32
data Velocity: dx: f32, dy: f32
data Health:   hp: 0...1000, max: 0...1000

data Item:   name: Text, owner: Entity      # owner = en nyckel = en relation
data Player: name: Text, gold: int

# ett system = query + kropp. fotavtrycket härleds → parallellism + SoA-layout.
system move(dt: f32):
    for e with Position, Velocity:
        e.Position.x += e.Velocity.dx * dt
        e.Position.y += e.Velocity.dy * dt

# kontrakt = intent → tester + garanti. mut = lokal skrivning.
fn damage(target: Entity, amount: i32):
    require amount > 0
    mut h = target.Health
    h.hp = max(0, h.hp - amount)
    ensure h.hp >= 0

# queries är förstklassiga och deklarativa — planeras som en databas.
query inventory(p: Entity) -> [Entity]:
    all i with Item where i.Item.owner == p

query richest() -> [Entity]:
    all p with Player
    order by p.Player.gold desc
    take 10

# skapa en entitet
fn spawn_player(name: Text) -> Entity =
    spawn Player{name: name, gold: 0}, Position{x: 0, y: 0}, Health{hp: 100, max: 100}

# data-parallell loop — säker tack vare fotavtrycket
parallel for e with Position, Velocity:
    e.Position.x += e.Velocity.dx * dt

# reaktivt: bara det som ändrats
for e with changed(Health) where e.Health.hp == 0:
    destroy e

# determinism opt-in där lockstep krävs.
deterministic system physics_step(dt: f32):
    ...
```

---

## 19. Roadmap & bootstrapping

Designen är nu komplett (v1). Nästa fas är att göra den körbar.

### Kompilator-strategi
- Skriv kompilator **v0 i Rust**, återanvänd Astras pipeline-struktur:
  `lex → parse → check → eval`. Astra är en beprövad mall för exakt den formen.
- **Backend:** Cranelift för debug/snabb iteration, **LLVM** för release (C++-klass
  prestanda, SIMD, layout-polymorfism). Samma split som Rust.
- **Self-host** senare (skriv Orion-kompilatorn i Orion) när språket bär sig självt.

### Milstolpar
1. **M0 — Lexer** ✅ — bas-syntaxens tokens, offside-kolumner. (`src/token.rs`, `src/lexer.rs`)
2. **M1 — Parser** ✅ — `data` + `fn` → AST, precedensklättring, offside-block.
   (`src/ast.rs`, `src/parser/`) (`system`/`query`/`for`/`match` kommer i M3.)
3. **M2 — Checker + interpreter** ✅ — semantisk check (scope, mutabilitet =
   bindning-vs-omtilldelning, arity) + en tree-walking-interpreter för rena funktioner
   (aritmetik, `if`, rekursion, builtins, kontrakt). (`src/check.rs`, `src/interp.rs`,
   `src/value.rs`) Kvar för senare pass: djupare typinferens (numerisk vs bool, range-typer,
   optionals), fotavtrycks-härledning, spans i fel.
4. **M3 — Relationell store + query-språket** ✅ — in-memory store (`src/store.rs`),
   `system`/`query`-deklarationer, `for … with … where`, comprehensions
   `[e.X for e with C where p]`, `spawn`/`destroy`, fält-läs/skriv `e.Comp.field`,
   block returnerar sitt sista uttryck. (Kvar: `match`, `order by`/`group by`/aggregat,
   `parallel`/`deterministic`-modifierare, footprint-härledning.)
5. **M4 — Codegen (Cranelift JIT)** ✅ — uttrycks-funktioner kompileras till native
   maskinkod: aritmetik, `if`, jämförelser, rekursion, anrop, **och floats (f64) + `sqrt`
   med int→float-promotion** (M4.1, via typinferens i codegen). `src/jit.rs`. Mätning:
   `fib(35)` ~400× snabbare än tolken. (Kvar: store-åtkomst + fler builtins i JIT.)
6. **M5 — Fotavtryck + layout + parallellism** ✅ — (a) fotavtrycks-härledning +
   parallella batches (`src/footprint.rs`); (b) layout-planerare SoA/AoS (`src/layout.rs`);
   (c) **äkta trådparallellism**: JIT:ad kod över alla kärnor (`parbench`, ~26,8× på
   `fib(35)×32`) *och* data-parallell ECS över en kolumnär SoA-värld (`src/parallel.rs`,
   `parrun`) — 20M entiteter, parallellt resultat identiskt med sekventiellt. (AoSoA/SIMD =
   M7.)
7. **M6 — `orbit`** ✅ — projektverktyget (`src/bin/orbit.rs`): `new`/`build`/`run`/`test`/
   `fmt`. `orbit test` kör kontrakt-bärande `test_*`-funktioner. (`add`/incremental builds
   senare.)
8. **M7 — AOT + SIMD (väg 1)** 🟡 — (a) **AOT till native objektfil**: samma codegen
   (`jit::compile_into`, generisk över Cranelift `Module`) driver både JIT och objekt-backend
   (`src/aot.rs`, CLI `aot`) → giltig x64 COFF-`.o`. (b) **Manuell SIMD utan LLVM**
   (`src/simd.rs`, CLI `simd`): Orion genererar en vektoriserad `F64X2`-loop (SSE2) + skalär
   rest för system-kärnor över SoA-kolumner; `integrate`/50M → 7,2× vs den tolkade skalära
   referensen (kombinerar native-vs-tolkad + 2-lane SIMD), bit-exakt resultat.
   (c) **AoSoA-layout + SIMD-codegen** (`src/aosoa.rs`, CLI `aosoa`, W=2): block =
   alla fält för 2 entiteter (en cache-rad); padding istället för rest. **Ärligt fynd:**
   för den rena streaming-kärnan `integrate` blev AoSoA *långsammare* (~0,33×) än SoA —
   SoA:s sekventiella per-kolumn-ström prefetchas bättre; AoSoA vinner på lokalitets-/
   gather-tunga mönster, inte streaming. Detta *bekräftar* layout-polymorfism: ingen layout
   är universellt bäst → kompilatorn måste välja per åtkomstmönster.
   (d) **Layout-väljare + empiriskt test** (`src/select.rs`, CLI `select`/`gatherbench`):
   klassificerar streaming vs gather → väljer SoA/AoSoA. **Andra överraskande fyndet:**
   gather-benchmarken visade AoS *20× LÅNGSAMMARE* än SoA på random access (40M läsningar)
   — alltså föll även lärobokstumregeln "AoS vinner gather" (troligen SoA:s oberoende
   läsströmmar → mer memory-level-parallelism). **Lärdom:** layout-prestanda trotsar
   tumregler → en riktig väljare måste *mäta*, inte gissa. (e) **Mätstyrd väljare**
   (`select::choose_measured`, CLI `select`): kompilerar BÅDA layouterna, kör kernel-only
   bench på en sampling, väljer den snabbare. Verifierat: `integrate` → SoA 16 ms vs
   AoSoA 26 ms → väljer SoA. Detta *är* layout-polymorfism i praktiken: kompilatorn äger
   och mäter beslutet.
   **Kvar:** **LLVM-backend** (valfri — auto-vektorisering + max-optimering); gather-*kärnor*
   i grammatiken (fler mönster att välja mellan); determinism-constrained codegen;
   länka `.o` → exe.

### Kvarvarande detaljbeslut (icke-blockerande)
- Exakt hint-syntax för layout-override när man *vill* styra fysiken.
- Sträng-typ: `Text` (ägd) vs vyer/slices — minnesmodell för strängar.
- Standardbibliotekets yta (matte, kollektioner) — vad är inbyggt vs en orb.
- Felmeddelande-format (intent-drivna, AI-läsbara diagnostik).
