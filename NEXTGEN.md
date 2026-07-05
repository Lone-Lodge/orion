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

- [ ] **A1. Reactive `derive`** (#1, #11) — `derive alive := health > 0`.
  A resource that is ALWAYS its expression; the runtime recomputes it
  when a dep changes (deps are known from facts — the dependency net).
  This is idea #1 made syntax: a graph, not an instruction list.
  Kills manual cache invalidation (#11: `derive TotalHealth := sum(Health)`).
  *Touches:* `lang` + `sims`. *Scope:* M. *Foundational — do first.*

- [ ] **A2. Laws-sugar** (#7) — `law Death:`, `entity becomes Dead`,
  `after 1.5s:`. Sugar over existing when/set/spawn so a rule reads
  like a world law, not a system. `becomes` = set a tag/state;
  `after Ns` = a delayed effect (needs a timer wheel in sims).
  *Touches:* `lang` (+ `sims` for `after`). *Scope:* M.

- [ ] **A3. Relations first-class** (#5, #6) — `relation owns(Player, Item)`,
  `when npc hates player and npc sees player: npc attacks player`.
  atlas_ecs already has Relate/Unrelate effects — this is the astra
  syntax + a relation query in eval. Makes the world a network, not
  a component table.
  *Touches:* `lang` + `rt` (relation index). *Scope:* M.

### Phase B — knowledge, uncertainty, intent

- [ ] **B1. Belief worlds** (belief #1) — `belief Guard: Player inside Forest`
  vs `reality: Player inside Castle`. An NPC's world is a fork that may
  diverge from reality; AI reasons over its belief, not a blackboard.
  Belief-vs-reality is a replay-diff between two worlds — our physics
  already does it. Most mystery/discovery flavor.
  *Touches:* `rt` (belief worlds) + `lang` (belief blocks). *Scope:* L.

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
