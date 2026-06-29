//! Multi-function module builder. `compile_into` plans reachability from a root
//! function, declares all needed function signatures, then emits each body via
//! `codegen::define_fn`.

use std::collections::{HashMap, HashSet};

use cranelift::prelude::*;
use cranelift_module::{FuncId, Linkage, Module};

use super::{CompiledFn, JTy, codegen, collect_calls, infer, jty_of_type};
use crate::ast::{Decl, FnBody, FnDecl, Program};

/// Translate `root` and everything it reaches into `module`. Caller finalizes.
pub fn compile_into<M: Module>(
    module: &mut M,
    program: &Program,
    root: &str,
) -> Result<CompiledFn, String> {
    let decls = collect_fn_decls(program);
    let needed = reachable_from(root, &decls)?;
    let (ret_tys, param_tys) = signature_kinds(&needed, &decls);
    let ids = declare_all(module, &needed, &ret_tys, &param_tys)?;
    for name in &needed {
        codegen::define_fn(module, decls[name.as_str()], &ids, &ret_tys, &param_tys)?;
    }
    Ok(CompiledFn {
        id: ids[root],
        params: param_tys[root].clone(),
        ret: ret_tys[root],
    })
}

fn collect_fn_decls(program: &Program) -> HashMap<&str, &FnDecl> {
    let mut out = HashMap::new();
    for d in &program.decls {
        if let Decl::Fn(f) = d {
            out.insert(f.name.as_str(), f);
        }
    }
    out
}

/// DFS from `root`, returning every reachable expression- or block-form
/// function in discovery order. Extern fns can't be compiled (they have no
/// body); missing return types are still required for ABI clarity.
fn reachable_from(root: &str, decls: &HashMap<&str, &FnDecl>) -> Result<Vec<String>, String> {
    let mut needed = Vec::new();
    let mut seen: HashSet<String> = HashSet::new();
    let mut stack = vec![root.to_string()];
    while let Some(name) = stack.pop() {
        if !seen.insert(name.clone()) {
            continue;
        }
        let f = decls.get(name.as_str())
            .ok_or_else(|| format!("codegen: no function `{name}`"))?;
        if matches!(f.body, FnBody::Extern) {
            return Err(format!("codegen: cannot compile extern fn `{name}`"));
        }
        needed.push(name.clone());
        gather_calls(&f.body, &mut stack, decls);
    }
    Ok(needed)
}

fn gather_calls(body: &FnBody, stack: &mut Vec<String>, decls: &HashMap<&str, &FnDecl>) {
    let mut calls = Vec::new();
    match body {
        FnBody::Expr(e) => collect_calls(e, &mut calls),
        FnBody::Block(stmts) => collect_calls_in_stmts(stmts, &mut calls),
        FnBody::Extern => {}
    }
    for c in calls {
        if decls.contains_key(c.as_str()) {
            stack.push(c);
        }
    }
}

fn collect_calls_in_stmts(stmts: &[crate::ast::Stmt], out: &mut Vec<String>) {
    use crate::ast::Stmt;
    for s in stmts {
        match s {
            Stmt::Require(e) | Stmt::Ensure(e) | Stmt::Expr(e) | Stmt::Destroy(e) => collect_calls(e, out),
            Stmt::Bind { value, .. } => collect_calls(value, out),
            Stmt::Assign { target, value, .. } => {
                collect_calls(target, out);
                collect_calls(value, out);
            }
            Stmt::For { filter, body, .. } => {
                if let Some(f) = filter { collect_calls(f, out); }
                collect_calls_in_stmts(body, out);
            }
            Stmt::ForIn { iter, body, .. } => {
                collect_calls(iter, out);
                collect_calls_in_stmts(body, out);
            }
            Stmt::If { cond, then, otherwise } => {
                collect_calls(cond, out);
                collect_calls_in_stmts(then, out);
                collect_calls_in_stmts(otherwise, out);
            }
            Stmt::Loop(body) | Stmt::Raw(body) => collect_calls_in_stmts(body, out),
            Stmt::Parallel(inner) => collect_calls_in_stmts(std::slice::from_ref(inner), out),
            Stmt::Break | Stmt::Continue => {}
            Stmt::Return(e) => collect_calls(e, out),
        }
    }
}

fn signature_kinds(
    needed: &[String],
    decls: &HashMap<&str, &FnDecl>,
) -> (HashMap<String, JTy>, HashMap<String, Vec<JTy>>) {
    let mut ret_tys = HashMap::new();
    let mut param_tys = HashMap::new();
    // First pass — params: explicit annotation wins, else scan the body for
    // uses of the param against a float operand to decide Int vs Float.
    for name in needed {
        let f = decls[name.as_str()];
        let pts: Vec<JTy> = f.params.iter().map(|p| {
            match p.ty.as_ref() {
                Some(t) => jty_of_type(t),
                None => infer::param_jty_from_body(&p.name, &f.body),
            }
        }).collect();
        param_tys.insert(name.clone(), pts);
    }
    // Second pass — return: explicit `-> T` wins, else infer from body's tail
    // expression using the param map we just built. We don't bother iterating
    // to a fixpoint; one pass covers the common case (no mutual recursion in
    // the no-annotation paths).
    for name in needed {
        let f = decls[name.as_str()];
        let rt = match f.ret.as_ref() {
            Some(t) => jty_of_type(t),
            None => infer::ret_jty_from_body(f, &param_tys, decls),
        };
        ret_tys.insert(name.clone(), rt);
    }
    (ret_tys, param_tys)
}

fn declare_all<M: Module>(
    module: &mut M,
    needed: &[String],
    ret_tys: &HashMap<String, JTy>,
    param_tys: &HashMap<String, Vec<JTy>>,
) -> Result<HashMap<String, FuncId>, String> {
    let mut ids = HashMap::new();
    for name in needed {
        let mut sig = module.make_signature();
        for t in &param_tys[name] {
            sig.params.push(AbiParam::new(t.clif()));
        }
        sig.returns.push(AbiParam::new(ret_tys[name].clif()));
        let id = module.declare_function(name, Linkage::Export, &sig)
            .map_err(|e| e.to_string())?;
        ids.insert(name.clone(), id);
    }
    Ok(ids)
}
