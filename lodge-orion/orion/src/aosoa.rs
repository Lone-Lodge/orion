//! M7 — AoSoA layout + SIMD codegen (the layout refinement on top of `simd.rs`).
//!
//! Plain SoA stores each (component,field) as its own flat column. **AoSoA**
//! (Array-of-Structs-of-Arrays) instead stores data in *blocks* of `W` entities:
//! within a block, each field's `W` lanes are contiguous, and all the block's
//! fields sit next to each other. So all of an entity's components land in the
//! same cache line(s), while each field is still a contiguous `W`-wide vector for
//! SIMD.
//!
//! Here `W = 2` (one `F64X2`), so a block holds 2 entities × all fields — exactly
//! one 64-byte cache line for ~4 `f64` fields. We pad up to a whole block and
//! process every block uniformly (padding lanes are computed and ignored), so no
//! scalar remainder is needed. This is the layout the planner (`layout.rs`) would
//! select for hot, multi-component systems; here it is real, generated code.

use std::mem;

use cranelift::codegen::ir::MemFlagsData;
use cranelift::prelude::*;
use cranelift_jit::{JITBuilder, JITModule};
use cranelift_module::{Linkage, Module, default_libcall_names};

use crate::ast::{AssignOp, BinOp};
use crate::parallel::{KExpr, Kernel};

const W: usize = 2; // entities per block (one F64X2)

pub struct Compiled {
    _module: JITModule,
    addr: usize,
    ncols: usize,
    pub col_names: Vec<String>,
}

impl Compiled {
    pub fn compile(kernel: &Kernel) -> Result<Compiled, String> {
        let mut flags = settings::builder();
        flags.set("use_colocated_libcalls", "false").map_err(|e| e.to_string())?;
        flags.set("is_pic", "false").map_err(|e| e.to_string())?;
        let isa = cranelift_native::builder()
            .map_err(|e| e.to_string())?
            .finish(settings::Flags::new(flags))
            .map_err(|e| e.to_string())?;
        let mut module = JITModule::new(JITBuilder::with_isa(isa, default_libcall_names()));

        // fn(nblocks: i64, params: *const f64, buf: *mut f64)
        let mut sig = module.make_signature();
        sig.params.push(AbiParam::new(types::I64));
        sig.params.push(AbiParam::new(types::I64));
        sig.params.push(AbiParam::new(types::I64));
        let id = module
            .declare_function("kernel_aosoa", Linkage::Export, &sig)
            .map_err(|e| e.to_string())?;

        let mut ctx = module.make_context();
        ctx.func.signature = sig;
        let mut fbctx = FunctionBuilderContext::new();
        build(&mut ctx.func, &mut fbctx, kernel);
        module.define_function(id, &mut ctx).map_err(|e| e.to_string())?;
        module.clear_context(&mut ctx);
        module.finalize_definitions().map_err(|e| e.to_string())?;

        let addr = module.get_finalized_function(id) as usize;
        Ok(Compiled {
            _module: module,
            addr,
            ncols: kernel.col_names.len(),
            col_names: kernel.col_names.clone(),
        })
    }

    /// Run over `n` entities; returns per-column results (length `n`), unpacked
    /// from the AoSoA buffer.
    pub fn run(&self, n: usize, params: &[f64]) -> Vec<Vec<f64>> {
        let m = self.ncols;
        let blocks = n.div_ceil(W);
        let mut buf = vec![1.0f64; blocks * m * W];
        let f: extern "C" fn(i64, *const f64, *mut f64) = unsafe { mem::transmute(self.addr) };
        f(blocks as i64, params.as_ptr(), buf.as_mut_ptr());

        // Unpack: entity i, column c lives at block (i/W), lane (i%W).
        let mut cols = vec![vec![0.0f64; n]; m];
        for (c, col) in cols.iter_mut().enumerate() {
            for (i, slot) in col.iter_mut().enumerate() {
                *slot = buf[(i / W) * m * W + c * W + i % W];
            }
        }
        cols
    }
}

