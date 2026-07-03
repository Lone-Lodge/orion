# Lone Lodge codebase review — 2026-07-01

Four-agent deep review (Astra, Atlas/Cubsy/Veil, orion-self, lodge-orion),
synthesized. Context: native-via-orion-self is the decided strategy;
lodge-orion becomes dev-loop only; Astra is the moat.

## Verdict in one paragraph

The architecture honors the vision everywhere it matters: Astra's closed
effect universe is real sandboxing, the edge-trigger semantics are
correct, Atlas's single-ingress tick-log makes rewind nearly free, and
orion-self is a genuinely one-person-maintainable self-hosting compiler
(~5,000 lines) with OCaml-class features. The problems are not the
designs — they are (1) a silent-failure culture in every layer that is
actively hiding shipped bugs, (2) allocation/O(n²) patterns that will
survive native compilation, and (3) three unsettled language decisions
(scoping, `=` semantics, runtime ownership) that will fossilize into the
native compiler if not decided first.

## CRITICAL — broken right now (verified, not theoretical)

1. **render.astra parses as 9 rules, not the 7 written.** The nested
   `when at(bits, ...) == 1:` blocks split into top-level `$when` rules
   that never fire (render bundle is never ticked). **Score digits and
   GAME OVER text are dead code today.** Root cause: bodies end at
   "next rule starter" because the parser is dedent-blind.
2. **drop.astra spawns TraySlot once per piece cell.** The dedented
   trailing statements nest inside `each cell in cells:` — duplicate
   TraySlot entities accumulate on every drop. Same root cause.
