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

- [x] **The trail is truth / rewind / replay / save** (#8) — B6, replay-diff, compaction.
- [x] **Why-engine, static** (#2) — `orbit why <name>`, backward causal chain. `tool`
- [x] **Forward causality** (#4, #14) — `orbit affects <name>`, the ripple. `tool`
- [x] **Auto-scheduler from facts** (#3, #9) — `orbit schedule`, hazard-free parallel batches. `tool`
- [x] **Liveness / dead-write audit** (#13, #16) — `orbit liveness`. `tool`
- [x] **Analysis suite wired to the CLI** ✓ 2026-07-05 — the four above
  shipped in atlas_project but were gate-only (orbit dispatch stopped at
  `facts`). Now real subcommands (orbit_main.or synth_analysis + dispatch
  + usage; orbit.exe rebuilt). Verified on cubsy: `orbit why score` walks
  the real chain incl. the line_clear/LineClear law, `orbit schedule` →
  117 rules/17 batches/0 hazards, `orbit affects`/`liveness` too. The
  runtime tools (resource_history, world_timeline, belief_wrong,
  goals_met, belief_apply) remain gate-proven PRIMITIVES; their CLI
  wrappers (`orbit explain`/`timeline`/`beliefs`/`goals`) need a session-
  run/replay harness to have a playthrough to read — a clean follow-up.
- [x] **Transitive facts** — the sound base under all four analyses. `lang`
- [x] **No tick if nothing changed** (#7) — idle floor 0 draws / 0B. `sims`
- [x] **Effect inference / self-proving** (#6) — `orion facts`, 249/272 pure. `lang`
- [x] **Multiple worlds** (belief #3) — the Oracle (fork + foresee). `rt`
- [x] **Determinism / time first-class** (#4 laws) — bit-identical replay + fingerprints. `rt`
- [x] **Crash trinity / self-symbolizing** (#2, #16) — what/where/why on any fault. `rt`
- [x] **Time-as-query** ✓ 2026-07-05 — `resource_at_tick(world, key, t)`,
  `first_tick_at_least(world, key, threshold)`, `first_tick_equal` (atlas_ecs).
  The trail records every change and replay is deterministic, so any PAST
  state is a query — "what was score at tick 400?", "when did it first
  cross 100?" — impossible in a polling engine (Unity/Godot cache history
  by hand or lose it). Builds on world_timeline. Gate st110; cubsy soak
  green. First exploitation of the engine per the 3-agent audit below;
  the substrate for regression-bisect + causality narration. `rt`+`tool`

## THREE-AGENT AUDIT (2026-07-05) — is this genuinely next-gen?

Ran a critical audit across all three layers. The convergent verdict:

- **Orion (language): CONVENTIONAL.** A clean, safe Rust/Zig-class systems
  language. Genuinely-novel bits are narrow (algebraic effects at OCaml-5
  level; relational-DB-as-boundary memory model; footprints as an auto-
  inferred primitive). Type system / control flow / regions are textbook.
  *Verdict: don't broaden the language — keep it KISS; the value is that
  it's a clean vehicle for the engine.*
- **Astra (DSL): 7 real capabilities, the rest is naming sugar.** `when`
  (edge-triggered), `after`, `relate`, `emit`/`spawn`/`destroy`/`set`,
  `require`, `count`/`exists`/`none` earn their place. `becomes` is a pure
  alias; `derive`/`goal`/`constraint` RECOMPUTE EVERY TICK — they describe
  *steps*, not truth, despite the vision. `belief`/`confidence` are naming
  conventions. *Consolidation: one `fact NAME = EXPR in NAMESPACE` could
  replace derive/goal/constraint/belief/confidence.*
- **Atlas (engine): every unique primitive is BUILT but UNDEREXPLOITED.**
  Determinism+fingerprints, trail-is-truth, fork/foresee, facts — all real,
  none fully used. *Every next-gen win is available; none needs a new
  primitive. The gap is product discipline, not capability.*

**The single through-line all three share: facts + the trail are computed
but not USED at runtime.** That is the biggest lever. Two payoffs:
1. **Reactive net (the #1 de-faking):** derive/goal/constraint recompute
   only when a dep (facts.reads, which already exists) changed — turns the
   biggest fake-declarative into real declarative AND kills per-tick churn
   (a lag win). NEXT recommended build. `lang`+`sims`. M, hot-path care.
2. **Exploit the trail:** time-as-query (SHIPPED above) → regression-bisect
   (soak finds the tick, fingerprint+facts bisect the RULE that regressed
   — the self-healing engine, the AI-native thesis realized) → causality
   narration ("score dropped because …"). Each rides the trail + facts.

Full agent reports: the audit ran 2026-07-05; keep this verdict as the
compass — **the novelty is the engine; stop broadening, start exploiting.**

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
  **RUNTIME BUG FOUND + FIXED 2026-07-05:** st89 proved derive at the
  EFFECT level, but the set-drain (apply_set) dropped bool payloads to 0
  — so `derive alive = health > 0` stored 0 at runtime regardless. Fixed
  apply_set to store {"bool": b} as 1/0 (gate st106); cubsy soak
  bit-identical (it uses no bool sets, so zero behavior change). derive-
  with-a-predicate now tracks truth live, not just in the gate.
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
  - [x] **Foresee-on-belief** ✓ 2026-07-05 — `belief_apply(world, prefix,
    name)` overlays an agent's believed facts onto a world so it can be
    SIMULATED as the agent imagines it (each real `<prefix><fact>` set to
    the belief's value). `belief_imagine(world, cfg, prefix, name)` is the
    full chain: fork reality (project_fork), overlay the belief, hand back
    a world ready for project_foresee — foreseeing it yields the agent's
    PLAN, which diverges from reality exactly when the belief is wrong
    (emergent mistakes, the mystery payoff). Gate st102 (belief_apply:
    player_x 10→5 as imagined, hp untouched, belief namespace intact);
    belief_imagine composes project_fork (proven) + belief_apply (gated).
  *Touches:* `rt` (belief worlds) + `lang` (belief blocks). *Scope:* L
  overall; each slice landed clean (S) — divergence, blocks, foresee.
  **B1 COMPLETE** — beliefs are first-class: declarable (`belief NAME:`),
  diverging (`belief_wrong`), correctable (converges to 0), imaginable
  (`belief_imagine` → foresee). The clean reframing (namespace, not World)
  made an L-scope arc land as three S slices.

- [x] **B2. Uncertainty as a type** (belief #2) ✓ 2026-07-05 — a fact
  carries a certainty and rules reason over it. Shipped as PURE PARSER
  SUGAR (no value-repr surgery, the clean reframing): `enemy_at = 3
  confidence 73` tags the fact with a 0-100 certainty stored as a
  parallel `conf:enemy_at` resource, and `confidence(enemy_at)` reads it
  back — desugaring to `SetVar(enemy_at,3) + SetVar(conf:enemy_at,73)`
  and `VarRef("conf:enemy_at")` respectively, both riding auto-ctx. So a
  rule can `when confidence(enemy_at) > 50: act` — reason over how sure
  it is. Unknown facts read confidence 0 at runtime (auto-ctx res_get_int
  default) → a plain fact is implicitly uncertain. Int-percent (0-100),
  not float 0.73 — stays in the int-fact/potato world; f64 confidence is
  a follow-up if needed. Gate st104 (write tags conf:, query reads it,
  >50 reasoning fires); cubsy soak green. Lexer `Confidence` keyword +
  set-suffix + primary query, ~35 lines.
  *Touches:* `lang` (parser only). *Scope:* was L; the parallel-resource
  reframing made it S.

- [~] **B3. Constraints / goals** (#8) — the world states its INTENT.
  - [x] **Declaration + evaluation** ✓ 2026-07-05 — `goal NAME = cond`
    and `constraint NAME = cond` desugar (like derive) to a Tick rule
    keeping `goal:NAME` / `constraint:NAME` at 1 while the predicate
    holds (coerced to int). The engine continuously SCORES intent —
    `goals_met(world, prefix)` lists achieved goals, `constraints_
    violated` lists broken ones. Goals/constraints are first-class,
    queryable, always-current facts a rule can react to (`when
    constraints_violated...`). Gate st105 (goal reach met, far unmet;
    constraint wet violated; both desugar + runtime queries); cubsy soak
    green. Lexer Goal/Constraint keywords + parse_prefixed_derive; the
    top-level dispatch was flattened into parse_belief_goal_or_rule.
  - [ ] **The SOLVER** — runtime plans HOW to achieve a goal under the
    constraints (pathfind/search). This is the genuinely speculative,
    L-scope half — emergence (#9) is its payoff. The declaration layer
    above is the foundation it stands on: a solver needs the goal/
    constraint predicates to score candidate plans against, which now
    exist as scannable facts. Distinct future arc.
  *Touches:* `lang` (parser) + `rt` (queries; solver later). *Scope:* the
  declaration layer was S; the solver stays L/speculative.

### Phase C — execute the parallelism, close the runtime loops

- [~] **C1. Run the schedule on threads** (#3) — the RUNTIME half of
  deterministic parallelism.
  - [x] **Deterministic-parallel PROOF** ✓ 2026-07-05 — the prerequisite
    the doc named. Gate st107 proves the scheduler's hazard criterion IS
    the determinism guarantee threads need: disjoint writes COMMUTE
    (rule A then B == B then A, by value — so a batch runs in ANY thread
    interleaving to one result), overlapping writes do NOT (order changes
    the result, so serializing them is correct). Oracle = world_int_diff
    (value comparison, order-independent).
  - [x] **Finding: the fingerprint is insertion-order-sensitive** —
    project_state_sig_bare hashes the save-text, which lists resources in
    insertion order, so two equal states reached in different orders
    fingerprint DIFFERENTLY. Fine for replay (deterministic insertion),
    but real thread execution needs a CANONICAL fingerprint.
  - [x] **Canonical fingerprint** ✓ 2026-07-05 — `project_state_sig_
    canonical(world, prefix)` sums a per-fact hash (a COMMUTATIVE fold),
    so insertion order can't change it — two equal states fingerprint the
    same regardless of the order threads produced them, yet a value change
    still shifts it. Prefix-normalized, int facts. Gate st108 (order-
    independent yet value-sensitive; save-text sig stays order-sensitive
    as found). The executor's parallel-result oracle now exists — one
    fewer blocker on the threaded executor.
  - [ ] **The threaded EXECUTOR** — a worker pool in orion_rt that runs a
    batch's rules concurrently, joins, applies effects in a canonical
    order. This is the genuine L-scope arch arc (OS threads, sync, the
    canonical fingerprint above) — a dedicated window, not a tail slice.
    The proof + finding above are its foundation: WHAT to run in parallel
    (hazard-free batches, st85) and WHY it's safe (st107) are settled;
    HOW (threads) is the remaining runtime build.
  *Touches:* `rt` + `arch`. *Scope:* L; proof landed (S), executor stays L.

- [~] **C2. Runtime provenance → timeline + live `explain`** (#2, #10) —
  why/affects are the static causal graph; this is the live instance.
  - [x] **`resource_history(world, key)`** ✓ 2026-07-05 — a resource's
    ACTUAL value-trajectory across the playthrough, walked from the tick
    trail (which already records every logged SetResource with its tick).
    `explain score` shows what score really was, tick by tick, in THIS
    run — no hot-path change, the data was already there. Gate st103
    (score 5@t0 → 20@t1 → 100@t2 recovered in order, hp separate); cubsy
    soak green. Byte-matches the key (native Text == is pointer eq).
  - [ ] **Cause enrichment** — tag each change with the RULE/event that
    caused it ("Death rule set wolf.dead because Health<0"). The crux
    (honestly scoped): the SetVar effect loses its rule identity by drain
    time (drain runs after ALL bundles in a pass). Needs either per-bundle
    draining with a `cur_bundle` slot, or threading cause through the
    effect payload from dispatch. That is the real M-scope runtime work;
    the value-history above is the clean slice that needs no plumbing.
  - [x] **Timeline view** ✓ 2026-07-05 — `world_timeline(world)` lists
    EVERY logged resource change across the playthrough in tick order —
    the runtime "what happened", one entry per change (tick, key, value),
    straight from the trail. Where resource_history is one resource's
    trajectory, this is all of them interleaved (a `timeline` tool or
    live HUD reads it). Gate st109 (all changes captured, tick order,
    right key/value).
  *Touches:* `rt` (trail provenance) + `tool`. *Scope:* M.

- [ ] **C3. Self-learning scheduler** (belief #5) — measure per-rule
  time, reorganize batches to balance workers next frame. **Gated on C1's
  threaded executor** — there is nothing to load-balance until batches
  actually run on workers. The per-rule timing half could be prototyped
  now (orion_ledger already tags spans), but the reorganization payoff
  needs C1. Deferred with C1's executor. *Touches:* `rt`. *Scope:* M, after C1.

### Phase D — far frontier (inscribed, not scheduled)

Assessed in this pass; each is a genuine architectural arc, NOT a clean
slice — shipping fake thread/GPU/opt code would betray the quality bar.
Honest scoping recorded so a future dedicated window can pick them up.

- [ ] **D1. Spatial partitioning** (belief #10) — world regions (Forest/
  Dungeon) to different workers. **Gated on C1's executor** (there are no
  workers yet) PLUS a spatial index (entities bucketed by region). The
  index alone is a real, achievable data structure — and useful for
  gameplay queries independent of parallelism — but the "to different
  workers" payoff needs C1. `arch` L.
- [ ] **D2. Data gravity** (belief #15) — GPU vs CPU placement by where
  the data lives. Needs a GPU compute path (the runtime has ogpu for
  DRAW, not general compute) — a large infra arc well beyond a language
  slice. Genuinely far frontier. `arch` L.
- [ ] **D3. Entropy/energy execution** (#7, #12) — minimize work by
  information change, not by frame. The coarse version SHIPPED (idle
  floor: no tick if nothing changed). The fine version — skip a RULE
  whose read-set didn't change this tick — is achievable in principle
  (facts give each rule's reads; the state has changed/added/removed
  maps) but the payoff is a run_sims integration with real correctness
  risk (a rule with unchanged inputs is only skippable if it is pure and
  nothing depends on re-emitting its effects). A perf arc for a fresh
  window, tied to the lag work. `sims` L, spekulativt.

---

## Status (2026-07-05, full-list pass)

**SHIPPED — every language + analysis item that was a clean slice:**
- **Phase A COMPLETE**: derive · becomes · law · after · relate · related
  (+ A1 runtime bool-drain bug found & fixed).
- **Phase B COMPLETE**: B1 belief worlds (divergence · blocks · foresee),
  B2 uncertainty-as-type (`confidence`), B3 goals/constraints (declaration
  + evaluation).
- **Phase C**: C2 live `explain` (resource_history) shipped; C1 the
  deterministic-parallel PROOF shipped (+ canonical-fingerprint finding).

**REMAINING — genuine architectural arcs, honestly deferred (not faked):**
- C1 threaded executor (OS worker pool in orion_rt) → C3 self-learning
  (rides it) → D1 spatial (rides it).
- C2 cause-enrichment (rule identity through the drain) + timeline view.
- D2 data gravity (GPU compute infra), D3 fine entropy execution (per-rule
  skip, a run_sims perf arc).

Each remaining item has its concrete blocker and next step recorded in
its entry above. The through-line of the shipped work: the clean
reframing beats the heavy build — `after` became resource-timers, belief
a namespace, confidence a parallel resource, goals a namespaced derive.
Core-enum surgery was never needed after A3. The arch frontier (threads,
GPU) is what genuinely remains, and it needs dedicated windows.

## Original planned order (for reference)

A1 → A2 → A3 → C2 → B1 → C1 → B2 → B3 → (D as physics demands).
A1 first: it turns the dependency net into syntax and everything
downstream (laws, derived caches, the reactive core) leans on it.
C2 early because runtime provenance makes the why-engine live and
costs little. The big-arch items (C1, D) wait for the deterministic-
parallel proof they need (now shipped: st107).
