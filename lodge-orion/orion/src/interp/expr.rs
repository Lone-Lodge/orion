//! Expression evaluation.

use std::collections::HashMap;

use super::{Env, Interp, Place, RunError, run_err};
use super::builtin::builtin;
use std::sync::Arc;

use super::ops::apply_binary;
use crate::ast::Param;

/// Re-order a call's argument list so positional + named entries line
/// up with the declared parameter order. Returns `None` if there are
/// no named args (caller can take the fast path) or if a name doesn't
/// match a parameter (caller errors).
fn reorder_named_args<'a>(params: &[Param], args: &'a [crate::ast::Expr]) -> Option<Vec<&'a crate::ast::Expr>> {
    let has_named = args.iter().any(|a| matches!(a, crate::ast::Expr::NamedArg { .. }));
    if !has_named {
        return None;
    }
    let mut out: Vec<Option<&crate::ast::Expr>> = vec![None; params.len()];
    let mut positional_cursor = 0usize;
    for a in args {
        match a {
            crate::ast::Expr::NamedArg { name, value } => {
                if let Some(idx) = params.iter().position(|p| &p.name == name) {
                    out[idx] = Some(value.as_ref());
                } else {
                    // Unknown name — bail out, caller errors normally.
                    return None;
                }
            }
            _ => {
                while positional_cursor < out.len() && out[positional_cursor].is_some() {
                    positional_cursor += 1;
                }
                if positional_cursor >= out.len() {
                    return None;
                }
                out[positional_cursor] = Some(a);
                positional_cursor += 1;
            }
        }
    }
    // Truncate trailing `None`s — defaults are filled by `bind_params`.
    while matches!(out.last(), Some(None)) {
        out.pop();
    }
    out.into_iter().collect()
}
use crate::ast::{BinOp, Expr, Pattern, UnOp};
use crate::store::Component;
use crate::value::Value;

