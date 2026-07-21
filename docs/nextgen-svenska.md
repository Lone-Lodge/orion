# Orion — nästa-gen plan (svensk spec)

Konkreta, exekverbara specar för de fyra riktningar Johan godkände. Skrivet
i `NEXTGEN.md`-idiom: varje punkt är en skiva med fil-för-fil-ordning och en
gate, eller en ärligt scopad designfråga.

**Var koden bor (viktigt):** `when` / `derive` / `belief` / `fact` är
**astra** (DSL) och det reaktiva nätet är **atlas** (motorn) — separata repon.
Det här repot (`orion`) är språket + kompilatorn och, precis som `NEXTGEN.md`
visar, planeringshemmet. Punkt 1 och 4 nedan är orion-språk; punkt 2, 3 och 5
är astra/atlas-specar redo att portas när de repona finns i sessionen.

Genomgående regel (bevisad i hela `NEXTGEN.md`): **den rena omtolkningen slår
det tunga bygget.** Ren parser-sugar, ingen core-enum-kirurgi, varje skiva
gate-bevisad — det är vägen med minst risk för fel.

---

## Punkt 3 (KISS) — `fact`: slå ihop fem nyckelord till ett

**Idé (från tre-agent-auditen):** `derive`, `goal`, `constraint`, `belief`,
`confidence` gör alla samma sak — de deklarerar en sanning i en namespace.
En primitiv ersätter dem:

```orion
fact alive  = health > 0                 # ersätter: derive alive = health > 0
fact reach  = score > 100     in goal     # ersätter: goal reach = score > 100
fact wet    = water > 0       in broken   # ersätter: constraint wet = ...
fact enemy_at = 3  in belief:Guard  conf 73   # belief + confidence i ETT
```

En regel att lära, inte fem. All befintlig desugaring återanvänds.

### Desugaring (bevisad mekanik — inget nytt i runtime)

| `fact`-form | desugarar till (befintlig väg) |
|---|---|
| `fact N = E` | `SetVar(N, E)` varje tick (som `derive`) |
| `fact N = E in goal` | `SetVar("goal:N", E ? 1 : 0)` |
| `fact N = E in broken` | `SetVar("constraint:N", E ? 1 : 0)` |
| `fact N = V in belief:B` | `SetVar("belief:B:N", V)` |
| `... conf C` (suffix) | extra `SetVar("conf:N", C)` |

Alla fem målformerna är redan skeppade och gate-bevisade individuellt — `fact`
lägger bara EN parser-gren som väljer namespace-prefix. Noll runtime-risk.

### Exekvering (astra, fil-för-fil — mönster som A1)

1. `astra_lexer/lib.or` — lägg `Fact` i `Tok`-enum; `keyword_of` mappar
   `"fact"` → `Fact`. Lägg `In` + `Conf` om de inte finns (spegla `Const`).
2. `astra_parser/lib.or` — `parse_fact_decl`: läs `NAMN = UTTRYCK`, sen
   valfritt `in NAMESPACE` och valfritt `conf N`. Återanvänd
   `parse_prefixed_derive` för prefix-valet (goal/constraint/belief redan
   där). Lägg `Fact`-gren i top-level `parse_belief_goal_or_rule`.
3. **Behåll de gamla nyckelorden som alias** — `derive`/`goal`/`constraint`/
   `belief` fortsätter parsa (peka på samma desugar-funktioner). Ingen befintlig
   bundle går sönder; `fact` är den nya, rekommenderade stavningen.
4. **Ingen** `astra_run`/`atlas_project`-ändring — desugaringen landar i
   redan-trådade rule-former. (Det är hela poängen med omtolkningen.)
5. Gate `st_fact`: en bundle med alla fem formerna via `fact`; verifiera att
   facten hamnar i rätt namespace (`goal:reach`, `belief:Guard:enemy_at`,
   `conf:enemy_at`) och att `derive`-aliaset ger identiskt resultat.

**Scope: S.** Ren sugar, alias-bakåtkompatibelt, ingen runtime-yta.

---

## Punkt 2 (Smartare) — det reaktiva nätet

**Problem idag:** `derive`/`fact` räknar om VARJE tick, även när ingen input
ändrats. Det är både fejk-deklarativt (beskriver steg, inte sanning) och en
lag-källa (per-tick churn).

