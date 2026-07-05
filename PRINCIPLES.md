# Lone Lodge — design principles

## #0: The discovery — time, memory and cause are one thing

The log orders CAUSE. Regions give MEMORY a lifetime — which is
time. Determinism makes the future computable and the past
replayable. In every other engine these are three unrelated
systems (frames, GC, mutations); here they are one substance, and
that is why the impossible keeps falling out as corollaries:
foresight rendered live, ghosts of your own past, replay under new
code, bit-identical parallelism, bug classes dying as categories.

Honest calibration: no ingredient is new — event sourcing runs
banks, region memory ran research languages, synchronous causality
flew airplanes. The union is new, and the potato constraint is
what makes it possible: the log is only free when the language
owns every lifetime. Gravity was known for three centuries; the
discovery was that it is a vehicle.

We are not chasing Unity. We are exploring ground their physics
cannot reach.

## #1: Runs on a potato

Small and fast is the product. This is the axis where Unreal/Unity
cannot follow — their business model requires the kitchen sink. Ours
forbids it. Old-school demoscene discipline, next-gen language design.

### Hard budgets (violations are bugs)

| Budget | Limit | Today |
|---|---|---|
| Game .exe (code, no assets) | ≤ 1 MB | hello_window 169 KB |
| Compiler .exe | ≤ 1 MB | 311 KB |
| Cold start → first frame | ≤ 200 ms | (measure at phase 3) |
| Native full rebuild of a game | ≤ 1 s | compiler self-compiles in 292 ms |
| Idle RAM, 2D game (working set) | ≤ 64 MB | active WS ~2.4 MB live session (event-driven idle lets the OS trim) |
| Commit (private bytes) | ≤ 192 MB with d3d12 (driver-dominated), ≤ 32 MB gdi | 106 MB measured (cubsy d3d12) — commit is the promise, WS the footprint |
| Perf floor | 60 fps on integrated graphics, 2-core CPU | software backend 240 fps, d3d12 ~1400 fps (cubsy, 1280×720 windowed) |
| Perf ceiling honesty | GPU backend must be uncapped-capable (no hidden vsync/adapter traps) | ✓ tearing + adapter logged at init |
| Idle cost | 0 frames rendered, 0 heap bytes while nothing happens | ✓ atlas/gates/idle: draws=0 malloc=0B over 300 ticks |
| Draw submission | rect append must never be the frame budget | 6 ns/og_rect measured (st53): 10k rects = 60 µs CPU |
| Runtime dependencies | libc + OS APIs, nothing else | ✓ holds |

### Rules that keep us under budget

1. **No middleware between us and the OS.** Raw Win32, raw D3D12, raw
   WASAPI via thin C shims (win32_min.c pattern). No wgpu, no winit,
   no SDL. Every abstraction layer someone else wrote is size, startup
   time, and a dependency treadmill.
2. **The runtime is emitted, not linked from a blob.** emit_runtime()
   puts list/map/text helpers in the same LLVM module as user code —
   clang inlines them into hot loops and dead-strips what's unused.
3. **Static everything.** One .exe, no DLL hunting, no installer.
   Double-click on a 10-year-old laptop and it runs.
4. **Measure, don't vibe.** Driver prints per-phase ms. Every perf PR
   states before/after numbers. The triple-bootstrap fixpoint is the
   correctness gate; the budget table is the speed gate.
5. **Fast is a feature of the LANGUAGE.** Explicit `push_mut` for
   audited owned accumulators, one-malloc text_join, exact-hex float
   constants — the primitives game code sits on are O(right) by
   default. Astra rules compile down to the same primitives.
6. **Dev loop counts too.** orbit run boots a game instantly under the
   interpreter; native compile is for shipping speed. Both must stay
   fast — a slow tool teaches slow habits.

### Memory rules (no GC — every malloc is forever)

The runtime has no garbage collector: heap memory is either freed by
the frame arena's reset or lives until exit. That makes leaks a
LANGUAGE-level concern, enforced by these invariants and tripwires:

0. **Four lifetimes, nothing else.** Every allocation is epoch
   (render/dispatch arena), frame (the DEFAULT — dies at the
   end-of-frame reset), ring (a generational pool: snapshots and the
   tick log — a generation fills one pool while the other's ages out
   of its ring, then the reclaimed pool resets), or persist (an
   explicit orion_persist scope: the world, caches). Resets poison
   their memory, so a missed persist crashes deterministically
   instead of leaking. Any new world-writing API must be a persist
   scope; anything a consumer retains out of a ring value must be
   evacuated (orion_persist_text). Region SIZES are the runtime's
   job, not a config knob: regions start small and re-size at reset
   (the only moment they are empty by definition); mid-cycle
   overflow chains onto the region and is freed at that same reset —
   spill costs one slow cycle, never a leak. The engine converges to
   what each game actually needs.
1. **Idle frames allocate zero bytes.** Enforced: atlas
   `app_idle_alloc_check` warns after ~2s of steady idle drip; the
   dev title shows live persist-growth KB/s next to fps. If KB/s
   isn't ~0 with hands off, that's a bug — find it before shipping.
2. **Persistent stores are arena-immune.** The slot store grows via
   malloc and copies keys on insert; the emitted slot-store path
   calls `orion_arena_ptr_guard`, which warns whenever a pointer that
   lives inside the arena is stored persistently (it would dangle at
   the next reset). Compilers run INSIDE an epoch and EVACUATE: astra
   `compile()` parses in the arena and deep-copies only the live tree
   to persist (ast_copy_* — every new AST variant needs its copy arm;
   a missed one is a deterministic poison crash on first dispatch).
   Persisting the whole compile cost 6.4MB for 10KB of scripts; the
   evacuated tree is ~190KB.
3. **Per-frame transients live in the arena.** Render packs, query
   effects, display lists — open an epoch, consume, reset. Anything
   escaping an epoch must be evacuated (`outcome_copy`) first.
4. **Transient UI state never enters the tick log.** Drag positions,
   dirty flags, mouse-move streams use `res_set_int_silent` /
   `channel_emit_silent`. The rewind log records meaningful effects
   only; rewind consumers re-seed transient state.
5. **`push` is value-semantic, always.** `x = push(x, v)` copies like
   every other push — the implicit in-place rewrite is retired, so
   aliased-spine mutation is impossible to write by accident. Audited
   owned accumulators (fresh `[]`, no live alias, rebound every call)
   opt into `push_mut(x, v)` explicitly; the audit note lives at the
   call site.
6. **Steady-state polls must be stat-only AND transient.** Hot-reload
   checks use `orion_file_stamp` (mtime+size); file contents are read
   only when a stamp moves. Never wrap a poll in a persist scope —
   persist the WRITE (the swap, the cache insert), not the probe. An
   over-wide persist scope is the one leak the poison can't catch.

### Determinism rules (the log is only worth what replay proves)

1. **Game logic is integer-only.** libm floats are not bit-identical
   across machines — replay verification, leaderboards and lockstep
   break silently. Floats belong to the render side only.
2. **Fixed timestep.** world_tick(16) is the standard; wall-clock
   never reaches rules. Frame pacing is presentation, not simulation.
3. **Effects are outcomes, not simulation.** when-rules + dirty
   gating keep the log sparse. Particles, animation and physics
   tweens are DERIVED render data — never entities, never effects.
   The effect log has a density ceiling; respect it by construction.
4. **Slot store is engine caches only** — unlogged and
   non-deterministic, so game state never lives there. Game state
   lives in worlds, where it is effects and history.
5. **Flat namespaces need manners.** Prefix resources per feature
   (ui_*, drag_*); text resources end _script/_truths/_txt so the
   int-only auto-ctx skips them.

### Anti-goals

- Feature parity with Unreal. We win by being 1000x smaller, not by
  matching their checkbox list.
- GPU-driven render graphs, nanite-alikes, ray tracing. A potato has
  no RT cores. Beautiful 2D/stylized 3D at 60 fps everywhere beats
  photorealism on a 4090.
- Editor-first workflows. Text files + hot reload. The editor is a
  debug view, not the product.
