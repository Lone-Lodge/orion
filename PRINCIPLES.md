# Lone Lodge — design principles

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
| Idle RAM, 2D game | ≤ 64 MB | (measure at phase 3) |
| Perf floor | 60 fps on integrated graphics, 2-core CPU | — |
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
5. **Fast is a feature of the LANGUAGE.** Growable lists with
   self-rebind in-place push, one-malloc text_join, exact-hex float
   constants — the primitives game code sits on are O(right) by
   default. Astra rules compile down to the same primitives.
6. **Dev loop counts too.** orbit run boots a game instantly under the
   interpreter; native compile is for shipping speed. Both must stay
   fast — a slow tool teaches slow habits.

### Memory rules (no GC — every malloc is forever)

The runtime has no garbage collector: heap memory is either freed by
the frame arena's reset or lives until exit. That makes leaks a
LANGUAGE-level concern, enforced by these invariants and tripwires:

1. **Idle frames allocate zero bytes.** Enforced: atlas
   `app_idle_alloc_check` warns after ~2s of steady idle drip; the
   dev title shows live malloc KB/s next to fps. If KB/s isn't ~0
   with hands off, that's a bug — find it before shipping.
2. **Persistent stores are arena-immune.** The slot store grows via
   malloc and copies keys on insert; the emitted slot-store path
   calls `orion_arena_ptr_guard`, which warns whenever a pointer that
   lives inside the arena is stored persistently (it would dangle at
   the next reset). Cache trees are built with the arena forced off
   (astra `compile()` guard).
3. **Per-frame transients live in the arena.** Render packs, query
   effects, display lists — open an epoch, consume, reset. Anything
   escaping an epoch must be evacuated (`outcome_copy`) first.
4. **Transient UI state never enters the tick log.** Drag positions,
   dirty flags, mouse-move streams use `res_set_int_silent` /
   `channel_emit_silent`. The rewind log records meaningful effects
   only; rewind consumers re-seed transient state.
5. **Never alias-then-self-push.** `mut x = <shared list>` followed
   by `x = push(x, v)` mutates the shared spine in place (the
   self-rebind fast path assumes ownership). Start accumulators from
   `[]`. Compiler-enforced ownership tracking is the planned fix.
6. **Steady-state polls must be stat-only.** Hot-reload checks use
   `orion_file_stamp` (mtime+size); file contents are read only when
   a stamp moves.

### Anti-goals

- Feature parity with Unreal. We win by being 1000x smaller, not by
  matching their checkbox list.
- GPU-driven render graphs, nanite-alikes, ray tracing. A potato has
  no RT cores. Beautiful 2D/stylized 3D at 60 fps everywhere beats
  photorealism on a 4090.
- Editor-first workflows. Text files + hot reload. The editor is a
  debug view, not the product.