**Fix:** räkna om en `fact` bara när en dep den LÄSER faktiskt ändrats. Datan
finns redan — `facts.reads` (uttryckets läs-set) och motorns changed/added/
removed-maps per tick. Ingen ny primitiv.

### Exekvering (atlas — `run_sims`)

1. Vid compile: för varje `fact N = E`, spara `reads(E)` (finns i facts-passet).
2. I `run_sims`, före omräkning: slå upp motorns "vad ändrades denna tick"-set.
   Om `reads(E) ∩ changed == ∅` → **hoppa över** omräkningen av `N`.
3. Behåll ett `dirty`-flöde: en fact som skrivs blir själv en `changed`-post,
   så kedjor (`fact b = a`, `fact c = b`) propagerar korrekt inom samma tick
   (topologisk ordning från facts-grafen, som redan finns för `orbit schedule`).

### Korrekthetskrav (det enda som gör detta icke-trivialt)

En fact är bara skippbar om den är **ren** (inga sido-effekter utöver sin egen
`SetVar`) och inget hänger på att effekten *återemitteras*. Orion bevisar redan
renhet (`orion facts`, 249/272 rena) — använd den bevisningen som gate: skippa
bara facts som passet flaggar rena. Orena regler kör som förr.

- Gate `st_reactive`: `fact alive = health>0`; tick utan att röra `health` →
  ingen omräkning loggas (räknare på skip-vägen), men `alive` behåller värdet;
  rör `health` → exakt en omräkning. Cubsy-soak: bit-identisk (ren optimering).

**Scope: M, hot-path-omsorg.** Rekommenderat NÄSTA bygge i `NEXTGEN.md` — det
förvandlar den största fejk-deklarativa biten till äkta deklarativ OCH är en
lag-vinst i samma slag.

---

## Punkt 4 (Minnessäkert) — mer next-gen än Rust, ärligt

Rust köper minnessäkerhet med en **borrow checker** och livstidsannoteringar
(`'a`) — säkerhet mot en annoterings-skatt. Orion har redan ett annat, nyare
svar (auditen erkänner det som en av få genuina nyheter): **regioner + auto-
inferrerade footprints.** Ingen `'a`, ingen borrow checker.

Dagens modell (`PRINCIPLES.md`) är **dynamisk**: fyra livstider (epoch/frame/
ring/persist), reset förgiftar minne, en missad `persist` *kraschar
deterministiskt* istället för att läcka. Säkert — men felet fångas vid körning.

**Next-gen-steget: flytta samma garanti till KOMPILERINGSTID.**

### Verklighetskoll (kod-grundad, 2026-07-06)

Efter att ha läst kompilatorn: **region-modellen finns INTE i språket.** De fyra
livstiderna bor helt i C-runtimen (`runtime/orion_rt.c`), anropade via
`extern fn orion_arena_on/off/reset/reset` från `orion_ir/lib.or`. Footprint-/
renhets-analysen (`orbit facts`) är **atlas**-verktyg, inte språket. Kompilatorns
typkontroll och IR (`data Inst: op, type_text, value, lhs, rhs, name, args` i
`orion_ir/lib.or`) bär **ingen** region-information alls, och
`orion_arena_ptr_guard` är en *runtime*-varning i C — inte en kompileringstids-
check.

Konsekvens: det finns inget footprint-pass i språket att "utöka". Att göra
region-säkerheten statisk kräver att man **inför region-som-typ** i orion från
grunden — en L-arc, inte en M-tweak. Den ärliga minsta första skivan nedan.

### ⚠️ Verklighetskoll 2026-07-09 — region-seeden är HÅLIG idag

Efter att ha grävt i koden: **region-som-typ (skiva 1 nedan) ger en hålig
feature just nu, inte "ren infrastruktur".** Tre konkreta fynd:

1. **`data Inst` har 91 konstruktions-ställen.** Ett `region`-fält måste sättas
   på alla 91 (Orion tillåter ingen partiell struct-konstruktion). Stor,
   mekanisk, bred ändring — inte en "seed".
2. **Det finns ingen STATISK region-*källa* att propagera FRÅN.**
   `orion_arena_on/off/reset` är `extern`-deklarerade men **används ingenstans**
   i riktig kod, och `scope:` (den tänkta statiska region-gränsen) är en av de
   **döda kulisserna** (parsar inte). Så fältet skulle alltid vara `0=okänd` —
   inget att sätta det till, inget att kontrollera mot.
