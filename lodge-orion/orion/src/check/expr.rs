//! Expression-level scope, arity, and visibility checks.

use std::collections::HashMap;

use super::{BUILTINS, CheckError, Checker, err_at};
use crate::ast::{Expr, Pattern, Span};

impl Checker<'_> {
    pub(crate) fn check_expr(&self, e: &Expr, scope: &HashMap<String, bool>) -> Result<(), CheckError> {
        match e {
            Expr::Int(_) | Expr::Float(_) | Expr::Str(_) | Expr::Bool(_) | Expr::None => Ok(()),
            Expr::Var(name, span) => self.check_var(name, *span, scope),
            Expr::Field { base, .. } => self.check_expr(base, scope),
            Expr::Call { callee, args } => self.check_call(callee, args, scope),
            Expr::Unary { rhs, .. } => self.check_expr(rhs, scope),
            Expr::Binary { lhs, rhs, .. } => {
                self.check_expr(lhs, scope)?;
                self.check_expr(rhs, scope)
            }
            Expr::If { cond, then, otherwise } => {
                self.check_expr(cond, scope)?;
                self.check_expr(then, scope)?;
                self.check_expr(otherwise, scope)
            }
            Expr::Range { lo, hi, .. } => {
                self.check_expr(lo, scope)?;
                self.check_expr(hi, scope)
            }
            Expr::List(items) => self.check_all(items, scope),
            Expr::Map(pairs) => {
                for (k, v) in pairs {
                    self.check_expr(k, scope)?;
                    self.check_expr(v, scope)?;
                }
                Ok(())
            }
            Expr::OrElse { value, default } => {
                self.check_expr(value, scope)?;
                self.check_expr(default, scope)
            }
            Expr::Struct { fields, .. } => {
                for (_, v) in fields {
                    self.check_expr(v, scope)?;
                }
                Ok(())
            }
            Expr::Spawn(comps) => self.check_all(comps, scope),
            Expr::Comprehension { projection, var, filter, .. } => {
                self.check_comprehension(projection, var, filter.as_deref(), scope)
            }
            Expr::Match { scrutinee, arms } => self.check_match(scrutinee, arms, scope),
            Expr::Interp(parts) => self.check_all(parts, scope),
            Expr::Comptime(inner) => self.check_expr(inner, scope),
            Expr::NamedArg { value, .. } => self.check_expr(value, scope),
            Expr::Lambda { params, body } => {
                // Lambda introduces new bindings for its params; everything
                // outside is captured at runtime. We don't track captures
                // here — runtime captures the live env at evaluation.
                let mut inner = scope.clone();
                for p in params {
                    inner.insert(p.clone(), true);
                }
                self.check_expr(body, &inner)
            }
        }
    }

    fn check_all(&self, items: &[Expr], scope: &HashMap<String, bool>) -> Result<(), CheckError> {
        for it in items {
            self.check_expr(it, scope)?;
        }
        Ok(())
    }

    fn check_var(&self, name: &str, span: Span, scope: &HashMap<String, bool>) -> Result<(), CheckError> {
        if scope.contains_key(name) {
            return Ok(());
        }
        if self.fns.contains_key(name) {
            return self.check_visibility(name, "fn", self.fn_origin.get(name), span);
        }
        if is_builtin(name) {
            return Ok(());
        }
        if self.variants.contains_key(name) {
            return self.check_visibility(name, "variant", self.variant_origin.get(name), span);
        }
        err_at(format!("unknown name `{name}`"), span)
    }

    fn check_call(&self, callee: &Expr, args: &[Expr], scope: &HashMap<String, bool>) -> Result<(), CheckError> {
        for a in args {
            self.check_expr(a, scope)?;
        }
        let Expr::Var(name, span) = callee else {
            // UFCS / computed callee — arity is gradual; just check the callee.
            return self.check_expr(callee, scope);
        };
        if let Some((req, max)) = self.fns.get(name.as_str()) {
            return self.check_user_call(name, *span, args.len(), *req, *max);
        }
        if let Some(arity) = builtin_arity(name) {
            return check_arity(name, *span, args.len(), arity);
        }
        if let Some(arities) = self.variants.get(name.as_str()) {
            // Multiple enums may export the same variant name with
            // different arities; accept the call if any registered arity
            // matches the supplied arg count, else report against the
            // first-declared arity for the diagnostic.
            if arities.contains(&args.len()) {
                return Ok(());
            }
            if let Some(&first) = arities.first() {
                return self.check_variant_call(name, *span, args.len(), first);
            }
        }
        if scope.contains_key(name) {
            // `name` is a local — could be a closure bound to a `let` /
            // `mut`. We don't track closure types statically, so accept
            // any arg count and let the interpreter check at runtime.
            for arg in args {
                self.check_expr(arg, scope)?;
            }
            return Ok(());
        }
        // §13 change-detection filters are recognised here so they
        // don't error on "unknown function" before the interpreter
        // can dispatch them.
        // `__spawn_job` is parser-internal magic for `spawn job EXPR`.
        if matches!(
            name.as_str(),
            "added" | "changed" | "removed" | "tick_events_clear" | "__spawn_job"
        ) {
            for arg in args {
                self.check_expr(arg, scope)?;
            }
            return Ok(());
        }
        err_at(format!("unknown function `{name}`"), *span)
    }

    fn check_user_call(&self, name: &str, span: Span, got: usize, req: usize, max: usize) -> Result<(), CheckError> {
        if got < req || got > max {
            return err_at(format!("`{name}` takes {req}..={max} argument(s), got {got}"), span);
        }
        self.check_visibility(name, "fn", self.fn_origin.get(name), span)
    }

    fn check_variant_call(&self, name: &str, span: Span, got: usize, arity: usize) -> Result<(), CheckError> {
        if got != arity {
            return err_at(format!("variant `{name}` takes {arity} value(s), got {got}"), span);
        }
        self.check_visibility(name, "variant", self.variant_origin.get(name), span)
    }

    fn check_comprehension(
        &self,
        projection: &Expr,
        var: &str,
        filter: Option<&Expr>,
        scope: &HashMap<String, bool>,
    ) -> Result<(), CheckError> {
        let mut inner = scope.clone();
        inner.insert(var.to_string(), false);
        if let Some(f) = filter {
            self.check_expr(f, &inner)?;
        }
        self.check_expr(projection, &inner)
    }

    fn check_match(
        &self,
        scrutinee: &Expr,
        arms: &[crate::ast::MatchArm],
        scope: &HashMap<String, bool>,
    ) -> Result<(), CheckError> {
        self.check_expr(scrutinee, scope)?;
        for arm in arms {
            let mut inner = scope.clone();
            if let Pattern::Variant { bindings, .. } = &arm.pattern {
                for b in bindings {
                    inner.insert(b.clone(), false);
                }
            }
            self.check_expr(&arm.body, &inner)?;
        }
        Ok(())
    }
}

fn is_builtin(name: &str) -> bool {
    BUILTINS.iter().any(|(n, _)| *n == name)
}

fn builtin_arity(name: &str) -> Option<usize> {
    BUILTINS.iter().find(|(n, _)| *n == name).map(|(_, a)| *a)
}

fn check_arity(name: &str, span: Span, got: usize, want: usize) -> Result<(), CheckError> {
    if got != want {
        return err_at(format!("`{name}` takes {want} argument(s), got {got}"), span);
    }
    Ok(())
}
