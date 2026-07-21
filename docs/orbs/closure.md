# orb `closure`

closure — first-class closures as a user-space data convention.

The native compile path lifts `|x| body` lambdas + captures via the
orion_ast_to_ir pass. That handles the common pattern:

    adder = |y| base + y       # captures `base`
    adder(42)                  # call site rewritten to lift fn

But the lift is restricted to direct-call use. To pass a closure
AS A VALUE (return it, store it in a list, hand it to a higher-order
fn), we need an env-struct representation.

This orb defines that representation in user-space — no IR changes
needed today. Closures become `Closure { env: [int], fn_id: int }`
pairs, and `apply` dispatches via a hand-written jump table.

Limitations: caller must dispatch fn_id explicitly. Real syntactic
sugar (`c(x)` calling a Closure value transparently) needs a parser
change to detect Closure type at the call site — future work.

## Public functions

### `pub fn make_closure(captures: [int], fn_id: int) -> Closure`

Build a closure: pair of captured environment + fn id (the caller's
private id used by dispatch — a fn name doesn't fit in an int).

### `pub fn closure_env(c: Closure) -> [int]`

Accessors — let callers introspect.

### `pub fn closure_fn_id(c: Closure) -> int`


