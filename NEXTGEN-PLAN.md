# Orion Next-Gen: hela arbetsplanen

## BYGGSTATUS (2026-08-02)
- **Runda A KLAR:** ett strängbibliotek (os.str_* borta), `println` borta, `push_mut` borta från ytan (internt `__push_inplace`; promotion lärde sig `slice()` är färsk; två handgranskade cross-function-helpers explicit in-place). Bench inom 25%.
- **Runda B KLAR (alias + corpus):** `define`/`edit`/`public`/`external`/`choose`/`collect` som parser-alias; `truth`/`table`/`text` typalias; HELA corpus (orion+atlas+astra+veil+fireplace) migrerat till v2-orden. Kompilatorn självhostar på v2-källa, seed regenererad. Gamla ord GILTIGA än - retirement när allt verifierats.
- **Ordoperatorer KLARA:** `is`-familjen, `to`/`until`, `then`-armar, `try`. **`where` ÅTERINFÖRD.**
- **`number` KLAR:** `/` är riktig division överallt (10/4 = 2.5), `//` är heltals/golv-division, `number` = typnamnet. Corpus migrerat lint-assisterat (233 sajter + 13 handfixade).
- **V1 RETIRERAT:** `fn`(deklaration)/`mut`/`pub`/`extern`/`match`/`yield` + `Text`/`Map`/`bool` ger nu tydliga fel som namnger ersättaren. Språket talar BARA v2-ytan.
- **Kvar (features):** named args, defaults, lätt lambda `(n):`, if-uttryck-värde, `given`, `list of T`, stdlib-renames (append/each/keep/combine, ett print, ett assert, arguments, main utan exit-kod). Sen temana.

Allt vi vill göra, samlat, INNAN vi bygger. Status per punkt:
**KLART** · **BESLUTAT** (bygg-redo) · **ÖPPET** (kräver ditt beslut) · **RESEARCH** (senare/oklart).

Vokabulären (Tema 1) har egen fil: `docs/SYNTAX-INVENTORY.md`.

**Docs-konsolidering (2026-08-02):** docs/ = field guide (`index.html`, visar v2-målbilden som `data-or2`-block) + `SYNTAX-INVENTORY.md` + genererad `reference.html`. `sv.html` arkiverad (en andra översättning driftar per konstruktion). **SKULD ATT ÅTERVÄPNA:** `docs_check.sh` kompilerar inte v2-blocken än - varje block flippas tillbaka till `data-or` (och återfår gaten) när dess syntax landar i migrationen.

## Alla beslut fattade (2026-08-02)
- **T3 `number`:** ja (yta). Range-typer: nej nu.
- **T4 Effekter som ryggrad:** JA, hela vägen (rand+tid → nät → file/print).
- **T5 Determinism:** fixed-point-läge för simulering; floats lovas ej cross-platform.
- **T6 Docs-som-tester:** OBLIGATORISKT (bygget failar utan exempel).
- **T2 tids-system:** bygg ETT nytt enat. **closure-orb:** radera. **`pi()`:** fixa const-över-orb. **map-generics:** fixa (typad `get()`). **JSON:** ett API (Runda C).
- **T7 typade fel:** senare. **traits:** trait-socker ovanpå op-passing. **lazy iterators:** bygg. **minnesmodell:** värde + uniqueness-in-place (Roc-modellen), dokumentera. **Unicode:** senare.
- **Vokabulär (T1):** se docs/SYNTAX-INVENTORY.md - inkl. `fn`→`define`, `match`→`choose`, `yield`→`collect` (läsbarhet för icke-programmerare).

## Sista designhålen STÄNGDA (2026-08-02) - formen för varje beslut
- **T4 effekt-yta:** `uses`-klausul i signaturen (`public define save(w) uses files:`). Standard-capabilities: `console`, `files`, `net`, `clock`, `random`. Privata + `main` inferreras; publika skriver kontraktet. Ingen klausul = ren.
- **T5 fixed-point-yta:** rider på `deterministic` - i deterministisk kod väljer kompilatorn fixed-point för bråktal → bit-exakt cross-platform. Ingen ny syntax.
- **T6 docs-som-tester-yta:** `example`-rader under signaturen (`example clamp(15, 0, 10) is 10`), kompileras + körs av bygget, renderas i referensen.
- **Datadrivet by default:** `store`-orb i stdlib (id → record; `insert`/`remove`/`get`; `loop ... where` är queryn). Värde-semantik förbjuder redan objektgrafer. Kompilatorägd SoA-layout = senare optimering. (Matchar beslutet att ECS bor i biblioteket.)
- **Lazy iterators-semantik:** fusion - `each`/`keep`/`collect`-kedjor bygger inga mellanlistor, samma svar som steg-för-steg. Evalueringsstrategi ägs av kompilatorn, ingen semantikändring.
- **Trait-socker-yta:** capability = record av funktioner (`type order given item: less: (item, item) -> truth`); `requires order` på en generisk define; anropet skickar recorden som named arg. Synlig dictionary-passing, ingen resolution-magi.
- **Float-formattering:** `to_text(x, decimals: 2)` - named args + defaults täcker det, ingen ny syntax.

