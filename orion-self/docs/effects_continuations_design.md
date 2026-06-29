# Effects with Continuations — Design for Next Session

## Where we are

Static dispatch effects ship as of #202. `perform Effect.op(args)` lowers to a direct call of `__handler_Effect_op(args)`. Works end-to-end via orion.exe v4. 80% of practical effect uses covered (mocking, logging, deterministic testing, dependency injection).

## What's missing

Real algebraic effects can `resume k(value)` — the handler decides if/when the original `perform` site comes back. Without this you can't model:

- Async I/O (`perform Async.fetch(url)` pauses, resumes when data ready)
- Cooperative multitasking
- Cancellation (handler aborts the computation by not resuming)
- Game replay (handler feeds recorded inputs, computation resumes)

## Approach: setjmp/longjmp (one-shot)

Use libc setjmp/longjmp. One-shot only — `resume` works once per perform. For multi-shot we'd need libco or similar.

### Runtime (emit_llvm)

```llvm
declare i32 @setjmp(ptr) returns_twice
declare void @longjmp(ptr, i32) noreturn

@__orion_current_k = global ptr null
@__orion_resume_value = global i64 0

define i64 @__orion_perform_int(ptr %handler_fn, i64 %arg) {
entry:
  %jb = alloca [64 x i64], align 16
  %old_k = load ptr, ptr @__orion_current_k
  store ptr %jb, ptr @__orion_current_k
  %sj = call i32 @setjmp(ptr %jb)
  %is_first = icmp eq i32 %sj, 0
  br i1 %is_first, label %first_call, label %resumed
first_call:
  %ret = call i64 %handler_fn(i64 %arg)
  store ptr %old_k, ptr @__orion_current_k
  ret i64 %ret
resumed:
  %v = load i64, ptr @__orion_resume_value
  store ptr %old_k, ptr @__orion_current_k
  ret i64 %v
}

define void @__orion_resume_int(i64 %value) {
entry:
  store i64 %value, ptr @__orion_resume_value
  %k = load ptr, ptr @__orion_current_k
  call void @longjmp(ptr %k, i32 1)
  unreachable
}
```

### User-side API

```orion
effect Async:
    fetch: fn(url: Text) -> int

# Handler that resumes with constant
fn __handler_Async_fetch(url: Text) -> int:
    resume_int(42)   # never returns
    0  # unreachable

fn main() -> int:
    n = perform Async.fetch("api")   # n = 42 after handler resumed
    n  # exit 42
```

### Implementation steps (in order)

1. **emit_runtime additions** — add the LLVM IR runtime above.
2. **Function-pointer support in IR** — new instruction `ir_fn_ref(name)` that produces a fn pointer value. emit_llvm: `%v = bitcast ptr @<name> to ptr` (or just use `@<name>` directly since LLVM functions are already ptrs).
3. **Modify Perform lowering** in ast_to_ir — instead of direct call, emit:
   ```
   fn_ref_id = ir_fn_ref("__handler_X_op")
   result = ir_call("__orion_perform_int", [fn_ref_id, arg0_id], "i64")
   ```
4. **Add `resume_int(value)` as a builtin** — recognize it like other builtins (e.g. `print_line`), lower to `ir_call("__orion_resume_int", [value], "void")`.
5. **Test** — write a one-shot resume demo. Verify: handler resumes → caller gets resumed value; handler doesn't resume → caller gets handler return.

### Risks

- **Stack alignment** — setjmp on Windows needs 16-byte alignment, jmp_buf size differs (Windows: 256 bytes; Linux: 200; macOS: ~200).
- **ABI quirks** — handler return type must match expected; mismatch = corruption.
- **LLVM verifier** — `returns_twice` attribute on setjmp must be present or optimizer mis-compiles.
- **One-shot only** — second `resume` of same `k` = UB (jmp_buf was overwritten when we restored old_k).
- **No async** — for real async we'd need to STORE k somewhere, return from handler, resume LATER from another thread. setjmp doesn't support that across thread boundaries. libco does.

### After one-shot works

To extend to multi-shot / true async:
- Replace setjmp/longjmp with libco
- libco provides `co_create(stack_size, fn)` + `co_switch(co)` + `co_active()`
- Continuations become heap-allocated coroutines, can be stored and resumed later
- Add libco.c (~500 LOC, BSD license) to the clang command line

### Why we paused

In-session, the cycle is: edit orb → 30s bundle rebuild → test → debug → repeat. For multi-step systems work like this, the cycle dominates. Better to commit a fresh focused session with the design above as the starting point.

## Estimated time for fresh session

- One-shot setjmp continuations: 3-4h
- Multi-shot via libco: +4h
- `handle E with: op(p) -> body in: code` syntactic sugar: +2h

Total for full algebraic effects shippable: 8-10h spread over 2-3 sessions.