impl Interp<'_> {
    pub(crate) fn eval(&self, e: &Expr, env: &mut Env) -> Result<Value, RunError> {
        match e {
            Expr::Int(n) => Ok(Value::Int(*n)),
            Expr::Float(x) => Ok(Value::Float(*x)),
            Expr::Str(s) => Ok(Value::Text(s.clone())),
            Expr::Bool(b) => Ok(Value::Bool(*b)),
            Expr::None => Ok(Value::None),
            Expr::Var(name, _) => self.eval_var(name, env),
            Expr::Unary { op, rhs } => self.eval_unary(*op, rhs, env),
            Expr::Binary { op, lhs, rhs } => self.eval_binary(*op, lhs, rhs, env),
            Expr::If { cond, then, otherwise } => {
                if self.as_bool(self.eval(cond, env)?)? {
                    self.eval(then, env)
                } else {
                    self.eval(otherwise, env)
                }
            }
            Expr::Call { callee, args } => self.eval_call(callee, args, env),
            Expr::Field { .. } => self.eval_field(e, env),
            Expr::Spawn(comps) => self.eval_spawn(comps, env),
            Expr::Comprehension { projection, var, components, filter } => {
                self.eval_comprehension(projection, var, components, filter.as_deref(), env)
            }
            Expr::Range { lo, hi, inclusive } => self.eval_range(lo, hi, *inclusive, env),
            Expr::List(items) => eval_list(self, items, env),
            Expr::Map(pairs) => eval_map(self, pairs, env),
            Expr::OrElse { value, default } => match self.eval(value, env)? {
                Value::None => self.eval(default, env),
                v => Ok(v),
            },
            Expr::Struct { name, fields } => self.eval_struct_literal(name, fields, env),
            Expr::Match { scrutinee, arms } => self.eval_match(scrutinee, arms, env),
            Expr::Interp(parts) => self.eval_interp(parts, env),
            // §10 — `comptime EXPR` evaluates exactly like the inner
            // expression at runtime. The compile-time evaluation is a
            // future optimization pass; until then, the result is the
            // same value either way, just computed at runtime.
            Expr::Comptime(inner) => self.eval(inner, env),
            // Bare evaluation of a NamedArg unwraps to its value — this
            // only happens if the call dispatch didn't handle it (e.g.,
            // someone wrote `(x = 5)` as a standalone expression). Most
            // sites special-case named args before evaluation.
            Expr::NamedArg { value, .. } => self.eval(value, env),
            Expr::Lambda { params, body } => Ok(Value::Closure {
                params: params.clone(),
                body: Arc::new((**body).clone()),
                captured: Arc::new(env.iter().map(|(k, v)| (k.clone(), v.clone())).collect()),
            }),
            Expr::ForCollect { var, iter, filter, body } => {
                self.eval_for_collect(var, iter, filter.as_deref(), body, env)
            }
        }
    }

    /// `for x in xs [where c]: expr` in expression position — bind each element,
    /// keep those passing the filter, collect the body value into a list.
    fn eval_for_collect(
        &self,
        var: &str,
        iter: &Expr,
        filter: Option<&Expr>,
        body: &Expr,
        env: &mut Env,
    ) -> Result<Value, RunError> {
        let seq = match self.eval(iter, env)? {
            Value::List(items) => items,
            other => {
                return Err(run_err(format!(
                    "`for {var} in …` expects a list, got {other:?}"
                )));
            }
        };
        let mut out = Vec::new();
        for item in seq.iter() {
            env.insert(var.to_string(), item.clone());
            if let Some(f) = filter {
                if !self.as_bool(self.eval(f, env)?)? {
                    continue;
                }
            }
            out.push(self.eval(body, env)?);
        }
        Ok(Value::List(Arc::new(out)))
    }

    fn eval_var(&self, name: &str, env: &mut Env) -> Result<Value, RunError> {
        // A nullary enum variant is a value when named bare. The same name
        // may be registered with multiple arities (cross-enum collision);
        // accept the bare form if any registration is nullary.
        if self.variants.get(name).map(|v| v.contains(&0)).unwrap_or(false) {
            return Ok(Value::Enum { variant: name.to_string(), payload: vec![] });
        }
        match env.get(name).cloned() {
            // A `fact` is lazy: re-evaluate its expr in the current scope so it
            // always reflects the latest inputs (the reactive read).
            Some(Value::Fact(expr)) => self.eval(&expr, env),
            Some(v) => Ok(v),
            None => Err(run_err(format!("unknown name `{name}`"))),
        }
    }

    fn eval_unary(&self, op: UnOp, rhs: &Expr, env: &mut Env) -> Result<Value, RunError> {
        let v = self.eval(rhs, env)?;
        match op {
            UnOp::Not => Ok(Value::Bool(!self.as_bool(v)?)),
            UnOp::Neg => match v {
                Value::Int(n) => Ok(Value::Int(-n)),
                Value::Float(x) => Ok(Value::Float(-x)),
                other => Err(run_err(format!("cannot negate {other:?}"))),
            },
            UnOp::BitNot => match v {
                Value::Int(n) => Ok(Value::Int(!n)),
                other => Err(run_err(format!("`~` expects an int, got {other:?}"))),
            },
        }
    }

    fn eval_binary(&self, op: BinOp, lhs: &Expr, rhs: &Expr, env: &mut Env) -> Result<Value, RunError> {
        // `and` / `or` short-circuit; everything else evaluates both sides.
        match op {
            BinOp::And => {
                if !self.as_bool(self.eval(lhs, env)?)? {
                    return Ok(Value::Bool(false));
                }
                Ok(Value::Bool(self.as_bool(self.eval(rhs, env)?)?))
            }
            BinOp::Or => {
                // `x or default` — value-preserving fallback: the left value if
                // it is present/truthy, else the right. Only `None` and
                // `Bool(false)` count as absent; everything else is present. So
                // boolean `or` still works (in an `if` the result is coerced by
                // as_bool), and `hp or 100` yields hp when it is a real value,
                // 100 when it is None.
                let a = self.eval(lhs, env)?;
                if !matches!(a, Value::None | Value::Bool(false)) {
                    return Ok(a);
                }
                self.eval(rhs, env)
            }
            _ => {
                let a = self.eval(lhs, env)?;
                let b = self.eval(rhs, env)?;
                apply_binary(op, a, b)
            }
        }
    }

    fn eval_call(&self, callee: &Expr, args: &[Expr], env: &mut Env) -> Result<Value, RunError> {
        // Method call: `obj.foo(args)` parses as `Call { callee: Field { obj, field: "foo" }, args }`.
        // Evaluate `obj`; if it's a `data`-typed value, look up `__m_<TypeName>_<foo>` in the fn
        // table — that's how `impl Trait for TypeName: fn foo …` registers (§14, static dispatch).
        if let Expr::Field { base, name: field, safe: false } = callee {
            let receiver = self.eval(base, env)?;
            if let Value::Data { type_name, .. } = &receiver {
                let key = (type_name.clone(), field.clone());
                if self.methods.contains_key(&key) {
                    let type_name = type_name.clone();
                    let mut argv = Vec::with_capacity(args.len() + 1);
                    argv.push(receiver);
                    for a in args {
                        argv.push(self.eval(a, env)?);
                    }
                    return self.call_method(&type_name, field, argv);
                }
            }
            return Err(run_err(format!("no method `{field}` for value `{receiver}`")));
        }

        // If the callee evaluates to a Closure, invoke it. Lets you do
        // `let add = fn(x, y) = x + y; add(2, 3)`.
        let name = match callee {
            Expr::Var(n, _) => n.as_str(),
            _ => return Err(run_err("only named function calls are supported")),
        };
        // First check if `name` resolves to a closure in the env. If so,
        // we shadow any fn / builtin with the same name (lambdas-first
        // is what every other language does).
        if let Some(Value::Closure { params, body, captured }) = env.get(name).cloned() {
            if args.len() != params.len() {
                return Err(run_err(format!(
                    "closure expected {} arg(s), got {}",
                    params.len(),
                    args.len()
                )));
            }
            let mut argv = Vec::with_capacity(args.len());
            for a in args {
                argv.push(self.eval(a, env)?);
            }
            // Build the call env from the closure's captured snapshot,
            // then bind params on top.
            let mut call_env: super::Env = (*captured).clone().into_iter().collect();
            for (p, v) in params.iter().zip(argv.into_iter()) {
                call_env.insert(p.clone(), v);
            }
            return self.eval(&body, &mut call_env);
        }
        // §11 — reorder named args (`spawn(x = 3, y = 4)`) into
        // declaration order using the fn's params list. Calls to fns
        // we don't know (builtins, closures from earlier shadowing)
        // get the raw arg list, and NamedArg unwraps to its value
        // via the fallback eval rule.
        let reordered_args: Option<Vec<&Expr>> = self.fns.get(name).copied()
            .map(|f| f.params.as_slice())
            .or_else(|| self.systems.get(name).copied().map(|s| s.params.as_slice()))
            .and_then(|params| reorder_named_args(params, args));
        let arg_iter: Box<dyn Iterator<Item = &Expr>> = match &reordered_args {
            Some(reordered) => Box::new(reordered.iter().copied()),
            None => Box::new(args.iter()),
        };
        let mut argv = Vec::with_capacity(args.len());
        for a in arg_iter {
            argv.push(self.eval(a, env)?);
        }
        // §15 — `spawn job EXPR` is desugared by the parser into a
        // call to `__spawn_job(EXPR)`. We evaluate the inner expr
        // right here (sequential model) and wrap the result in a
        // Job handle. `.await` unwraps it.
        if name == "__spawn_job" && argv.len() == 1 {
            let inner = argv.into_iter().next().unwrap();
            return Ok(Value::Job(Arc::new(inner)));
        }
        // §13 change-detection filters — `added("Velocity")` returns the
        // list of entities that gained that component since last tick.
        // Same shape for changed/removed. Lives here (not in builtin.rs)
        // because builtins are free fns with no access to the store.
        if matches!(name, "added" | "changed" | "removed") && argv.len() == 1 {
            if let Value::Text(component) = &argv[0] {
                let store = self.store.read().unwrap();
                let ids = match name {
                    "added" => store.added(component),
                    "changed" => store.changed(component),
                    "removed" => store.removed(component),
                    _ => unreachable!(),
                };
                let entities: Vec<Value> = ids.into_iter().map(Value::Entity).collect();
                return Ok(Value::List(std::sync::Arc::new(entities)));
            }
        }
        // `tick_events_clear()` — drain the per-tick event log. Engine
        // drivers call this between ticks; user code can too for custom
        // scheduling.
        if name == "tick_events_clear" && argv.is_empty() {
            self.store.write().unwrap().take_events();
            return Ok(Value::Unit);
        }
        if self.variants.contains_key(name) {
            Ok(Value::Enum { variant: name.to_string(), payload: argv })
        } else if self.fns.contains_key(name) || self.systems.contains_key(name) {
            self.call(name, argv)
        } else {
            builtin(name, argv)
        }
    }

    fn eval_struct_literal(&self, name: &str, fields: &[(String, Expr)], env: &mut Env) -> Result<Value, RunError> {
        let mut out = Vec::with_capacity(fields.len());
        for (k, e) in fields {
            out.push((k.clone(), self.eval(e, env)?));
        }
        Ok(Value::Data { type_name: name.to_string(), fields: out })
    }

    fn eval_field(&self, e: &Expr, env: &mut Env) -> Result<Value, RunError> {
        // `data` literals are first-class values. Try a direct field read on
        // any non-Field base (Var, Call, Struct, parens) — those return a
        // single value we can inspect. Nested `Field { base, … }` bases
        // belong to the entity-chain `e.Component.field` form that
        // `resolve_place` walks, so we leave those for the fallback.
        if let Expr::Field { base, name: field, safe } = e {
            if !matches!(base.as_ref(), Expr::Field { .. }) {
                let v = self.eval(base, env)?;
                // §15 — `handle.await` on a Job unwraps to the inner
                // value. With Phase C threading this becomes a real
                // block-on; today the work already ran at spawn time.
                if field == "await" {
                    if let Value::Job(inner) = &v {
                        return Ok((**inner).clone());
                    }
                }
                if let Value::Data { fields, .. } = &v {
                    return fields.iter().find(|(k, _)| k == field)
                        .map(|(_, v)| v.clone())
                        .ok_or_else(|| run_err(format!("no field `{field}` on data value")));
                }
                // `entity.Component` — read the whole component as a
                // Data value. Enables the Hylo/Val "take a local copy"
                // pattern: `mut h = entity.Health` / mutate / write back.
                if let Value::Entity(id) = &v {
                    let store = self.store.read().unwrap();
                    if let Some(component_fields) = store.get_component(*id, field) {
                        return Ok(Value::Data { type_name: field.clone(), fields: component_fields });
                    }
                    if *safe {
                        return Ok(Value::None);
                    }
                    return Err(run_err(format!("entity#{id} has no component `{field}`")));
                }
                if *safe && matches!(v, Value::None) {
                    return Ok(Value::None);
                }
                // Non-Data, non-Entity base on a simple `x.field` is an error,
                // but let resolve_place produce the canonical message.
            }
        }
        match self.resolve_place(e, env)? {
            Place::Field { id, comp, field } => self
                .store
                .read()
                .unwrap()
                .get_field(id, &comp, &field)
                .ok_or_else(|| run_err(format!("entity#{id} has no {comp}.{field}"))),
            Place::SafeMissing => Ok(Value::None),
        }
    }

    fn eval_spawn(&self, comps: &[Expr], env: &mut Env) -> Result<Value, RunError> {
        let mut map: HashMap<String, Component> = HashMap::default();
        for c in comps {
            let Expr::Struct { name, fields } = c else {
                return Err(run_err("spawn expects component literals"));
            };
            let mut comp = Component::new();
            for (f, v) in fields {
                let raw = self.eval(v, env)?;
                // §8 — same pack-on-write applied at spawn time so the
                // initial assignment matches the storage shape of every
                // subsequent assignment.
                let packed = if let Some(ty) = self.field_type(name, f) {
                    super::Interp::check_range_bounds(ty, &raw, &format!("{name}.{f}"))?;
                    if let crate::ast::Type::Range { lo, hi, inclusive } = ty {
                        let upper = if *inclusive { *hi } else { *hi - 1 };
                        if let Some(n) = raw.as_int() {
                            if let Some(pk) = crate::value::PackedInt::pack_for_range(n, *lo, upper) {
                                Value::Packed(pk)
                            } else { raw }
                        } else { raw }
                    } else { raw }
                } else { raw };
                comp.insert(f.clone(), packed);
            }
            map.insert(name.clone(), comp);
        }
        Ok(Value::Entity(self.store.write().unwrap().spawn(map)))
    }

    fn eval_comprehension(
        &self,
        projection: &Expr,
        var: &str,
        components: &[String],
        filter: Option<&Expr>,
        env: &mut Env,
    ) -> Result<Value, RunError> {
        let ids = self.store.read().unwrap().with(components);
        let mut out = Vec::new();
        for id in ids {
            env.insert(var.to_string(), Value::Entity(id));
            let keep = match filter {
                Some(f) => self.as_bool(self.eval(f, env)?)?,
                None => true,
            };
            if keep {
                out.push(self.eval(projection, env)?);
            }
        }
        Ok(Value::List(std::sync::Arc::new(out)))
    }

    fn eval_range(&self, lo: &Expr, hi: &Expr, inclusive: bool, env: &mut Env) -> Result<Value, RunError> {
        match (self.eval(lo, env)?, self.eval(hi, env)?) {
            (Value::Int(a), Value::Int(b)) => {
                let end = if inclusive { b + 1 } else { b };
                let items: Vec<Value> = (a..end).map(Value::Int).collect();
                Ok(Value::List(std::sync::Arc::new(items)))
            }
            _ => Err(run_err("range bounds must be integers")),
        }
    }

    fn eval_match(&self, scrutinee: &Expr, arms: &[crate::ast::MatchArm], env: &mut Env) -> Result<Value, RunError> {
        let value = self.eval(scrutinee, env)?;
        for arm in arms {
            match &arm.pattern {
                Pattern::Wildcard => return self.eval(&arm.body, env),
                Pattern::Str(want) => {
                    if let Value::Text(got) = &value {
                        if got == want {
                            return self.eval(&arm.body, env);
                        }
                    }
                }
                Pattern::Int(want) => {
                    if let Value::Int(got) = &value {
                        if got == want {
                            return self.eval(&arm.body, env);
                        }
                    }
                }
                Pattern::Variant { name, bindings, .. } => {
                    if let Value::Enum { variant, payload } = &value {
                        if name == variant {
                            for (b, v) in bindings.iter().zip(payload.iter()) {
                                env.insert(b.clone(), v.clone());
                            }
                            return self.eval(&arm.body, env);
                        }
                    }
                }
            }
        }
        Err(run_err(format!("no `match` arm for value {value:?}")))
    }

    fn eval_interp(&self, parts: &[Expr], env: &mut Env) -> Result<Value, RunError> {
        let mut out = String::new();
        for p in parts {
            out.push_str(&self.eval(p, env)?.to_string());
        }
        Ok(Value::Text(out))
    }
}

fn eval_list(interp: &Interp<'_>, items: &[Expr], env: &mut Env) -> Result<Value, RunError> {
    let mut out = Vec::with_capacity(items.len());
    for it in items {
        out.push(interp.eval(it, env)?);
    }
    Ok(Value::List(std::sync::Arc::new(out)))
}

fn eval_map(interp: &Interp<'_>, pairs: &[(Expr, Expr)], env: &mut Env) -> Result<Value, RunError> {
    let mut out = Vec::with_capacity(pairs.len());
    for (k, v) in pairs {
        out.push((interp.eval(k, env)?, interp.eval(v, env)?));
    }
    Ok(Value::Map(std::sync::Arc::new(out)))
}
