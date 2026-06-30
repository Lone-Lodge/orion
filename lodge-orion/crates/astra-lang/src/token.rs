//! The token vocabulary — the alphabet the parser matches on. Kept apart from
//! the scanner (`lexer`) so "what a token is" and "how text becomes one" stay
//! two small files. Keywords are their own tags, so the parser never compares
//! strings; everything else is `Int`/`Str`/`Ident` plus punctuation.

/// One lexical atom.
#[derive(Clone, Debug, PartialEq)]
pub enum Tok {
    Int(i64),
    Str(String),
    Ident(String),
    // declaration & statement keywords
    Rule,
    Record,
    Require,
    Let,
    Set,
    Spawn,
    Destroy,
    Emit,
    On,
    View,
    Entity,
    Test,
    Apply,
    Expect,
    Tick,
    // expression keywords
    If,
    Then,
    Else,
    Match,
    For,
    Count,
    All,
    In,
    Where,
    Empty,
    True,
    False,
    Not,
    And,
    Or,
    // punctuation & operators
    LParen,
    RParen,
    LBrace,
    RBrace,
    Comma,
    Dot,
    Colon,
    Assign,
    Eq,
    Ne,
    Lt,
    Le,
    Gt,
    Ge,
    Plus,
    Minus,
    Star,
    Slash,
    Percent,
    Newline,
}

/// A token and the source line it began on — enough to point an error at a line
/// without carrying full spans (those arrive with the typechecker).
#[derive(Clone, Debug, PartialEq)]
pub struct Token {
    pub tok: Tok,
    pub line: u32,
}

/// Why lexing stopped before consuming the source.
#[derive(Debug, PartialEq)]
pub struct LexError {
    pub message: String,
    pub line: u32,
}
