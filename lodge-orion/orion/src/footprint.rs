//! M5 (first slice) — footprint inference.
//!
//! ORION.md's central idea: every system has a *footprint* — the set of
//! components it reads and the set it writes — and the compiler derives it
//! automatically. From footprints the engine can schedule systems in parallel
//! (two systems may run together when neither writes what the other touches),
//! and later choose data layout. Atlas does a primitive version of this
//! (`hot_columns`); here it becomes a real analysis pass.
//!
//! This slice computes the footprint and groups systems into parallel batches.
//! Layout selection and the runtime scheduler build on it in later steps.

use std::collections::BTreeSet;

use crate::ast::{AssignOp, Decl, Expr, Program, Stmt, SystemDecl};

/// What a system touches: component names it reads and writes.
#[derive(Debug, Default, Clone, PartialEq)]
pub struct Footprint {
    pub reads: BTreeSet<String>,
    pub writes: BTreeSet<String>,
}

/// Infer the footprint of one system.
pub fn analyze_system(s: &SystemDecl) -> Footprint {
    let mut fp = Footprint::default();
    for stmt in &s.body {
        walk_stmt(stmt, &mut fp);
    }
    fp
}

/// Footprints for every system in a program, in declaration order.
pub fn analyze(program: &Program) -> Vec<(String, Footprint)> {
    program
        .decls
        .iter()
        .filter_map(|d| match d {
            Decl::System(s) => Some((s.name.clone(), analyze_system(s))),
            _ => None,
        })
        .collect()
}

/// Two systems conflict if one writes a component the other reads or writes.
/// Non-conflicting systems can run in parallel.
pub fn conflicts(a: &Footprint, b: &Footprint) -> bool {
    !a.writes.is_disjoint(&b.writes)
        || !a.writes.is_disjoint(&b.reads)
        || !b.writes.is_disjoint(&a.reads)
}

/// Honour the `before` / `after` ordering hints (§15) on top of the
/// footprint-derived conflict graph. Each pass of `parallel_batches`
/// places systems into the earliest batch where:
///   1. no data conflicts with any system already there, AND
///   2. every `after` dependency is in a *strictly earlier* batch, AND
///   3. no system in the same or earlier batch lists *us* as `before`.
pub fn parallel_batches_ordered(program: &Program) -> Vec<Vec<String>> {
    let systems = analyze(program);
    // Index by name for ordering lookups.
    let mut order: std::collections::HashMap<String, (Vec<String>, Vec<String>)> =
        std::collections::HashMap::new();
    for decl in &program.decls {
        if let Decl::System(s) = decl {
            order.insert(s.name.clone(), (s.before.clone(), s.after.clone()));
        }
    }

    let mut batches: Vec<Vec<usize>> = Vec::new();
    let mut placed_batch_of: std::collections::HashMap<String, usize> = std::collections::HashMap::new();
    for (i, (name, fp)) in systems.iter().enumerate() {
        let (befores, afters) = order.get(name).cloned().unwrap_or_default();
        // Earliest legal batch index is one greater than the highest
        // batch already occupied by any `after` dependency.
        let mut min_batch = 0usize;
        for a in &afters {
            if let Some(&b) = placed_batch_of.get(a) {
                min_batch = min_batch.max(b + 1);
            }
        }
        let mut placed = false;
        for (b_index, batch) in batches.iter_mut().enumerate() {
            if b_index < min_batch { continue; }
            // No data conflicts inside this batch.
            if batch.iter().any(|&j| conflicts(fp, &systems[j].1)) { continue; }
            // Don't violate any `before` declaration we hold by ending
            // up in the same batch as a target we should precede.
            if befores.iter().any(|t| batch.iter().any(|&j| &systems[j].0 == t)) { continue; }
            batch.push(i);
            placed_batch_of.insert(name.clone(), b_index);
            placed = true;
            break;
        }
        if !placed {
            placed_batch_of.insert(name.clone(), batches.len());
            batches.push(vec![i]);
        }
    }
    batches
        .into_iter()
        .map(|b| b.into_iter().map(|i| systems[i].0.clone()).collect())
        .collect()
}

