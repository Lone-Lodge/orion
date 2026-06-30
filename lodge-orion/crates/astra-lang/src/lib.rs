//! astra — a small, typed, host-agnostic language for authored game logic.
//!
//! One language for both halves of a world: a **rule** is a pure function from
//! arguments to an `Outcome` — the `Effect`s it proposes, plus the reads and the
//! trace it yields (the write side); a **view** the same shape
//! over a render tree (the read side — reserved). The core does the lexing,
//! typing and evaluation; everything it cannot do for itself — read the world,
//! resolve an imported module — it asks a host through the seam in `host`. The
//! core therefore depends on nothing and names no host: "Astra knows no host"
//! is the dependency graph, not a slogan.
//!
//! Two deliberate smallnesses carry the safety. The value universe is four
//! typed data (`Value`) and absence is `Option`, so the typechecker is a table
//! lookup, not Hindley–Milner. The effect universe is a closed set — three
//! writes (`Set`, `Spawn`, `Destroy`) and one signal (`Emit`) — and nothing
//! else: no IO, no mutation, no unbounded loop, so the sandbox is the grammar,
//! not a runtime guard. A failed `require` proposes zero effects: an illegal
//! move is a silent no-op, exactly Atlas's contract.
//!
//! Atlas embeds the core as `atlas-astra`, mapping `Value` <-> `atlas-wire` and
//! folding each `Effect` into one logged event — the pure-Rust successor to the
//! Luau front-end, and with it the end of mlua's bundled C++.

mod ast;
mod analyze;
mod check;
#[cfg(feature = "lsp")]
pub mod lsp;
mod eval;
mod host;
mod lexer;
mod outcome;
mod parser;
mod render;
mod run;
mod token;
mod types;
mod value;

pub use analyze::{auto_require_tests, hot_columns};
pub use ast::{
    BinOp, EntityDecl, Expr, Param, Program, Rule, Stmt, TestAction, TestDecl, UnOp, View, ViewElem,
};
pub use check::{CheckError, check};
pub use eval::RunError;
pub use host::{Host, Resolver};
pub use lexer::lex;
pub use outcome::{Outcome, Reads, TraceEntry};
pub use parser::{ParseError, parse};
pub use render::Rendered;
pub use run::{Error, dispatch, render, run};
pub use token::{LexError, Tok, Token};
pub use types::Type;
pub use value::{Effect, Value};
