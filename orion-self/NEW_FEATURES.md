# New features shipped this session

## ✅ Closures with captures
`|x| body` where `body` references vars from the enclosing fn.
Lambda lift in `orion_ast_to_ir` rewrites the call site to pass captures
as prepended args to a synthesized `__lambda_N` global fn.

Native compile path only (orion-self orbs → LLVM).

## ✅ Generics MVP
`fn id<T>(x: T) -> T` syntax parses in both orion-self and lodge-orion
parsers. Real **HM substitution** at call sites — generic param names
produce `Ty::Var(name)`, `collect_subst` pins each var to the arg type
that defined it, `apply_subst` rewrites the return type.

Verified: `double(id(21))` typechecks (`id` returns Int, not Unknown).

## ✅ SIMD vector ops
`vec_add(a, b)` / `vec_sub` / `vec_mul` — elementwise int list ops.
`vec_dot(a, b)` — sum-of-products.

Native LLVM emit: `call ptr @orion_vec_add(...)` against inline-emitted
runtime fns. Scalar loop today; clang `-Os` autovectorizer may lift
to `<N x i64>` on AVX2 targets.

## ✅ Async runtime primitives
`time_now_ms()`  → wall clock (non-deterministic)
`monotonic_ms()` → monotonic since process start
`sleep_ms(n)`    → yield to OS

Native lowering via `__orion_time_now_ms` / `__orion_monotonic_ms` /
`__orion_sleep_ms` in `orion_rt.c` (Windows: FILETIME + GetTickCount64
+ Sleep; POSIX: clock_gettime + nanosleep).

## ✅ Async scheduler MVP
`orbs/async/lib.or` adds a cooperative-async layer:
- `sleep_until(deadline_ms)`
- `delay(duration_ms)`
- `deadline_from_now(offset_ms) -> int`
- `past_deadline(deadline_ms) -> int`
- `time_left(deadline_ms) -> int`
- `timers_new() / add_timer / next_due / count_due / wait_next` — a
  deadline-driven timer queue.

A real preemptive scheduler with non-blocking I/O is future work
(libco + IOCP/epoll bindings).

## Test status
**90/90 tests.** New tests added:
- `test_42_generics.or`
- `test_42_simd_native.or`
- `test_42_async_native.or`
- `test_42_scheduler.or`

## Demos
- `examples/compile_or/test_files/demo_all_features.or` — generics + SIMD
- `examples/compile_or/test_files/demo_closure.or` — closure with capture (native only)
- `examples/compile_or/test_files/demo_kitchen_sink.or` — generics + SIMD + async + HM

Run via lodge-orion interp:
```
orbit.exe run examples/compile_or/test_files/demo_kitchen_sink.or main
```
