//! Scope, mutability, arity, and cross-module privacy checks. Runs before
//! type-checking; catches the most common mistakes without needing inference.
//!
//! Rules:
//! - Every used name resolves to a parameter, binding, fn, builtin, or variant.
//! - `x = e` on a fresh name introduces an *immutable* binding; reassigning
//!   needs `mut`. `+=`/`-=` require an existing `mut`.
//! - Calls match the callee's arity.
//! - Cross-module references need `pub` on the defining decl.
//! - `break`/`continue` only inside a loop.

mod expr;
mod stmt;

use std::collections::HashMap;

use crate::ast::{Decl, FnBody, FnDecl, Program, Qualifier, Span, Stmt};

#[derive(Debug, PartialEq)]
pub struct CheckError {
    pub message: String,
    pub span: Option<Span>,
}

pub(crate) fn err_at<T>(msg: impl Into<String>, span: Span) -> Result<T, CheckError> {
    Err(CheckError { message: msg.into(), span: Some(span) })
}

// One builtin table shared with the interpreter — a checker-local copy
// drifted and rejected valid programs. §13 names (added/changed/removed/
// tick_events_clear) dispatch outside builtin() and stay special-cased
// in expr.rs.
pub(crate) use crate::interp::builtin::BUILTINS;

pub fn check(program: &Program) -> Result<(), CheckError> {
    let cx = build_checker(program);
    for decl in &program.decls {
        check_decl(&cx, decl)?;
    }
    Ok(())
}

fn check_decl(cx: &Checker, decl: &Decl) -> Result<(), CheckError> {
    match decl {
        Decl::Fn(f) => {
            cx.check_fn(f)?;
            if f.deterministic {
                check_deterministic_body(cx, &f.body)?;
            }
            Ok(())
        }
        Decl::System(s) => {
            cx.check_body(&s.params, &s.body)?;
            if s.deterministic {
                check_deterministic_stmts(cx, &s.body)?;
            }
            Ok(())
        }
        Decl::Query(q) => {
            let scope = cx.param_scope(&q.params);
            cx.check_expr(&q.body, &scope)
        }
        Decl::Impl(i) => {
            for m in &i.methods {
                cx.check_fn(m)?;
            }
            Ok(())
        }
        // Trait sigs have no bodies; nothing to scope-check.
        Decl::Trait(_) | Decl::Data(_) | Decl::Enum(_) => Ok(()),
    }
}

/// Builtins / orb fns that are forbidden inside `deterministic` bodies
/// (§9). They read fresh state every call (RNG, wall clock, etc.) and
/// breaks the lockstep-reproducibility guarantee netcode/replay needs.
const NON_DETERMINISTIC_NAMES: &[&str] = &[
    "random", "random_int", "random_float", "random_range",
    "uuid_v4", "uuid_new",
    "time_now", "time_now_ms", "time_now_ns", "monotonic_ns",
    "wall_clock", "clock",
    // Heuristic — RNG-flavoured orb fns are usually `*_rand*`.
];

fn is_non_deterministic(name: &str) -> bool {
    NON_DETERMINISTIC_NAMES.contains(&name)
        || name.contains("random")
        || name.contains("rand_")
}

fn check_deterministic_body(cx: &Checker, body: &crate::ast::FnBody) -> Result<(), CheckError> {
    use crate::ast::FnBody;
    match body {
        FnBody::Expr(e) => check_deterministic_expr(cx, e),
        FnBody::Block(stmts) => check_deterministic_stmts(cx, stmts),
        FnBody::Extern => Ok(()),
    }
}

fn check_deterministic_stmts(cx: &Checker, stmts: &[crate::ast::Stmt]) -> Result<(), CheckError> {
    for s in stmts {
        check_deterministic_stmt(cx, s)?;
    }
    Ok(())
}

fn check_deterministic_stmt(cx: &Checker, s: &crate::ast::Stmt) -> Result<(), CheckError> {
    use crate::ast::Stmt;
    match s {
        Stmt::Bind { value, .. } => check_deterministic_expr(cx, value),
        Stmt::Fact { expr, .. } => check_deterministic_expr(cx, expr),
        Stmt::Assign { target, value, .. } => {
            check_deterministic_expr(cx, target)?;
            check_deterministic_expr(cx, value)
        }
        Stmt::Destroy(e) | Stmt::Expr(e) => check_deterministic_expr(cx, e),
        Stmt::Require(e) | Stmt::Ensure(e) => check_deterministic_expr(cx, e),
        Stmt::For { body, filter, .. } => {
            if let Some(f) = filter { check_deterministic_expr(cx, f)?; }
            check_deterministic_stmts(cx, body)
        }
        Stmt::ForIn { iter, body, .. } => {
            check_deterministic_expr(cx, iter)?;
            check_deterministic_stmts(cx, body)
        }
        Stmt::If { cond, then, otherwise } => {
            check_deterministic_expr(cx, cond)?;
            check_deterministic_stmts(cx, then)?;
            check_deterministic_stmts(cx, otherwise)
        }
        Stmt::Loop(body) | Stmt::Raw(body) => check_deterministic_stmts(cx, body),
        Stmt::Parallel(inner) => check_deterministic_stmt(cx, inner),
        Stmt::Break | Stmt::Continue | Stmt::Return(_) => Ok(()),
    }
}