/// Greedily group systems into parallel batches: each batch holds systems whose
/// footprints are mutually non-conflicting. (A simplified model — it does not yet
/// honour explicit `before`/`after` ordering.)
pub fn parallel_batches(systems: &[(String, Footprint)]) -> Vec<Vec<String>> {
    let mut batches: Vec<Vec<usize>> = Vec::new();
    for (i, (_, fp)) in systems.iter().enumerate() {
        let mut placed = false;
        for batch in &mut batches {
            if batch.iter().all(|&j| !conflicts(fp, &systems[j].1)) {
                batch.push(i);
                placed = true;
                break;
            }
        }
        if !placed {
            batches.push(vec![i]);
        }
    }
    batches
        .into_iter()
        .map(|b| b.into_iter().map(|i| systems[i].0.clone()).collect())
        .collect()
}

fn walk_stmt(s: &Stmt, fp: &mut Footprint) {
    match s {
        Stmt::Require(e) | Stmt::Ensure(e) | Stmt::Expr(e) | Stmt::Destroy(e) => walk_expr(e, fp),
        Stmt::Bind { value, .. } => walk_expr(value, fp),
        Stmt::Assign { target, op, value } => {
            walk_expr(value, fp);
            if let Some(comp) = component_of(target) {
                fp.writes.insert(comp.clone());
                // `+=` / `-=` read the field before writing it.
                if matches!(op, AssignOp::Add | AssignOp::Sub) {
                    fp.reads.insert(comp);
                }
            } else {
                walk_expr(target, fp);
            }
        }
        Stmt::For {
            components,
            filter,
            body,
            ..
        } => {
            // Selecting `with C` reads the membership of those components.
            for c in components {
                fp.reads.insert(c.clone());
            }
            if let Some(f) = filter {
                walk_expr(f, fp);
            }
            for st in body {
                walk_stmt(st, fp);
            }
        }
        Stmt::ForIn { iter, body, .. } => {
            walk_expr(iter, fp);
            for st in body {
                walk_stmt(st, fp);
            }
        }
        Stmt::If { cond, then, otherwise } => {
            walk_expr(cond, fp);
            for st in then.iter().chain(otherwise) {
                walk_stmt(st, fp);
            }
        }
        Stmt::Loop(body) | Stmt::Raw(body) => {
            for st in body {
                walk_stmt(st, fp);
            }
        }
        Stmt::Parallel(inner) => walk_stmt(inner, fp),
        Stmt::Break | Stmt::Continue => {}
        Stmt::Return(e) => walk_expr(e, fp),
    }
}

fn walk_expr(e: &Expr, fp: &mut Footprint) {
    match e {
        // `entity.Component.field` in read position.
        Expr::Field { base, .. } => {
            if let Some(comp) = component_of(e) {
                fp.reads.insert(comp);
            }
            walk_expr(base, fp);
        }
        Expr::Unary { rhs, .. } => walk_expr(rhs, fp),
        Expr::Binary { lhs, rhs, .. } => {
            walk_expr(lhs, fp);
            walk_expr(rhs, fp);
        }
        Expr::If { cond, then, otherwise } => {
            walk_expr(cond, fp);
            walk_expr(then, fp);
            walk_expr(otherwise, fp);
        }
        Expr::Call { callee, args } => {
            walk_expr(callee, fp);
            for a in args {
                walk_expr(a, fp);
            }
        }
        Expr::Range { lo, hi, .. } => {
            walk_expr(lo, fp);
            walk_expr(hi, fp);
        }
        Expr::List(items) => items.iter().for_each(|i| walk_expr(i, fp)),
        Expr::Map(pairs) => pairs.iter().for_each(|(k, v)| {
            walk_expr(k, fp);
            walk_expr(v, fp);
        }),
        Expr::OrElse { value, default } => {
            walk_expr(value, fp);
            walk_expr(default, fp);
        }
        Expr::Comprehension {
            projection,
            components,
            filter,
            ..
        } => {
            for c in components {
                fp.reads.insert(c.clone());
            }
            walk_expr(projection, fp);
            if let Some(f) = filter {
                walk_expr(f, fp);
            }
        }
        Expr::Struct { name, fields } => {
            // A struct literal here means `spawn Kind{…}` — it creates a component.
            fp.writes.insert(name.clone());
            for (_, v) in fields {
                walk_expr(v, fp);
            }
        }
        Expr::Spawn(comps) => comps.iter().for_each(|c| walk_expr(c, fp)),
        Expr::Interp(parts) => parts.iter().for_each(|p| walk_expr(p, fp)),
        _ => {}
    }
}

/// If `e` is `entity.Component.field`, return `Component`.
fn component_of(e: &Expr) -> Option<String> {
    if let Expr::Field { base, .. } = e {
        if let Expr::Field { name: comp, .. } = base.as_ref() {
            return Some(comp.clone());
        }
    }
    None
}
