//! M5 (finish) — data-parallel system execution over a columnar SoA world.
//!
//! This is the payoff of the footprint + layout work: a system that iterates
//! entities and updates their components is *embarrassingly parallel* across
//! entities (each entity is independent). With components stored as SoA columns
//! (`Vec<f64>`), we split the entity range into disjoint chunks and run one
//! thread per chunk. Disjoint index ranges never alias, so this is safe — the one
//! `unsafe` block shares column pointers across threads under exactly that
//! guarantee (ORION.md §15, `parallel for`).
//!
//! Scope: the common kernel shape — `for e with C…: (e.C.field (=|+=|-=) arith)…`
//! over `f64` columns, where `arith` is field reads, parameters, literals and
//! `+ - * /`. Richer bodies fall back to the tree-walking interpreter.

use std::thread;

use crate::ast::{AssignOp, BinOp, Decl, Expr, Program, Stmt, SystemDecl};

/// A lowered arithmetic expression that reads columns/params by index.
pub(crate) enum KExpr {
    Num(f64),
    Param(usize),
    Col(usize),
    Bin(BinOp, Box<KExpr>, Box<KExpr>),
}

/// A system lowered to a flat, parallel-friendly kernel.
pub struct Kernel {
    pub col_names: Vec<String>,
    pub params: Vec<String>,
    pub(crate) assigns: Vec<(usize, AssignOp, KExpr)>,
    /// The `for e with <components>:` filter — the entity set this kernel iterates.
    pub components: Vec<String>,
}

/// Lower a system to a kernel, or explain why it isn't in the parallel subset.
pub fn lower(program: &Program, system: &str) -> Result<Kernel, String> {
    let decl = program
        .decls
        .iter()
        .find_map(|d| match d {
            Decl::System(s) if s.name == system => Some(s),
            _ => None,
        })
        .ok_or_else(|| format!("no system named `{system}`"))?;
    lower_system(decl)
}

fn lower_system(s: &SystemDecl) -> Result<Kernel, String> {
    let (components, body) = match s.body.as_slice() {
        [Stmt::For { filter: None, body, components, .. }] => (components.clone(), body),
        _ => return Err("parallel subset: system body must be a single `for … with …:` with no filter".into()),
    };
    let params: Vec<String> = s.params.iter().map(|p| p.name.clone()).collect();
    let mut col_names: Vec<String> = Vec::new();
    let mut assigns = Vec::new();
    for stmt in body {
        let (target, op, value) = match stmt {
            Stmt::Assign { target, op, value } => (target, *op, value),
            _ => return Err("parallel subset: loop body must be field assignments only".into()),
        };
        let tcol = component_field(target)
            .ok_or("parallel subset: assignment target must be `e.Component.field`")?;
        let tid = intern(&mut col_names, &tcol);
        let ex = lower_expr(value, &params, &mut col_names)?;
        assigns.push((tid, op, ex));
    }
    Ok(Kernel {
        col_names,
        params,
        assigns,
        components,
    })
}

fn lower_expr(e: &Expr, params: &[String], cols: &mut Vec<String>) -> Result<KExpr, String> {
    match e {
        Expr::Int(n) => Ok(KExpr::Num(*n as f64)),
        Expr::Float(x) => Ok(KExpr::Num(*x)),
        Expr::Var(name, _) => params
            .iter()
            .position(|p| p == name)
            .map(KExpr::Param)
            .ok_or_else(|| format!("parallel subset: `{name}` is not a parameter")),
        Expr::Field { .. } => {
            let key = component_field(e)
                .ok_or("parallel subset: field read must be `e.Component.field`")?;
            Ok(KExpr::Col(intern(cols, &key)))
        }
        Expr::Binary { op, lhs, rhs } => {
            if matches!(op, BinOp::Add | BinOp::Sub | BinOp::Mul | BinOp::Div) {
                Ok(KExpr::Bin(
                    *op,
                    Box::new(lower_expr(lhs, params, cols)?),
                    Box::new(lower_expr(rhs, params, cols)?),
                ))
            } else {
                Err(format!("parallel subset: operator {op:?} not supported"))
            }
        }
        other => Err(format!("parallel subset: {other:?} not supported")),
    }
}

/// `e.Component.field` -> `"Component.field"`.
fn component_field(e: &Expr) -> Option<String> {
    if let Expr::Field { base, name: field, .. } = e {
        if let Expr::Field { name: comp, .. } = base.as_ref() {
            return Some(format!("{comp}.{field}"));
        }
    }
    None
}

fn intern(cols: &mut Vec<String>, key: &str) -> usize {
    if let Some(i) = cols.iter().position(|c| c == key) {
        i
    } else {
        cols.push(key.to_string());
        cols.len() - 1
    }
}

/// Run a kernel over `n` entities with the given parameters, using `threads`
/// worker threads. Columns start at 1.0. Returns the resulting columns (same
/// order as `kernel.col_names`).
pub fn run(kernel: &Kernel, n: usize, params: &[f64], threads: usize) -> Vec<Vec<f64>> {
    let mut cols: Vec<Vec<f64>> = vec![vec![1.0f64; n]; kernel.col_names.len()];
    let ptrs: Vec<*mut f64> = cols.iter_mut().map(|c| c.as_mut_ptr()).collect();
    let shared = Cols(ptrs);

    if threads <= 1 || n == 0 {
        run_range(kernel, &shared.0, params, 0, n);
    } else {
        let chunk = n.div_ceil(threads);
        thread::scope(|s| {
            let mut lo = 0;
            while lo < n {
                let hi = (lo + chunk).min(n);
                let sh = &shared;
                let k = kernel;
                let pr = params;
                s.spawn(move || run_range(k, &sh.0, pr, lo, hi));
                lo = hi;
            }
        });
    }
    cols
}

/// Apply the kernel to entity indices `[lo, hi)`.
///
/// # Safety contract (upheld by the caller)
/// Each thread is given a disjoint `[lo, hi)`, so no two threads touch the same
/// column index — the shared raw pointers are never aliased for the same element.
fn run_range(kernel: &Kernel, ptrs: &[*mut f64], params: &[f64], lo: usize, hi: usize) {
    for i in lo..hi {
        for (tid, op, ex) in &kernel.assigns {
            let v = eval(ex, ptrs, params, i);
            unsafe {
                let cell = ptrs[*tid].add(i);
                let new = match op {
                    AssignOp::Set => v,
                    AssignOp::Add => *cell + v,
                    AssignOp::Sub => *cell - v,
                };
                *cell = new;
            }
        }
    }
}

fn eval(e: &KExpr, ptrs: &[*mut f64], params: &[f64], i: usize) -> f64 {
    match e {
        KExpr::Num(n) => *n,
        KExpr::Param(k) => params[*k],
        KExpr::Col(c) => unsafe { *ptrs[*c].add(i) },
        KExpr::Bin(op, a, b) => {
            let x = eval(a, ptrs, params, i);
            let y = eval(b, ptrs, params, i);
            match op {
                BinOp::Add => x + y,
                BinOp::Sub => x - y,
                BinOp::Mul => x * y,
                BinOp::Div => x / y,
                _ => unreachable!("lowering rejects other operators"),
            }
        }
    }
}

/// Column base pointers, shareable across scoped threads under the disjoint-range
/// guarantee documented on `run_range`.
struct Cols(Vec<*mut f64>);
unsafe impl Send for Cols {}
unsafe impl Sync for Cols {}
