# Lone Lodge — expedition roadmap

PRINCIPLES.md #0 is the physics: time, memory and cause are one
substance. This file is the map: three braided tracks that feed
each other and converge. Every step is measurable with instruments
we already built (orbit soak / orbit try / the alloc ledger / the
gate battery / the recorder). Status: 2026-07-05.

## The instruments (built, green — what makes boldness cheap)

- `orbit soak [ticks] [seed]` — the engine plays the game;
  invariants + cause ledger. Found and killed a 21.8MB->418KB->
  ~0 drip arc in one day.
- `orbit try [ticks] [seed]` — the shadow verdict: compile,
  parse-preflight every bundle, replay the pilot's last real
  session under the candidate, chaos-soak, verdict.
- Alloc-site ledger (`orion_ledger_*`) — names every immortal
  allocation by region of code.
- Flight recorder — a session is a document; replay is a right.
- Gate battery st33-st58 + idle gates + fixpoint self-compile.

## Track 1 — Discovery (world-firsts, in order)

1. **The Oracle** (`world_fork` + `foresee(n)` + ghost overlay):
   deterministic foresight rendered live. Fork = the save-text
   roundtrip (proven by compaction). The screenshot that breaks
   brains: hold a piece, see the board's future shimmer. NEXT UP.
2. **Replay-diff**: probe points during replay — snapshot, run
   sims under NEW code, diff produced effects vs logged, restore.
   "Tick N: your change would have altered X." The new dev loop.
3. **orbit prove**: symbolic execution over Astra (int-only, tiny,
   rule-based => model checking is TRACTABLE — nobody can verify
   C++/Lua). Soak samples; prove proves. "Can the player ever
   reach this state?" answered with a proof.
4. **Deterministic parallelism**: static rule footprints ->
   disjoint bundles on threads -> canonical effect merge ->
   bit-identical replay on 8 cores. The strongest scientific
   claim. (Converges with Track 2 step 4.)

Replay-diff in one image: git diff for gameplay — play 10 min,
change ONE number, the engine replays your recorded session under
the new rule and reports exactly where the timelines diverge
("tick 3810: the boss would have died 40 ticks earlier"). The
Oracle diffs futures; replay-diff diffs pasts.

Continents behind these: ghost-selves (trail-exchange multiplayer,
KB letters — falls out of determinism), archaeology (causality as
genre), provable worlds (trail = verified speedrun submission).
PARKED (user verdict: most speculative, revisit only if try+soak
make it nearly free): the petri dish (breeding mechanics).

## Track 2 — Engine architecture (the arc)

Hull work — but INVENTED THROUGH OUR PHYSICS, not bought from the
1970s shipyard: texts become hash-consed identity with region
lifetimes (equality = pointer compare, O(1), everywhere);
interning becomes DETERMINISTIC LOG-BOUND NAMING (a name's id is
born as an effect => replay/fork keep identity bit-stable — the
Oracle and ghost-selves require this); the checker learns OUR laws
(the splash-teleport class caught statically; every field bug the
soak finds becomes grammar the checker enforces forever — a
language whose static analysis is trained by its own telemetry).

1. ⏩ Interning (STARTED): short-key compile cache SHIPPED
   (dirty sims frame 435us -> 288us, -34%). REMAINING: resource/
   channel/event names -> ints at load (the Astra compiler sees
   every name statically); slot store same treatment.
2. **Textures in the GPU orb**: atlas texture + UV quads (+ glyph
   atlas => text 35x cheaper). The capability gap between tech
   demo and game. Cubsy gets beautiful; Veil gets its surface.
3. **Columnar components** (SoA + dense eid index) behind the
   trail contract — "state is a cache of the trail" makes the swap
   semantics-free.
4. **Footprint scheduling** = Track 1 step 4.
5. Moonshot: **Astra compiles to Orion** (AST -> Orion source ->
   native). The scripting tax -> 0. Our language boundary is a
   compiler pass, not an API.
6. Orion language: length-prefixed texts (kills the strlen class);
   checker-as-law (non-mut reassign emits invalid SSA today —
   must be a compile ERROR; errors as structured spans for
   agents); escape analysis -> AUTOMATIC region assignment (the
   persist/arena dance dies as a category).

## Track 3 — Product

- **Itch upload**: build/cubsy-win64.zip (1.0MB) is READY — drag
  it to itch.io (user's move).
- Sounds 1.3MB -> synth-at-boot + QOA (kills sounds/ entirely).
- Cubsy polish: quests reward feel, beat-quantized music.
- Platform ports when wanted: smallness IS the port strategy —
  one platform = a handful of *_min.c files behind frozen orb
  contracts (og_*, audio seam, win_*).

## Research triage (from the 24-idea sweep — what we ruled OUT)

CRDTs (merge without order — but ORDER is our soul; input-trail
lockstep wins for games), GPU sims (kills determinism and console
portability; sims are 288us — nothing to save), differential
programming (gradients = floats = the enemy; our answer is seeded
SEARCH), runtime constraint solvers (bake-time only), category-
theory cosplay (keep the discipline, skip the costume).

## Standing debts (bookmarked, not urgent)

One-time boot warm-up ~2MB (first Resize/Init dispatch); ~2KB per
restart residual; compiler flake (one-shot segfault, retry clean);
MiniDumpWriteDump 0x80070466; parked 1b ([] interning — ASAN
root-cause first); machine bench noise 2026-07-04 evening
(re-bench fps claims when the box is calm).
