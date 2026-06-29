//! Best-effort type inference for codegen. The full type system lives in
//! `typeck`; here we only resolve the int/float question — that's all
//! Cranelift's ABI cares about for a function signature.
//!
//! Two passes drive the inference:
//! 1. `param_jty_from_body` — scan a body for operations on a named param;
//!    if it's ever paired with a Float operand or used in `sqrt`, infer Float.
//! 2. `ret_jty_from_body` — walk the body's tail expression with the already-
//!    inferred param map. Defaults to Int when nothing pins the type.
//!
//! We do not iterate to a fixpoint. One pass handles every non-mutually-
//! recursive case the user can write today.

use std::collections::HashMap;

use crate::ast::{Expr, FnBody, FnDecl, Stmt};
use crate::jit::JTy;

/// Infer a single parameter's JIT type from its uses in `body`. Default Int.
pub(crate) fn param_jty_from_body(name: &str, body: &FnBody) -> JTy {
    let mut visitor = ParamScan { name, saw_float: false };
    match body {
        FnBody::Expr(e) => visitor.expr(e),
        FnBody::Block(stmts) => visitor.stmts(stmts),
        FnBody::Extern => {}
    }
    if visitor.saw_float { JTy::Float } else { JTy::Int }
}

/// Infer a function's return type from the tail expression of its body. The
/// `param_tys` map covers all reachable fns so calls can be looked up.
pub(crate) fn ret_jty_from_body(
    f: &FnDecl,
    param_tys: &HashMap<String, Vec<JTy>>,
    decls: &HashMap<&str, &FnDecl>,
) -> JTy {
    let scope: HashMap<&str, JTy> = f.params.iter().zip(
        param_tys.get(&f.name).map(|v| v.as_slice()).unwrap_or(&[])
    ).map(|(p, t)| (p.name.as_str(), *t)).collect();

    let cx = RetCx { scope, decls };
    match &f.body {
        FnBody::Expr(e) => cx.expr_jty(e),
        FnBody::Block(stmts) => cx.tail_jty(stmts),
        FnBody::Extern => JTy::Int,
    }
}

// ---------- param scan ----------

struct ParamScan<'a> {
    name: &'a str,
    saw_float: bool,
}

impl ParamScan<'_> {
    fn expr(&mut self, e: &Expr) {
        match e {
            Expr::Binary { lhs, rhs, .. } => {
                self.float_pair_check(lhs, rhs);
                self.expr(lhs);
                self.expr(rhs);
            }
            Expr::Unary { rhs, .. } => self.expr(rhs),
            Expr::If { cond, then, otherwise } => {
                self.expr(cond);
                self.expr(then);
                self.expr(otherwise);
            }
            Expr::Call { callee, args } => {
                // The one float-coercing builtin we know by name today.
                if let Expr::Var(n, _) = callee.as_ref() {
                    if n == "sqrt" && args.iter().any(|a| self.refers_to_param(a)) {
                        self.saw_float = true;
                    }
                }
                self.expr(callee);
                for a in args { self.expr(a); }
            }
            _ => {}
        }
    }

    fn stmts(&mut self, stmts: &[Stmt]) {
        for s in stmts {
            match s {
                Stmt::Expr(e) | Stmt::Require(e) | Stmt::Ensure(e) | Stmt::Destroy(e) => self.expr(e),
                Stmt::Bind { value, .. } => self.expr(value),
                Stmt::Assign { target, value, .. } => { self.expr(target); self.expr(value); }
                Stmt::If { cond, then, otherwise } => {
                    self.expr(cond);
                    self.stmts(then);
                    self.stmts(otherwise);
                }
                Stmt::Loop(body) | Stmt::Raw(body) => self.stmts(body),
                Stmt::Parallel(inner) => self.stmts(std::slice::from_ref(inner)),
                Stmt::ForIn { iter, body, .. } => { self.expr(iter); self.stmts(body); }
                Stmt::For { body, filter, .. } => {
                    if let Some(f) = filter { self.expr(f); }
                    self.stmts(body);
                }
                Stmt::Break | Stmt::Continue => {}
                Stmt::Return(e) => self.expr(e),
            }
        }
    }

    /// If our param appears on one side of a binary op and a float literal
    /// (or float-typed expression) appears on the other, it must be Float.
    fn float_pair_check(&mut self, a: &Expr, b: &Expr) {
        let touches = self.refers_to_param(a) || self.refers_to_param(b);
        let floaty = is_floaty(a) || is_floaty(b);
        if touches && floaty {
            self.saw_float = true;
        }
    }

    fn refers_to_param(&self, e: &Expr) -> bool {
        matches!(e, Expr::Var(n, _) if n == self.name)
    }
}

fn is_floaty(e: &Expr) -> bool {
    match e {
        Expr::Float(_) => true,
        Expr::Unary { rhs, .. } => is_floaty(rhs),
        Expr::Binary { lhs, rhs, .. } => is_floaty(lhs) || is_floaty(rhs),
        Expr::Call { callee, .. } => matches!(callee.as_ref(), Expr::Var(n, _) if n == "sqrt"),
        _ => false,
    }
}

// ---------- return scan ----------

struct RetCx<'a> {
    scope: HashMap<&'a str, JTy>,
    decls: &'a HashMap<&'a str, &'a FnDecl>,
}

impl RetCx<'_> {
    fn expr_jty(&self, e: &Expr) -> JTy {
        match e {
            Expr::Int(_) => JTy::Int,
            Expr::Float(_) => JTy::Float,
            Expr::Var(n, _) => self.scope.get(n.as_str()).copied().unwrap_or(JTy::Int),
            Expr::Unary { rhs, .. } => self.expr_jty(rhs),
            Expr::Binary { lhs, rhs, .. } => unify(self.expr_jty(lhs), self.expr_jty(rhs)),
            Expr::If { then, otherwise, .. } => unify(self.expr_jty(then), self.expr_jty(otherwise)),
            Expr::Call { callee, .. } => match callee.as_ref() {
                Expr::Var(n, _) if n == "sqrt" => JTy::Float,
                Expr::Var(n, _) => {
                    if let Some(f) = self.decls.get(n.as_str()) {
                        if let Some(t) = f.ret.as_ref() {
                            return crate::jit::jty_of_type(t);
                        }
                        // Mutual recursion fallback — default rather than loop.
                    }
                    JTy::Int
                }
                _ => JTy::Int,
            },
            _ => JTy::Int,
        }
    }

    fn tail_jty(&self, stmts: &[Stmt]) -> JTy {
        match stmts.last() {
            Some(Stmt::Expr(e)) => self.expr_jty(e),
            // For `if`/`loop` etc. the block has no value; default Int.
            _ => JTy::Int,
        }
    }
}

fn unify(a: JTy, b: JTy) -> JTy {
    if a == JTy::Float || b == JTy::Float { JTy::Float } else { JTy::Int }
}
