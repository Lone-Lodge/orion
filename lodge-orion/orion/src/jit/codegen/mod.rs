//! IR translator for one function body. `define_fn` sets up the Cranelift
//! function builder; `Fx` (in `fx`) walks the expression tree and emits IR.

mod fx;

use std::collections::HashMap;

use cranelift::codegen::ir::FuncRef;
use cranelift::prelude::*;
use cranelift_module::{FuncId, Module};

use super::JTy;
use crate::ast::{BinOp, FnBody, FnDecl};
use fx::Fx;

pub fn define_fn<M: Module>(
    module: &mut M,
    f: &FnDecl,
    ids: &HashMap<String, FuncId>,
    ret_tys: &HashMap<String, JTy>,
    param_tys: &HashMap<String, Vec<JTy>>,
) -> Result<(), String> {
    let mut ctx = module.make_context();
    for t in &param_tys[&f.name] {
        ctx.func.signature.params.push(AbiParam::new(t.clif()));
    }
    ctx.func.signature.returns.push(AbiParam::new(ret_tys[&f.name].clif()));

    let mut fbctx = FunctionBuilderContext::new();
    {
        let mut builder = FunctionBuilder::new(&mut ctx.func, &mut fbctx);
        let entry = setup_entry(&mut builder);
        // Use the inferred param types so the JIT Variable matches the signature
        // ABI we declared. Annotation-driven `param_jty` would silently fall
        // back to Int for un-annotated params and trip Cranelift's type check.
        let vars = bind_params(&mut builder, entry, f, &param_tys[&f.name]);
        let frefs = import_callees(module, &mut builder, ids);

        let mut fx = Fx::new(&mut builder, &frefs, vars, ret_tys, param_tys);
        let want = ret_tys[&f.name];
        let (body_ty, v) = match &f.body {
            FnBody::Expr(e) => (fx.infer(e), fx.expr(e)?),
            FnBody::Block(stmts) => fx.block(stmts)?,
            FnBody::Extern => return Err(format!("codegen: cannot compile extern fn `{}`", f.name)),
        };
        let v = fx.convert(v, body_ty, want);
        builder.ins().return_(&[v]);
        builder.finalize();
    }

    let id = ids[&f.name];
    module.define_function(id, &mut ctx).map_err(|e| e.to_string())?;
    module.clear_context(&mut ctx);
    Ok(())
}

fn setup_entry(b: &mut FunctionBuilder) -> Block {
    let entry = b.create_block();
    b.append_block_params_for_function_params(entry);
    b.switch_to_block(entry);
    b.seal_block(entry);
    entry
}

fn bind_params(
    b: &mut FunctionBuilder,
    entry: Block,
    f: &FnDecl,
    inferred_param_tys: &[JTy],
) -> HashMap<String, (Variable, JTy)> {
    let mut vars = HashMap::new();
    for (i, p) in f.params.iter().enumerate() {
        let val = b.block_params(entry)[i];
        let ty = inferred_param_tys.get(i).copied().unwrap_or(JTy::Int);
        let var = b.declare_var(ty.clif());
        b.def_var(var, val);
        vars.insert(p.name.clone(), (var, ty));
    }
    vars
}

fn import_callees<M: Module>(
    module: &mut M,
    b: &mut FunctionBuilder,
    ids: &HashMap<String, FuncId>,
) -> HashMap<String, FuncRef> {
    ids.iter()
        .map(|(name, id)| (name.clone(), module.declare_func_in_func(*id, b.func)))
        .collect()
}

pub(super) fn is_compare(op: BinOp) -> bool {
    matches!(op, BinOp::Lt | BinOp::Le | BinOp::Gt | BinOp::Ge | BinOp::Eq | BinOp::Ne)
}

pub(super) fn float_cc(op: BinOp) -> FloatCC {
    match op {
        BinOp::Lt => FloatCC::LessThan,
        BinOp::Le => FloatCC::LessThanOrEqual,
        BinOp::Gt => FloatCC::GreaterThan,
        BinOp::Ge => FloatCC::GreaterThanOrEqual,
        BinOp::Eq => FloatCC::Equal,
        _ => FloatCC::NotEqual,
    }
}

pub(super) fn int_cc(op: BinOp) -> IntCC {
    match op {
        BinOp::Lt => IntCC::SignedLessThan,
        BinOp::Le => IntCC::SignedLessThanOrEqual,
        BinOp::Gt => IntCC::SignedGreaterThan,
        BinOp::Ge => IntCC::SignedGreaterThanOrEqual,
        BinOp::Eq => IntCC::Equal,
        _ => IntCC::NotEqual,
    }
}