impl Compiled {
    /// Time just the native kernel (excluding allocation and unpacking), averaged
    /// over `iters` calls — for fair comparison against the SoA kernel.
    pub fn bench(&self, n: usize, params: &[f64], iters: u32) -> std::time::Duration {
        let m = self.ncols;
        let blocks = n.div_ceil(W);
        let mut buf = vec![1.0f64; blocks * m * W];
        let f: extern "C" fn(i64, *const f64, *mut f64) = unsafe { mem::transmute(self.addr) };
        f(blocks as i64, params.as_ptr(), buf.as_mut_ptr()); // warm up
        let t = std::time::Instant::now();
        for _ in 0..iters {
            f(blocks as i64, params.as_ptr(), buf.as_mut_ptr());
        }
        t.elapsed() / iters.max(1)
    }
}

pub fn run(kernel: &Kernel, n: usize, params: &[f64]) -> Result<Vec<Vec<f64>>, String> {
    Ok(Compiled::compile(kernel)?.run(n, params))
}

fn build(func: &mut cranelift::codegen::ir::Function, fbctx: &mut FunctionBuilderContext, kernel: &Kernel) {
    let m = kernel.col_names.len();
    let block_bytes = (m * W * 8) as i64; // size of one block in bytes
    let mut b = FunctionBuilder::new(func, fbctx);
    let flags = MemFlagsData::new();
    let f64x2 = types::F64X2;

    let entry = b.create_block();
    let header = b.create_block();
    let body = b.create_block();
    let done = b.create_block();

    b.append_block_params_for_function_params(entry);
    b.switch_to_block(entry);
    let nblocks = b.block_params(entry)[0];
    let pptr = b.block_params(entry)[1];
    let bufptr = b.block_params(entry)[2];

    let mut ps: Vec<Value> = Vec::with_capacity(kernel.params.len());
    for k in 0..kernel.params.len() {
        ps.push(b.ins().load(types::F64, flags, pptr, (k * 8) as i32));
    }

    let bi = b.declare_var(types::I64);
    let zero = b.ins().iconst(types::I64, 0);
    b.def_var(bi, zero);
    b.ins().jump(header, &[]);
    b.seal_block(entry);

    b.switch_to_block(header);
    let cur_b = b.use_var(bi);
    let cond = b.ins().icmp(IntCC::SignedLessThan, cur_b, nblocks);
    b.ins().brif(cond, body, &[], done, &[]);

    b.switch_to_block(body);
    b.seal_block(body);
    {
        let cur_b = b.use_var(bi);
        let block_off = b.ins().imul_imm(cur_b, block_bytes);
        let blockaddr = b.ins().iadd(bufptr, block_off);
        for (tid, op, ex) in &kernel.assigns {
            let v = ax(&mut b, &ps, blockaddr, &flags, f64x2, ex);
            let toff = (tid * W * 8) as i32; // column `tid`'s lanes within the block
            let new = match op {
                AssignOp::Set => v,
                AssignOp::Add => {
                    let cur = b.ins().load(f64x2, flags, blockaddr, toff);
                    b.ins().fadd(cur, v)
                }
                AssignOp::Sub => {
                    let cur = b.ins().load(f64x2, flags, blockaddr, toff);
                    b.ins().fsub(cur, v)
                }
            };
            b.ins().store(flags, new, blockaddr, toff);
        }
        let nb = b.use_var(bi);
        let nbn = b.ins().iadd_imm(nb, 1);
        b.def_var(bi, nbn);
        b.ins().jump(header, &[]);
    }

    b.switch_to_block(done);
    b.ins().return_(&[]);
    b.seal_block(done);
    b.seal_block(header);
    b.finalize();
}

fn ax(b: &mut FunctionBuilder, ps: &[Value], blockaddr: Value, flags: &MemFlagsData, f64x2: Type, e: &KExpr) -> Value {
    match e {
        KExpr::Num(n) => {
            let c = b.ins().f64const(*n);
            b.ins().splat(f64x2, c)
        }
        KExpr::Param(k) => b.ins().splat(f64x2, ps[*k]),
        KExpr::Col(c) => {
            let off = (c * W * 8) as i32;
            b.ins().load(f64x2, *flags, blockaddr, off)
        }
        KExpr::Bin(op, x, y) => {
            let a = ax(b, ps, blockaddr, flags, f64x2, x);
            let c = ax(b, ps, blockaddr, flags, f64x2, y);
            match op {
                BinOp::Add => b.ins().fadd(a, c),
                BinOp::Sub => b.ins().fsub(a, c),
                BinOp::Mul => b.ins().fmul(a, c),
                BinOp::Div => b.ins().fdiv(a, c),
                _ => unreachable!("kernel lowering rejects other operators"),
            }
        }
    }
}