3. Slutsats: skiva 1+2 kräver **först en statisk region-källa** (antingen en
   annotering, eller att `scope:` blir riktig syntax som statisk arena-gräns).
   Det är designarbete doc:et sa att vi skulle undvika — så den *ärliga* minsta
   vägen är inte region-fältet.

**Den välgrundade minnessäkerhets-skivan är istället `move`/linjära värden
(skiva 2b nedan).** Den behöver ingen arena-inferens och ingen statisk
region-källa: `push_mut`:s alias-löfte är idag en *människo-audit-not* (osäkrad)
— gör det kontrollerbart med en linjär `move`-binding. Lokalt, bevisbart,
demonstrerbart. **Rekommenderad start för Punkt 4.**

### Riktning (i skivor, minst risk först — omskattad mot verkligheten)

1. **Region-som-typ, minimal seed.** *(Se verklighetskollen ovan — hålig utan en
   statisk region-källa; börja INTE här.)* Ge `data Inst` ett `region`-fält
   (0=okänd, 1=frame, 2=ring, 3=persist). Förutsätter en statisk region-källa
   som inte finns än. Skiva: L (inte M–L). *Berör:* `orion_ir` (91 ställen) +
   `orion_ast_to_ir`.

2. **Statisk region-escape-check (kräver #1).** När region-fältet finns: flagga
   när ett `frame`/`ring`-värde lagras i ett `persist`-scope — det
   `orion_arena_ptr_guard` idag *varnar* om i runtime blir ett **kompileringsfel**
   via `compile_error(...)` (finns redan i `orion_ir/lib.or:81`). Poison-kraschen
   kvar som skyddsnät. Skiva: M, *ovanpå #1*.

2. **`move`/linjära värden för ägda ackumulatorer.** Idag är `push` värde-
   semantisk och `push_mut` en *audit-not vid anropsstället* (människan lovar
   ingen alias). Gör löftet kontrollerbart: markera en binding `move` (linjär —
   får användas exakt en gång), så kompilatorn *bevisar* att ingen live alias
   finns istället för att lita på noten. Det är Hylo-stil move-semantik utan
   Rusts fulla lånemaskineri, för footprints redan känner alias-grafen. Skiva: L.

3. **Region-polymorfism i signaturer, inferrerad.** `fn f(x) -> y` där
   kompilatorn *härleder* att `y` ärver `x`:s region — aldrig skrivet av
   användaren. Det är Rusts livstidsinferens, fast total: annotering är aldrig
   det normala fallet, bara en override när inferensen är osäker.

**Ärlig kalibrering:** typsystemet i övrigt är läroboks (auditen kallar det
"textbook") — sälj inte in det som magi. Vinsten som gör Orion nyare än Rust
här är att **säkerheten är auto-inferrerad från footprints, inte annoterad.**
Det är det enda stället där det är motiverat att *bredda* språket, för det köper
säkerhet — inte bekvämlighet.

---

## Punkt 5 (Mindre for, minst risk) — gör `when` mer next-gen

`when` (kant-utlöst regel) är redan den bästa for-loop-ersättaren: du beskriver
*villkoret*, motorn kör effekten när det blir sant. Att göra det mer next-gen
= göra det svårare att skriva fel, med samma låg-risk-recept (ren sugar, gate
per skiva):

### a) Uttömmande `when` — kompilatorn varnar för ohanterat tillstånd

Orion har redan uttömmandekontroll på `match` (utan wildcard krävs alla
varianter). Ge `when` samma: när ett block grenar på en enum/tillstånd och en
variant saknar en `when`, **varna**. For-loopens tysta "glömde ett fall" dör
som kategori — samma trygghet du redan har i `match`, nu i regel-lagret.

```orion
enum Door: Shut, Open, Locked
when door is Shut  and knock: door becomes Open
when door is Locked and knock: emit thud
# kompilator: varning — 'Open' saknar en when-gren
```

### b) `when` över relationer och beliefs (ingen manuell iteration)

Relationsfrågan (`when npc hates player`) och belief-frågan är redan scopade i
`NEXTGEN.md` (A3-query, B1). Med dem loopar du aldrig över entiteter för att
hitta "vilka hatar spelaren" — du deklarerar villkoret och motorn matchar. Det
är den största konkreta "mindre for"-vinsten och den är låg-risk (host-agnostisk
eval + ctx-injektion, designen redan bestämd i A3).

### c) Ersätt nästlade if-guards med `when` + `fact`

```orion
# Klassiskt (nästlade steg — lätt att missa ett fall):
mut score = 0
for tile in tiles:
    if tile == Loot:
        if roll > 95: score += 500
        else: if roll > 80: score += 100

# Next-gen (villkor som sanningar — inga loopar, inga nästlade if):
fact big_loot = tile is Loot and roll > 95
when big_loot: score becomes score + 500
```

### Låg-risk-principen (varför det här är rätt väg)

Varje bit ovan är **ren parser-sugar** ovanpå redan-skeppade vägar (`match`-
exhaustiveness finns; relate/belief finns; `becomes`/`derive` finns). Ingen
core-enum-kirurgi, varje bit en gate-bevisad skiva. Det är exakt mönstret som
gjorde `after`/`belief`/`confidence` till S istället för M i `NEXTGEN.md` —
minst yta, minst risk för fel.

---

## Ordningsförslag (minst risk → störst arkitektur)

| # | Bygge | Repo | Scope | Risk |
|---|---|---|---|---|
| 3 | `fact`-konsolidering (+ gamla som alias) | astra | S | låg (ren sugar) |
| 5a | Uttömmande `when` (varning) | astra | S | låg |
| 5b | `when` över relationer/beliefs | astra+atlas | M | medel (A3-design klar) |
| 2 | Reaktivt nät (skip via facts.reads) | atlas | M | medel (hot-path + renhet) |
| 4.1 | Region-som-typ (seed) → escape-check | **orion** | M–L | medel (INGET region-pass finns än — bygg från grunden) |
| 4.2 | `move`/linjära ägda värden | **orion** | L | hög (nytt i typsystemet, kräver 4.1) |

Punkt 1 (AI-vänligt: "koden ska vara enklare") är inte en separat rad — den är
*resultatet* av alla ovan: beskriv sanning (`fact`), inte steg; låt motorn välja
när (`when` + reaktivt nät); låt kompilatorn fånga felen (uttömmande + region-
check). Enklare kod är utfallet, inte en feature.

---

## Att bygga detta på riktigt — byggblockeraren

Punkt 3, 5 och 2 kräver **astra**- och **atlas**-repona (koden bor där). Punkt 4
är orion-språk och hör hemma i det här repot.

> **✅ LÖST 2026-07-09:** Blockeraren nedan gäller inte längre.
> `tools/seed/orion.ll` **är incheckad i git**, och
> `tools/bootstrap_from_ll.sh` bygger `dist/orion.exe` från den på en frisk
> klon (retargetar Windows-triplet → host, länkar med clang). Alla byggvägar
> (`self_bootstrap.sh`, `build_orbit.sh`, `test.sh`) fungerar i web-sessionen —
> ~10 kompilator-ändringar har fixpunkt-bevisats här den här veckan. Punkt 4 är
> alltså byggbar och gate-bevisbar här. (Texten nedan behålls som historik.)

**MEN (historik):** i en web-session går kompilatorn inte att bygga eller köra. Varje
byggväg (`tools/build_orbit.sh`, `tools/self_bootstrap.sh`, `tools/test.sh`)
kräver en existerande `dist/orion.exe` — men `dist/` är gitignorerad, ingen
binär är incheckad, och Rust-bootstrappen (lodge-orion) är arkiverad/borttagen.
clang finns, men inget producerar LLVM-IR:n utan orion.exe, och ingen bootstrap
skapar den första. Så en ändring i den självkompilerande kompilatorn kan inte
**gate-bevisas** här — och repots disciplin är gate-bevisade skivor.

För att kunna bygga punkt 4 i en web-session, ett av dessa måste ordnas först:
1. **Checka in en seed-`orion.exe`** (eller en frisläppt binär) som byggvägarna
   kan utgå från — då blir `build_orbit.sh` → `test.sh` körbara här.
2. **Återinför en minimal bootstrap** (t.ex. behåll en frusen `orbit.exe` från
   den sista gröna byggen) så första IR:n kan produceras.
3. Annars: språk-kompilator-arbete sker på en maskin som redan har `orion.exe`;
   den här sessionen levererar den kod-grundade specen ovan, redo att portas.

Tills dess är detta dokument den ärliga planen: specarna är skrivna mot riktiga
funktioner (`compile_error` i `orion_ir/lib.or:81`, `data Inst`, `orion_arena_*`)
så att bygget blir mekaniskt när verktygskedjan finns.
