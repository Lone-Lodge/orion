//! The parser — turns the token stream into an AST by recursive descent, with
//! precedence climbing for binary operators (`BinOp::bp`).
//!
//! It owns only a cursor (`toks` + `i`); every method consumes exactly the tokens
//! it returns, so an error can name the line it stalled on. The grammar is split
//! across three siblings over this shared cursor — `decls` (top-level forms),
//! `stmts` (function bodies) and `exprs` (the expression grammar) — same layout
//! astra uses.

mod decls;
mod exprs;
mod stmts;

use crate::ast::{BinOp, Program};
use crate::token::{Tok, Token};

/// Why parsing stopped, and where.
#[derive(Debug, PartialEq)]
pub struct ParseError {
    pub message: String,
    pub line: u32,
    pub col: u32,
}

/// Parse a whole token stream into a `Program` (single-file; file id 0).
pub fn parse(tokens: &[Token]) -> Result<Program, ParseError> {
    parse_file(tokens, 0)
}

/// Parse a token stream, stamping each span with `file` (for multi-module builds).
pub fn parse_file(tokens: &[Token], file: u32) -> Result<Program, ParseError> {
    Parser { toks: tokens, i: 0, file }.program()
}

/// A cursor over the token slice. The grammar methods live in the sibling files;
/// these primitives — the only code that touches `toks`/`i` — live here.
struct Parser<'a> {
    toks: &'a [Token],
    i: usize,
    file: u32,
}

impl Parser<'_> {
    fn peek(&self) -> Option<&Tok> {
        self.toks.get(self.i).map(|t| &t.tok)
    }
    pub(super) fn peek_ahead(&self, n: usize) -> Option<&Tok> {
        self.toks.get(self.i + n).map(|t| &t.tok)
    }
    fn check(&self, t: &Tok) -> bool {
        self.peek() == Some(t)
    }
    fn bump(&mut self) -> Option<Tok> {
        let t = self.peek().cloned();
        if t.is_some() {
            self.i += 1;
        }
        t
    }
    fn eat(&mut self, t: &Tok) -> Result<(), ParseError> {
        if self.check(t) {
            self.i += 1;
            Ok(())
        } else {
            Err(self.err(&format!(
                "expected {}, found {}",
                describe(t),
                describe_opt(self.peek())
            )))
        }
    }
    fn ident(&mut self) -> Result<String, ParseError> {
        match self.bump() {
            Some(Tok::Ident(s)) => Ok(s),
            other => Err(self.err(&format!("expected a name, found {}", describe_opt(other.as_ref())))),
        }
    }
    fn skip_newlines(&mut self) {
        while self.check(&Tok::Newline) {
            self.i += 1;
        }
    }
    /// Column of the current token (0 at end of input). The offside rule reads
    /// this — after `skip_newlines` — to nest blocks by indentation, not braces.
    fn cur_col(&self) -> u32 {
        self.toks.get(self.i).map_or(0, |t| t.col)
    }
    /// The source span of the current token (for attaching to AST nodes).
    fn here(&self) -> crate::ast::Span {
        let t = self.toks.get(self.i);
        crate::ast::Span {
            line: t.map_or(0, |t| t.line),
            col: t.map_or(0, |t| t.col),
            file: self.file,
        }
    }
    /// Is the current token the *contextual* keyword `kw` (an identifier with that
    /// spelling)? Query-clause words like `with`/`where` are matched this way so
    /// they stay usable as ordinary names elsewhere.
    fn is_kw(&self, kw: &str) -> bool {
        matches!(self.peek(), Some(Tok::Ident(s)) if s == kw)
    }
    fn eat_kw(&mut self, kw: &str) -> Result<(), ParseError> {
        if self.is_kw(kw) {
            self.i += 1;
            Ok(())
        } else {
            Err(self.err(&format!("expected `{kw}`, found {:?}", self.peek())))
        }
    }
    fn err(&self, message: &str) -> ParseError {
        let here = self.toks.get(self.i).or(self.toks.last());
        ParseError {
            message: message.to_string(),
            line: here.map_or(0, |t| t.line),
            col: here.map_or(0, |t| t.col),
        }
    }
}

/// A human-readable description of a token for error messages ("`:`", "name `x`").
fn describe(t: &Tok) -> String {
    match t {
        Tok::Newline => "a newline".into(),
        Tok::Ident(s) => format!("name `{s}`"),
        Tok::Int(n) => format!("number `{n}`"),
        Tok::Float(x) => format!("number `{x}`"),
        Tok::Str(_) => "a string".into(),
        Tok::Colon => "`:`".into(),
        Tok::Comma => "`,`".into(),
        Tok::Assign => "`=`".into(),
        Tok::Arrow => "`->`".into(),
        Tok::LParen => "`(`".into(),
        Tok::RParen => "`)`".into(),
        Tok::LBrace => "`{`".into(),
        Tok::RBrace => "`}`".into(),
        Tok::LBracket => "`[`".into(),
        Tok::RBracket => "`]`".into(),
        other => format!("{other:?}"),
    }
}

fn describe_opt(o: Option<&Tok>) -> String {
    match o {
        None => "end of input".into(),
        Some(t) => describe(t),
    }
}

/// The binary operator a token introduces, if any — the gate of the precedence loop.
fn binop(t: &Tok) -> Option<BinOp> {
    Some(match t {
        Tok::Or => BinOp::Or,
        Tok::And => BinOp::And,
        Tok::Eq => BinOp::Eq,
        Tok::Ne => BinOp::Ne,
        Tok::Lt => BinOp::Lt,
        Tok::Le => BinOp::Le,
        Tok::Gt => BinOp::Gt,
        Tok::Ge => BinOp::Ge,
        Tok::Plus => BinOp::Add,
        Tok::Minus => BinOp::Sub,
        Tok::Star => BinOp::Mul,
        Tok::Slash => BinOp::Div,
        Tok::Percent => BinOp::Rem,
        Tok::BitAnd => BinOp::BitAnd,
        Tok::BitOr => BinOp::BitOr,
        Tok::BitXor => BinOp::BitXor,
        Tok::Shl => BinOp::Shl,
        Tok::Shr => BinOp::Shr,
        _ => return None,
    })
}
