//! Cranelift IR emission for one vectorised kernel.
//!
//! Loop shape (LANES = 2):
//!   header: while i + 2 <= n -> body; else -> remh
//!   body:   process 2 lanes with F64X2 ops, i += 2, jump header
//!   remh:   i < n ? rem : done
//!   rem:    process 1 scalar lane, jump done
//!   done:   return

use cranelift::codegen::ir::{Function, MemFlagsData};
use cranelift::prelude::*;

use crate::ast::{AssignOp, BinOp};
use crate::parallel::{KExpr, Kernel};

const LANES: usize = 2; // F64X2

pub(super) fn build_kernel(func: &mut Function, fbctx: &mut FunctionBuilderContext, kernel: &Kernel) {
    let mut b = FunctionBuilder::new(func, fbctx);
    let flags = MemFlagsData::new();
    let f64x2 = types::F64X2;

    let entry = b.create_block();
    let header = b.create_block();
    let body = b.create_block();
    let remh = b.create_block();
    let rem = b.create_block();
    let done = b.create_block();

    let (n, bases, ps, i_var) = emit_entry(&mut b, entry, header, kernel, flags);
    emit_header(&mut b, header, i_var, n, body, remh);
    emit_vector_body(&mut b, body, header, i_var, kernel, &bases, &ps, f64x2, flags);
    emit_remainder_header(&mut b, remh, i_var, n, rem, done);
    emit_scalar_remainder(&mut b, rem, done, i_var, kernel, &bases, &ps, flags);

    b.switch_to_block(done);
    b.ins().return_(&[]);
    b.seal_block(done);
    b.seal_block(header); // preds: entry + body, both now emitted
    b.finalize();
}

/// `entry` reads ABI params, preloads column / parameter pointers, initializes
/// the loop counter, and jumps into `header`. Returns the pieces later blocks need.
fn emit_entry(
    b: &mut FunctionBuilder,
    entry: Block,
    header: Block,
    kernel: &Kernel,
    flags: MemFlagsData,
) -> (Value, Vec<Value>, Vec<Value>, Variable) {
    b.append_block_params_for_function_params(entry);
    b.switch_to_block(entry);
    let n = b.block_params(entry)[0];
    let pptr = b.block_params(entry)[1];
    let cptr = b.block_params(entry)[2];

    let bases = preload(b, cptr, kernel.col_names.len(), types::I64, flags);
    let ps = preload(b, pptr, kernel.params.len(), types::F64, flags);
    let i_var = init_loop_counter(b);
    b.ins().jump(header, &[]);
    b.seal_block(entry);
    (n, bases, ps, i_var)
}

fn preload(b: &mut FunctionBuilder, base: Value, count: usize, ty: Type, flags: MemFlagsData) -> Vec<Value> {
    (0..count).map(|c| b.ins().load(ty, flags, base, (c * 8) as i32)).collect()
}

fn init_loop_counter(b: &mut FunctionBuilder) -> Variable {
    let i_var = b.declare_var(types::I64);
    let zero = b.ins().iconst(types::I64, 0);
    b.def_var(i_var, zero);
    i_var
}

fn emit_header(b: &mut FunctionBuilder, header: Block, i_var: Variable, n: Value, body: Block, remh: Block) {
    b.switch_to_block(header);
    let i = b.use_var(i_var);
    let inext = b.ins().iadd_imm(i, LANES as i64);
    let fits = b.ins().icmp(IntCC::SignedLessThanOrEqual, inext, n);
    b.ins().brif(fits, body, &[], remh, &[]);
}

fn emit_vector_body(
    b: &mut FunctionBuilder,
    body: Block,
    header: Block,
    i_var: Variable,
    kernel: &Kernel,
    bases: &[Value],
    ps: &[Value],
    f64x2: Type,
    flags: MemFlagsData,
) {
    b.switch_to_block(body);
    b.seal_block(body);
    let i = b.use_var(i_var);
    let off = b.ins().imul_imm(i, 8);
    for (tid, op, ex) in &kernel.assigns {
        let v = vec_expr(b, bases, ps, off, ex, f64x2, flags);
        let taddr = b.ins().iadd(bases[*tid], off);
        let new = combine(b, *op, taddr, v, f64x2, flags);
        b.ins().store(flags, new, taddr, 0);
    }
    let i2 = b.use_var(i_var);
    let inext = b.ins().iadd_imm(i2, LANES as i64);
    b.def_var(i_var, inext);
    b.ins().jump(header, &[]);
}

