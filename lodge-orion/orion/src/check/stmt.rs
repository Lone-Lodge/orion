//! Statement-level scope, mutability, and loop-context checks.

use std::collections::HashMap;

use super::{CheckError, Checker, err_at};
use crate::ast::{AssignOp, Expr, Stmt};

impl Checker<'_> {
    pub(crate) fn check_stmt(
        &self,
        s: &Stmt,
        scope: &mut HashMap<String, bool>,
        in_loop: bool,
    ) -> Result<(), CheckError> {
        match s {
            Stmt::Require(e) | Stmt::Ensure(e) | Stmt::Expr(e) | Stmt::Destroy(e) => self.check_expr(e, scope),
            Stmt::Fact { name, expr } => {
                self.check_expr(expr, scope)?;
                scope.insert(name.clone(), true);
                Ok(())
            }
            Stmt::Bind { name, value } => {
                self.check_expr(value, scope)?;
                scope.insert(name.clone(), true);
                Ok(())
            }
            Stmt::Assign { target, op, value } => self.check_assign(target, *op, value, scope),
            Stmt::For { var, filter, body, .. } => self.check_for(var, filter.as_ref(), body, scope),
            Stmt::ForIn { var, index_var, iter, body } => self.check_for_in(var, index_var.as_deref(), iter, body, scope),
            Stmt::If { cond, then, otherwise } => self.check_if(cond, then, otherwise, scope, in_loop),
            Stmt::Loop(body) => {
                let mut inner = scope.clone();
                self.check_block(body, &mut inner, true)
            }
            // `raw:` is a transparent scope for the scope/arity checker — it
            // only relaxes ownership rules (handled in `ownership.rs`).
            Stmt::Raw(body) => self.check_block(body, scope, in_loop),
            Stmt::Parallel(inner) => self.check_stmt(inner, scope, in_loop),
            Stmt::Return(_) => Ok(()),
            Stmt::Break | Stmt::Continue => {
                if in_loop {
                    Ok(())
                } else {
                    Err(CheckError { message: "`break`/`continue` outside a loop".into(), span: None })
                }
            }
        }
    }

    fn check_assign(
        &self,
        target: &Expr,
        op: AssignOp,
        value: &Expr,
        scope: &mut HashMap<String, bool>,
    ) -> Result<(), CheckError> {
        self.check_expr(value, scope)?;
        match target {
            Expr::Var(name, span) => self.check_var_assign(name, *span, op, scope),
            // Assignment into a place — verify the base resolves.
            other => self.check_expr(other, scope),
        }
    }

    fn check_var_assign(
        &self,
        name: &str,
        span: crate::ast::Span,
        op: AssignOp,
        scope: &mut HashMap<String, bool>,
    ) -> Result<(), CheckError> {
        match op {
            AssignOp::Set => match scope.get(name) {
                None => {
                    // Fresh name introduces an immutable binding.
                    scope.insert(name.to_string(), false);
                    Ok(())
                }
                Some(true) => Ok(()),
                Some(false) => err_at(
                    format!("cannot reassign `{name}`: it is immutable (declare it with `mut`)"),
                    span,
                ),
            },
            AssignOp::Add | AssignOp::Sub => match scope.get(name) {
                Some(true) => Ok(()),
                Some(false) => err_at(
                    format!("cannot mutate `{name}`: it is immutable (declare it with `mut`)"),
                    span,
                ),
                None => err_at(format!("`{name}` is not defined"), span),
            },
        }
    }

    fn check_for(
        &self,
        var: &str,
        filter: Option<&Expr>,
        body: &[Stmt],
        scope: &HashMap<String, bool>,
    ) -> Result<(), CheckError> {
        let mut inner = scope.clone();
        inner.insert(var.to_string(), false);
        if let Some(f) = filter {
            self.check_expr(f, &inner)?;
        }
        self.check_block(body, &mut inner, true)
    }

    fn check_for_in(
        &self,
        var: &str,
        index_var: Option<&str>,
        iter: &Expr,
        body: &[Stmt],
        scope: &HashMap<String, bool>,
    ) -> Result<(), CheckError> {
        self.check_expr(iter, scope)?;
        let mut inner = scope.clone();
        inner.insert(var.to_string(), false);
        if let Some(idx) = index_var {
            inner.insert(idx.to_string(), false);
        }
        self.check_block(body, &mut inner, true)
    }

    fn check_if(
        &self,
        cond: &Expr,
        then: &[Stmt],
        otherwise: &[Stmt],
        scope: &HashMap<String, bool>,
        in_loop: bool,
    ) -> Result<(), CheckError> {
        self.check_expr(cond, scope)?;
        let mut t = scope.clone();
        self.check_block(then, &mut t, in_loop)?;
        let mut e = scope.clone();
        self.check_block(otherwise, &mut e, in_loop)
    }
}
