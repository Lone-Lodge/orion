//! Leaf expressions — literals, names, parens, brackets, `if`, `match`, `spawn`,
//! and map / struct literals. Each opening token gets its own focused helper.

use super::super::{ParseError, Parser};
use crate::ast::{Expr, MatchArm, Pattern};
use crate::token::Tok;

impl Parser<'_> {
    pub(super) fn atom(&mut self) -> Result<Expr, ParseError> {
        let sp = self.here();
        // §10 `comptime EXPR` — must check before the generic Ident
        // arm consumes `comptime` as a variable.
        if matches!(self.peek(), Some(Tok::Ident(n)) if n == "comptime") {
            // Only treat as the keyword when followed by a real expression
            // (the next token starts one). Otherwise fall through and
            // let `comptime` be a regular identifier.
            let starts_expr = matches!(
                self.peek_ahead(1),
                Some(Tok::Int(_)) | Some(Tok::Float(_)) | Some(Tok::Str(_))
                    | Some(Tok::True) | Some(Tok::False) | Some(Tok::None)
                    | Some(Tok::Ident(_)) | Some(Tok::LParen) | Some(Tok::LBracket)
                    | Some(Tok::LBrace) | Some(Tok::If) | Some(Tok::Match)
                    | Some(Tok::Spawn) | Some(Tok::Fn)
            );
            if starts_expr {
                self.bump();
                let inner = self.expr()?;
                return Ok(Expr::Comptime(Box::new(inner)));
            }
        }
        match self.bump() {
            Some(Tok::Int(n)) => Ok(Expr::Int(n)),
            Some(Tok::Float(f)) => Ok(Expr::Float(f)),
            Some(Tok::Str(s)) => self.build_str(s, sp.line),
            Some(Tok::True) => Ok(Expr::Bool(true)),
            Some(Tok::False) => Ok(Expr::Bool(false)),
            Some(Tok::None) => Ok(Expr::None),
            Some(Tok::Ident(name)) => {
                // Capitalised name followed by `{` is a data literal — outside
                // `spawn`, this produces a first-class `Value::Data` rather
                // than a store component.
                if name.starts_with(|c: char| c.is_ascii_uppercase()) && self.check(&Tok::LBrace) {
                    self.bump();
                    return self.struct_lit_tail(name);
                }
                Ok(Expr::Var(name, sp))
            }
            Some(Tok::LParen) => self.atom_paren(),
            Some(Tok::LBracket) => self.atom_brackets(),
            Some(Tok::LBrace) => self.atom_map(),
            Some(Tok::If) => self.atom_if(),
            Some(Tok::Spawn) => self.atom_spawn(),
            Some(Tok::Match) => self.atom_match(sp.col),
            // Anonymous fn — `fn(x, y) = expr`. Captures the surrounding
            // environment when evaluated, just like every modern lambda.
            Some(Tok::Fn) => self.atom_lambda(),
            other => Err(self.err(&format!("expected an expression, found {other:?}"))),
        }
    }

    fn atom_lambda(&mut self) -> Result<Expr, ParseError> {
        self.eat(&Tok::LParen)?;
        let mut params = Vec::new();
        if !self.check(&Tok::RParen) {
            loop {
                let name = self.ident()?;
                // Optional `: Type` — accepted and discarded; lambdas
                // are dynamically typed for now (the typeck returns
                // Unknown for lambda bodies regardless).
                if self.check(&Tok::Colon) {
                    self.bump();
                    let _ = self.ty()?;
                }
                params.push(name);
                if self.check(&Tok::Comma) {
                    self.bump();
                } else {
                    break;
                }
            }
        }
        self.eat(&Tok::RParen)?;
        // Optional return type annotation — also discarded.
        if self.check(&Tok::Arrow) {
            self.bump();
            let _ = self.ty()?;
        }
        self.eat(&Tok::Assign)?;
        self.skip_newlines();
        let body = self.expr()?;
        Ok(Expr::Lambda { params, body: Box::new(body) })
    }

    fn atom_paren(&mut self) -> Result<Expr, ParseError> {
        let e = self.expr()?;
        self.eat(&Tok::RParen)?;
        Ok(e)
    }

    /// `[]`, `[a, b, c]`, or `[projection for var with C [where p]]`.
    fn atom_brackets(&mut self) -> Result<Expr, ParseError> {
        if self.check(&Tok::RBracket) {
            self.bump();
            return Ok(Expr::List(Vec::new()));
        }
        let first = self.expr()?;
        if self.check(&Tok::For) {
            return self.comprehension(first);
        }
        self.list_tail(first)
    }

    fn comprehension(&mut self, projection: Expr) -> Result<Expr, ParseError> {
        self.bump(); // `for`
        let var = self.ident()?;
        let components = self.with_clause()?;
        let filter = if self.is_kw("where") {
            self.bump();
            Some(Box::new(self.expr()?))
        } else {
            None
        };
        self.eat(&Tok::RBracket)?;
        Ok(Expr::Comprehension { projection: Box::new(projection), var, components, filter })
    }

    fn list_tail(&mut self, first: Expr) -> Result<Expr, ParseError> {
        let mut items = vec![first];
        while self.check(&Tok::Comma) {
            self.bump();
            items.push(self.expr()?);
        }
        self.eat(&Tok::RBracket)?;
        Ok(Expr::List(items))
    }

    /// `{ key: value, … }` — a map literal.
    fn atom_map(&mut self) -> Result<Expr, ParseError> {
        let mut pairs = Vec::new();
        if !self.check(&Tok::RBrace) {
            loop {
                let k = self.expr()?;
                self.eat(&Tok::Colon)?;
                let v = self.expr()?;
                pairs.push((k, v));
                if self.check(&Tok::Comma) {
                    self.bump();
                } else {
                    break;
                }
            }
        }
        self.eat(&Tok::RBrace)?;
        Ok(Expr::Map(pairs))
    }

    /// `if cond then a else b` — the *expression* form.
    fn atom_if(&mut self) -> Result<Expr, ParseError> {
        let cond = self.expr()?;
        self.skip_newlines();
        self.eat(&Tok::Then)?;
        self.skip_newlines();
        let then = self.range_expr()?; // don't let this branch eat the `else`
        self.skip_newlines();
        self.eat(&Tok::Else)?;
        self.skip_newlines();
        let otherwise = self.expr()?;
        Ok(Expr::If {
            cond: Box::new(cond),
            then: Box::new(then),
            otherwise: Box::new(otherwise),
        })
    }

    fn atom_spawn(&mut self) -> Result<Expr, ParseError> {
        // §15 `spawn job EXPR` — yields a `Job` handle that `.await`
        // unwraps. Today the work runs immediately (sequential),
        // matching the rest of the interpreter. Real concurrency is
        // Phase C work after Interp becomes Sync.
        if matches!(self.peek(), Some(Tok::Ident(n)) if n == "job") {
            self.bump(); // consume `job`
            let body = self.expr()?;
            // Encode as a Call to a reserved magic name the evaluator
            // intercepts — saves a new AST variant.
            return Ok(Expr::Call {
                callee: Box::new(Expr::Var("__spawn_job".into(), self.here())),
                args: vec![body],
            });
        }
        let mut comps = vec![self.struct_lit()?];
        while self.check(&Tok::Comma) {
            self.bump();
            // Multi-line spawn: allow a newline after the comma so each
            // component can sit on its own line for readability.
            self.skip_newlines();
            comps.push(self.struct_lit()?);
        }
        Ok(Expr::Spawn(comps))
    }

    fn atom_match(&mut self, base_col: u32) -> Result<Expr, ParseError> {
        // Subjectless cond-form: `match:` with `cond -> body` arms, first true
        // wins, `else -> body` as the catch-all. Desugars to a right-nested
        // if/else chain — reuses Expr::If, so eval and typeck stay untouched.
        if self.check(&Tok::Colon) {
            self.eat(&Tok::Colon)?;
            return self.cond_arms(base_col);
        }
        let scrutinee = self.expr()?;
        self.eat(&Tok::Colon)?;
        let arms = self.match_arms(base_col)?;
        Ok(Expr::Match { scrutinee: Box::new(scrutinee), arms })
    }

    /// `match:` cond-form arms — `cond -> body` (first true wins) + a final
    /// `else -> body`. Folded into a right-nested if/else chain.
    fn cond_arms(&mut self, base: u32) -> Result<Expr, ParseError> {
        let mut conds: Vec<(Expr, Expr)> = Vec::new();
        let mut default: Option<Expr> = None;
        loop {
            self.skip_newlines();
            if self.peek().is_none() || self.cur_col() <= base {
                break;
            }
            if self.check(&Tok::Else) {
                self.bump();
                self.eat(&Tok::Colon)?;
                default = Some(self.expr()?);
                break;
            }
            let cond = self.expr()?;
            self.eat(&Tok::Colon)?;
            let body = self.expr()?;
            conds.push((cond, body));
        }
        if conds.is_empty() {
            return Err(self.err("a subjectless `match:` needs at least one `cond -> body` arm"));
        }
        let Some(default) = default else {
            return Err(self.err("a subjectless `match:` needs an `else -> body` arm"));
        };
        let mut chain = default;
        for (cond, body) in conds.into_iter().rev() {
            chain = Expr::If {
                cond: Box::new(cond),
                then: Box::new(body),
                otherwise: Box::new(chain),
            };
        }
        Ok(chain)
    }

    fn match_arms(&mut self, base: u32) -> Result<Vec<MatchArm>, ParseError> {
        let mut arms = Vec::new();
        loop {
            self.skip_newlines();
            if self.peek().is_none() || self.cur_col() <= base {
                break;
            }
            let pattern = self.pattern()?;
            self.eat(&Tok::Arrow)?;
            let body = self.expr()?;
            arms.push(MatchArm { pattern, body });
        }
        if arms.is_empty() {
            return Err(self.err("a `match` needs at least one arm"));
        }
        Ok(arms)
    }

    /// `Variant`, `Variant(a, b)`, `"string"`, `<int>`, or `_`.
    fn pattern(&mut self) -> Result<Pattern, ParseError> {
        // Literal patterns: string, int.
        if let Some(Tok::Str(s)) = self.peek().cloned() {
            self.bump();
            return Ok(Pattern::Str(s));
        }
        if let Some(Tok::Int(n)) = self.peek().cloned() {
            self.bump();
            return Ok(Pattern::Int(n));
        }
        let span = self.here();
        let name = self.ident()?;
        if name == "_" {
            return Ok(Pattern::Wildcard);
        }
        let mut bindings = Vec::new();
        if self.check(&Tok::LParen) {
            self.bump();
            if !self.check(&Tok::RParen) {
                loop {
                    bindings.push(self.ident()?);
                    if self.check(&Tok::Comma) {
                        self.bump();
                    } else {
                        break;
                    }
                }
            }
            self.eat(&Tok::RParen)?;
        }
        Ok(Pattern::Variant { name, bindings, span })
    }

    /// `Kind{ field: value, … }` — used by `spawn`.
    fn struct_lit(&mut self) -> Result<Expr, ParseError> {
        let name = self.ident()?;
        self.eat(&Tok::LBrace)?;
        self.struct_lit_tail(name)
    }

    /// `field: value, … }` — the part after `Name {`, shared between
    /// spawn-component parsing and ordinary data-literal expressions.
    fn struct_lit_tail(&mut self, name: String) -> Result<Expr, ParseError> {
        let mut fields = Vec::new();
        if !self.check(&Tok::RBrace) {
            loop {
                let f = self.ident()?;
                self.eat(&Tok::Colon)?;
                let v = self.expr()?;
                fields.push((f, v));
                if self.check(&Tok::Comma) {
                    self.bump();
                } else {
                    break;
                }
            }
        }
        self.eat(&Tok::RBrace)?;
        Ok(Expr::Struct { name, fields })
    }
}
