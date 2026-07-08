# Orion — language status

## What works today

### Core language
- `fn` / `pub fn` declarations, `extern fn` for FFI
- `mut name = ...` (mutable bindings), `name = ...` (immutable binding / reassignment)
- `fact name = expr` — reactive derived binding; reading `name` re-evaluates
  `expr` against current state (lowered by inlining, so no runtime tick needed)
- Type annotations on params, optional on locals. Built-in type names are
  case-insensitive: `int`, `text`/`Text`, `map`/`Map`, `list`/`List`, `bool`, `float`
- `return <expr>` keyword (early-exit)
- `if cond:` block-form + `if c then a else b` expression-form
- `for v in 0..<n:` (exclusive) and `for v in 0..=n:` (inclusive) ranges; `for v in list:`
- `for idx, v in list:` (with-index iteration)
- `for v with Component:` (ECS query — for entities)
- `loop:` + `break` + `continue` (unbounded loops)
- `match` on int/text patterns + enum-variant destructuring; exhaustiveness checked
- `data` structs (not OOP — pure record types)
- `enum` sum types with payload (tag + val_int + val_text)
- `?` operator (early-return-on-Err for sum types)
- Method-call syntax: `text.upper()`, `list.len()`, `xs.slice(1, 3)` (desugars `x.f(a)` → `f(x, a)`)
- String interpolation of any expression: `"{a + b}"`, `"{xs[0]}"`, `"{f(x)}"`
- `xs[i]` / `m[k]` indexing and `xs[i] = v` / `m[k] = v` element assignment
- Compound assignment: `+=`, `-=`, `*=`, `/=`; unary negation `-x`
- `defer <expr>` — runs at block end + before any `return` (LIFO, block-scoped)
- Contracts: `require <cond>`, `ensure <cond>` (runtime checked)
- `comptime` constant folding

### Functions as values
- **First-class fn refs**: `f = some_fn` binds a fn-pointer; `f(args)` calls indirect
- **Higher-order fns**: `fn apply(f: fn, x: int) -> int: f(x)` end-to-end
- **Lambdas**: `fn(x): x + 1` (the one lambda syntax), with typed params `fn(s: Text): len(s)`
- **Real closures**: a lambda captures locals by value — `add_k = fn(n): n + k` — in
  every position (binding, returned/factory, inline-arg, nested-block, escaping),
  with int / text / list / map captures
- **Generics** (erasure): `fn map<T>(xs: [T], f: fn) -> [int]` — the `iter` orb is generic
  over the element type

### Compile-time checks (loud, not silent)
- Return type must match the body (`fn f() -> int: "hi"` is an error, not garbage)
- Reassignment type must match the binding
- Division / modulo by the literal `0`
- Duplicate function definitions; empty function bodies
- Errors report types in source terms (`int`, `[int]`, `Point`)

### Effects (algebraic — rare next-gen feature)
- `effect Name: op_name: fn(params) -> ret` declarations
- `perform Effect.op(args)` — invoke; static dispatch via `__handler_Effect_op`
- One-shot continuations via setjmp/longjmp: `resume_int(v)`, `resume_text(v)`

### Concurrency
- `spawn job <expr>` + `.await` (basic), `parallel for` (footprint-checked), `scope:` block

### Tooling
- Self-hosting: `orion.exe` compiles its own bundle (fixpoint: stage1 == stage2)
- LLVM IR backend via clang link
- `orbit run / build / test` CLI
- 108/108 smoke tests passing; 15/15 demos

### Stdlib orbs (pure Orion)
`text` (split/join/replace/trim/pad/upper/lower/starts_with/…),
`num` (abs/min/max/clamp/sign/gcd/parse/ipow/is_even/is_odd),
`list` (range/reversed/includes/find/first/last/max_of/min_of/avg),
`dict` (keys/values/size/has_key),
`iter` (map/filter/reduce/any/all/find_index/count/sum/sort_by/max_by/min_by — generic, closure-powered),
plus `result`, `option`, `assert`, `log`, `os`, `async`, `scheduler`, `closure`,
and the compiler internals (`orion_lex` / `orion_parse` / `orion_ir` /
`orion_ast_to_ir` / `orion_emit_llvm` / `orion_driver`).

## What's missing (ranked by impact)

### Language
1. **Type inference for locals** — annotations are optional but there is no full
   HM/bidirectional inference; non-int params still need annotating.
2. **Orb namespaces** — function names are global across `use`d orbs (a clash is a
   clear error today, but there is no `list.sum` qualification).
3. **Generic return-type re-typing** — an element read out of a returned generic
   list (`filter(words, …)[0]`) is opaque at the call site (erasure limit).
4. **Runtime bounds / div-by-zero** — out-of-range `at()` returns garbage and a
   runtime `x / 0` still SIGFPEs (only the literal `/ 0` is caught at compile time).

### Next-gen game / AI
5. **Async runtime** — effects are sync; need a scheduler + multi-shot continuations.
6. **SIMD primitives**, **first-class tensors**.

### Niche
7. Refinement types, distinct/newtype, macros, hot reload.

## Honest summary

**Orion is REAL and self-hosting** — it compiles its own bundle to a native
binary, with closures, generics, sum types, pattern matching, algebraic effects
with continuations, and a small readable standard library.

**Orion is deliberately KISS** — one obvious way to write a lambda (`fn(x): …`),
to chain (plain intermediate variables), and to range (`..<` / `..=`); no cryptic
one-symbol operators. The compiler tries to *do what you mean* (case-insensitive
type names) and to *fail loudly* rather than miscompile silently.

**Orion is NOT FINISHED** — no language is. The gaps above are real, but the core
is solid enough to write ordinary programs (see `examples/demos/`) without surprises.
