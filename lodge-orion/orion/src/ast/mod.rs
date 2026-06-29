//! The AST. Submodules group definitions by role: top-level declarations
//! (`decls`), statements (`stmt`), and expressions (`expr`). This file holds
//! the fundamentals: source spans, the program wrapper, and written types.

mod decls;
mod expr;
mod stmt;

pub use decls::*;
pub use expr::*;
pub use stmt::*;

/// 1-based line, 0-based column, and the file id (for multi-module spans).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Span {
    pub line: u32,
    pub col: u32,
    pub file: u32,
}

/// A whole parsed source file: its `use` imports and its declarations.
#[derive(Clone, Debug, PartialEq)]
pub struct Program {
    pub uses: Vec<String>,
    pub decls: Vec<Decl>,
}

/// A written type. Includes Orion's range type — the compiler picks the
/// machine representation from it later.
#[derive(Clone, Debug, PartialEq)]
pub enum Type {
    /// `int`, `f32`, `Text`, `Entity`, a `data` name, …
    Named(String),
    /// `0...255` (inclusive) or `0..<256` (exclusive).
    Range { lo: i64, hi: i64, inclusive: bool },
    /// `[T]` — a list of `T`.
    List(Box<Type>),
    /// `T?` — an optional `T` (no null in Orion).
    Optional(Box<Type>),
}
