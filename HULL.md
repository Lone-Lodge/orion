# The hull, invented — shipyard survey 2026-07-05

Rule of this document: no plank gets bought from the 1970s
shipyard. Every hull system is reinvented through PRINCIPLES #0
(time/memory/cause are one) or it waits. Costs are stated against
the ACTUAL code, honestly.

## H1. Texts: identity with a header (the hash is the discovery)

Today: NUL-terminated char*, len() = strlen (O(n), bit us in
st56), equality = strcmp, every map in the engine scans keys with
memcmp.

Invention: layout `[hash:i64][len:i64][bytes...NUL]`, the POINTER
still aims at bytes — every fprintf/strcmp/extern keeps working
untouched. len() becomes ptr[-8]. The gold is ptr[-16]:

- **Hash-reject in every map lookup in the engine** (slots,
  resources, channels, compile cache) without touching a single
  map layout: compare two i64 before any memcmp is considered.
  Linear scans stay linear but get 10-20x cheaper per entry.
- text equality: ptr== fast path, hash reject, memcmp only on
  hash match — inequality is O(1).
- strlen bug class dies as a category.

Cost, honestly: ~10 allocation sites (rt.c: persist_text
equivalent in emitted LLVM, key_copy, oe_text, dir evac; emit
prelude: text_concat, int_to_text, bytes_to_text, slice, case
fns) + emit len/text_eq cases + STRING CONSTANTS become
`{i64,i64,[n x i8]}` globals referenced via GEP to the bytes
field — mechanical but fiddly. One work block + fixpoint.
Full hash-consing (unique pointer per content) is NOT v1: a
global intern table fights region lifetimes. v2 idea: intern only
the persistent lifetime class; frame/arena texts die too fast to
matter.

## H2. Facts: one machinery, three fruits (checker/AI/parallelism)

Today: eval discovers everything dynamically; the checker knows
no game laws; footprints exist only as a dream in the SPEC.

Invention: an AST pass over every compiled bundle extracts
**facts as data**: per rule — reads(resources), writes(resources),
emits(channels), spawns(kinds), screen-writes. Stored per bundle,
queryable. Three fruits from one tree:

1. **Parallelism prerequisite**: facts ARE the static footprints
   (Track 1 #4 / Track 2 #4 converge here).
2. **The AI surface** (#24): "show every rule that writes score",
   "which bundles can affect the economy" — answered from facts,
   no C++ archaeology. `orbit facts <query>` as the first organ.
3. **Field-law linting**: telemetry becomes grammar. First law,
   from the splash-teleport incident: WARN when a `when` compares
   a ui_* transient and its branch writes a persisted resource
   (screen). Every future soak finding that has a static shadow
   becomes a checker rule. A language whose static analysis is
   trained by its own field telemetry.

Plus the two landmines as hard errors with structured spans
(agent-parsable): non-mut branch reassign (emits invalid SSA
today — miscompile!), unknown fn (silently "guesses i64" today).

Cost: astra AST walk (compile cache already yields ASTs), a facts
store, checker rules, two orion-self checker errors. One block.

## H3. Names: the log owns identity (eval's hidden treasure)

Today: identities are texts everywhere; Astra eval resolves every
variable reference by scanning Binding LISTS with strcmp — with
~50+ auto-ctx bindings this is likely the LARGEST remaining cost
in the 288us dirty frame. Interning at compile time is 1960s;
ours must survive replay and fork bit-identically.

Invention: **names are born as effects.** Per-world NameTable:
name -> nid (dense int); first use logs NameBorn(nid, name) so
replay/fork reassign identically. Bundle load pre-declares all
statically known names in deterministic order (bundle order x
declaration order) so nids are stable even without dynamic
births. Then:

- auto-ctx becomes an ARRAY indexed by nid; Astra compile
  resolves variable references to nid slots; **eval reads
  ctx[nid] — O(1), zero strcmp, ever**. (De Bruijn is old; De
  Bruijn over a dynamic auto-ctx with replayable identity is
  ours.)
- world resources/channels keyed by nid internally (map_*_ik
  exists); text keys remain the API rim and the save format
  (nids resolve at load — saves stay human).

Cost: the big rewrite of the arc — NameTable in atlas_ecs, Astra
compile emits nid-resolved refs, auto-ctx array, dispatch paths.
1-2 blocks. Measure with st63 before/after; expect the largest
single sims win since the 30x.

## H4. World: views subscribe to effects (columnar is just view #1)

Today: state maps-of-maps; the plan said "columnar SoA" which is
every engine's answer. Our physics gives a better frame: state is
a cache of the log, so ANY layout is a **materialized view that
subscribes to effects** — deterministic, rebuildable, forkable,
invisible to the save format. Columnar packs = view #1. Morton
spatial index = view #2 when boards grow. By-value indexes later.
A tiny internal datalog instead of a storage migration. After H3.

## H5. Veil: provenance is already half-born

DrawRect carries `_src` today — verify it is filled meaningfully
and upgrade to (bundle nid, rule index) once H3 lands. This is
the causality query's first link AND the agent's DisplayList-diff
surface. Cheap, rides on H3.

## BEDROCK — beneath the hull (assumptions we have not yet torn up)

Not scheduled. Inscribed so the expeditions know what they are
walking toward. Three inherited assumptions, each removable:

B1. **The tick** (Spacewar 1962): why does time advance in fixed
    slices at all? Tear it out: time = the log's index; effects
    ARE the clock; rules subscribe to change instead of being
    polled. Cost becomes proportional to CHANGE, not to time —
    worlds at different rates for free, sub-tick causality,
    determinism by definition. We already proved half of it
    (idle = 0 frames); the Oracle is an exercise in this.

B2. **The pointer**: why is identity a memory address? Next floor
    down from regions: identity = BIRTH COORDINATE in the log —
    not where a value lives but when and why it arose. A pointer
    becomes a time coordinate; serialization, network sync and
    structural sharing across forks become free (same coordinate
    system everywhere). Unison did this for code; nobody has done
    it for living game state via cause. H3's nids are the first
    step down this mine. Open problem: hot-path cost of
    coordinates vs raw pointers (likely hybrid).

B3. **The code/data wall**: why does code live OUTSIDE the
    timeline? Game events enter the log; code changes enter git —
    two separate universes. Tear the wall: code changes are
    effects too. The timeline contains its own evolution;
    replay-diff stops being a tool and becomes a property (the
    log KNOWS when the rules changed); hot-swap is just an
    effect; version control and the runtime merge. Git and the
    engine become the same thing. Zero-build is this bedrock's
    kindergarten.

B4 (engineering-deep, not new space): deterministic math as a
    language type (fixed-point/rationals with a guarantee) — the
    door future physics needs for bit-identical cross-platform.

Second dig (2026-07-05, user demanded MORE — the thread: move
EVERYTHING into the log and things keep falling out free):

B5. **The frame**: with facts + render-as-view the engine can
    statically derive which PIXELS an effect can touch —
    footprints all the way down to damage rects. Provably minimal
    redraw; causality analysis as a rendering optimizer.
B6. **Saving**: the log IS the save — append it continuously
    (it's KBs), compaction = checkpoint, crash = replay. Progress
    loss becomes impossible by construction; "Saving..." dies as
    a concept. Databases call it WAL and need racks. Closest to
    reach of the whole dig (the recorder almost does it).
    ⭐ FIRST SLICE SHIPPED 2026-07-05: the crash report survives
    to crash.txt (unbuffered tee — the filter itself may die),
    autosave heartbeat rides the compact-poll site (full=1
    fidelity), recovery boot sees the marker and stands where it
    stood. Gate st72. The full log-append form (crash = replay,
    not checkpoint) remains the bedrock dig; the next language
    step is supervision — rule quarantine + in-process rewind
    (needs the fn-ref/SEH bridge).
B8. **Device input**: the log records INTENT ("place piece col
    3"), device->intent is a pure replaceable layer. Replays
    survive UI redesign (replay-diff robust across versions!),
    accessibility free, humans/bots/agents indistinguishable at
    log level (the soak already proved it silently).
B9. **Determinism as discipline**: law — exactly THREE
    nondeterminism sources (input, boot seed, external/AI), all
    logged; the checker PROVES a bundle hides no randomness.
    Deterministic AI stops being a promise and becomes a
    certificate.
B10. **Code as files**: a rule's identity = hash of its AST
    (Unison, for gameplay). Swap one rule = recompile one rule
    (B3's atom); global eternal compile cache; rules shared
    across games with automatic dedup — gameplay as a library
    ecosystem with addresses.
B14. **Netcode as heroism**: foresee = prediction of remote
    intent, rewind = rollback when truth arrives. That is GGPO —
    generalized to every game in the engine as a property of two
    primitives already on the map. Perceived zero-latency
    multiplayer as an engine trait.

## THE LANGUAGE DOCK — Orion's own inherited flaws (audit 2026-07-05)

Verdict: Orion's next-gen-ness lives in its ALLIANCES (runtime,
log, telemetry->law loop); the language itself still carries
C-era assumptions. Evidence is our own week. Not "start over" —
the bootstrap vehicle was exactly right — but the language is the
next continent. "Orion 2" is TWO moves, not twenty (the potato
forbids Rust-maximalism):

L1. **Lifetimes into the types.** Today persist/arena are manual
    API brackets — the whole 21.8MB drip hunt was ONE bug class:
    hand-managed scopes. Values carry their birth scope in the
    type; escape analysis assigns regions. Auto-regions is not an
    optimization, it is the language's missing sentence.
L2. **Effects into the signatures.** An Orion fn touches slots/
    IO/externs invisibly; Astra gets facts, Orion has convention.
    One facts model from Astra rule down to runtime fn — B9's
    certificate can then cover the ENGINE, and the compiler can
    parallelize its own passes.
Craft that follows under them: L3 errors as values with spans
(st56's slot_get->strlen was the type system's fault — typed
slots kill the class), L4 ownership-lite so push_mut is checked
not audited-by-comment, L5 real generics replacing type_text
strings, L6 thread-ready runtime (pool stack is a GLOBAL STATIC —
deterministic parallelism's own prerequisite). Astra: the truths
bitmask caps at 31 when-rules per bundle — a ticking bomb;
compile-to-Orion remains the moonshot.

Sequence is free: L1 stands on escape analysis (already on the
arc), L2 stands on the facts machinery H2 is building right now.

## Untouched by design (frozen is a feature)

Effect log format; the six-pool world lifetime model; orb
contracts (og_*, audio seam, win_*) — frozen surfaces are the
port strategy; Astra's rule syntax — it is the product.

## Order and how it braids with the expeditions

H2 first (landmines die, facts unlock three doors, small) ->
**the Oracle sails** (needs nothing from H1/H3: fork-by-save-text
keeps identity by NAME) -> H1 texts (one calm block, everything
gets faster) -> H3 names (the big sims win + Oracle's fork gets
bit-stable ids for free) -> H4 views -> parallelism stands on
H2's facts + H3's determinism.
