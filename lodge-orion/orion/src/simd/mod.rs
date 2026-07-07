//! SIMD code generation via Cranelift — emits a vectorised native loop for one
//! lowered kernel. Uses `F64X2` (128-bit SSE2, two `f64` lanes per step) plus a
//! scalar tail for the odd leftover.

mod build;

use std::mem;

use cranelift::prelude::*;
use cranelift_jit::{JITBuilder, JITModule};
use cranelift_module::{Linkage, Module, default_libcall_names};

use crate::parallel::Kernel;

/// A compiled, vectorised kernel. Keeps the JIT module alive so the code stays
/// mapped while it's callable.
pub struct Compiled {
    _module: JITModule,
    addr: usize,
    ncols: usize,
    pub col_names: Vec<String>,
}

impl Compiled {
    pub fn compile(kernel: &Kernel) -> Result<Compiled, String> {
        let mut module = build_module()?;
        let id = declare_kernel(&mut module)?;

        let mut ctx = module.make_context();
        ctx.func.signature = kernel_signature(&module);
        let mut fbctx = FunctionBuilderContext::new();
        build::build_kernel(&mut ctx.func, &mut fbctx, kernel);
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

    /// Run the kernel over `n` entities (columns start at 1.0).
    pub fn run(&self, n: usize, params: &[f64]) -> Vec<Vec<f64>> {
        let mut cols: Vec<Vec<f64>> = vec![vec![1.0f64; n]; self.ncols];
        let col_ptrs: Vec<i64> = cols.iter_mut().map(|c| c.as_mut_ptr() as i64).collect();
        self.invoke(n, params, &col_ptrs);
        cols
    }

    /// Raw entry-point address — the live engine calls this directly so it can
    /// pass its own pre-allocated column buffers instead of going through `run`.
    pub fn addr_for_engine(&self) -> usize {
        self.addr
    }

    /// Time the native kernel (setup excluded), averaged over `iters` calls.
    pub fn bench(&self, n: usize, params: &[f64], iters: u32) -> std::time::Duration {
        let mut cols: Vec<Vec<f64>> = vec![vec![1.0f64; n]; self.ncols];
        let col_ptrs: Vec<i64> = cols.iter_mut().map(|c| c.as_mut_ptr() as i64).collect();
        self.invoke(n, params, &col_ptrs); // warm up
        let t = std::time::Instant::now();
        for _ in 0..iters {
            self.invoke(n, params, &col_ptrs);
        }
        t.elapsed() / iters.max(1)
    }

    fn invoke(&self, n: usize, params: &[f64], col_ptrs: &[i64]) {
        let f: extern "C" fn(i64, *const f64, *const i64) = unsafe { mem::transmute(self.addr) };
        f(n as i64, params.as_ptr(), col_ptrs.as_ptr());
    }
}

/// Compile and run in one go.
pub fn run(kernel: &Kernel, n: usize, params: &[f64]) -> Result<Vec<Vec<f64>>, String> {
    Ok(Compiled::compile(kernel)?.run(n, params))
}

fn build_module() -> Result<JITModule, String> {
    let mut flags = settings::builder();
    flags.set("use_colocated_libcalls", "false").map_err(|e| e.to_string())?;
    flags.set("is_pic", "false").map_err(|e| e.to_string())?;
    let isa = cranelift_native::builder()
        .map_err(|e| e.to_string())?
        .finish(settings::Flags::new(flags))
        .map_err(|e| e.to_string())?;
    Ok(JITModule::new(JITBuilder::with_isa(isa, default_libcall_names())))
}

fn kernel_signature(module: &JITModule) -> Signature {
    // fn(n: i64, params: *const f64, cols: *const i64)
    let mut sig = module.make_signature();
    sig.params.push(AbiParam::new(types::I64));
    sig.params.push(AbiParam::new(types::I64));
    sig.params.push(AbiParam::new(types::I64));
    sig
}

fn declare_kernel(module: &mut JITModule) -> Result<cranelift_module::FuncId, String> {
    let sig = kernel_signature(module);
    module
        .declare_function("kernel", Linkage::Export, &sig)
        .map_err(|e| e.to_string())
}