fn check_deterministic_expr(cx: &Checker, e: &crate::ast::Expr) -> Result<(), CheckError> {
    use crate::ast::Expr;
    if let Expr::Call { callee, args, .. } = e {
        if let Expr::Var(name, span) = callee.as_ref() {
            if is_non_deterministic(name) {
                return crate::check::err_at(
                    format!("`{name}` is non-deterministic and cannot be called from a `deterministic` body"),
                    *span,
                );
            }
        }
        for a in args {
            check_deterministic_expr(cx, a)?;
        }
    }
    Ok(())
}

fn build_checker(program: &Program) -> Checker<'_> {
    let mut fns = HashMap::new();
    let mut variants = HashMap::new();
    let mut fn_origin = HashMap::new();
    let mut variant_origin = HashMap::new();
    for decl in &program.decls {
        match decl {
            Decl::Fn(f) => {
                let required = f.params.iter().filter(|p| p.default.is_none()).count();
                fns.insert(f.name.as_str(), (required, f.params.len()));
                fn_origin.insert(f.name.as_str(), (f.file, f.public));
            }
            Decl::System(s) => {
                let required = s.params.iter().filter(|p| p.default.is_none()).count();
                fns.insert(s.name.as_str(), (required, s.params.len()));
                fn_origin.insert(s.name.as_str(), (s.file, s.public));
            }
            Decl::Enum(e) => {
                for v in &e.variants {
                    let arities = variants.entry(v.name.as_str()).or_insert_with(Vec::new);
                    let arity = v.payload.len();
                    if !arities.contains(&arity) {
                        arities.push(arity);
                    }
                    // Origin records the FIRST enum that declared this
                    // variant name; cross-enum collisions still respect
                    // the first-seen visibility for now.
                    variant_origin.entry(v.name.as_str()).or_insert((e.file, e.public));
                }
            }
            _ => {}
        }
    }
    Checker { fns, variants, fn_origin, variant_origin }
}

pub(crate) struct Checker<'a> {
    pub(crate) fns: HashMap<&'a str, (usize, usize)>,
    /// Variant name → set of arities (one entry per enum that declared it).
    /// Multi-arity tolerates cross-enum collisions like Tok::Require + Stmt::Require(Expr).
    pub(crate) variants: HashMap<&'a str, Vec<usize>>,
    /// (def-file, is_public) for each fn/system.
    pub(crate) fn_origin: HashMap<&'a str, (u32, bool)>,
    /// (def-file, is_public) for each enum variant.
    pub(crate) variant_origin: HashMap<&'a str, (u32, bool)>,
}

impl Checker<'_> {
    /// Same-file references are always fine; cross-file requires `pub`.
    pub(crate) fn check_visibility(
        &self,
        name: &str,
        kind: &str,
        origin: Option<&(u32, bool)>,
        use_span: Span,
    ) -> Result<(), CheckError> {
        if let Some((def_file, public)) = origin {
            if *def_file != use_span.file && !public {
                return err_at(
                    format!("{kind} `{name}` is private to its module (declare it `pub` to expose it)"),
                    use_span,
                );
            }
        }
        Ok(())
    }

    pub(crate) fn param_scope(&self, params: &[crate::ast::Param]) -> HashMap<String, bool> {
        params.iter()
            .map(|p| (p.name.clone(), p.qualifier == Some(Qualifier::Mut)))
            .collect()
    }

    fn check_body(&self, params: &[crate::ast::Param], body: &[Stmt]) -> Result<(), CheckError> {
        let mut scope = self.param_scope(params);
        self.check_block(body, &mut scope, false)
    }

    fn check_fn(&self, f: &FnDecl) -> Result<(), CheckError> {
        match &f.body {
            FnBody::Expr(e) => self.check_expr(e, &self.param_scope(&f.params)),
            FnBody::Block(stmts) => self.check_body(&f.params, stmts),
            FnBody::Extern => Ok(()), // no body to check
        }
    }

    /// Run each statement of `block` in the given scope. `in_loop` propagates
    /// down so nested `break`/`continue` are accepted.
    pub(crate) fn check_block(
        &self,
        block: &[Stmt],
        scope: &mut HashMap<String, bool>,
        in_loop: bool,
    ) -> Result<(), CheckError> {
        for s in block {
            self.check_stmt(s, scope, in_loop)?;
        }
        Ok(())
    }
}
