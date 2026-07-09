# Orion — language status

## What works today

### Core language
- `fn` / `pub fn` declarations, `extern fn` for FFI
- `mut name = ...` (mutable bindings), `name = ...` (immutable binding / reassignment)
- `derived name = expr` — reactive derived binding; reading `name` re-evaluates
  `expr` against current state (lowered by inlining, so no runtime tick needed)
- Type annotations on params, optional on locals. Built-in type names are
  case-insensitive: `int`, `text`/`Text`, `map`/`Map`, `list`/`List`, `bool`, `float`
- `return <expr>` keyword (early-exit)
- `if cond:` block-form + `if c then a else b` expression-form
- `for v in 0..<n:` (exclusive) and `for v in 0..=n:` (inclusive) ranges; `for v in list:`
- `for idx, v in list:` (with-index iteration)
- `loop:` + `break` + `continue` (unbounded loops)
- `match` on int/text patterns + enum-variant destructuring; exhaustiveness
  checked. Arms are `-> expr`, an inline assignment (`Num(v) -> total += v`),
  or an indented block (bind locals, last expression is the arm's value —
  like an `if` branch). Works in expression and statement position
- `data` structs (not OOP — pure record types)
- `enum` sum types with per-variant payloads, incl. multiple mixed fields
  (`Add(int, int)`, `Rel(int, text, int)`), destructured in `match`
  (`Add(l, r) -> …`). A `data` struct can hold a `[Enum]` field, so recursive
  structures work as an arena (`[Node]`, children referenced by index)
- `?` operator (early-return-on-Err for sum types)
- Method-call syntax: `text.upper()`, `list.len()`, `xs.slice(1, 3)` (desugars `x.f(a)` → `f(x, a)`)
- String interpolation of any expression: `"{a + b}"`, `"{xs[0]}"`, `"{f(x)}"`
- Character literals: `'+'` is the byte value `43` (an int, not a new type),
  escapes too (`'\n'`, `'\t'`, `'\''`) — readable notation for ASCII codes
- `xs[i]` / `m[k]` indexing and `xs[i] = v` / `m[k] = v` element assignment
- Compound assignment: `+=`, `-=`, `*=`, `/=`; unary negation `-x`
- `defer <expr>` — runs at block end + before any `return` (LIFO, block-scoped)
- Contracts: `require <cond>`, `ensure <cond>` — runtime checked; a false
  condition traps loudly (clear message + exit 70)
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

### Checks (loud, not silent)
- Return type must match the body — only when an explicit `-> type` is
  declared (`fn f() -> int: "hi"` is an error; a `->`-less procedure is exempt)
- Reassignment type must match the binding
- Division / modulo by the literal `0` (compile time)
- Duplicate function definitions; empty function bodies
- Errors report types in source terms (`int`, `[int]`, `Point`)
- **Runtime**: out-of-range `xs[i]` traps with `list index N out of range (len L)`
  and `x / 0` traps with `division by zero` (exit 70) — no more silent garbage
  or bare SIGFPE
- Using an unannotated parameter as text/list names the parameter and points
  at the fix (untyped params default to `int`)
- **Linear `move` bindings**: `move x = e` may be read at most once; a second
  read is a compile-time use-after-move error (the checked form of `push_mut`'s
  alias promise). First slice — straight-line use; branch/loop paths not yet
  analyzed (conservatively over-strict on `if` branches)

### FFI + hot reload
- `extern fn name(params) -> ret` — call C / runtime / any native symbol
- `call_ptr(fnptr, arg)` — call a raw function pointer held as an int (e.g. one
  from `dlsym`); distinct from `f(x)`, which assumes `f` is a closure
- **Hot reload works**: compile gameplay code to a `.so`, `dlopen`/`dlsym` it,
  and `call_ptr` the result — swap new code into a running program with state
  preserved. See `examples/hot_reload/` (Orion host, no restart).

### Effects (algebraic — rare next-gen feature)
- `effect Name: op_name: fn(params) -> ret` declarations
- `handle Name.op(params) -> ret:` — the handler (readable sugar; no magic name)
- `perform Effect.op(args)` — invoke
- One-shot continuations via setjmp/longjmp: `resume(v)` (int/text inferred)

### Concurrency — NOT working (parsed/reserved only)
- `spawn` / `job` / `.await` / `parallel for` / `scope:` and the ECS `for v
  with Component:` are reserved words with **no lowering** — they fail to
  parse or are skipped. Listed here as direction, not as features.

### Tooling
- Self-hosting: `orion.exe` compiles its own bundle (fixpoint: stage1 == stage2)
- LLVM IR backend via clang link
- `orbit run / build / test` CLI
- 118/118 smoke tests passing; 21/21 demos (incl. a recursive-descent
  arithmetic calculator, a mini-interpreter with variables, an RPN stack
  machine on an `enum`, a safe evaluator that propagates errors with `?`,
  an arena-based AST evaluator, and a CSV → aligned-table formatter that
  exercises the text stdlib)

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
1. **Non-int param inference** — locals infer from their initializer and the
   return type is optional, but a parameter used as text/list/map still needs
   annotating. This is *deliberate*: the annotation keeps a signature readable
   (a newcomer reads `fn f(s: text)`, not the call sites), and inferring it
   would add a second way to say the same thing. The compiler now names the
   parameter and suggests the fix instead of failing cryptically.
2. **Orb namespaces** — function names are global across `use`d orbs (a clash is a
   clear error today, but there is no `list.sum` qualification).
3. **Generic return-type re-typing** — an element read out of a returned generic
   list (`filter(words, …)[0]`) is opaque at the call site (erasure limit).

### Next-gen game / AI
4. **Async runtime** — effects are sync; need a scheduler + multi-shot continuations.
5. **SIMD primitives**, **first-class tensors**.

### Niche
6. Refinement types, distinct/newtype, macros.
   (Hot reload is no longer here — it works today; see `examples/hot_reload/`.)

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
