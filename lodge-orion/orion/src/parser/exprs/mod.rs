//! The expression grammar: precedence climbing for binary operators, prefix
//! unary operators, and a postfix loop for field access and calls.

mod atom;
mod interp;

use super::{ParseError, Parser, binop};
use crate::ast::{Expr, UnOp};
use crate::token::Tok;

impl Parser<'_> {
    /// A full expression. `value else default` sits below operator precedence.
    pub(super) fn expr(&mut self) -> Result<Expr, ParseError> {
        let e = self.range_expr()?;
        if self.check(&Tok::Else) {
            self.bump();
            let default = self.range_expr()?;
            return Ok(Expr::OrElse {
                value: Box::new(e),
                default: Box::new(default),
            });
        }
        Ok(e)
    }

    /// Like `expr`, but does NOT consume a trailing `else` — used inside `if`'s
    /// then-branch so its own `else` isn't mistaken for an `OrElse`.
    pub(super) fn range_expr(&mut self) -> Result<Expr, ParseError> {
        let lo = self.expr_bp(0)?;
        match self.peek() {
            Some(Tok::RangeExcl) | Some(Tok::RangeIncl) => {
                let inclusive = self.check(&Tok::RangeIncl);
                self.bump();
                let hi = self.expr_bp(0)?;
                Ok(Expr::Range { lo: Box::new(lo), hi: Box::new(hi), inclusive })
            }
            _ => Ok(lo),
        }
    }

    /// Precedence climbing: prefix expression, then fold in binary operators
    /// whose left binding power is at least `min_bp`.
    fn expr_bp(&mut self, min_bp: u8) -> Result<Expr, ParseError> {
        let mut lhs = self.prefix()?;
        while let Some(op) = self.peek().and_then(binop) {
            let (l, r) = op.bp();
            if l < min_bp {
                break;
            }
            self.bump();
            let rhs = self.expr_bp(r)?;
            lhs = Expr::Binary { op, lhs: Box::new(lhs), rhs: Box::new(rhs) };
        }
        Ok(lhs)
    }

    /// Prefix operators bind looser than postfix, so `-a.b` is `-(a.b)`.
    fn prefix(&mut self) -> Result<Expr, ParseError> {
        match self.peek() {
            Some(Tok::Not) => {
                self.bump();
                Ok(Expr::Unary { op: UnOp::Not, rhs: Box::new(self.prefix()?) })
            }
            Some(Tok::Minus) => {
                self.bump();
                Ok(Expr::Unary { op: UnOp::Neg, rhs: Box::new(self.prefix()?) })
            }
            Some(Tok::Tilde) => {
                self.bump();
                Ok(Expr::Unary { op: UnOp::BitNot, rhs: Box::new(self.prefix()?) })
            }
            _ => {
                let atom = self.atom()?;
                self.postfix(atom)
            }
        }
    }

    /// Postfix chain: `.name` / `?.name` and `(args)`, tightest binding.
    fn postfix(&mut self, mut e: Expr) -> Result<Expr, ParseError> {
        loop {
            match self.peek() {
                Some(Tok::Dot) => e = self.field_access(e, false)?,
                Some(Tok::QuestionDot) => e = self.field_access(e, true)?,
                Some(Tok::LParen) => e = self.call(e)?,
                _ => break,
            }
        }
        Ok(e)
    }

    fn field_access(&mut self, base: Expr, safe: bool) -> Result<Expr, ParseError> {
        self.bump();
        let name = self.ident()?;
        Ok(Expr::Field { base: Box::new(base), name, safe })
    }

    fn call(&mut self, callee: Expr) -> Result<Expr, ParseError> {
        self.bump();
        let mut args = Vec::new();
        if !self.check(&Tok::RParen) {
            loop {
                // §11 named arg: `IDENT = EXPR` (only at the top level of
                // an argument). Look for ident-followed-by-`=`. Anything
                // else parses as a regular expression.
                let is_named = matches!(self.peek(), Some(Tok::Ident(_)))
                    && matches!(self.peek_ahead(1), Some(Tok::Assign));
                if is_named {
                    let name = self.ident()?;
                    self.eat(&Tok::Assign)?;
                    let value = self.expr()?;
                    args.push(Expr::NamedArg { name, value: Box::new(value) });
                } else {
                    args.push(self.expr()?);
                }
                if self.check(&Tok::Comma) {
                    self.bump();
                } else {
                    break;
                }
            }
        }
        self.eat(&Tok::RParen)?;
        Ok(Expr::Call { callee: Box::new(callee), args })
    }
}
