//! Statement type checking.

use std::collections::HashMap;

use super::{Cx, Ty, TypeError, assignable, err, span_of};
use crate::ast::{Expr, Stmt};

impl Cx {
    pub(crate) fn block(&self, stmts: &[Stmt], scope: &mut HashMap<String, Ty>) -> Result<(), TypeError> {
        for s in stmts {
            self.stmt(s, scope)?;
        }
        Ok(())
    }

    pub(crate) fn expect(&self, want: &Ty, got: &Ty, e: &Expr, msg: &str) -> Result<(), TypeError> {
        if assignable(want, got) {
            Ok(())
        } else {
            err(format!("{msg} (found {})", got.show()), span_of(e))
        }
    }

    fn stmt(&self, s: &Stmt, scope: &mut HashMap<String, Ty>) -> Result<(), TypeError> {
        match s {
            Stmt::Require(e) | Stmt::Ensure(e) => {
                let t = self.infer(e, scope)?;
                self.expect(&Ty::Bool, &t, e, "a contract condition must be a bool")
            }
            Stmt::Expr(e) => {
                self.infer(e, scope)?;
                Ok(())
            }
            Stmt::Destroy(e) => {
                let t = self.infer(e, scope)?;
                self.expect(&Ty::Entity, &t, e, "`destroy` expects an entity")
            }
            Stmt::Bind { name, value } => {
                let t = self.infer(value, scope)?;
                scope.insert(name.clone(), t);
                Ok(())
            }
            Stmt::Fact { name, expr } => {
                let t = self.infer(expr, scope)?;
                scope.insert(name.clone(), t);
                Ok(())
            }
            Stmt::Assign { target, value, .. } => self.assign(target, value, scope),
            Stmt::For { var, filter, body, .. } => self.for_world(var, filter.as_ref(), body, scope),
            Stmt::ForIn { var, iter, body, .. } => self.for_in(var, iter, body, scope),
            Stmt::If { cond, then, otherwise } => self.if_stmt(cond, then, otherwise, scope),
            Stmt::Loop(body) => {
                let mut inner = scope.clone();
                self.block(body, &mut inner)
            }
            // `raw` shares scope with its parent; type-checking is normal —
            // the safety relaxation is in ownership.rs only.
            Stmt::Raw(body) => self.block(body, scope),
            Stmt::Parallel(inner) => self.stmt(inner, scope),
            Stmt::Break | Stmt::Continue => Ok(()),
            Stmt::Return(e) => {
                self.infer(e, scope)?;
                Ok(())
            }
        }
    }

    fn assign(&self, target: &Expr, value: &Expr, scope: &mut HashMap<String, Ty>) -> Result<(), TypeError> {
        let vt = self.infer(value, scope)?;
        match target {
            Expr::Var(name, _) => {
                scope.entry(name.clone()).or_insert(vt);
                Ok(())
            }
            _ => {
                let tt = self.infer(target, scope)?;
                if !assignable(&tt, &vt) {
                    return err(
                        format!("cannot store {} into {}", vt.show(), tt.show()),
                        span_of(target).or_else(|| span_of(value)),
                    );
                }
                Ok(())
            }
        }
    }

    fn for_world(
        &self,
        var: &str,
        filter: Option<&Expr>,
        body: &[Stmt],
        scope: &HashMap<String, Ty>,
    ) -> Result<(), TypeError> {
        let mut inner = scope.clone();
        inner.insert(var.to_string(), Ty::Entity);
        if let Some(f) = filter {
            let t = self.infer(f, &inner)?;
            self.expect(&Ty::Bool, &t, f, "a `where` filter must be a bool")?;
        }
        self.block(body, &mut inner)
    }

    fn for_in(&self, var: &str, iter: &Expr, body: &[Stmt], scope: &HashMap<String, Ty>) -> Result<(), TypeError> {
        let it = self.infer(iter, scope)?;
        let elem = match it {
            Ty::List(t) => *t,
            _ => Ty::Unknown,
        };
        let mut inner = scope.clone();
        inner.insert(var.to_string(), elem);
        self.block(body, &mut inner)
    }

    fn if_stmt(
        &self,
        cond: &Expr,
        then: &[Stmt],
        otherwise: &[Stmt],
        scope: &HashMap<String, Ty>,
    ) -> Result<(), TypeError> {
        let ct = self.infer(cond, scope)?;
        self.expect(&Ty::Bool, &ct, cond, "an `if` condition must be a bool")?;
        let mut t = scope.clone();
        self.block(then, &mut t)?;
        let mut e = scope.clone();
        self.block(otherwise, &mut e)
    }
}