---

## Redan byggt (planera inte om)
- Sized types `i8..u64` + `f32/f64`, `x as T`, literal-range-check. **KLART**
- `Result<T>` / `Option<T>` är riktiga generiska sumtyper, `?`-propagering. **KLART**
- Effekter (one-shot `perform`/`handle`/`resume`); multi-shot experimentell. **KLART**
- push in-place-promotion (så `push_mut` är historik, inte nödvändighet). **KLART**
- Slice 1: text/list-predikat → bool, LSP fixad, test.sh 164/164. **KLART**

---

## Tema 1 - Vokabulär (surface) · BESLUTAT
Se `SYNTAX-INVENTORY.md`. `number`, `text`, `table`, `truth`, `edit`, gemener,
`public`/`external`/`compile_time`, `combine`, `add`, `xs[i]`, `size`→`len`,
`println` bort. Tre rundor: A säker städning, B typ-migration, C API.

## Tema 2 - Stdlib-koherens (ett ord/begrepp) · mest BESLUTAT
- **Ett strängbibliotek**: radera `os.str_*`, peka `orbit.or` på `text`. (Slice 2, rör bootstrap.)
- **`println`/`push_mut`-dubbletter bort.**
- **`f`-tal-dubbletterna** (`fabs`/`fmin`/`fmax`/`fclamp`, `vec_addi`) → dör med `number` (Tema 3).
- **`pi()` som funktion** → const som korsar orb-gräns (språkbegränsning som blev API). **ÖPPET**: fixa const-över-orb, eller acceptera fn?
- **`closure`-orben** (env+fn_id läcker ut som API fast språket har lambdas) → radera. **ÖPPET**: bekräfta borttagning.
- **Tre tids/task-system** (`async` + `scheduler` + `timer`) → ett. **ÖPPET**: vilket är kärnan?
- **Dubbel-JSON-API** (`j*` sumtyp vs `json_*` map) → ett. **ÖPPET** (visar koden i Runda C).
- **Typade map-getters** (`get_int`/`get_list`/...) → generics över map-värden. **ÖPPET** (kopplat till den kända dynamiska-map-luckan).

## Tema 3 - `number` (next-gen numerik) · BESLUTAT (yta) + RESEARCH (djup)
- Kollapsa `int`+`float` → `number` som surface-fasad ovanpå befintliga sized types. `/` riktig, `//` golv. **BESLUTAT**
- Kompilatorn äger bredd/repr under huven; smarthet är en gradient (ranges→8 bitar, SoA, SIMD) man klättrar. **RESEARCH**
- Range/refinement-typer (`number in 0..100`): tidigare BESLUTAT att INTE bygga nu (research-grade + tredje talstavning krockar med minimalism). **ÖPPET**: står det fast, eller vill du öppna det igen?

## Tema 4 - Effekter som ryggrad (identiteten) · ÖPPET
Routa IO/rand/tid/nät genom effektsystemet i stället för vanliga builtins.
Låser upp tre saker inget mainstream har: test utan mocks (byt handler),
capability-säkerhet (signatur = vad funktionen får göra), record/replay-debug.
- Stort, stegvis: rand+tid först (determinism behöver dem), sen nät, sist file/print.
- Beroende: unifiera tids-systemen (Tema 2) FÖRE man routar tid genom effekter.
- **ÖPPET**: committar vi till detta, och hur långt (allt, eller bara rand+tid)?

## Tema 5 - Determinism som löfte · ÖPPET
Samma program + input + seed → samma output.
- Faller delvis ut ur Tema 4 (seedad rand, tid som input).
- **Golvet: floats.** Bit-exakt cross-platform kräver soft-float/fixed-point, annars håller det inte.
- **ÖPPET**: (a) begränsa löftet till heltal/seedad, eller (b) fixed-point-läge för simulering (speltestning)?

## Tema 6 - Docs som inte kan ljuga · ÖPPET
Varje `pub fn` kräver ett körbart exempel med förväntad output; referenssidan visar dem.
Bygger vidare på att ni redan kompilerar exempel.
- **ÖPPET**: gör vi exempel obligatoriskt (bygget failar utan), eller rekommenderat?

## Tema 7 - Det som faktiskt saknas (större, senare) · ÖPPET/RESEARCH
- **Typade fel**: `Result<T, E>` (strukturellt E, inte bara `Err(Text)`). Idag `Result<T>`. Buildbart.
- **Unicode**: `upper`/`lower`/`reverse`/`index_of` är byte-baserade ("ASCII-safe only"). Störst lucka, men vänta tills API-ytan är rätt.
- **Lazy iterators**: allt `loop` samlar eagert till listor.
- **Nätverk**: `net` är en stub; sockets → sen TLS/HTTP.
- **Datum/tid-typer.**
- **Float-formattering i interpolation.**
- **`table` med icke-`text`-nycklar.**
- **Minnesmodell dokumenterad**: kopiering (naiv) vs persistenta strukturer (Clojure/Roc, next-gen-svaret). **ÖPPET**: vilken stance?
- **Traits/interfaces**: idag generics = operation-passing, inga traits (reserverade, ej byggda). **ÖPPET**: återinföra eller stå fast?

