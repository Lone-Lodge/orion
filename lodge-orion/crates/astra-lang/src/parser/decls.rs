//! Declarations: the top-level forms and their headers — `rule`, `on`, and
//! `record` — plus the shared `name(params)` signature and parameter list. The
//! statements inside a body live in the `stmts` sibling; expression positions
//! defer to `exprs` through `self.expr`.

use super::{ParseError, Parser};
use crate::ast::{
    EntityDecl, Expr, Field, Param, Program, RecordDecl, Rule, Stmt, TestAction, TestDecl, View,
    ViewElem,
};
use crate::token::Tok;

impl Parser<'_> {
    pub(super) fn program(&mut self) -> Result<Program, ParseError> {
        let mut rules = Vec::new();
        let mut records = Vec::new();
        let mut views = Vec::new();
        let mut entities = Vec::new();
        let mut tests = Vec::new();
        self.skip_newlines();
        while self.peek().is_some() {
            match self.peek() {
                Some(Tok::Rule) => rules.push(self.rule()?),
                Some(Tok::On) => rules.push(self.on_rule()?),
                Some(Tok::Record) => records.push(self.record()?),
                Some(Tok::View) => views.push(self.view()?),
                Some(Tok::Entity) => entities.push(self.entity()?),
                Some(Tok::Test) => tests.push(self.test()?),
                other => {
                    return Err(self.err(&format!(
                        "expected `rule`, `on`, `record`, `view`, `entity`, or `test`, found {other:?}"
                    )));
                }
            }
            self.skip_newlines();
        }
        Ok(Program {
            rules,
            records,
            views,
            entities,
            tests,
        })
    }

    /// `entity NAME { field = value, field = value, ... }` — authored Facts as
    /// source. Fields are separated by commas, newlines, or both; the right side
    /// is any expression. A bare identifier matching another entity's name is a
    /// name-ref (resolved at load), so `type = firetype` is the natural form.
    fn entity(&mut self) -> Result<EntityDecl, ParseError> {
        self.eat(&Tok::Entity)?;
        let name = self.ident()?;
        self.optional_colon();
        self.skip_newlines();
        let mut fields = Vec::new();
        // Body ends at end-of-input OR at a true declaration head — a keyword
        // followed by an identifier (`view roster()`). A keyword followed by `=`
        // is a field assignment (`view = "camp"`) and stays in the body.
        while !self.at_decl_head() {
            let field = self.field_name()?;
            self.eat(&Tok::Assign)?;
            let value = self.expr()?;
            fields.push((field, value));
            if self.check(&Tok::Comma) {
                self.i += 1;
            }
            self.skip_newlines();
        }
        Ok(EntityDecl { name, fields })
    }

    /// True if the current position is the start of a *real* declaration —
    /// keyword + identifier or end-of-input. A keyword followed by `=` is a
    /// field assignment and not a declaration boundary.
    fn at_decl_head(&self) -> bool {
        let next = self.peek();
        let after = self.toks.get(self.i + 1).map(|t| &t.tok);
        match next {
            None => true,
            Some(
                Tok::Rule | Tok::On | Tok::Record | Tok::View | Tok::Entity | Tok::Test,
            ) => matches!(after, Some(Tok::Ident(_))),
            _ => false,
        }
    }

    /// `test NAME { apply [rule, rule, ...]; expect field == value; ... }` — an
    /// executable spec. The session is fresh per test; each `apply` fires its
    /// rule on the acting entity (the player by default); each `expect` asserts a
    /// field's value on that entity.
    fn test(&mut self) -> Result<TestDecl, ParseError> {
        self.eat(&Tok::Test)?;
        let name = self.ident()?;
        self.optional_colon();
        self.skip_newlines();
        let mut actions: Vec<TestAction> = Vec::new();
        let mut expects: Vec<(String, Expr)> = Vec::new();
        while !self.at_decl_head() {
            match self.peek() {
                Some(Tok::Apply) => {
                    self.i += 1;
                    actions.push(TestAction::Apply(self.ident()?));
                }
                Some(Tok::Tick) => {
                    self.i += 1;
                    let count = match self.peek() {
                        Some(Tok::Int(n)) if *n > 0 => {
                            let n = *n as u32;
                            self.i += 1;
                            n
                        }
                        // Bare `tick` advances one.
                        _ => 1,
                    };
                    actions.push(TestAction::Tick(count));
                }
                Some(Tok::Set) => {
                    self.i += 1;
                    let field = self.field_name()?;
                    self.eat(&Tok::Assign)?;
                    let value = self.expr()?;
                    actions.push(TestAction::Set { field, value });
                }
                Some(Tok::Expect) => {
                    self.i += 1;
                    let field = self.field_name()?;
                    self.eat(&Tok::Assign)?;
                    let value = self.expr()?;
                    expects.push((field, value));
                }
                other => {
                    return Err(self.err(&format!(
                        "in a `test` body, expected `apply`, `tick`, or `expect`, found {other:?}"
                    )));
                }
            }
            if self.check(&Tok::Comma) {
                self.i += 1;
            }
            self.skip_newlines();
        }
        Ok(TestDecl {
            name,
            actions,
            expects,
        })
    }

    /// `record Name [:] field: Type, field: Type, …` — indent-based.
    fn record(&mut self) -> Result<RecordDecl, ParseError> {
        self.eat(&Tok::Record)?;
        let name = self.ident()?;
        self.optional_colon();
        self.skip_newlines();
        let mut fields = Vec::new();
        while !self.at_decl_head() {
            let name = self.ident()?;
            self.eat(&Tok::Colon)?;
            let ty = self.ident()?;
            fields.push(Field { name, ty });
            if self.check(&Tok::Comma) {
                self.i += 1;
            }
            self.skip_newlines();
        }
        Ok(RecordDecl { name, fields })
    }

    fn rule(&mut self) -> Result<Rule, ParseError> {
        self.eat(&Tok::Rule)?;
        let name = self.ident()?;
        self.eat(&Tok::LParen)?;
        let params = self.params()?;
        self.eat(&Tok::RParen)?;
        let (every, on_target) = self.scheduler_modifiers()?;
        self.optional_colon();
        let (body, expects) = self.indented_body()?;
        Ok(Rule {
            name,
            params,
            body,
            trigger: None,
            expects,
            every,
            on_target,
        })
    }

    /// `on Event(params) [:] <indented body>` — a handler.
    fn on_rule(&mut self) -> Result<Rule, ParseError> {
        self.eat(&Tok::On)?;
        let name = self.ident()?;
        self.eat(&Tok::LParen)?;
        let params = self.params()?;
        self.eat(&Tok::RParen)?;
        self.optional_colon();
        let (body, expects) = self.indented_body()?;
        Ok(Rule {
            trigger: Some(name.clone()),
            name,
            params,
            body,
            expects,
            every: None,
            on_target: None,
        })
    }

    /// Consume an optional `:` after a declaration head. Both `rule x()` and
    /// `rule x():` are accepted; the colon is a visual cue but never required.
    fn optional_colon(&mut self) {
        if matches!(self.peek(), Some(Tok::Colon)) {
            self.i += 1;
        }
    }

    /// Optional `every N` and `on TARGET` modifiers between the rule signature
    /// and its body. Either order, both optional.
    fn scheduler_modifiers(&mut self) -> Result<(Option<i64>, Option<String>), ParseError> {
        let mut every = None;
        let mut on_target = None;
        loop {
            self.skip_newlines();
            match self.peek() {
                Some(Tok::Ident(s)) if s == "every" && every.is_none() => {
                    self.i += 1;
                    match self.peek() {
                        Some(Tok::Int(n)) if *n > 0 => {
                            let n = *n;
                            self.i += 1;
                            every = Some(n);
                        }
                        other => {
                            return Err(self.err(&format!(
                                "after `every`, expected a positive integer, found {other:?}"
                            )));
                        }
                    }
                }
                Some(Tok::On) if on_target.is_none() => {
                    self.i += 1;
                    on_target = Some(self.ident()?);
                }
                _ => break,
            }
        }
        Ok((every, on_target))
    }

    /// Indent-based body: statements (and `expect` postconditions) until the
    /// next top-level declaration or end of input. No braces. Statements end on
    /// a newline; consecutive newlines are skipped.
    fn indented_body(&mut self) -> Result<(Vec<Stmt>, Vec<(String, Expr)>), ParseError> {
        self.skip_newlines();
        let mut body = Vec::new();
        let mut expects = Vec::new();
        while !self.at_decl_head() {
            if matches!(self.peek(), Some(Tok::Expect)) {
                self.i += 1;
                let field = self.field_name()?;
                self.eat(&Tok::Assign)?;
                let value = self.expr()?;
                expects.push((field, value));
            } else {
                body.push(self.stmt()?);
            }
            match self.peek() {
                None | Some(Tok::Newline) => self.skip_newlines(),
                other => {
                    return Err(self.err(&format!("expected end of line, found {other:?}")));
                }
            }
        }
        Ok((body, expects))
    }

    /// `view name(params) [:] <root-element>` — the body is one root element
    /// (which may itself nest children via `{ ... }`).
    fn view(&mut self) -> Result<View, ParseError> {
        self.eat(&Tok::View)?;
        let name = self.ident()?;
        self.eat(&Tok::LParen)?;
        let params = self.params()?;
        self.eat(&Tok::RParen)?;
        self.optional_colon();
        self.skip_newlines();
        let root = self.view_elem()?;
        Ok(View { name, params, root })
    }

    /// One view node: `for var in <source> { <body> }`, or an element
    /// `kind <arg-exprs…> { <children> }` (the `{…}` block optional for a leaf).
    fn view_elem(&mut self) -> Result<ViewElem, ParseError> {
        if self.check(&Tok::For) {
            self.i += 1;
            let var = self.ident()?;
            self.eat(&Tok::In)?;
            let source = self.expr()?;
            self.eat(&Tok::LBrace)?;
            self.skip_newlines();
            let body = Box::new(self.view_elem()?);
            self.skip_newlines();
            self.eat(&Tok::RBrace)?;
            return Ok(ViewElem::For { var, source, body });
        }
        let kind = self.ident()?;
        let mut args = Vec::new();
        while !matches!(
            self.peek(),
            None | Some(Tok::Newline) | Some(Tok::LBrace) | Some(Tok::RBrace)
        ) {
            args.push(self.expr()?);
        }
        let children = if self.check(&Tok::LBrace) {
            self.i += 1;
            self.skip_newlines();
            let mut kids = Vec::new();
            while !self.check(&Tok::RBrace) {
                kids.push(self.view_elem()?);
                self.skip_newlines();
            }
            self.eat(&Tok::RBrace)?;
            kids
        } else {
            Vec::new()
        };
        Ok(ViewElem::Element {
            kind,
            args,
            children,
        })
    }

    /// A field name in an entity declaration: a regular identifier, or any
    /// declaration/expression keyword treated as a plain name (so authors can
    /// write `view = "camp"` or `on = you` without escaping).
    pub(super) fn field_name(&mut self) -> Result<String, ParseError> {
        let name = match self.peek() {
            Some(Tok::Ident(n)) => n.clone(),
            Some(Tok::Rule) => "rule".into(),
            Some(Tok::Record) => "record".into(),
            Some(Tok::Require) => "require".into(),
            Some(Tok::Let) => "let".into(),
            Some(Tok::Set) => "set".into(),
            Some(Tok::Spawn) => "spawn".into(),
            Some(Tok::Destroy) => "destroy".into(),
            Some(Tok::Emit) => "emit".into(),
            Some(Tok::On) => "on".into(),
            Some(Tok::View) => "view".into(),
            Some(Tok::Entity) => "entity".into(),
            Some(Tok::Test) => "test".into(),
            Some(Tok::Apply) => "apply".into(),
            Some(Tok::Expect) => "expect".into(),
            Some(Tok::If) => "if".into(),
            Some(Tok::Then) => "then".into(),
            Some(Tok::Else) => "else".into(),
            Some(Tok::Match) => "match".into(),
            Some(Tok::For) => "for".into(),
            Some(Tok::Count) => "count".into(),
            Some(Tok::All) => "all".into(),
            Some(Tok::In) => "in".into(),
            Some(Tok::Where) => "where".into(),
            Some(Tok::Empty) => "empty".into(),
            Some(Tok::Not) => "not".into(),
            Some(Tok::And) => "and".into(),
            Some(Tok::Or) => "or".into(),
            other => return Err(self.err(&format!(
                "expected a field name, found {other:?}"
            ))),
        };
        self.i += 1;
        Ok(name)
    }

    fn params(&mut self) -> Result<Vec<Param>, ParseError> {
        let mut ps = Vec::new();
        if self.check(&Tok::RParen) {
            return Ok(ps);
        }
        loop {
            let name = self.ident()?;
            let ty = if self.check(&Tok::Colon) {
                self.i += 1;
                Some(self.ident()?)
            } else {
                None
            };
            ps.push(Param { name, ty });
            if self.check(&Tok::Comma) {
                self.i += 1;
            } else {
                break;
            }
        }
        Ok(ps)
    }
}