3. **Rewind is subtly wrong:** `replay_frame` never clears channel
   buffers, so after a rewind every ToChannel message from tick 0..target
   is still buffered → duplicate spawns/stale writes on the next drain.
   (cubsy main.or:306-308's manual resource patching is a symptom.)
4. **Heap-corruption landmine in the native runtime:** `orion_map_set`'s
   append path has no capacity check; the global slot store is created
   with cap 16 — the 17th distinct `slot_set` key writes past the
   allocation.
5. **Silent miscompiles in orion-self:** `..=` inclusive ranges lower
   with `icmp_lt` (off-by-one); "UNSUPPORTED op" emits *valid* `add i64
   0, 0` and links a wrong .exe with exit code 0. Errors print to stdout
   and compilation continues.
6. **`apply_effect` is O(total log length) per effect** (atlas_ecs
   rebuilds the whole frame list per effect) — and the render stream
   (~100+ Draw effects/frame) is logged into the permanent TickLog, so
   the quadratic base grows 100× faster than it should.

## The three cross-cutting themes

### A. Silent failure everywhere (all four layers)
- Astra: unknown var/fn → NoneV, failed parse → empty Compiled (game
  silently does nothing), no error channel to the host.
- Atlas: dispatch returns 0 on failure, drainers read fields blind.
- orion-self: type guesses ("unknown fn returns i64"), errors don't stop
  the build, driver exits 0.
- lodge-orion: `read_file` → `""`, gpu swallows HRESULTs.
This is the #1 trust problem. Fix order: loud errors in astra_run +
project_setup refuses to start on parse failure; fail-fast in orion-self
driver (stderr + non-zero exit + UNSUPPORTED fatal).

### B. Costs that survive native compilation
- orion-self runtime: `orion_list_push` copies the whole list per push
  (token lists, IR lists, game lists — all quadratic); LLVM text built
  by repeated string concat (O(n²) on 1.2MB); malloc-everywhere-no-free
  → a 60fps game OOMs in minutes. Needs growable lists, string builder,
  and an arena/frame allocator (or Boehm as stopgap).
- Atlas: per-frame full-entity MapV packing 5×/frame; per-frame
  create_buffer; the O(log) effect append.
- Astra: env scans, per-tick re-parse of components
  (compile_parse_result uncached), string-keyed everything.

### C. Decisions to make BEFORE the native push (or they fossilize)
1. **Scoping:** astra eval_call is dynamically scoped today (params
   bound on top of caller env). Must become lexical (consts + params
   only) while the corpus is 13 small files.
2. **`=` semantics:** `name = value` currently means three different
   things (host SetVar effect / implicit let-in / planned const).
   Decide: top-level `=` → const, rule-level `=` → local binding,
   `set` keyword → host effect. Aligns with the kill-const plan.
3. **Runtime ownership:** list/map/text semantics live in emit_runtime()
   inline IR; effects/time in orion_rt.c; a third copy in lodge-orion
   Rust. The exit plan doc proposes a Rust staticlib — contradicting the
   current C+inline-IR direction. Pick ONE owner before Tier-1 builtins
   land twice.
4. **31-bit truth mask** for edge-triggered rules: rules ≥31 silently
   degrade to fire-every-tick. Also positional → hot-reload corrupts
   edge state. Replace with unbounded bitstring resource.

## What is genuinely good (keep, don't churn)

- Astra: layering (value→outcome→ast→lexer→parser→eval→run), closed
  effect enum, correct edge-trigger core, compile-time `each` rule
  expansion with correct shadowing, the parse-smoke harness.
- Atlas: single mutation ingress, channels as the one primitive,
  atlas_astra as a clean host seam, truths-bitmask round-trip design
  (state rewinds with the world), SPEC.md discipline.
- orion-self: real self-hosting with a generational fixpoint test,
  5-orb pipeline a single person can hold in their head, enum
  exhaustiveness/defer/pipe/effects actually wired, inline runtime
  enables clang inlining into hot loops.
- lodge-orion: enumerable `__os_*` FFI boundary (the port surface is
  greppable), lean deps (no winit/wgpu), Arc CoW lists/maps, honest
  STATUS.md.

## Native-path blockers discovered (adjusts the phase plan)

- **No floats in orion-self.** Lexer emits float tokens; parser/IR/emit
  have nothing. Hard blocker for D3D12 vertex data, positions, dt.
  → f64 end-to-end is now part of phase 3, before D3D12.
- **extern fn is parsed and thrown away** — every extern call prints a
  spurious ERROR and works only because the i64 guess matches. Register
  real signatures.
- **Multi-orb compile doesn't exist** (bash concat, one namespace).
  Cubsy is a 9-orb graph.
- **gpu.rs must not be ported as-is:** current model is allocator reset
  + record + clear + ExecuteCommandLists **per draw call** (second draw
  clears the first), busy-wait present, new committed resource per
  write_buffer. Redesign the frame model (clear in begin_frame, submit
  in present, persistent upload ring) in whichever home it lands.
- **Port difficulty:** window.rs easy (already raw Win32), audio medium
  (WASAPI in C ~300 lines; WAV decoder → Orion), gpu medium-hard
  (raw COM vtables in C, mechanical but 2-3×the code).

## Dev-loop relief (lodge-orion, optional but cheap)

A realistic 5-10x interpreter speedup exists: pre-resolve call targets
into the AST (kill the string-compare cascade + linear builtin scan,
2-3d) + slot-indexed locals (env as Vec, 3-4d). Would make
Astra-on-Orion iteration interactive while the native path matures.
Also: `Value::Bytes` variant (10-30x on asset/file work), feature-gate
cranelift (build time), fix gpu stub extern drift.

## SEQUENCED PLAN (merged top-lists, correctness → native → polish)

### Week 1 — stop being lied to (all ~hours each)
1. Loud Astra compile errors (error field in Compiled; project_setup
   refuses to start on failure; cache failures too)
2. Harness semantic assertions (expected rule/fn counts per script —
   render=7 would have failed today)
3. Fail-fast orion-self driver (stderr, non-zero exit, UNSUPPORTED fatal)
4. Fix drop.astra + render.astra interim (hoist dedented statements)
5. Fix `..=` lowering; map capacity check + doubling
6. Cache compile_parse_result (unify into Compiled)

### Week 2 — the language decisions (before anything fossilizes)
7. Lexical scoping in eval_call (~2h + script verification)
8. `=` semantics settlement + kill const + optional fn (parser + migrate
   13 scripts, ~1 day)
9. INDENT/DEDENT lexing in Astra — the single highest-value language
   change; fixes the W2 bug class permanently, makes nested `when` real
   (~1-2 days)
10. Replace 31-bit truth mask with bitstring resource (~3-4h)

### Weeks 3-4 — native phase 3 prerequisites
11. Growable lists in emit_runtime (kills biggest O(n²) in compiler AND
    game, 1-2d)
12. String-builder emit (O(n) codegen, 1d)
13. extern fn registration end-to-end (1d)
14. f64 end-to-end (3-5d — the long pole; blocking D3D12)
15. Hoist allocas to entry block (0.5d — stack growth in game loop)
16. In-driver multi-orb compile, retire bundle_orbs.sh (1-2d)
17. Arena/frame allocator in orion_rt.c (2-3d)

### Then — D3D12 (phase 3 proper)
18. d3d12_min.c shim with the CORRECT frame model (begin_frame clears,
    draws record, present submits; persistent upload ring; fence wait
    not spin)

### Parallel/optional — Atlas hygiene (survives native, ~1 day total)
19. O(1) effect append (separate current_effects key)
20. Transient channels (Draw/mouse_move excluded from TickLog)
21. Clear channels during replay (fixes rewind dupes)
22. AstraSetVar → SetResource direct (dead set_resource exists; kills
    all drainers)
23. Component decls in cubsy scripts + project_event_ecs (kills packers;
    the reflection path already exists unused)
24. Despawn removes component entries

### Later
25. project_run engine loop → "no main.or" (after 19-24)
26. lodge-orion interp 5-10x (pre-resolve + slots) if dev loop hurts
27. Minimal AST-level type checker in orion-self (grow incrementally
    once floats/externs force real signatures — NOT a big-bang checker)

Full agent reports archived in git history of this file's first commit.