fn emit_remainder_header(b: &mut FunctionBuilder, remh: Block, i_var: Variable, n: Value, rem: Block, done: Block) {
    b.switch_to_block(remh);
    b.seal_block(remh);
    let i = b.use_var(i_var);
    let has = b.ins().icmp(IntCC::SignedLessThan, i, n);
    b.ins().brif(has, rem, &[], done, &[]);
}

fn emit_scalar_remainder(
    b: &mut FunctionBuilder,
    rem: Block,
    done: Block,
    i_var: Variable,
    kernel: &Kernel,
    bases: &[Value],
    ps: &[Value],
    flags: MemFlagsData,
) {
    b.switch_to_block(rem);
    b.seal_block(rem);
    let i = b.use_var(i_var);
    let off = b.ins().imul_imm(i, 8);
    for (tid, op, ex) in &kernel.assigns {
        let v = scal_expr(b, bases, ps, off, ex, flags);
        let taddr = b.ins().iadd(bases[*tid], off);
        let new = combine(b, *op, taddr, v, types::F64, flags);
        b.ins().store(flags, new, taddr, 0);
    }
    b.ins().jump(done, &[]);
}

/// Apply an assignment op: replace (`Set`), or load-and-fadd/fsub. Works the
/// same for scalar `f64` and `F64X2`.
fn combine(b: &mut FunctionBuilder, op: AssignOp, taddr: Value, v: Value, ty: Type, flags: MemFlagsData) -> Value {
    match op {
        AssignOp::Set => v,
        AssignOp::Add => {
            let cur = b.ins().load(ty, flags, taddr, 0);
            b.ins().fadd(cur, v)
        }
        AssignOp::Sub => {
            let cur = b.ins().load(ty, flags, taddr, 0);
            b.ins().fsub(cur, v)
        }
    }
}

fn vec_expr(
    b: &mut FunctionBuilder,
    bases: &[Value],
    ps: &[Value],
    off: Value,
    e: &KExpr,
    f64x2: Type,
    flags: MemFlagsData,
) -> Value {
    match e {
        KExpr::Num(n) => {
            let c = b.ins().f64const(*n);
            b.ins().splat(f64x2, c)
        }
        KExpr::Param(k) => b.ins().splat(f64x2, ps[*k]),
        KExpr::Col(c) => {
            let addr = b.ins().iadd(bases[*c], off);
            b.ins().load(f64x2, flags, addr, 0)
        }
        KExpr::Bin(op, a, c) => {
            let x = vec_expr(b, bases, ps, off, a, f64x2, flags);
            let y = vec_expr(b, bases, ps, off, c, f64x2, flags);
            bin(b, *op, x, y)
        }
    }
}

fn scal_expr(b: &mut FunctionBuilder, bases: &[Value], ps: &[Value], off: Value, e: &KExpr, flags: MemFlagsData) -> Value {
    match e {
        KExpr::Num(n) => b.ins().f64const(*n),
        KExpr::Param(k) => ps[*k],
        KExpr::Col(c) => {
            let addr = b.ins().iadd(bases[*c], off);
            b.ins().load(types::F64, flags, addr, 0)
        }
        KExpr::Bin(op, a, c) => {
            let x = scal_expr(b, bases, ps, off, a, flags);
            let y = scal_expr(b, bases, ps, off, c, flags);
            bin(b, *op, x, y)
        }
    }
}

/// Float arithmetic — same instructions work on scalar `f64` and `F64X2`.
fn bin(b: &mut FunctionBuilder, op: BinOp, x: Value, y: Value) -> Value {
    match op {
        BinOp::Add => b.ins().fadd(x, y),
        BinOp::Sub => b.ins().fsub(x, y),
        BinOp::Mul => b.ins().fmul(x, y),
        BinOp::Div => b.ins().fdiv(x, y),
        _ => unreachable!("kernel lowering rejects other operators"),
    }
}
