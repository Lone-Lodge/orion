# Orion — the whole syntax, on one page

Every construct below is drawn from working code (the smoke suite in
`examples/tests` and the demos in `examples/demos`). It is organised from the
smallest pieces up. Orion is indentation-based (offside rule, like Python) and
expression-oriented — the last expression of a block/function is its value, so
there is usually no `return`.

---

## 1. Comments

```orion
# a comment runs to end of line. There are no block comments.
```

## 2. Literals

```orion
42            # int (i64)
3.14          # float (f64)
"hello"       # text (UTF-8 bytes)
'A'           # char literal — an int equal to the byte value (65)
'\n' '\t' '\\' '\'' '\0'   # char/string escapes
true  false   # bool (an int under the hood: 1 / 0)
[1, 2, 3]     # list literal
[]            # empty list
{"a": 1, "b": 2}   # map literal (text or int keys)
{}            # empty map
```

String interpolation — `{expr}` runs any expression:

```orion
"sum = {a + b}, first = {xs[0]}, call = {f(x)}"
```

## 3. Bindings

```orion
x = 5             # immutable binding (also: reassignment of a mut var)
mut n = 0         # mutable binding
mut xs: [int] = []   # typed mut (needed when the value can't be inferred, e.g. [])
move a = big()       # linear binding — may be read at most once (compile-checked)
derived area = w * w   # reactive: reading `area` re-evaluates `w * w` each time
```

`move` makes an aliasing promise checkable (the honest version of `push_mut`):
a second read is a use-after-move compile error. MVP scope: straight-line single
use; a value read in both branches of an `if` is conservatively flagged. `move`
outside the `move NAME =` shape is a plain identifier.

Locals infer their type from the right-hand side. Function *parameters* are
annotated (see §5).

## 4. Types

```orion
int        # i64            bool      # (i64 0/1)
float      # f64            Text/text # UTF-8 text  (built-in names are
[int]      # list of int              #  case-insensitive: text == Text)
[Text]     # list of text   Map/map   # map
[[Text]]   # nested list    fn        # function pointer
Point      # a `data` or `enum` type (capitalised name)
```

## 5. Functions

```orion
fn add(a: int, b: int) -> int:      # block form; body is indented
    a + b                           # last expression is the return value

fn double(x: int) -> int = x * 2    # short form: `= expr`

fn greet(name: Text):               # no `-> type` = a void procedure
    print_line("hi {name}")

return x                            # early exit (optional; tail value is implicit)

pub fn helper() -> int: 1           # `pub` exports from an orb
extern fn win_open(title: Text, w: int, h: int) -> int   # FFI declaration
```

Functions as values, higher-order, lambdas, generics:

```orion
op = add                            # first-class fn reference
fn apply(f: fn, x: int) -> int: f(x)   # higher-order
call_ptr(fnptr, arg)                # call a RAW fn pointer (int), e.g. from dlsym
                                    # — the FFI / hot-reload primitive

inc = fn(n): n + 1                  # lambda (the one lambda syntax)
sq  = fn(x: int): x * x             # lambda with a typed param
add_k = fn(n): n + k                # real closure — captures `k` by value

fn map<T>(xs: [T], f: fn) -> [int]: ...   # generics (erasure); see the iter orb
```

## 6. Operators

```orion
+  -  *  /  %          # arithmetic (int and float)
-x                     # unary negation
== != < <= > >=        # comparison
and  or  not           # logical (keywords, not && || !)
+=  -=  *=  /=         # compound assignment
expr?                  # early-return on Err for a Result-like enum
0..<n                  # exclusive range (0 … n-1)
0..=n                  # inclusive range (0 … n)
```

There are **no** cryptic one-symbol operators (no `|>`, no bitwise soup) — that
is a deliberate readability choice.

## 7. Control flow

`if` — expression form and block form:

```orion
y = if c then a else b              # expression form

if cond:                            # block form
    do_a()
else:
    do_b()
```

