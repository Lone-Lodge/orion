//! Statement execution and `entity.Component.field` place resolution.

use super::{Env, Flow, Interp, Place, run_err};
use super::ops::{apply_binary, assign_binop};
use crate::ast::{AssignOp, Expr, Stmt};
use crate::value::Value;

impl Interp<'_> {
    pub(super) fn exec(&self, stmt: &Stmt, env: &mut Env) -> Result<Flow, super::RunError> {
        match stmt {
            Stmt::Require(cond) => check_contract(self, cond, env, "require"),
            Stmt::Ensure(cond) => check_contract(self, cond, env, "ensure"),
            Stmt::Fact { name, expr } => {
                // Store the expr lazily; `eval_var` re-evaluates it on read.
                env.insert(name.clone(), Value::Fact(std::sync::Arc::new(expr.clone())));
                Ok(Flow::Normal(Value::Unit))
            }
            Stmt::Bind { name, value } => {
                let v = self.eval(value, env)?;
                env.insert(name.clone(), v);
                Ok(Flow::Normal(Value::Unit))
            }
            Stmt::Assign { target, op, value } => self.exec_assign(target, *op, value, env),
            Stmt::Destroy(e) => self.exec_destroy(e, env),
            Stmt::For { var, components, filter, body } => {
                self.exec_for(var, components, filter.as_ref(), body, env)
            }
            Stmt::ForIn { var, index_var, iter, body } => self.exec_for_in(var, index_var.as_deref(), iter, body, env),
            Stmt::If { cond, then, otherwise } => {
                if self.as_bool(self.eval(cond, env)?)? {
                    self.run_block(then, env)
                } else {
                    self.run_block(otherwise, env)
                }
            }
            Stmt::Loop(body) => {
                loop {
                    match self.run_block(body, env)? {
                        Flow::Break => return Ok(Flow::Normal(Value::Unit)),
                        Flow::Return(v) => return Ok(Flow::Return(v)),
                        _ => {}
                    }
                }
            }
            Stmt::Break => Ok(Flow::Break),
            Stmt::Continue => Ok(Flow::Continue),
            Stmt::Return(e) => Ok(Flow::Return(self.eval(e, env)?)),
            // `raw` runs its body unchanged at runtime — the safety relaxation
            // is purely static (ownership.rs); the bits don't change.
            Stmt::Raw(body) => self.run_block(body, env),
            // §15 `parallel for …:` — dispatch ForIn/For to rayon when
            // the iteration space is data-parallel (numeric range, list,
            // or `with`-clause entity set) and the body has no shared
            // mutable captures. Today we still execute sequentially —
            // every body is `&mut Env` which is `!Send`. The rayon
            // path lands when we move env to `Arc<HashMap>` per
            // iteration (Phase D follow-up).
            Stmt::Parallel(inner) => self.exec(inner, env),
            Stmt::Expr(e) => Ok(Flow::Normal(self.eval(e, env)?)),
        }
    }

    fn exec_assign(&self, target: &Expr, op: AssignOp, value: &Expr, env: &mut Env) -> Result<Flow, super::RunError> {
        // Hot path: `x = push(x, val)` — without this special-case, the
        // Var(x) lookup inside the call clones the entire list, making
        // any `for: x = push(x, v)` accumulator pattern O(N²). We take
        // x out of env, push in place, and put it back. True O(1).
        if let (AssignOp::Set, Expr::Var(target_name, _)) = (op, target) {
            if let Expr::Call { callee, args } = value {
                if let Expr::Var(callee_name, _) = callee.as_ref() {
                    if (callee_name == "push" || callee_name == "push_mut") && args.len() == 2 {
                        if let Expr::Var(list_var, _) = &args[0] {
                            if list_var == target_name {
                                let val = self.eval(&args[1], env)?;
                                // env.remove() moves the value out so we
                                // own the underlying Vec. If it's not a
                                // list, fall through to the slow path.
                                if let Some(Value::List(mut items_arc)) = env.remove(target_name) {
                                    std::sync::Arc::make_mut(&mut items_arc).push(val);
                                    env.insert(target_name.clone(), Value::List(items_arc));
                                    return Ok(Flow::Normal(Value::Unit));
                                }
                                // Not a List or not present — put None
                                // back if we removed something else, then
                                // fall through. (Shouldn't happen for
                                // well-typed Orion, but doesn't crash.)
                            }
                        }
                    }
                }
            }
        }
        let rhs = self.eval(value, env)?;
        match target {
            Expr::Var(name, _) => {
                let new = match op {
                    AssignOp::Set => rhs,
                    AssignOp::Add | AssignOp::Sub => {
                        let cur = env.get(name).cloned()
                            .ok_or_else(|| run_err(format!("`{name}` is not defined")))?;
                        apply_binary(assign_binop(op), cur, rhs)?
                    }
                };
                env.insert(name.clone(), new);
            }
            // Single-level `local.field = value` (local is Data) — mutate
            // in place. Hylo/Val style:
            //   `mut h = entity.Health`  /  `h.hp -= 1`  /  `entity.Health = h`
            // Also: `entity.Component = data_value` — write whole component back.
            Expr::Field { base, name: field, .. } if matches!(base.as_ref(), Expr::Var(_, _)) => {
                let Expr::Var(name, _) = base.as_ref() else { unreachable!() };
                let cur = env.get(name).cloned()
                    .ok_or_else(|| run_err(format!("`{name}` is not defined")))?;
                // Branch 1: `entity.Component = data` — replace the whole component.
                if let Value::Entity(id) = cur {
                    if !matches!(op, AssignOp::Set) {
                        return Err(run_err(format!("`entity.{field} +=/-= data` not supported — assign the whole component")));
                    }
                    let Value::Data { fields, .. } = rhs else {
                        return Err(run_err(format!("`entity.{field} = ...` expects a data value")));
                    };
                    let mut store = self.store.write().unwrap();
                    for (fname, fval) in fields.iter() {
                        if !store.set_field(id, field, fname, fval.clone()) {
                            return Err(run_err(format!("entity#{id} has no component `{field}`")));
                        }
                    }
                    return Ok(Flow::Normal(Value::Unit));
                }
                // Branch 2: `local.field = ...` — local is a Data value.
                let Value::Data { type_name, mut fields } = cur else {
                    return Err(run_err(format!("`{name}.{field}` — `{name}` is not a data value")));
                };
                let cur_field = fields.iter().find(|(n, _)| n == field).map(|(_, v)| v.clone())
                    .ok_or_else(|| run_err(format!("`{type_name}` has no field `{field}`")))?;
                let new_field = match op {
                    AssignOp::Set => rhs,
                    AssignOp::Add | AssignOp::Sub => apply_binary(assign_binop(op), cur_field, rhs)?,
                };
                if let Some(slot) = fields.iter_mut().find(|(n, _)| n == field) {
                    slot.1 = new_field;
                }
                env.insert(name.clone(), Value::Data { type_name, fields });
                return Ok(Flow::Normal(Value::Unit));
            }
            Expr::Field { .. } => {
                let (id, comp, field) = match self.resolve_place(target, env)? {
                    Place::Field { id, comp, field } => (id, comp, field),
                    Place::SafeMissing => return Ok(Flow::Normal(Value::Unit)),
                };
                let new = match op {
                    AssignOp::Set => rhs,
                    AssignOp::Add | AssignOp::Sub => {
                        let cur = self.store.read().unwrap().get_field(id, &comp, &field)
                            .ok_or_else(|| run_err(format!("entity#{id} has no {comp}.{field}")))?;
                        apply_binary(assign_binop(op), cur, rhs)?
                    }
                };
                // §8 — range type enforcement at the write boundary. The
                // declared type drives the check; arithmetic stays i64 so
                // intermediate computation can overshoot, but **storage**
                // must fit.
                let mut new = new;
                if let Some(ty) = self.field_type(&comp, &field) {
                    super::Interp::check_range_bounds(ty, &new, &format!("{comp}.{field}"))?;
                    // §8 packing — once we've validated, store the value
                    // in the narrowest int width that fits the range.
                    // Saves up to 7 bytes per field for 1M-entity worlds.
                    if let crate::ast::Type::Range { lo, hi, inclusive } = ty {
                        let upper = if *inclusive { *hi } else { *hi - 1 };
                        if let Some(n) = new.as_int() {
                            if let Some(packed) = crate::value::PackedInt::pack_for_range(n, *lo, upper) {
                                new = Value::Packed(packed);
                            }
                        }
                    }
                }
                if !self.store.write().unwrap().set_field(id, &comp, &field, new) {
                    return Err(run_err(format!("entity#{id} has no component `{comp}`")));
                }
            }
            _ => return Err(run_err("invalid assignment target")),
        }
        Ok(Flow::Normal(Value::Unit))
    }

    fn exec_destroy(&self, e: &Expr, env: &mut Env) -> Result<Flow, super::RunError> {
        match self.eval(e, env)? {
            Value::Entity(id) => self.store.write().unwrap().destroy(id),
            other => return Err(run_err(format!("`destroy` expects an entity, got {other:?}"))),
        }
        Ok(Flow::Normal(Value::Unit))
    }

    fn exec_for(
        &self,
        var: &str,
        components: &[String],
        filter: Option<&Expr>,
        body: &[Stmt],
        env: &mut Env,
    ) -> Result<Flow, super::RunError> {
        let ids = self.store.read().unwrap().with(components);
        for id in ids {
            env.insert(var.to_string(), Value::Entity(id));
            let keep = match filter {
                Some(f) => self.as_bool(self.eval(f, env)?)?,
                None => true,
            };
            if keep {
                match self.run_block(body, env)? {
                    Flow::Break => break,
                    Flow::Return(v) => return Ok(Flow::Return(v)),
                    _ => {}
                }
            }
        }
        Ok(Flow::Normal(Value::Unit))
    }

    fn exec_for_in(&self, var: &str, index_var: Option<&str>, iter: &Expr, body: &[Stmt], env: &mut Env) -> Result<Flow, super::RunError> {
        let seq = match self.eval(iter, env)? {
            Value::List(items) => items,
            other => return Err(run_err(format!("`for {var} in …` expects a list or range, got {other:?}"))),
        };
        for (index, item) in seq.iter().enumerate() {
            env.insert(var.to_string(), item.clone());
            if let Some(idx_name) = index_var {
                env.insert(idx_name.to_string(), Value::Int(index as i64));
            }
            match self.run_block(body, env)? {
                Flow::Break => break,
                Flow::Return(v) => return Ok(Flow::Return(v)),
                _ => {}
            }
        }
        Ok(Flow::Normal(Value::Unit))
    }

    /// Resolve `entity.Component.field` to its concrete place. A `?.` anywhere
    /// in the chain collapses a `none` entity or a missing component into
    /// `SafeMissing` instead of an error.
    pub(super) fn resolve_place(&self, e: &Expr, env: &mut Env) -> Result<Place, super::RunError> {
        let Expr::Field { base, name: field, safe: safe_field } = e else {
            return Err(run_err("field access must be `entity.Component.field`"));
        };
        let Expr::Field { base: inner, name: comp, safe: safe_comp } = base.as_ref() else {
            return Err(run_err("field access must be `entity.Component.field` (single-level access is not supported yet)"));
        };
        match self.eval(inner, env)? {
            Value::Entity(id) => {
                if *safe_field && !self.store.read().unwrap().has_component(id, comp) {
                    return Ok(Place::SafeMissing);
                }
                Ok(Place::Field { id, comp: comp.clone(), field: field.clone() })
            }
            Value::None if *safe_field || *safe_comp => Ok(Place::SafeMissing),
            other => Err(run_err(format!("expected an entity before `.{comp}`, got {other:?}"))),
        }
    }
}

fn check_contract(interp: &Interp<'_>, cond: &Expr, env: &mut Env, kind: &str) -> Result<Flow, super::RunError> {
    if !interp.as_bool(interp.eval(cond, env)?)? {
        return Err(run_err(format!("contract failed: a(n) `{kind}` was not satisfied")));
    }
    Ok(Flow::Normal(Value::Unit))
}
