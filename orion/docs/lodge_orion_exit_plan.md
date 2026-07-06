# Lodge-orion exit plan — Phase 1 findings (recon)

## Goal
Move atlas/cubsy/astra runtime from lodge-orion (Rust interpreter) to
orion-self (native PE via `orion link`). Then move lodge-orion to legacy/.

## Phase 1 recon — what blocks today

### First failure
`orion link hello.or main hello.exe` → `link error: codegen: cannot call print`.

Even the simplest Orion program with `print()` fails to compile to native.

### Root cause
- `runtime/orion_rt.c` currently only provides effect-continuation helpers
  (`__orion_perform_int`, `__orion_resume_int`, `__orion_perform_text`).
- Native codegen (`jit/codegen/fx.rs:357`) looks up callees in a `frefs`
  HashMap that is NOT populated with stdlib builtins.
- Therefore: every call to `print`, `print_line`, `len`, `at`, `push`,
  `get`, `set`, `bytes_*`, `file_read`, `window_*`, `gpu_*`, `audio_*`
  fails at link time.

### Gap inventory (what native is missing vs lodge-orion's stdlib)

#### Tier 1 — core builtins (every Orion program needs these)
- `print`, `print_line`, `eprint`, `eprint_line`
- `len`, `at`, `push` (lists)
- `get`, `set`, `has` (maps)
- `bytes_from_text`, `bytes_to_text`, `byte_at`, `bytes_length`,
  `bytes_slice`, `bytes_concat`
- `text_concat`, `slice`, `contains`, `fmt_int`, `str_to_int`
- `type_of`, `to_text`

#### Tier 2 — common OS FFI
- File: `file_read`, `file_write`, `read_file`, `write_file`,
  `write_bytes`, `read_line`
- Env: `env_get`, `env_set`, `argv`
- Time: `now_ms`, `unix_time`
- Process: `run_command`
- Net: `tcp_connect`, `tcp_send`, `tcp_recv`

#### Tier 3 — graphics/audio (for atlas/cubsy)
- Window: `window_open`, `window_pump`, `window_should_close`, etc.
- GPU/D3D12: `gpu_init`, `create_buffer`, `write_buffer`,
  `create_shader`, `create_pipeline`, `record_and_submit`, etc.
- Audio: `audio_init`, `audio_play_buffer`, etc.

#### Tier 4 — language internals (for closures, generics, async, effects)
- Closure dispatch with captures
- Generic monomorphization
- Async scheduler
- Effect continuations (already there for int/text — needs more arg types)

## Plan

| Phase | Work | Est days |
|---|---|---|
| 3a | Extend `orion_rt.c` with Tier 1 builtins | 3-5 |
| 3b | Add Tier 2 OS FFI to runtime | 1-2 |
| 3c | Add Tier 3 graphics/audio (windows-sys + D3D12 from native PE) | 5-7 |
| 4 | Multi-orb compile: handle cubsy's 9-orb graph in one link | 2-3 |
| 2 | Fix known lang bugs: #114, #140, #141, #154, #155 | 2-3 |
| 5 | Verify Tier 4 features end-to-end (closures, generics, etc) | 1-2 |
| 6 | Port atlas/cubsy/astra to `orion link`, diff against lodge-orion behaviour | 1-2 |

**Total: 3-4 focused weeks.**

## Implementation strategy

Build `orion-runtime.lib` as a Rust staticlib that orion link can link
against. Each Tier N builtin gets:

1. A C ABI wrapper in the lib (`extern "C" fn __orion_print(s: *const c_char)`)
2. Cranelift codegen knows the symbol → emits `call __orion_print`
3. Linker pulls the symbol from `orion-runtime.lib` into the final PE

This mirrors how lodge-orion's `register_extern("__os_print_line", ...)`
hooks today — but in compiled form, registered once at link time
instead of registered per-interp.

For Tier 3 (graphics), the runtime statically links windows-sys + the
D3D12 crate — the same Rust deps lodge-orion already uses. The
compiled cubsy.exe gets ~2-5MB of windowing/gpu code embedded.

## Acceptance for "lodge-orion to legacy/"

1. ✅ `orion link cubsy/src/main.or main cubsy.exe` produces a runnable
   .exe matching lodge-orion behaviour (clicks, line clear, rewind).
2. ✅ `orion link astra/src/main.or main astra.exe` runs lexer+parser+eval.
3. ✅ `orion link atlas/examples/ecs_smoke main` passes the smoke test.
4. ✅ Diff test: same input gives same output as lodge-orion interpret.
5. ✅ Move `lodge-orion/` to `legacy/lodge-orion/`, update top-level
   README to point at orion-self as the canonical runtime.
