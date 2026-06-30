//! Statements: a rule or handler body and the six things it can say —
//! `require`/`let`/`set`/`spawn`/`destroy`/`emit`. Each statement is
//! newline-terminated; a top-level `rule`/`on`/`record`/`view` (or end of input)
//! closes the body. Expression positions defer to `exprs` through `self.expr`.

use super::{ParseError, Parser};
use crate::ast::{Expr, Stmt};
use crate::token::Tok;

impl Parser<'_> {
    pub(super) fn stmt(&mut self) -> Result<Stmt, ParseError> {
        match self.peek() {
            Some(Tok::Require) => {
                self.i += 1;
                Ok(Stmt::Require(self.expr()?))
            }
            Some(Tok::Let) => {
                self.i += 1;
                let name = self.ident()?;
                self.eat(&Tok::Assign)?;
                Ok(Stmt::Let {
                    name,
                    value: self.expr()?,
                })
            }
            Some(Tok::Set) => {
                self.i += 1;
                let target = self.expr()?;
                self.eat(&Tok::Assign)?;
                let value = self.expr()?;
                match target {
                    Expr::Field { base, name } => Ok(Stmt::Set {
                        entity: *base,
                        field: name,
                        value,
                    }),
                    _ => Err(self.err("`set` expects a field target like `cell.mark`")),
                }
            }
            Some(Tok::Spawn) => {
                self.i += 1;
                let kind = self.ident()?;
                let fields = self.brace_fields()?;
                Ok(Stmt::Spawn { kind, fields })
            }
            Some(Tok::Destroy) => {
                self.i += 1;
                Ok(Stmt::Destroy {
                    entity: self.expr()?,
                })
            }
            Some(Tok::Emit) => {
                self.i += 1;
                let event = self.ident()?;
                let fields = self.brace_fields()?;
                Ok(Stmt::Emit { event, fields })
            }
            other => Err(self.err(&format!("expected a statement, found {other:?}"))),
        }
    }

    /// An optional `{ name: expr, ... }` block — the shared payload syntax of
    /// `spawn` and `emit`. Absent braces mean no fields; separators may be commas,
    /// newlines, or both, with any trailing one tolerated.
    fn brace_fields(&mut self) -> Result<Vec<(String, Expr)>, ParseError> {
        let mut fields = Vec::new();
        if self.check(&Tok::LBrace) {
            self.i += 1;
            self.skip_newlines();
            while !self.check(&Tok::RBrace) {
                let name = self.ident()?;
                self.eat(&Tok::Colon)?;
                fields.push((name, self.expr()?));
                if self.check(&Tok::Comma) {
                    self.i += 1;
                }
                self.skip_newlines();
            }
            self.eat(&Tok::RBrace)?;
        }
        Ok(fields)
    }
}