---

## Tema 8 - Gammal-programmerings-skit (konventioner & läckande mekanik) · BESLUTAT
Djupare än ord: konventioner och lågnivå-mekanik som läcker upp till ytan.
- **`main() -> int` exit-kod** → `main` returnerar `nothing`; fel via `Result`/effekter. **BESLUTAT**
- **Tvingande returtyper** → inferera för privata `action`, valfri på publika. **BESLUTAT**
- **`argc`/`argv`** (C-namn) → `arguments: [text]` (`len(arguments)`, `arguments[0]`). **BESLUTAT**
- **`use` stdlib** → behåll explicit (lightweight, ej ceremoni). **BESLUTAT**
- **`vec_add`/`vec_addi`/`vec_madd`/`vec_dot`** handanropad SIMD → göm; skriv vanlig aritmetik, kompilatorn vektoriserar (din egen intent-vision). Kompilator-jobb.
- **Rå pekare `ptr`/`call_ptr`/`struct_field_int`/`struct_field_text`** → göm mekaniken (semantiskt ägande read/edit/take/share, inte rå ptr).
- **`slot_get`/`slot_set`/`slot_has`** global muterbar store på ytan → göm (bryter P5 truth-is-local).
- **`print_int`/`print_float`/`print_text`** typ-specialiserad utskrift → ETT `print` som tar vilket värde som helst (kollapsar med `number`+generics).
- **`assert`/`assert_eq`/`assert_true`/`assert_text_eq`** → ett `assert(villkor)`.
- **`Orbit.toml`** → verifiera att enfilsfallet kör utan projektfil (manifest "no project file").
- **Ren städning (stdlib-omskrivning, inget beslut):** C-stil index-loopar (`loop i in 0..<n`+`at`) → element-iteration; `bytes_zeros`/manuell byte-bygge → göm bakom `text`; `is_even`/`is_odd` → `truth` (predikat-läcka).

## Tema 10 - Resurser & samtidighet (design LÅST 2026-08-03, bygg när net landar)
- **Resurser = scopade effekter.** När handtag kommer (sockets!) ägs de av `handle`-blocket: scope-utträde stänger, garanterat - strukturellt i stället för manuell defer. Komponerar med record/replay och `uses net`. ALDRIG lifetimes i användarsyntax. Dagens helfils-IO är handtags-fritt by design - håll det så länge det går.
- **Strukturerad samtidighet via `scope:`-blocket** (redan i planen): tasks scopade till förälder, teardown vid utträde. NYTT: cancellation + timeout som SCOPE-egenskaper (`scope timeout 100:`), deterministisk nedstängning - inte utspridda cancel-tokens. Fibrer, aldrig futures (pinning/Send/Sync kan inte uppstå). Streams/backpressure = lazy fusion + kanalerna. Actors: NEJ (store+systems+kanaler är modellen, P3).
- **Diagnostik som kärnfunktion:** topfelen får undervisningsform ("Choose one: ..."), påbörjat med bound-once-enforcement (som visade sig SAKNAS - guiden lovade det, kompilatorn höll det inte).

## Tema 9 - Läsbarhets-features & strukturell renhet · BESLUTAT
Hittat i tre extra genomgångar av konstruktionerna (effekter/kontrakt/typer läste redan bra).
- **Named arguments** (valfria etiketter vid anrop): `create_window(width: 800, height: 600, fullscreen: yes)`. Största läsbarhetsvinsten vid anrop. **BESLUTAT**
- **Default-värden på parametrar**: `action greet(name, greeting = "Hi")`. **BESLUTAT** (trots P5-doft; named args mildrar).
- **Lätt anonym funktion**: `(n): n + k` (ingen `action`-keyword inline). `each(xs, (n): n * 2)`. **BESLUTAT**
- **Allt är ett uttryck**: block-`if:`/`else:` blir också ett uttryck (`y = if c:\n a\nelse:\n b`), statement/expression-splitten bort. En `if`. **BESLUTAT**

## Beroenden (bygg-ordning)
```
Tema 1B (number-migration) ── möjliggör ── f-dubbletter bort (Tema 2)
Tema 2 (unifiera tids-system) ── FÖRE ── Tema 4 (tid genom effekter)
Tema 4 (rand+tid genom effekter) ── möjliggör ── Tema 5 (determinism)
Tema 7 (typad-fel/Unicode) ── EFTER ── att API-ytan är rätt (Tema 1-2)
```

## Rekommenderad ordning
1. **Runda A** - säker städning (ett strängbibliotek, println/push_mut). Inga beslut.
2. **Runda B** - typ-migration (`number` först, sen resten av vokabulären).
3. **Tema 2-rest** - unifiera tids-system, radera closure, fixa const-över-orb.
4. **Tema 4** - effekter som ryggrad (rand+tid → nät → file/print).
5. **Tema 5-6** - determinism + docs-som-tester (faller delvis ut ur 4).
6. **Tema 7** - typade fel, sen Unicode, sen nät/lazy (var sitt jobb).