`match` — on a value, or subjectless (replaces if/else-if chains):

```orion
kind = match code:                  # scrutinee form, arms use `->`
    1 -> "one"
    2 -> "two"
    _ -> "other"                    # `_` is the wildcard

tier = match:                       # subjectless: first true arm wins
    score > 100 -> 1
    score > 50  -> 2
    else        -> 0
```

`match` arms can be an expression, an inline assignment, or an indented block:

```orion
match tok:
    Num(v) -> total += v            # inline assignment arm (side effect)
    Op(o)  ->                       # block arm: bind locals, last expr is value
        a = pop(stack)
        apply(o, a)
```

Loops:

```orion
for i in 0..<n:            # counted (exclusive); 0..=n for inclusive
for x in xs:               # over a list
for i, x in xs:            # with index

loop:                      # unbounded
    if done: break
    continue
```

## 8. Data & sum types

```orion
data Point: x: int, y: int          # record type (not OOP)
p = Point{x: 3, y: 4}               # construct
p.x                                 # field access

enum Shape: Circle(int), Rect(int, int)    # sum type; variants carry payloads
c = Shape.Circle(5)                        # construct
match c:                                   # destructure in match
    Circle(r)    -> r * r * 3
    Rect(w, h)   -> w * h
```

Payloads can be several mixed fields (`Rect(int, int)`, `Rel(int, text, int)`).
A `data` struct may hold a `[Enum]` field, so recursive structures work as an
arena (`[Node]`, children referenced by index — see `examples/demos/ast_eval.or`).

## 9. Indexing, assignment, methods

```orion
xs[i]         m[k]                  # index a list / map
xs[i] = v     m[k] = v             # element / entry assignment
xs.len()      text.upper()          # method call: x.f(a) desugars to f(x, a)
xs.slice(1, 3)                      # half-open slice [1, 3)
```

## 10. Contracts, defer, comptime

```orion
require x > 0                       # precondition — traps (exit 70) if false
ensure result >= 0                 # postcondition — traps (exit 70) if false
defer cleanup()                    # runs at block end + before any return (LIFO)
comptime fn big() -> int = 2 * 21  # `comptime` modifier: folded at compile time
```

## 11. Effects (algebraic — with continuations)

```orion
effect Random:                     # declare an effect + its operations
    roll: fn(max: int) -> int

handle Random.roll(max: int) -> int:   # the handler for that operation
    resume(73)                     # send a value back to the perform site

n = perform Random.roll(100)       # invoke the effect -> n == 73
# resume(v) resumes the one-shot continuation; int vs text is inferred from v.
```

## 12. Runtime safety

Out-of-range `xs[i]` and a runtime `x / 0` **trap loudly** with a message and
exit 70 — never silent garbage or a bare SIGFPE. The literal `/ 0`, a return
type that doesn't match its body, duplicate function names, and empty bodies
are caught at **compile time**.

---

## Reserved / aspirational — parsed but NOT lowered (do not use)

These *look* like syntax but the compiler has no lowering for them. Using one
is a **loud error**, never a silent miscompile:

- **Types/traits**: `trait`, `impl`, `system` → clear "not supported yet" error
- **Concurrency**: `spawn` / `job` / `scope:` / `parallel for` / `.await`
  → "unknown identifier" / "unhandled statement kind"
- **ECS query**: `for e with Component:` → unhandled
- Other reserved words: `deterministic`, `raw`, `frame`, `before`, `after`,
  `as`, `self`

Effects (§11) DO work. If you reach for one of the above you get told, rather
than getting a program that quietly does the wrong thing.

## The KISS rules of thumb

- One obvious way to do a thing: one lambda syntax, one way to range (`..<` /
  `..=`), plain intermediate variables instead of pipe operators.
- Built-in type names are case-insensitive (`text` == `Text`).
- The compiler tries to *do what you mean*, and to *fail loudly* rather than
  miscompile silently.
