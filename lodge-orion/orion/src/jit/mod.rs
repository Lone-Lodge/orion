//! Native code generation via Cranelift. Translates expression-form `fn`s over
//! `int`/`float` to native: arithmetic with int→float promotion, comparisons,
//! `if`, calls/recursion, and the `sqrt` builtin. The translator (`compile`) is
//! generic over the Cranelift backend; the in-process JIT lives here and the
//! object-file emitter lives in `aot.rs`.

mod codegen;
mod compile;
mod infer;

use std::mem;

use cranelift::prelude::*;
use cranelift_jit::{JITBuilder, JITModule};
use cranelift_module::{FuncId, default_libcall_names};

use crate::ast::{Expr, Program, Type};
pub use compile::compile_into;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum JTy {
    Int,
    Float,
}

impl JTy {
    fn clif(self) -> types::Type {
        match self {
            JTy::Int => types::I64,
            JTy::Float => types::F64,
        }
    }
}

pub struct CompiledFn {
    pub id: FuncId,
    pub params: Vec<JTy>,
    pub ret: JTy,
}

pub(crate) fn jty_of_type(t: &Type) -> JTy {
    match t {
        Type::Named(n) if n == "f32" || n == "f64" || n == "float" => JTy::Float,
        _ => JTy::Int,
    }
}

pub(crate) fn unify(a: JTy, b: JTy) -> JTy {
    if a == JTy::Float || b == JTy::Float { JTy::Float } else { JTy::Int }
}

/// Walk `e` and push every called-function name into `out`.
pub(crate) fn collect_calls(e: &Expr, out: &mut Vec<String>) {
    match e {
        Expr::Call { callee, args } => {
            if let Expr::Var(n, _) = callee.as_ref() {
                out.push(n.clone());
            }
            for a in args {
                collect_calls(a, out);
            }
        }
        Expr::Unary { rhs, .. } => collect_calls(rhs, out),
        Expr::Binary { lhs, rhs, .. } => {
            collect_calls(lhs, out);
            collect_calls(rhs, out);
        }
        Expr::If { cond, then, otherwise } => {
            collect_calls(cond, out);
            collect_calls(then, out);
            collect_calls(otherwise, out);
        }
        Expr::Range { lo, hi, .. } => {
            collect_calls(lo, out);
            collect_calls(hi, out);
        }
        Expr::List(items) => items.iter().for_each(|i| collect_calls(i, out)),
        Expr::Comprehension { projection, filter, .. } => {
            collect_calls(projection, out);
            if let Some(f) = filter {
                collect_calls(f, out);
            }
        }
        Expr::Field { base, .. } => collect_calls(base, out),
        Expr::Struct { fields, .. } => fields.iter().for_each(|(_, v)| collect_calls(v, out)),
        Expr::Spawn(comps) => comps.iter().for_each(|c| collect_calls(c, out)),
        _ => {}
    }
}

/// In-memory JIT: compile a function and run it through a raw pointer.
pub struct Jit {
    module: JITModule,
}

impl Jit {
    pub fn new() -> Result<Self, String> {
        let mut flags = settings::builder();
        flags.set("use_colocated_libcalls", "false").map_err(|e| e.to_string())?;
        flags.set("is_pic", "false").map_err(|e| e.to_string())?;
        let isa = cranelift_native::builder()
            .map_err(|e| e.to_string())?
            .finish(settings::Flags::new(flags))
            .map_err(|e| e.to_string())?;
        let builder = JITBuilder::with_isa(isa, default_libcall_names());
        Ok(Jit { module: JITModule::new(builder) })
    }

    pub fn compile(&mut self, program: &Program, root: &str) -> Result<CompiledFn, String> {
        let cf = compile_into(&mut self.module, program, root)?;
        self.module.finalize_definitions().map_err(|e| e.to_string())?;
        Ok(cf)
    }

    /// Raw address of a compiled function — `Send`, so callers can run it across
    /// threads. Valid while this `Jit` is alive.
    pub fn func_addr(&self, id: FuncId) -> usize {
        self.module.get_finalized_function(id) as usize
    }

    /// Parse `raw` per the function's signature, run the native code, format
    /// the result. Supports all-int or all-float signatures.
    pub fn run_cli(&self, cf: &CompiledFn, raw: &[String]) -> Result<String, String> {
        if raw.len() != cf.params.len() {
            return Err(format!("expected {} argument(s), got {}", cf.params.len(), raw.len()));
        }
        let all_int = cf.ret == JTy::Int && cf.params.iter().all(|t| *t == JTy::Int);
        let all_float = cf.ret == JTy::Float && cf.params.iter().all(|t| *t == JTy::Float);
        if all_int {
            let args: Vec<i64> = raw.iter()
                .map(|s| s.parse::<i64>().map_err(|_| "expected integer arguments".to_string()))
                .collect::<Result<_, _>>()?;
            Ok(self.run_int(cf.id, &args)?.to_string())
        } else if all_float {
            let args: Vec<f64> = raw.iter()
                .map(|s| s.parse::<f64>().map_err(|_| "expected numeric arguments".to_string()))
                .collect::<Result<_, _>>()?;
            Ok(self.run_float(cf.id, &args)?.to_string())
        } else {
            Err("jit CLI supports all-int or all-float signatures".into())
        }
    }

    pub fn run_int(&self, id: FuncId, args: &[i64]) -> Result<i64, String> {
        let code = self.module.get_finalized_function(id);
        unsafe {
            Ok(match args.len() {
                0 => mem::transmute::<_, extern "C" fn() -> i64>(code)(),
                1 => mem::transmute::<_, extern "C" fn(i64) -> i64>(code)(args[0]),
                2 => mem::transmute::<_, extern "C" fn(i64, i64) -> i64>(code)(args[0], args[1]),
                3 => mem::transmute::<_, extern "C" fn(i64, i64, i64) -> i64>(code)(args[0], args[1], args[2]),
                4 => mem::transmute::<_, extern "C" fn(i64, i64, i64, i64) -> i64>(code)(args[0], args[1], args[2], args[3]),
                n => return Err(format!("jit supports up to 4 arguments, got {n}")),
            })
        }
    }

    pub fn run_float(&self, id: FuncId, args: &[f64]) -> Result<f64, String> {
        let code = self.module.get_finalized_function(id);
        unsafe {
            Ok(match args.len() {
                0 => mem::transmute::<_, extern "C" fn() -> f64>(code)(),
                1 => mem::transmute::<_, extern "C" fn(f64) -> f64>(code)(args[0]),
                2 => mem::transmute::<_, extern "C" fn(f64, f64) -> f64>(code)(args[0], args[1]),
                3 => mem::transmute::<_, extern "C" fn(f64, f64, f64) -> f64>(code)(args[0], args[1], args[2]),
                4 => mem::transmute::<_, extern "C" fn(f64, f64, f64, f64) -> f64>(code)(args[0], args[1], args[2], args[3]),
                n => return Err(format!("jit supports up to 4 arguments, got {n}")),
            })
        }
    }
}
