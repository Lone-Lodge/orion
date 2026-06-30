//! The expression grammar: `if…then…else` as a prefix, then precedence climbing
//! over the binary operators, unary `not`/`-`, postfix `.field`, and the
//! primaries — literals, `empty`, variables, `all Kind`, `count(...)`, and
//! parenthesised expressions.

use super::{ParseError, Parser, binop};
use crate::ast::{Expr, UnOp};
use crate::token::Tok;

impl Parser<'_> {
    pub(super) fn expr(&mut self) -> Result<Expr, ParseError> {
        if self.check(&Tok::If) {
            return self.if_expr();
        }
        self.binary(0)
    }

    fn if_expr(&mut self) -> Result<Expr, ParseError> {
        self.eat(&Tok::If)?;
        let cond = Box::new(self.expr()?);
        self.eat(&Tok::Then)?;
        let then = Box::new(self.expr()?);
        self.eat(&Tok::Else)?;
        let otherwise = Box::new(self.expr()?);
        Ok(Expr::If {
            cond,
            then,
            otherwise,
        })
    }

    fn binary(&mut self, min_bp: u8) -> Result<Expr, ParseError> {
        let mut lhs = self.unary()?;
        while let Some(op) = self.peek().and_then(binop) {
            let (lbp, rbp) = op.bp();
            if lbp < min_bp {
                break;
            }
            self.i += 1;
            let rhs = self.binary(rbp)?;
            lhs = Expr::Binary {
                op,
                lhs: Box::new(lhs),
                rhs: Box::new(rhs),
            };
        }
        Ok(lhs)
    }

    fn unary(&mut self) -> Result<Expr, ParseError> {
        let op = match self.peek() {
            Some(Tok::Not) => UnOp::Not,
            Some(Tok::Minus) => UnOp::Neg,
            _ => return self.postfix(),
        };
        self.i += 1;
        Ok(Expr::Unary {
            op,
            rhs: Box::new(self.unary()?),
        })
    }

    fn postfix(&mut self) -> Result<Expr, ParseError> {
        let mut e = self.primary()?;
        while self.check(&Tok::Dot) {
            self.i += 1;
            // `field_name` (not `ident`) so reserved words can be used as
            // member names after a dot — `by.view`, `by.rule`, `by.set` all
            // parse. The dot disambiguates: no declaration starts here.
            e = Expr::Field {
                base: Box::new(e),
                name: self.field_name()?,
            };
        }
        Ok(e)
    }

    fn primary(&mut self) -> Result<Expr, ParseError> {
        match self.bump() {
            Some(Tok::Int(n)) => Ok(Expr::Int(n)),
            Some(Tok::Str(s)) => Ok(Expr::Str(s)),
            Some(Tok::True) => Ok(Expr::Bool(true)),
            Some(Tok::False) => Ok(Expr::Bool(false)),
            Some(Tok::Empty) => Ok(Expr::Empty),
            Some(Tok::Ident(name)) => {
                // `name(args)` is a builtin call (host-registered functions like
                // `t("key")` from atlas-i18n); a bare ident is just a variable.
                if self.check(&Tok::LParen) {
                    self.i += 1;
                    let mut args = Vec::new();
                    if !self.check(&Tok::RParen) {
                        args.push(self.expr()?);
                        while self.check(&Tok::Comma) {
                            self.i += 1;
                            args.push(self.expr()?);
                        }
                    }
                    self.eat(&Tok::RParen)?;
                    Ok(Expr::Call { name, args })
                } else {
                    Ok(Expr::Var(name))
                }
            }
            Some(Tok::All) => Ok(Expr::All {
                kind: self.ident()?,
            }),
            Some(Tok::Count) => self.count(),
            Some(Tok::LParen) => {
                let e = self.expr()?;
                self.eat(&Tok::RParen)?;
                Ok(e)
            }
            other => Err(self.err(&format!("expected an expression, found {other:?}"))),
        }
    }

    fn count(&mut self) -> Result<Expr, ParseError> {
        self.eat(&Tok::LParen)?;
        let var = self.ident()?;
        self.eat(&Tok::In)?;
        let source = Box::new(self.expr()?);
        let filter = if self.check(&Tok::Where) {
            self.i += 1;
            Some(Box::new(self.expr()?))
        } else {
            None
        };
        self.eat(&Tok::RParen)?;
        Ok(Expr::Count {
            var,
            source,
            filter,
        })
    }
}
