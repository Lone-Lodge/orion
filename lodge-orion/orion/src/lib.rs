//! Orion — a next-gen, intent-driven, data-oriented systems language.
//!
//! This crate is the Orion compiler. The pipeline (mirroring astra's shape) is:
//!
//! ```text
//! source text  ->  lex  ->  parse  ->  check  ->  codegen
//!                  ^^^^      (M1)      (M1)        (M3, LLVM/Cranelift)
//! ```
//!
//! Milestones shipped: **M0** `lex`, **M1** `parse` (data + fn), **M2** `check`
//! (scope / mutability / arity) + a tree-walking `interp`reter for pure
//! functions. See `ORION.md` for the design and the milestone roadmap.

pub mod aosoa;
pub mod aot;
pub mod ast;
pub mod check;
pub mod comptime;
pub mod diag;
pub mod format;
pub mod engine;
pub mod footprint;
pub mod interp;
pub mod jit;
pub mod json;
pub mod layout;
pub mod lexer;
pub mod link;
pub mod loader;
pub mod lsp;
pub mod orbit_toml;
pub mod ownership;
pub mod parallel;
pub mod parser;
pub mod select;
pub mod stdlib;
pub mod simd;
pub mod typeck;
pub mod store;
pub mod token;
pub mod value;

pub use lexer::lex;
pub use parser::{ParseError, parse, parse_file};
pub use token::{LexError, Tok, Token};
