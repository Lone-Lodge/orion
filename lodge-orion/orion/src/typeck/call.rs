//! Call type checking — dispatches across builtins, variant construction, and
//! user-defined fns/queries/systems.

use std::collections::HashMap;

use super::{Cx, Ty, TypeError, assignable, err, numeric, span_of, unify};
use crate::ast::Expr;

impl Cx {
    pub(crate) fn call(&self, callee: &Expr, args: &[Expr], scope: &HashMap<String, Ty>) -> Result<Ty, TypeError> {
        let name = match callee {
            Expr::Var(n, _) => n.clone(),
            _ => {
                self.infer(callee, scope)?;
                return Ok(Ty::Unknown);
            }
        };

        if let Some(t) = self.call_builtin(&name, args, scope)? {
            return Ok(t);
        }
        if let Some(t) = self.call_variant(&name, args, scope)? {
            return Ok(t);
        }
        if let Some(t) = self.call_user_fn(&name, args, scope)? {
            return Ok(t);
        }
        Ok(Ty::Unknown)
    }

    fn call_builtin(&self, name: &str, args: &[Expr], scope: &HashMap<String, Ty>) -> Result<Option<Ty>, TypeError> {
        Ok(Some(match name {
            "print" => {
                if let Some(a) = args.first() {
                    self.infer(a, scope)?;
                }
                Ty::Unit
            }
            "len" => self.check_len(args, scope)?,
            "has" => {
                for a in args {
                    self.infer(a, scope)?;
                }
                Ty::Bool
            }
            "get_or" | "get" | "set" | "at" | "push" | "slice" => {
                for a in args {
                    self.infer(a, scope)?;
                }
                Ty::Unknown
            }
            "sqrt" | "abs" | "max" | "min" | "floor" | "ceil" | "round" | "pow" | "clamp" | "sign"
            | "sin" | "cos" | "tan" | "atan2" | "exp" | "ln" | "log2"
            | "to_int" | "to_float" => {
                self.check_numeric_builtin(name, args, scope)?
            }
            "type_of" => {
                // Polymorphic — accept any single value, return Text.
                for arg in args {
                    self.infer(arg, scope)?;
                }
                Ty::Text
            }
            "map_keys" | "map_values" => {
                // Polymorphic over Map. Return type is List<Unknown> so callers
                // can use it as [Text] when keys are texts (e.g. JSON objects).
                for arg in args {
                    self.infer(arg, scope)?;
                }
                Ty::List(Box::new(Ty::Unknown))
            }
            "slot_get" => {
                // Returns whatever was stored — Unknown.
                for arg in args {
                    self.infer(arg, scope)?;
                }
                Ty::Unknown
            }
            "slot_set" | "slot_push" | "slot_set_at" => {
                // Side-effecting write — returns Unit.
                for arg in args {
                    self.infer(arg, scope)?;
                }
                Ty::Unit
            }
            "eprint" => {
                for arg in args {
                    self.infer(arg, scope)?;
                }
                Ty::Unit
            }
            _ => return Ok(None),
        }))
    }

    fn check_len(&self, args: &[Expr], scope: &HashMap<String, Ty>) -> Result<Ty, TypeError> {
        if let Some(a) = args.first() {
            let t = self.infer(a, scope)?;
            if !matches!(t, Ty::Text | Ty::List(_) | Ty::Unknown) {
                return err(format!("len expects Text/list/map, found {}", t.show()), span_of(a));
            }
        }
        Ok(Ty::Int)
    }

    fn check_numeric_builtin(&self, name: &str, args: &[Expr], scope: &HashMap<String, Ty>) -> Result<Ty, TypeError> {
        let mut acc = Ty::Int;
        for a in args {
            let t = self.infer(a, scope)?;
            if !numeric(&t) {
                return err(format!("`{name}` expects numbers, found {}", t.show()), span_of(a));
            }
            acc = unify(&acc, &t).unwrap_or(Ty::Float);
        }
        Ok(match name {
            "sqrt" | "floor" | "ceil" | "round" | "pow"
            | "sin" | "cos" | "tan" | "atan2" | "exp" | "ln" | "log2"
            | "to_float" => Ty::Float,
            "sign" | "to_int" => Ty::Int,
            _ => acc,
        })
    }

    fn call_variant(&self, name: &str, args: &[Expr], scope: &HashMap<String, Ty>) -> Result<Option<Ty>, TypeError> {
        let Some((enum_name, payload)) = self.variants.get(name) else {
            return Ok(None);
        };
        for (i, a) in args.iter().enumerate() {
            let at = self.infer(a, scope)?;
            if let Some(pt) = payload.get(i) {
                if !assignable(pt, &at) {
                    return err(
                        format!("variant `{name}` value {} expects {}, found {}", i + 1, pt.show(), at.show()),
                        span_of(a),
                    );
                }
            }
        }
        Ok(Some(Ty::Enum(enum_name.clone())))
    }

    fn call_user_fn(&self, name: &str, args: &[Expr], scope: &HashMap<String, Ty>) -> Result<Option<Ty>, TypeError> {
        let Some((params, ret)) = self.fns.get(name) else {
            return Ok(None);
        };
        for (i, a) in args.iter().enumerate() {
            let at = self.infer(a, scope)?;
            if let Some(pt) = params.get(i) {
                if !assignable(pt, &at) {
                    return err(
                        format!("argument {} of `{name}` expects {}, found {}", i + 1, pt.show(), at.show()),
                        span_of(a),
                    );
                }
            }
        }
        Ok(Some(ret.clone()))
    }
}
