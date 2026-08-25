# Orion

[In English](README.md)

Ett litet språk med indenteringsstruktur som kompilerar till LLVM IR och vidare
till en binär. Ingen null, inga undantag, ingen skräpsamlare: allokering går
genom en arena som kompilatorn kontrollerar för balanserade scope innan något
körs. Kompilatorn är skriven i Orion och kompilerar sig själv.

```python
define main() -> number:
    name = "world"
    print_line("hello {name}")
    0
```

**[Fältguiden](https://lone-lodge.github.io/orion/)** - hela språket på en sida,
på tio minuter, varje exempel körbart i webbläsaren.
**[Biblioteket](https://lone-lodge.github.io/orion/reference.html)** - varje orb
och varje funktion den exporterar, genererad ur källan så den inte kan glida.
Bägge ligger också som vanlig HTML i [docs/](docs/): öppna filen, ingen server
och inget nät behövs. Guiderna är på engelska; **[Syntaxen](docs/SYNTAX.sv.md)**
är uppslagsverket på svenska.

## Bygg

Du behöver `clang`. Inget annat - ingen Rust, ingen Node, ingen pakethanterare.

```sh
bash tools/bootstrap.sh
```

Från en tom utcheckning till en fungerande verktygskedja: den incheckade fröIR:en
bygger en första kompilator, den kompilatorn bygger om sig själv till en
fixpunkt, `orbit` byggs, och röktestsviten körs.

```sh
orbit run hello.or      # kompilera, länka, kör
orbit build hello.or    # lämnar ./hello bredvid källan
orbit new myapp         # ett projekt; run / build / test fungerar inuti det
```

Ingen projektfil, ingen utdatasökväg att namnge, ingen clang-rad att skriva.

## Kontrollera

| grind | vad den bevisar |
|---|---|
| `tools/seed_check.sh` | det incheckade fröet bygger fortfarande kompilatorn, så en färsk klon kan starta upp |
| `tools/test.sh` | 228 röktester, ett drag i taget |
| `tools/project_test.sh` | grindarna som behöver ett projekt: det deterministiska certifikatet, orb-synlighet |
| `tools/negative_test.sh` | 37 program som måste *avvisas*, med rätt meddelande |
| `tools/combo_test.sh` | varje par av drag använt tillsammans |
| `tools/demos_smoke.sh` | de 23 demoprogrammen går fortfarande |
| `tools/docs_check.sh` | varje kodexempel i fältguiden kompilerar |
| `tools/wasm_conformance.sh` | wasm-backenden faller inte tillbaka |
| `tools/lsp_test.sh` | editorservern svarar som en editor frågar |
| `tools/region_shrink_test.sh` | arenan ger minne tillbaka och tröskar inte |
| `tools/compile_bench.sh` | hur snabbt kompilatorn går |
| `tools/runtime_bench.sh` | hur snabb koden den skickar ut är |

CI kör allihop på Linux, Windows och macOS, från en utcheckning utan en enda
binär på disk. Den startas för hand från Actions-fliken: en push behöver ingen
runner för att upprepa vad de här redan sagt.

## WebAssembly

En utdatasökväg som slutar på `.wasm` använder wasm-backenden i stället för
LLVM:

```sh
orion prog.or prog.wasm orbs
```

Modulen står för sig själv: värden ger förmågor (rita, indata, `print`), aldrig
datastruktursemantik. `node tools/playground.js` serverar fältguiden med varje
exempel körbart i webbläsaren.

Det är en andrahandsbackend, inte en spegel av den native. Röktestsviten körd
genom wasm ger rätt svar på 164 av 228; resten använder ett drag den inte har.
CI grindar mot regression, inte mot 100 %. Schemaläggaren för async
(`spawn`/`await` med parkerade uppgifter) behöver riktig stackväxling och
förblir native.

## Karta

```
orbs/       biblioteken, och kompilatorn själv (lex, parse, ir, emit, wasm)
runtime/    C-runtimen som den utsända koden länkar mot
vendor/     tredjeparts-C som en orb länkar mot: sqlite, whisper.cpp
tools/      bootstrap, testriggar, mätningar, LSP:n, orbit, lekplatsen
tests/      röktestsviten, de negativa, och grindarna som behöver ett projekt
examples/   demos, drivrutiner, wasm-galleriet
docs/       fältguiden, biblioteket, syntaxen, hur man portar Orion
```

## Läge

v0.1. Självvärdande, grön på Linux, Windows och macOS. Samma källa sänder ut
samma IR på båda värdarna.

Kända luckor:

- **`x = push(x, v)` kopierar** när kompilatorn inte kan bevisa att `x` ägs
  ensamt. Det vanliga `mut x = []`-bygget i en loop är bevisat och trycker på
  plats; en lista som har alias, sparas eller fångas förblir en kopia.
  `push_mut` är vägen ut.
- **Fleranvända effekter är experimentella.** Engångs (`perform` / `handle` /
  `resume`) är den kärna som stöds och fungerar överallt. `ask` / `resume_with`
  går bara på Windows-fibrer; annars svarar `resumable_ok()` 0 och `ask` vägrar
  i stället för att låtsas.
- **Interaktiv terminalindata** fungerar på Windows och genom en pipe överallt.
  På en POSIX-TTY svarar `orion_console_readline` med ingenting.

## Licens

Apache 2.0. Copyright 2026 Lone Lodge. Se [LICENSE](LICENSE) och
[NOTICE](NOTICE).
