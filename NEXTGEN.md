# NEXT-GEN — the idea list, made a checklist (2026-07-05)

Johan's big brainstorm, sorted into what we actually build. Rule of
this document: every item is an idea from the list, mapped to what it
touches, in dependency order. We tick them off one at a time — each
lands as a gate-proven slice or it waits. Honest scope, honest fit.

**Touches**: `lang` = astra parser/eval · `sims` = the tick/dispatch
loop · `rt` = orion runtime/atlas ecs · `arch` = a structural change ·
`tool` = analysis surface (no runtime cost).
**Scope**: S = one sitting · M = a focused block · L = its own arc.

---

## SHIPPED (the foundation the rest stands on)

- [x] **The log is truth / rewind / replay / save** (#8) — B6, replay-diff, compaction.
- [x] **Why-engine, static** (#2) — `orbit why <name>`, backward causal chain. `tool`
- [x] **Forward causality** (#4, #14) — `orbit affects <name>`, the ripple. `tool`
- [x] **Auto-scheduler from facts** (#3, #9) — `orbit schedule`, hazard-free parallel batches. `tool`
- [x] **Liveness / dead-write audit** (#13, #16) — `orbit liveness`. `tool`
- [x] **Transitive facts** — the sound base under all four analyses. `lang`
- [x] **No tick if nothing changed** (#7) — idle floor 0 draws / 0B. `sims`
- [x] **Effect inference / self-proving** (#6) — `orion facts`, 249/272 pure. `lang`
- [x] **Multiple worlds** (belief #3) — the Oracle (fork + foresee). `rt`
- [x] **Determinism / time first-class** (#4 laws) — bit-identical replay + fingerprints. `rt`
- [x] **Crash trinity / self-symbolizing** (#2, #16) — what/where/why on any fault. `rt`

---

## TO DO — one at a time, top-down

### Phase A — the language describes TRUTH, not steps

- [x] **A1. Reactive `derive`** (#1, #11) — `derive alive = health > 0`. ✓ 2026-07-05
  SHIPPED as parser sugar (no core-datatype surgery after all): `derive
  NAME = EXPR` desugars to a Tick rule `SetVar(NAME, EXPR)`, reusing the
  whole rule->dispatch->set pipeline. Lexer `Derive` keyword + parser
  branch, ~40 lines, gate st89 (alive tracks health>0). The program
  describes what is TRUE. v2 follow-up: recompute only when a dep changes
  (facts.reads of the expr) instead of every tick — the reactive net.
  **SCOPED to the file (2026-07-05), execute in this order:**
  1. `astra_lexer/lib.or` — add `Derive` to the `Tok` enum; `keyword_of`
     maps `"derive"` → `Derive`. (Mirror `const`/`Const` exactly.)
  2. `astra_parser/lib.or` — reuse the `=` (Assign) form of
     `parse_const_decl` (no `:=` needed). Add `data Derivation: name, value`
     (or reuse ConstDecl shape). Add `derivations` to `ParseResult` —
     BOTH construction sites (the fail branch ~L132 and the ok branch
     ~L134) must add the field. Add a `Derive` dispatch branch in `parse`.
  3. `astra_run/lib.or` — add `derivations` to `data Compiled` and thread
     it through EVERY `Compiled{...}` literal (compile, compile_c,
     compiled_copy, the empty/fallback) — grep `Compiled{` first, miss
     none or astra won't build.
  4. `atlas_project/lib.or` — in `run_sims`, after the rule passes and
     before drain, recompute each derivation: `res_set_int_silent(world,
     "{prefix}{name}", eval_in_env(expr, ctx, funcs))`. v1 recomputes
     every pass; the reactive-only-when-deps-change optimization (via
     facts.reads of the derive expr) is a v2 follow-up.
  5. Gate st89: a bundle with `derive alive = health > 0`; set health>0
     → alive==1; set health=0 → alive==0, WITHOUT any rule writing alive.
  RISK: ParseResult + Compiled are constructed in many places; a missed
  literal breaks astra compilation. Do step 3's grep first.

- [x] **A2. Laws-sugar** (#7) — `becomes` ✓, `law` ✓, `after` ✓ (all 2026-07-05).
  - [x] **`becomes`** ✓ 2026-07-05 — a law-readable synonym for `=`:
    `when health <= 0: player becomes dead` desugars to `SetVar(player,
    dead)`, reusing the whole assignment path (looks_like_assignment +
    parse_set_stmt accept `Becomes` alongside `Assign`). Reads like a
    world rule, means a state set. Gate st90; cubsy check + soak green.
    Cleared the one dead reserved keyword.
  - [x] **`law NAME:`** ✓ 2026-07-05 — names the following rule after
    the law: `law Gravity: on Tick(): ...` gives an otherwise-anonymous
    rule the name `Gravity`, so facts/why/quarantine identify it. Pure
    parser sugar over parse_rule (Law keyword + parse_law_decl). Gate st91.
    VALIDATED IN PRODUCTION: cubsy's scoring rule is now `law LineClear:`
    — soak identical (behavior unchanged), and `why score` shows
    `line_clear/LineClear` instead of anonymous `line_clear/Tick`.
  - [x] **`after Ns:` delayed effect** ✓ 2026-07-05 — the last A2 piece,
    SHIPPED via a fundamentally cleaner design than the reverted attempt.
    NO core-enum surgery, NO world-state timer queue, NO text-pool
    lifetime dance. `after N: name = value` is PURE PARSER SUGAR (like
    `derive`/`becomes`): it desugars to two int-resource writes inside an
    always-true block — `__after:name = tick + N` (the fire tick, `tick`
    from ctx) and `__after_val:name = value` (the value). Int resources
    save/rewind and self-manage lifetime, so the whole memory problem
    evaporated. A `world_tick` scan (in atlas_ecs, right after the tick
    bumps) fires armed timers whose fire tick has arrived: sets
    `name = __after_val:name`, then disarms (`__after:name = 0`). The
    prefix is recovered from the key so atlas_ecs stays prefix-agnostic;
    the scan is gated on an `atlas:any_after` slot that `apply_set` flips
    the first time an `after` arms, so a game that never uses `after`
    pays one int read per tick and no scan (potato principle). N is in
    ticks (frames); N≥1 fires exactly N frames later. `becomes` accepted
    as the synonym. Gates st95 (desugar) + st96 (world_tick firing) +
    st97 (full dispatch->drain->tick chain, incl. slot arming); cubsy
    soak 2000 green (scan dormant, no regression). v1 caveat: int values
    only, one pending `after` per target name.
    *Touched:* `lang` (parser only) + `rt` (atlas_ecs scan) + `sims`
    (apply_set slot). The revert's "wall" was the wrong design, not a
    real barrier — the resource-based reframing made it an S, not an M.

- [x] **A3. Relations first-class** (#5, #6) — CREATE + QUERY ✓ 2026-07-05.
  - [x] **`relate A kind B`** ✓ 2026-07-05 — creates a real atlas relation
    from a rule (`relate player owns sword`), forward+reverse queryable via
    related_to/from. Stmt.RelateStmt -> AstraRelate -> atlas Relate. Two
    core enums grew, compiler-guided (proved core-enum surgery is safe
    when done compiler-first). Gate st92; cubsy soak green.
  - [ ] **QUERY (`when npc hates player`)** — the host-agnostic eval
    boundary. Clean design: inject the relations index as a ctx binding
    and add a `related(x, kind)` builtin that reads it (eval stays data-
    driven, no world access). `lang` + a thin atlas ctx injection. M.
  Makes the world a network, not a component table.
  **SCOPED (2026-07-05): the RUNTIME is already DONE** — atlas_ecs has
  Relate/Unrelate effects, bidirectional relations_fwd/rev index, cascade
  cleanup on despawn, AND the queries `related_to(world, src, kind)` /
  `related_from(world, target, kind)`. What remains is astra SYNTAX:
  1. A relate statement in a rule body -> a new AstraEffect (AstraRelate)
     mapped to atlas Relate. NOTE: AstraEffect is a core enum constructed
     in many places (like ParseResult) — grep `AstraEffect`/each variant
     first, or astra won't build. This is why it is NOT A1/A2-clean sugar.
  2. A relation query builtin (`hates(x)` / `x hates y`) that the host
     (atlas) resolves via related_to/from — eval is host-agnostic, so it
     routes through a ctx binding or a host callback, not pure eval.
  *Touches:* `lang` (astra effect+eval) + a thin atlas mapping. *Scope:* M.
  **DEEPER SCOPE (2026-07-05, after attacking it):** the CREATE side is
  clean-ish — AstraEffect maps to atlas via CHANNELS (`to_atlas_effect`
  -> ToChannel), so `relate a owns b` can desugar to `emit relate {...}`
  and an atlas drain applies the atlas Relate effect (no core-enum change
  needed after all — reuse AstraEmit). The QUERY side is the real design
  question: astra_eval is deliberately HOST-AGNOSTIC (no world access),
  so `when npc hates player` cannot resolve in eval. The clean answer:
  the host uses FACTS to see which relation queries a rule needs, pre-
  computes them via related_to/from, and injects them as ctx bindings —
  the same auto-ctx mechanism, extended to relations. That is the design
  to make first; then create+query land together.

### Phase B — knowledge, uncertainty, intent

- [~] **B1. Belief worlds** (belief #1) — `belief Guard: Player inside Forest`
  vs `reality: Player inside Castle`. An NPC's world is a fork that may
  diverge from reality; AI reasons over its belief, not a blackboard.
  Belief-vs-reality is a replay-diff between two worlds — our physics
  already does it. Most mystery/discovery flavor.
  - [x] **Divergence primitive** ✓ 2026-07-05 — `world_int_diff(a, b)`
    (atlas_ecs): the exact int-resource keys where two worlds disagree
    (differ in value, or present in only one). This is "belief-vs-reality
    is a replay-diff" made concrete and queryable — the engine can now
    compute what an agent believes that ISN'T true. A belief IS a fork
    (project_fork, shipped): fork reality → 0 divergence, then the agent's
    perceptions diverge and the diff names exactly the wrong facts. Gate
    st99 (fresh belief 0 diff; mis-seen player_x → diff = [player_x],
    correct hp stays clean; symmetric). Read-only, additive; cubsy soak
    green. v1: int resources (text divergence not seen — game facts that
    matter for belief are positions/hp/flags).
  - [x] **`belief NAME:` blocks** ✓ 2026-07-05 — astra syntax for an
    agent's believed facts, shipped as PURE PARSER SUGAR (no separate
    World object, no fork lifecycle — the clean reframing, like after).
    A belief is a resource NAMESPACE: `belief Guard: player_x = 5`
    desugars to a Tick rule setting `belief:Guard:player_x = 5`, so the
    belief is re-asserted each tick and its divergence from the real
    `player_x` is a resource-prefix comparison. `belief_wrong(world,
    prefix, name)` (atlas_project) scans `<prefix>belief:<name>:<fact>`
    and returns the bare facts that disagree with reality — exactly what
    the agent believes that ISN'T true. Gates st100 (desugar: facts land
    in the namespace, never touch real facts) + st101 (belief_wrong names
    exactly the wrong fact, hp stays clean, converges to 0 when the agent
    learns the truth); cubsy soak 2000 deterministic, no regression.
    Lexer `Belief` keyword + parser branch + parse_belief_decl, ~45 lines.
    NOTE: this namespace model does NOT simulate the belief forward — for
    that see foresee-on-belief below (the fork model, distinct slice).
  - [ ] **Foresee-on-belief** — an agent plans over its belief world
    (project_foresee on the fork), so the plan can be WRONG when the
    belief is. The payoff: emergent mistakes, discovery, mystery. M.
  *Touches:* `rt` (belief worlds) + `lang` (belief blocks). *Scope:* L
  overall; the divergence primitive was the clean first slice (S).

- [ ] **B2. Uncertainty as a type** (belief #2) — `Door.open confidence 0.73`,
  `Enemy probably at Forest`. A value carries a confidence; queries and
  `when` reason over it. Perfect for AI.
  *Touches:* `lang` (type) + `rt` (value repr). *Scope:* L.

- [ ] **B3. Constraints / goals** (#8) — `goal: NPC inside House`,
  `constraints: avoid Water, avoid Fire`. Runtime solves the HOW.
  Describe the world, not the behavior — emergence (#9) is the payoff.
  *Touches:* `lang` + `rt` (solver). *Scope:* L, spekulativt.

### Phase C — execute the parallelism, close the runtime loops

- [ ] **C1. Run the schedule on threads** (#3) — the RUNTIME half of
  deterministic parallelism. The scheduler already derives hazard-free
  batches (st85); this actually runs a batch's rules on workers,
  deterministically (bit-identical to serial). World-first #1, executed.
  *Touches:* `rt` + `arch`. *Scope:* L. *Needs the deterministic-parallel proof.*

- [ ] **C2. Runtime provenance → timeline + live `explain`** (#2, #10) —
  tag each logged effect with the rule/event/tick that caused it, so
  `explain wolf.dead` walks the ACTUAL playthrough ("Player emitted
  Attack → DamageTaken(12) → Health<0 → Death rule"), and a timeline
  view lists events with their causes. why/affects are the static
  graph; this is the runtime instance on top of it.
  *Touches:* `rt` (log provenance) + `tool`. *Scope:* M.

- [ ] **C3. Self-learning scheduler** (belief #5) — measure per-rule
  time, reorganize batches to balance workers next frame. Rides C1.
  *Touches:* `rt`. *Scope:* M, after C1.

### Phase D — far frontier (inscribed, not scheduled)

- [ ] **D1. Spatial partitioning** (belief #10) — world regions (Forest/
  Dungeon) to different workers; the compiler knows space. `arch` L.
- [ ] **D2. Data gravity** (belief #15) — GPU vs CPU placement by where
  the data lives; the programmer doesn't choose. `arch` L.
- [ ] **D3. Entropy/energy execution** (#7, #12) — minimize work by
  information change, not by frame. `sims` L, spekulativt.

---

## Order we actually go

A1 → A2 → A3 → C2 → B1 → C1 → B2 → B3 → (D as physics demands).
A1 first: it turns the dependency net into syntax and everything
downstream (laws, derived caches, the reactive core) leans on it.
C2 early because runtime provenance makes the why-engine live and
costs little. The big-arch items (C1, D) wait for the deterministic-
parallel proof they need.
