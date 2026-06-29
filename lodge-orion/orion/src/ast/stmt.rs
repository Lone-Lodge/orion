//! Statements — the contents of a `fn` block or `system` body.

use super::Expr;

#[derive(Clone, Debug, PartialEq)]
pub enum Stmt {
    /// `require <cond>` — a precondition contract.
    Require(Expr),
    /// `ensure <cond>` — a postcondition contract.
    Ensure(Expr),
    /// `mut name = value` — a new mutable binding.
    Bind { name: String, value: Expr },
    /// `target = value` / `target += value` / `target -= value`. A bare
    /// `name = value` may introduce an immutable binding or reassign an
    /// existing `mut`; the checker decides which.
    Assign {
        target: Expr,
        op: AssignOp,
        value: Expr,
    },
    /// `destroy <entity>`.
    Destroy(Expr),
    /// `for <var> with <components> [where <filter>]:` over the world.
    For {
        var: String,
        components: Vec<String>,
        filter: Option<Expr>,
        body: Vec<Stmt>,
    },
    /// `for <var> in <iter>:` — iterate a list or range. With
    /// `index_var: Some(n)` the loop binds the current index as well
    /// (`for idx, item in items:`).
    ForIn {
        var: String,
        index_var: Option<String>,
        iter: Expr,
        body: Vec<Stmt>,
    },
    /// `if cond:` block [`else:` block] — the *statement* form (distinct from
    /// the `if`-expression in `Expr::If`); a branch may run side effects.
    If {
        cond: Expr,
        then: Vec<Stmt>,
        otherwise: Vec<Stmt>,
    },
    /// `loop:` — repeat the body until a `break`.
    Loop(Vec<Stmt>),
    /// `break` — exit the nearest enclosing loop.
    Break,
    /// `continue` — skip to the next iteration.
    Continue,
    /// `raw:` — explicit unsafe block (§4). Ownership rules relax inside so
    /// FFI calls (`extern fn`) can use values in ways the move-checker would
    /// otherwise reject. Rust's `unsafe` equivalent.
    Raw(Vec<Stmt>),
    /// `parallel for …:` (§15). Wraps a `For` / `ForIn` so the interpreter
    /// can fan out across rayon worker threads. The footprint rules in §6
    /// guarantee that iterations don't conflict for the kernel forms
    /// `parallel.rs` already accepts; richer bodies run sequentially as
    /// a safety fallback.
    Parallel(Box<Stmt>),
    /// `return <expr>` — early exit from the enclosing fn with `expr` as
    /// the value. Bypasses the rest of the body. Last-expression-is-value
    /// stays the idiomatic form; use `return` for guard clauses.
    Return(Expr),
    /// A bare expression — for its effect, or as a block's tail value.
    Expr(Expr),
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum AssignOp {
    Set, // =
    Add, // +=
    Sub, // -=
}
