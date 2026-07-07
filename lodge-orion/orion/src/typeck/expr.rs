//! Expression type inference and exhaustive `match` checking.

use std::collections::HashMap;

use super::{Cx, Ty, TypeError, err, numeric, span_of, unify};
use crate::ast::{BinOp, Expr, MatchArm, Pattern, UnOp};

impl Cx {
    pub(crate) fn infer(&self, e: &Expr, scope: &HashMap<String, Ty>) -> Result<Ty, TypeError> {
        match e {
            Expr::Int(_) => Ok(Ty::Int),
            Expr::Float(_) => Ok(Ty::Float),
            Expr::Str(_) => Ok(Ty::Text),
            Expr::Bool(_) => Ok(Ty::Bool),
            Expr::None => Ok(Ty::Unknown),
            Expr::Var(name, _) => self.infer_var(name, scope),
            Expr::Unary { op, rhs } => self.infer_unary(*op, rhs, scope),
            Expr::Binary { op, lhs, rhs } => self.infer_binary(*op, lhs, rhs, e, scope),
            Expr::If { cond, then, otherwise } => self.infer_if(cond, then, otherwise, scope),
            Expr::Call { callee, args } => self.call(callee, args, scope),
            Expr::Field { base, name, safe } => self.infer_field(e, base, name, *safe, scope),
            Expr::Range { lo, hi, .. } => self.infer_range(lo, hi, scope),
            Expr::List(items) => self.infer_list(items, scope),
            Expr::Map(pairs) => self.infer_map(pairs, scope),
            Expr::OrElse { value, default } => {
                self.infer(value, scope)?;
                self.infer(default, scope)
            }
            Expr::Struct { .. } | Expr::Spawn(_) => Ok(Ty::Entity),
            Expr::Comprehension { projection, var, .. } => self.infer_comprehension(projection, var, scope),
            Expr::Match { scrutinee, arms } => self.match_expr(scrutinee, arms, scope),
            Expr::Interp(parts) => self.infer_interp(parts, scope),
            Expr::Lambda { .. } => Ok(Ty::Unknown),
            Expr::Comptime(inner) => self.infer(inner, scope),
            Expr::NamedArg { value, .. } => self.infer(value, scope),
        }
    }

    fn infer_var(&self, name: &str, scope: &HashMap<String, Ty>) -> Result<Ty, TypeError> {
        if let Some((en, payload)) = self.variants.get(name) {
            if payload.is_empty() {
                return Ok(Ty::Enum(en.clone()));
            }
        }
        Ok(scope.get(name).cloned().unwrap_or(Ty::Unknown))
    }

    fn infer_unary(&self, op: UnOp, rhs: &Expr, scope: &HashMap<String, Ty>) -> Result<Ty, TypeError> {
        let t = self.infer(rhs, scope)?;
        match op {
            UnOp::Not => {
                self.expect(&Ty::Bool, &t, rhs, "`not` expects a bool")?;
                Ok(Ty::Bool)
            }
            UnOp::Neg => {
                if !numeric(&t) {
                    return err(format!("cannot negate {}", t.show()), span_of(rhs));
                }
                Ok(t)
            }
            UnOp::BitNot => {
                if !matches!(t, Ty::Int | Ty::Unknown) {
                    return err(format!("`~` expects an int, found {}", t.show()), span_of(rhs));
                }
                Ok(Ty::Int)
            }
        }
    }

    fn infer_binary(
        &self,
        op: BinOp,
        lhs: &Expr,
        rhs: &Expr,
        whole: &Expr,
        scope: &HashMap<String, Ty>,
    ) -> Result<Ty, TypeError> {
        let lt = self.infer(lhs, scope)?;
        let rt = self.infer(rhs, scope)?;
        use BinOp::*;
        match op {
            And | Or => {
                self.expect(&Ty::Bool, &lt, lhs, "`and`/`or` expects a bool")?;
                self.expect(&Ty::Bool, &rt, rhs, "`and`/`or` expects a bool")?;
                Ok(Ty::Bool)
            }
            Eq | Ne => Ok(Ty::Bool),
            Lt | Le | Gt | Ge => {
                if !numeric(&lt) || !numeric(&rt) {
                    return err(format!("cannot compare {} and {}", lt.show(), rt.show()), span_of(whole));
                }
                Ok(Ty::Bool)
            }
            Add | Sub | Mul | Div | Rem => {
                if op == Add && lt == Ty::Text && rt == Ty::Text {
                    return Ok(Ty::Text);
                }
                if !numeric(&lt) || !numeric(&rt) {
                    return err(
                        format!("cannot apply this operator to {} and {}", lt.show(), rt.show()),
                        span_of(whole),
                    );
                }
                Ok(unify(&lt, &rt).unwrap_or(Ty::Int))
            }
            BitOr | BitXor | BitAnd | Shl | Shr => {
                let is_int = |t: &Ty| matches!(t, Ty::Int | Ty::Unknown);
                if !is_int(&lt) || !is_int(&rt) {
                    return err(
                        format!("bitwise operators require int, found {} and {}", lt.show(), rt.show()),
                        span_of(whole),
                    );
                }
                Ok(Ty::Int)
            }
        }
    }

