# Orion — language status

## What works today

### Core language
- `fn` / `pub fn` declarations, `extern fn` for FFI
- `mut name = ...` (mutable bindings), `name = ...` (reassignment)
- Type annotations on params, optional on locals
- `return <expr>` keyword (early-exit)
- `if cond:` block-form + `if c then a else b` expression-form
- `for v in 0..<n:` (exclusive range) and `for v in list:`
- `for idx, v in list:` (with-index iteration)
- `for v with Component:` (ECS query — for entities)
- `loop:` + `break` + `continue` (unbounded loops)
- `match` on int/text patterns + enum-variant destructuring
- `data` structs (not OOP — pure record types)
- `enum` sum types with payload (tag + val_int + val_text)
- `?` operator (early-return-on-Err for sum types)
- Method-call syntax: `text.upper()`, `list.len()`
- String interpolation: `"{name} = {value}"`
- Bitwise ops: `<<`, `>>`, `&`, `|`, `^`, `~`
- Compound assignment: `+=`, `-=`, `*=`, `/=`
- Unary negation: `-x`
- `defer <expr>` — runs at block end + before any `return` (LIFO order; block-scope)
- Pipe operator: `x |> f` → `f(x)`; `x |> f(a, b)` → `f(x, a, b)`
- Exhaustiveness check on enum match (no wildcard → all variants required)
- **First-class fn refs**: `f = some_fn` binds a fn-pointer; `f(args)` calls indirect
- **Higher-order fns**: `fn apply(f: fn, x: int) -> int: f(x)` works end-to-end
- Lambda parsing: `|x| x + 1` syntax parsed but lowering deferred (use named fn + ref instead)
- Contracts: `require <cond>`, `ensure <cond>` (runtime checked)
- `comptime` constant folding

### Effects (algebraic — rare next-gen feature)
- `effect Name: op_name: fn(params) -> ret` declarations
- `perform Effect.op(args)` — invoke
- Static dispatch via fn naming: `__handler_Effect_op`
- One-shot continuations via setjmp/longjmp:
  - `resume_int(value)` — return-via-longjmp with int
  - `resume_text(value)` — return-via-longjmp with text

### Concurrency
- `spawn job <expr>` + `.await` (basic)
- `parallel for` (footprint-checked)
- `scope:` (structured concurrency block)

### Tooling
- Self-hosting: `orion.exe` (294KB native PE) compiles its own bundle
- LLVM IR backend via clang link
- `orbit run / build / test` CLI
- 82/82 tests passing

### Stdlib orbs (pure Orion)
bytes, text, fs, io, time, math, random, log, hash, json, csv, xml, regex, url, base64, hex, color, crypto, easing, noise, format, collections, env, sysinfo, image, audio, gpu, wgsl, net, result, option, assert, plus orion compiler internals (lex/parse/ir/ast_to_ir/emit_llvm).

## What's missing (ranked by impact)

### Critical gaps (every modern language has these)
1. **Generics** — `fn id<T>(x: T) -> T`, `List<int>` parameterized. 8-12h.
2. **Lambda lift pass** — `|x| x + 1` inline syntax. Parser done; needs tree
   walker that hoists Lambdas as `__lambda_N` top-level fns + rewrites
   references. Workaround today: use named fns + first-class fn refs (works).
3. **Closures with captures** — `fn outer(): adder = |y| x + y`. Needs env
   struct + capture analysis on top of lambda lift. 5-8h.
4. **Type inference** — currently you annotate; full HM/bidirectional inference. 6-10h.

### Important for next-gen game/AI
4. **Async runtime** — effects are sync; need scheduler + libco for multi-shot. 15-25h.
5. **SIMD primitives** — `vec4`, `mat4` with hardware vector ops. 8-12h.
6. **First-class tensors** — needed for "AI-friendly" claim. 30-50h.

### Quality of life
7. **Block-scope defer (proper)** — outer-block defers should fire on inner return.
8. **More effect arg types** — currently single int/text arg per perform; need n-arg.
9. **`handle E: ops in body` syntax** — sugar over current naming convention.
10. **Hot reload** — DLL swap for game-dev iteration. 10-20h.

### Niche but cool
11. **Refinement types** — `int where x > 0` statically checked. 40-80h.
12. **Distinct/newtype** — `type UserId = distinct int`. 3-5h.
13. **Macros** — comptime code generation. 15-25h.
14. **Linear types** — Hylo-style move semantics. 30-50h.

## Honest summary

**Orion is REAL.** It's self-hosting, has algebraic effects with continuations (OCaml 5 territory — rare), sum types, pattern matching, all the modern semantics. Game demos work end-to-end natively via orion.exe.

**Orion is NOT FINISHED.** No language ever is. Rust at this maturity didn't have async/await, didn't have const generics. Go still doesn't have generics in some forms.

The remaining gaps (#1–#3 critical) prevent serious production use. Plan: **dedicate one focused session per gap.** Each is 5-12h of careful systems work. Trying to ship them in a tired chat-session = buggy half-features.
