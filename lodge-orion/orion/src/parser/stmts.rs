//! Statements inside a `fn` block, and the offside block reader.

use super::{ParseError, Parser};
use crate::ast::{AssignOp, Expr, Stmt};
use crate::token::Tok;

impl Parser<'_> {
    /// Read an indented block: every statement whose column is greater than
    /// `base` (the column of the declaration that owns the block). A dedent back
    /// to `base` or shallower — or end of input — ends the block.
    pub(super) fn block(&mut self, base: u32) -> Result<Vec<Stmt>, ParseError> {
        let mut out = Vec::new();
        loop {
            self.skip_newlines();
            if self.peek().is_none() || self.cur_col() <= base {
                break;
            }
            out.push(self.stmt()?);
        }
        Ok(out)
    }

    fn stmt(&mut self) -> Result<Stmt, ParseError> {
        // The statement's own column is the offside baseline for any nested block
        // (e.g. a `for` body).
        let base = self.cur_col();
        // `parallel for` / `scope:` are contextual keywords — recognised
        // only in statement position. Until the rayon-backed scheduler
        // lands (Phase C, see ORION.md §15), they parse the same as a
        // sequential `for` / block. Code written today is forward-
        // compatible — the only thing that changes later is the runtime.
        if matches!(self.peek(), Some(Tok::Ident(n)) if n == "parallel") {
            if let Some(Tok::Ident(_)) = self.peek_ahead(1) {
                // false alarm — `parallel` followed by another ident is
                // just a variable named parallel; fall through.
            } else if matches!(self.peek_ahead(1), Some(Tok::For)) {
                self.bump(); // consume `parallel`
                let inner = self.for_stmt(base)?;
                return Ok(Stmt::Parallel(Box::new(inner)));
            }
        }
        if matches!(self.peek(), Some(Tok::Ident(n)) if n == "scope") {
            if matches!(self.peek_ahead(1), Some(Tok::Colon)) {
                self.bump();             // `scope`
                self.eat(&Tok::Colon)?;
                // A scope block runs its statements sequentially today;
                // `spawn job` inside it runs to completion in-place.
                // Structured-concurrency joining is deferred to Phase C.
                return Ok(Stmt::Raw(self.block(base)?));
            }
        }
        match self.peek() {
            Some(Tok::For) => self.for_stmt(base),
            Some(Tok::If) => self.if_stmt(base),
            Some(Tok::Loop) => {
                self.bump();
                self.eat(&Tok::Colon)?;
                Ok(Stmt::Loop(self.block(base)?))
            }
            Some(Tok::Raw) => {
                self.bump();
                self.eat(&Tok::Colon)?;
                Ok(Stmt::Raw(self.block(base)?))
            }
            // §4 `region frame { ... }` — arena allocation scope.
            // Today treated as a regular block (no real arena yet); the
            // parser keeps the keyword reserved so spec-compliant code
            // round-trips. A future allocator-aware codegen reads this.
            Some(Tok::Region) => {
                self.bump();
                // Optional arena name — most commonly `frame`.
                if let Some(Tok::Ident(_)) = self.peek() {
                    self.bump();
                }
                self.eat(&Tok::LBrace)?;
                let mut body = Vec::new();
                while !self.check(&Tok::RBrace) {
                    self.skip_newlines();
                    if self.check(&Tok::RBrace) {
                        break;
                    }
                    body.push(self.stmt()?);
                }
                self.eat(&Tok::RBrace)?;
                Ok(Stmt::Raw(body))
            }
            Some(Tok::Break) => {
                self.bump();
                Ok(Stmt::Break)
            }
            Some(Tok::Continue) => {
                self.bump();
                Ok(Stmt::Continue)
            }
            Some(Tok::Return) => {
                self.bump();
                Ok(Stmt::Return(self.expr()?))
            }
            Some(Tok::Require) => {
                self.bump();
                Ok(Stmt::Require(self.expr()?))
            }
            Some(Tok::Ensure) => {
                self.bump();
                Ok(Stmt::Ensure(self.expr()?))
            }
            Some(Tok::Fact) => {
                self.bump();
                let name = self.ident()?;
                self.eat(&Tok::Assign)?;
                let expr = self.expr()?;
                Ok(Stmt::Fact { name, expr })
            }
            Some(Tok::Mut) => {
                self.bump();
                let name = self.ident()?;
                self.eat(&Tok::Assign)?;
                let value = self.expr()?;
                Ok(Stmt::Bind { name, value })
            }
            Some(Tok::Destroy) => {
                self.bump();
                Ok(Stmt::Destroy(self.expr()?))
            }
            // Otherwise: an expression, possibly the target of an assignment.
            _ => {
                let target = self.expr()?;
                let op = match self.peek() {
                    Some(Tok::Assign) => Some(AssignOp::Set),
                    Some(Tok::PlusEq) => Some(AssignOp::Add),
                    Some(Tok::MinusEq) => Some(AssignOp::Sub),
                    _ => None,
                };
                match op {
                    Some(op) => {
                        self.bump();
                        let value = self.expr()?;
                        Ok(Stmt::Assign { target, op, value })
                    }
                    None => Ok(Stmt::Expr(target)),
                }
            }
        }
    }

    /// `if cond:` block [`else:` block] (statement) — or `if c then a else b` used
    /// as an expression statement.
    fn if_stmt(&mut self, base: u32) -> Result<Stmt, ParseError> {
        self.eat(&Tok::If)?;
        let cond = self.expr()?;
        if self.check(&Tok::Colon) {
            self.bump();
            let then = self.block(base)?;
            // else binds by COLUMN: only an else at this if's own indent
            // belongs to it — a dedented else belongs to an ENCLOSING if
            // (dangling-else). Parity with orion-self psr fix 2026-07-05.
            let otherwise = if self.check(&Tok::Else) && self.cur_col() == base {
                self.bump();
                if self.check(&Tok::If) {
                    // `else if …` — the chained if IS the else body.
                    vec![self.if_stmt(base)?]
                } else {
                    self.eat(&Tok::Colon)?;
                    self.block(base)?
                }
            } else {
                Vec::new()
            };
            Ok(Stmt::If { cond, then, otherwise })
        } else {
            // expression `if … then … else …` used for its value/effect
            self.skip_newlines();
            self.eat(&Tok::Then)?;
            self.skip_newlines();
            let t = self.range_expr()?; // don't let it swallow this `if`'s `else`
            self.skip_newlines();
            self.eat(&Tok::Else)?;
            self.skip_newlines();
            let e = self.expr()?;
            Ok(Stmt::Expr(Expr::If {
                cond: Box::new(cond),
                then: Box::new(t),
                otherwise: Box::new(e),
            }))
        }
    }

    /// `for <var> with <Comp>, <Comp> [where <filter>]:` + an indented block.
    /// Also: `for <idx>, <var> in <iter>:` for indexed iteration.
    fn for_stmt(&mut self, base: u32) -> Result<Stmt, ParseError> {
        self.eat(&Tok::For)?;
        let first = self.ident()?;
        // Detect `for IDX, VAR in ITER:` — comma after the first ident
        // means the first ident is the index var, second is the value.
        let (var, index_var) = if self.check(&Tok::Comma) {
            self.bump();
            let value_var = self.ident()?;
            (value_var, Some(first))
        } else {
            (first, None)
        };
        // `for v in <iter>:` (range/list) vs `for v with <components>:` (entities)
        if self.check(&Tok::In) {
            self.bump();
            let iter = self.expr()?;
            self.eat(&Tok::Colon)?;
            let body = self.block(base)?;
            return Ok(Stmt::ForIn {
                var,
                index_var,
                iter,
                body,
            });
        }
        // `for IDX, VAR with ...` doesn't make sense — components have no index.
        if index_var.is_some() {
            return Err(self.err("`for idx, var with ...` is not supported — use `for idx, var in ...`"));
        }
        let components = self.with_clause()?;
        let filter = if self.is_kw("where") {
            self.bump();
            Some(self.expr()?)
        } else {
            None
        };
        self.eat(&Tok::Colon)?;
        let body = self.block(base)?;
        Ok(Stmt::For {
            var,
            components,
            filter,
            body,
        })
    }

    /// `with <Comp>, <Comp>, …` — shared by `for` statements and comprehensions.
    pub(super) fn with_clause(&mut self) -> Result<Vec<String>, ParseError> {
        self.eat_kw("with")?;
        let mut comps = vec![self.ident()?];
        while self.check(&Tok::Comma) {
            self.bump();
            comps.push(self.ident()?);
        }
        Ok(comps)
    }
}
