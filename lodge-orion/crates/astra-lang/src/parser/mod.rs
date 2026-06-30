//! The parser — a token stream to an AST by recursive descent, precedence
//! climbing for binary operators (`BinOp::bp`). It owns only a cursor; every
//! method consumes exactly the tokens it returns, so an error names the line it
//! stalled on. The grammar splits across three siblings — `decls` (the top-level
//! forms), `stmts` (rule and handler bodies), and `exprs` (the expression
//! grammar) — over this shared cursor.

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
}

/// Parse a whole source unit into its declarations.
pub fn parse(tokens: &[Token]) -> Result<Program, ParseError> {
    Parser { toks: tokens, i: 0 }.program()
}

/// A cursor over the token slice. The grammar methods live in `decls`/`exprs`;
/// these primitives — the only code that reads `toks`/`i` — live here.
struct Parser<'a> {
    toks: &'a [Token],
    i: usize,
}

impl Parser<'_> {
    fn peek(&self) -> Option<&Tok> {
        self.toks.get(self.i).map(|t| &t.tok)
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
            Err(self.err(&format!("expected {t:?}, found {:?}", self.peek())))
        }
    }
    fn ident(&mut self) -> Result<String, ParseError> {
        match self.bump() {
            Some(Tok::Ident(s)) => Ok(s),
            other => Err(self.err(&format!("expected an identifier, found {other:?}"))),
        }
    }
    fn skip_newlines(&mut self) {
        while self.check(&Tok::Newline) {
            self.i += 1;
        }
    }
    fn err(&self, message: &str) -> ParseError {
        let line = self
            .toks
            .get(self.i)
            .or(self.toks.last())
            .map_or(0, |t| t.line);
        ParseError {
            message: message.to_string(),
            line,
        }
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
        _ => return None,
    })
}