    fn infer_if(
        &self,
        cond: &Expr,
        then: &Expr,
        otherwise: &Expr,
        scope: &HashMap<String, Ty>,
    ) -> Result<Ty, TypeError> {
        let ct = self.infer(cond, scope)?;
        self.expect(&Ty::Bool, &ct, cond, "an `if` condition must be a bool")?;
        let tt = self.infer(then, scope)?;
        let et = self.infer(otherwise, scope)?;
        unify(&tt, &et).ok_or_else(|| TypeError {
            message: format!("`if` branches disagree: {} vs {}", tt.show(), et.show()),
            span: span_of(then).or_else(|| span_of(otherwise)),
        })
    }

    fn infer_field(
        &self,
        whole: &Expr,
        base: &Expr,
        field: &str,
        safe: bool,
        scope: &HashMap<String, Ty>,
    ) -> Result<Ty, TypeError> {
        // `entity.Component.field`
        if let Expr::Field { name: comp, .. } = base {
            if let Some(fields) = self.data.get(comp) {
                return match fields.get(field) {
                    // `?.` chains stay gradual — they may yield `none`.
                    Some(_) if safe => Ok(Ty::Unknown),
                    Some(t) => Ok(t.clone()),
                    None => err(format!("component `{comp}` has no field `{field}`"), span_of(whole)),
                };
            }
            return Ok(Ty::Unknown);
        }
        self.infer(base, scope)?;
        Ok(Ty::Unknown)
    }

    fn infer_range(&self, lo: &Expr, hi: &Expr, scope: &HashMap<String, Ty>) -> Result<Ty, TypeError> {
        let lt = self.infer(lo, scope)?;
        let rt = self.infer(hi, scope)?;
        self.expect(&Ty::Int, &lt, lo, "range bounds must be int")?;
        self.expect(&Ty::Int, &rt, hi, "range bounds must be int")?;
        Ok(Ty::List(Box::new(Ty::Int)))
    }

    fn infer_list(&self, items: &[Expr], scope: &HashMap<String, Ty>) -> Result<Ty, TypeError> {
        let mut elem = Ty::Unknown;
        for it in items {
            let t = self.infer(it, scope)?;
            elem = unify(&elem, &t).unwrap_or(Ty::Unknown);
        }
        Ok(Ty::List(Box::new(elem)))
    }

    fn infer_map(&self, pairs: &[(Expr, Expr)], scope: &HashMap<String, Ty>) -> Result<Ty, TypeError> {
        for (k, v) in pairs {
            self.infer(k, scope)?;
            self.infer(v, scope)?;
        }
        Ok(Ty::Unknown)
    }

    fn infer_comprehension(&self, projection: &Expr, var: &str, scope: &HashMap<String, Ty>) -> Result<Ty, TypeError> {
        let mut inner = scope.clone();
        inner.insert(var.to_string(), Ty::Entity);
        let t = self.infer(projection, &inner)?;
        Ok(Ty::List(Box::new(t)))
    }

    fn infer_interp(&self, parts: &[Expr], scope: &HashMap<String, Ty>) -> Result<Ty, TypeError> {
        for p in parts {
            self.infer(p, scope)?;
        }
        Ok(Ty::Text)
    }

    fn match_expr(&self, scrutinee: &Expr, arms: &[MatchArm], scope: &HashMap<String, Ty>) -> Result<Ty, TypeError> {
        let st = self.infer(scrutinee, scope)?;
        let enum_name = if let Ty::Enum(n) = &st { Some(n.clone()) } else { None };

        let mut result: Option<Ty> = None;
        let mut covered: Vec<String> = Vec::new();
        let mut wildcard = false;
        for arm in arms {
            let mut inner = scope.clone();
            match &arm.pattern {
                Pattern::Wildcard => wildcard = true,
                Pattern::Str(_) | Pattern::Int(_) => {
                    // Literal patterns — no variant coverage tracking needed.
                    // Exhaustiveness for these comes from a wildcard arm.
                }
                Pattern::Variant { name, bindings, span } => {
                    covered.push(name.clone());
                    match self.variants.get(name) {
                        Some((_, payload)) => {
                            for (b, t) in bindings.iter().zip(payload.iter()) {
                                inner.insert(b.clone(), t.clone());
                            }
                        }
                        None => return err(format!("unknown variant `{name}`"), Some(*span)),
                    }
                }
            }
            let bt = self.infer(&arm.body, &inner)?;
            result = Some(match result {
                None => bt,
                Some(prev) => unify(&prev, &bt).unwrap_or(Ty::Unknown),
            });
        }

        check_exhaustive(self, &enum_name, &covered, wildcard, scrutinee)?;
        Ok(result.unwrap_or(Ty::Unknown))
    }
}

fn check_exhaustive(
    cx: &Cx,
    enum_name: &Option<String>,
    covered: &[String],
    wildcard: bool,
    scrutinee: &Expr,
) -> Result<(), TypeError> {
    if wildcard {
        return Ok(());
    }
    let Some(en) = enum_name else { return Ok(()); };
    let Some(all) = cx.enums.get(en) else { return Ok(()); };
    let missing: Vec<String> = all.iter().filter(|v| !covered.contains(v)).cloned().collect();
    if !missing.is_empty() {
        return err(
            format!("non-exhaustive `match` on {en}: missing {}", missing.join(", ")),
            span_of(scrutinee),
        );
    }
    Ok(())
}
