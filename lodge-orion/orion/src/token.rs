//! The token vocabulary — the "alphabet" the parser will match on.
//!
//! A *token* is one indivisible piece of source text: a number, a name, a
//! keyword, a piece of punctuation. The lexer (`lexer.rs`) turns raw text into a
//! stream of these; the parser (a later milestone) builds a tree out of them.
//!
//! Kept apart from the scanner on purpose, so "what a token is" and "how text
//! becomes one" stay two small, readable files — same split astra uses.
//!
//! Each keyword gets its own tag (`Data`, `Fn`, …) so the parser never has to
//! compare strings; everything else is `Int`/`Float`/`Str`/`Ident` plus
//! punctuation.

/// One lexical atom.
#[derive(Clone, Debug, PartialEq)]
pub enum Tok {
    // ---- literals & names ----
    Int(i64),
    Float(f64),
    Str(String),
    Ident(String),

    // ---- item / declaration keywords ----
    // Reserved per the design (ORION.md §2 + §4 + §14) even when the parser
    // doesn't consume them yet — they're committed words that future grammar
    // hangs on. Don't take them out to free identifier names.
    Data,    // data Position: x: f32, y: f32
    Enum,    // enum Shape: Circle(f32) | …
    Fn,      // fn double(x: int) -> int
    System,  // system move(dt: f32):
    Query,   // query wounded() -> [Entity]
    Trait,   // trait Drawable:                  (§14 — generic code)
    Impl,    // impl Drawable for Position:      (§14 — generic code)
    Dyn,     // [dyn Drawable]                   (§14 — opt-in dispatch)
    Region,  // region frame { ... }             (§4  — arena escape)
    Raw,     // raw: ...                         (§4  — unsafe escape)
    Extern,  // extern fn name(...) -> T
    Pub,     // pub fn ...
    Use,     // use physics.collide

    // ---- binding / parameter qualifiers ----
    Mut,  // mut y = 0   /   fn heal(target: mut Health)
    Take, // fn equip(item: take Item)   (also the query `take N` limiter)

    // ---- contracts ----
    Require, // require amount > 0
    Ensure,  // ensure h.hp >= 0
    Fact,    // fact alive = health > 0

    // ---- world mutation ----
    Spawn,   // spawn Position{..}, Velocity{..}
    Destroy, // destroy e

    // ---- control flow ----
    If,
    Then,
    Else,
    Match,
    For,
    Loop,
    Break,
    Continue,
    Return,
    In,

    // Query-clause and modifier words (`all`, `with`, `without`, `maybe`,
    // `where`, `order`, `by`, `group`, `skip`, `parallel`, `scope`, `before`,
    // `after`, `deterministic`) are deliberately NOT reserved here. They are
    // *contextual* keywords: the M3 query/system parser recognises them by string
    // only in the position they're meaningful, so they stay usable as ordinary
    // names (e.g. a parameter called `by` or `order`) everywhere else.

    // ---- logic & boolean literals ----
    And,
    Or,
    Not,
    True,
    False,
    None, // the `none` optional literal

    // ---- punctuation & operators ----
    LParen,     // (
    RParen,     // )
    LBrace,     // {
    RBrace,     // }
    LBracket,   // [
    RBracket,   // ]
    Comma,      // ,
    Dot,        // .
    Colon,      // :
    Assign,     // =   (binding / reassignment)
    Eq,         // ==
    Ne,         // !=
    Lt,         // <
    Le,         // <=
    Gt,         // >
    Ge,         // >=
    Plus,       // +
    Minus,      // -
    Star,       // *
    Slash,      // /
    Percent,    // %
    PlusEq,     // +=
    MinusEq,    // -=

    // ---- bit operators (operate on int) ----
    BitAnd,     // &
    BitOr,      // |
    BitXor,     // ^
    Tilde,      // ~ (prefix: bitwise NOT)
    Shl,        // <<
    Shr,        // >>
    Arrow,      // ->   (return type, match arm)
    FatArrow,   // =>   (closure)
    RangeExcl,  // ..<  (0..<n, exclusive — Swift style)
    RangeIncl,  // ...  (0...n, inclusive; also a range *type*)
    Question,   // ?    (optional type / propagation)
    QuestionDot,// ?.   (optional chaining)
    Newline,
}

/// A token plus where it began: the source line, and its column (0-based byte
/// offset from the line start).
///
/// The line points an error at a place without needing full spans. The column
/// drives the **offside rule** — children nest by being more indented than their
/// parent — which is what lets Orion's blocks skip braces (same trick as astra
/// views).
#[derive(Clone, Debug, PartialEq)]
pub struct Token {
    pub tok: Tok,
    pub line: u32,
    pub col: u32,
}

/// Why lexing stopped before consuming the whole source.
#[derive(Debug, PartialEq)]
pub struct LexError {
    pub message: String,
    pub line: u32,
    pub col: u32,
}
