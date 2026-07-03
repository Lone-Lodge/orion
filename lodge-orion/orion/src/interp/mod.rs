//! Tree-walking interpreter. `Interp` resolves names and owns the world; the
//! actual evaluation lives in:
//!   - `stmt`     — statement execution and entity-place resolution
//!   - `expr`     — expression evaluation
//!   - `ops`      — arithmetic, comparison, equality on values
//!   - `builtin`  — the built-in function library (max/min/get/…)

pub(crate) mod builtin;
mod expr;
mod ops;
mod stmt;

use std::sync::RwLock;
use rustc_hash::FxHashMap as HashMap;

use crate::ast::{DataDecl, Decl, FnBody, FnDecl, Param, Stmt, SystemDecl, Type};
use crate::store::Store;
use crate::value::Value;

#[derive(Debug, PartialEq)]
pub struct RunError {
    pub message: String,
}

pub(crate) fn run_err(msg: impl Into<String>) -> RunError {
    RunError { message: msg.into() }
}

/// How a statement finished. `break`/`continue` propagate out of `run_block`
/// until the nearest enclosing loop catches them. `Return(v)` propagates all
/// the way to the fn boundary, which unwraps it as the fn's return value.
pub(crate) enum Flow {
    Normal(Value),
    Break,
    Continue,
    Return(Value),
}

/// The result of resolving an `entity.Component.field` place. `SafeMissing`
/// means a `?.` short-circuit fired on a `none` entity or missing component.
pub(crate) enum Place {
    Field { id: u64, comp: String, field: String },
    SafeMissing,
}

pub type Env = HashMap<String, Value>;

/// A host-provided implementation of an `extern fn name(...) -> ret`.
pub type ExternFn = Box<dyn Fn(Vec<Value>) -> Result<Value, RunError> + Send + Sync>;

pub struct Interp<'a> {
    pub(crate) fns: HashMap<&'a str, &'a FnDecl>,
    pub(crate) systems: HashMap<&'a str, &'a SystemDecl>,
    /// enum variant name -> payload arity.
    /// Variant name → set of arities seen. A name may appear in multiple
    /// enums with different arities (e.g. `Tok::Require` nullary vs
    /// `Stmt::Require(Expr)` unary). Lookup picks the matching arity by
    /// call-site context, so collisions degrade gracefully instead of
    /// silently overwriting.
    pub(crate) variants: HashMap<String, Vec<usize>>,
    /// `(data_type, method)` -> the implementing `fn` (§14, static dispatch).
    pub(crate) methods: HashMap<(String, String), &'a FnDecl>,
    /// data type name -> its declaration. Used at field-write time so we
    /// can enforce range-type bounds (§8 — `r: 0...255` panics if you
    /// try to write 256).
    pub(crate) data_decls: HashMap<&'a str, &'a DataDecl>,
    /// Phase C — moved from `RefCell` to `RwLock` so the interpreter
    /// is `Sync` and can be shared across rayon worker threads. The
    /// hot path stays cheap because most accesses are reads.
    pub(crate) store: RwLock<Store>,
    /// `extern fn` impls registered by the host (orbit, an embedder, …).
    pub(crate) externs: RwLock<HashMap<String, ExternFn>>,
}

impl<'a> Interp<'a> {
    pub fn new(program: &'a crate::ast::Program) -> Self {
        let mut fns = HashMap::default();
        let mut systems = HashMap::default();
        let mut variants = HashMap::default();
        let mut methods = HashMap::default();
        let mut data_decls: HashMap<&str, &DataDecl> = HashMap::default();
        for decl in &program.decls {
            match decl {
                Decl::Fn(f) => { fns.insert(f.name.as_str(), f); }
                Decl::System(s) => { systems.insert(s.name.as_str(), s); }
                Decl::Data(d) => { data_decls.insert(d.name.as_str(), d); }
                Decl::Enum(e) => {
                    for v in &e.variants {
                        let arities = variants.entry(v.name.clone()).or_insert_with(Vec::new);
                        let arity = v.payload.len();
                        if !arities.contains(&arity) {
                            arities.push(arity);
                        }
                    }
                }
                Decl::Impl(i) => {
                    for m in &i.methods {
                        methods.insert((i.for_type.clone(), m.name.clone()), m);
                    }
                }
                _ => {}
            }
        }
        Interp {
            fns, systems, variants, methods, data_decls,
            store: RwLock::new(Store::new()),
            externs: RwLock::new(HashMap::default()),
        }
    }

    /// Look up the declared `Type` of `data.field` — used to enforce range
    /// bounds at write time (§8). Returns `None` if the data type or the
    /// field is unknown (the checker has the same view at compile time).
    pub(crate) fn field_type(&self, data: &str, field: &str) -> Option<&Type> {
        self.data_decls
            .get(data)?
            .fields
            .iter()
            .find(|f| f.name == field)
            .map(|f| &f.ty)
    }

    /// Validate `value` against a declared range type. `Type::Range { lo, hi,
    /// inclusive }` rejects writes that fall outside the bounds — that's the
    /// guarantee `data Health: hp: 0...1000` actually buys you. Other types
    /// pass through.
    pub(crate) fn check_range_bounds(
        ty: &Type, value: &Value, who: &str,
    ) -> Result<(), RunError> {
        if let Type::Range { lo, hi, inclusive } = ty {
            let n = match value {
                Value::Int(n) => *n,
                Value::Float(x) => *x as i64,
                _ => return Ok(()),
            };
            let in_bounds = if *inclusive { n >= *lo && n <= *hi } else { n >= *lo && n < *hi };
            if !in_bounds {
                let upper = if *inclusive { format!("{hi}") } else { format!("<{hi}") };
                return Err(run_err(format!(
                    "range overflow: {who} = {n} is outside {lo}..{upper}"
                )));
            }
        }
        Ok(())
    }

    /// Register a host-side implementation for an `extern fn name(...)`.
    pub fn register_extern<F>(&self, name: &str, f: F)
    where
        F: Fn(Vec<Value>) -> Result<Value, RunError> + Send + Sync + 'static,
    {
        self.externs.write().unwrap().insert(name.to_string(), Box::new(f));
    }

    /// Public wrapper around the internal expression evaluator. Used
    /// by the REPL and embedders that need to evaluate ad-hoc
    /// expressions against an interpreter's state.
    pub fn eval_expr_with_env(&self, e: &crate::ast::Expr, env: &mut Env) -> Result<Value, RunError> {
        self.eval(e, env)
    }

    pub fn store(&self) -> std::sync::RwLockReadGuard<'_, Store> {
        self.store.read().unwrap()
    }

    pub fn store_mut(&self) -> std::sync::RwLockWriteGuard<'_, Store> {
        self.store.write().unwrap()
    }

    /// Look up an impl method by `(data_type, method_name)` and call it.
    pub(crate) fn call_method(&self, data_type: &str, method: &str, args: Vec<Value>) -> Result<Value, RunError> {
        let key = (data_type.to_string(), method.to_string());
        let f = self.methods.get(&key).copied()
            .ok_or_else(|| run_err(format!("no method `{method}` for type `{data_type}`")))?;
        let mut env = self.bind_params(&f.params, args, &f.name)?;
        match &f.body {
            FnBody::Expr(e) => self.eval(e, &mut env),
            FnBody::Block(stmts) => self.finish(self.run_block(stmts, &mut env)?),
            FnBody::Extern => Err(run_err(format!("impl method `{data_type}::{method}` has no body"))),
        }
    }

    /// Call a top-level function or system by name.
    pub fn call(&self, name: &str, args: Vec<Value>) -> Result<Value, RunError> {
        if let Some(f) = self.fns.get(name).copied() {
            if matches!(f.body, FnBody::Extern) {
                return self.call_extern(name, args);
            }
            let mut env = self.bind_params(&f.params, args, &f.name)?;
            return match &f.body {
                FnBody::Expr(e) => self.eval(e, &mut env),
                FnBody::Block(stmts) => self.finish(self.run_block(stmts, &mut env)?),
                FnBody::Extern => unreachable!("guarded above"),
            };
        }
        if let Some(s) = self.systems.get(name).copied() {
            let mut env = self.bind_params(&s.params, args, &s.name)?;
            return self.finish(self.run_block(&s.body, &mut env)?);
        }
        Err(run_err(format!("no function or system named `{name}`")))
    }

    pub(crate) fn call_extern(&self, name: &str, args: Vec<Value>) -> Result<Value, RunError> {
        let externs = self.externs.read().unwrap();
        let Some(f) = externs.get(name) else {
            // Native runtime hooks (frame arena, alloc telemetry, embedded
            // assets) are no-ops here — shared orbs declare them and must
            // run unchanged. embedded_has = 0 keeps games on the file path,
            // so embedded_text is never reached.
            // Identity under the interpreter: no pools to evacuate from.
            if name == "orion_persist_text" {
                return Ok(args
                    .into_iter()
                    .next()
                    .unwrap_or(Value::Text(String::new())));
            }
            // Terminal capability: styled output only when stdout is
            // an interactive console (redirected logs stay plain).
            // First hit also flips conhost into VT + UTF-8 mode.
            if name == "orion_console_color" {
                use std::io::IsTerminal;
                if !std::io::stdout().is_terminal() {
                    return Ok(Value::Int(0));
                }
                #[cfg(windows)]
                unsafe {
                    unsafe extern "system" {
                        fn GetStdHandle(which: u32) -> *mut std::ffi::c_void;
                        fn GetConsoleMode(h: *mut std::ffi::c_void, m: *mut u32) -> i32;
                        fn SetConsoleMode(h: *mut std::ffi::c_void, m: u32) -> i32;
                        fn SetConsoleOutputCP(cp: u32) -> i32;
                    }
                    let h = GetStdHandle(-11i32 as u32);
                    let mut mode: u32 = 0;
                    if !h.is_null() && GetConsoleMode(h, &mut mode) != 0 {
                        SetConsoleMode(h, mode | 0x0004);
                        SetConsoleOutputCP(65001);
                    }
                }
                return Ok(Value::Int(1));
            }
            // Real commit charge even under the interpreter — the mem
            // report should never lie about the process.
            if name == "orion_os_private_kb" {
                #[cfg(windows)]
                {
                    #[repr(C)]
                    struct Pmc {
                        cb: u32,
                        page_fault_count: u32,
                        peak_ws: usize,
                        ws: usize,
                        qppu: usize,
                        qpu: usize,
                        qpnpu: usize,
                        qnpu: usize,
                        pagefile: usize,
                        peak_pagefile: usize,
                    }
                    unsafe extern "system" {
                        fn GetCurrentProcess() -> *mut std::ffi::c_void;
                        fn K32GetProcessMemoryInfo(
                            h: *mut std::ffi::c_void,
                            pmc: *mut Pmc,
                            cb: u32,
                        ) -> i32;
                    }
                    unsafe {
                        let mut pmc: Pmc = std::mem::zeroed();
                        pmc.cb = std::mem::size_of::<Pmc>() as u32;
                        if K32GetProcessMemoryInfo(GetCurrentProcess(), &mut pmc, pmc.cb) != 0 {
                            return Ok(Value::Int((pmc.pagefile / 1024) as i64));
                        }
                    }
                }
                return Ok(Value::Int(0));
            }
            if name.starts_with("orion_arena_")
                || name.starts_with("orion_frame_")
                || name.starts_with("orion_persist_")
                || name.starts_with("orion_pool_")
            {
                return Ok(Value::Int(1));
            }
            if name == "orion_dir_list" {
                let Some(Value::Text(dir)) = args.first() else {
                    return Ok(Value::Text(String::new()));
                };
                let mut names: Vec<String> = Vec::new();
                if let Ok(rd) = std::fs::read_dir(dir.as_str()) {
                    for e in rd.flatten() {
                        if e.path().is_file() {
                            names.push(e.file_name().to_string_lossy().into_owned());
                        }
                    }
                }
                return Ok(Value::Text(names.join("\n")));
            }
            // Non-blocking console line for the dev console: a reader
            // thread feeds a channel; try_recv per poll, "" when idle.
            if name == "orion_console_readline" {
                use std::sync::mpsc::{channel, Receiver};
                use std::sync::{Mutex, OnceLock};
                static RX: OnceLock<Mutex<Receiver<String>>> = OnceLock::new();
                let rx = RX.get_or_init(|| {
                    let (tx, rx) = channel();
                    std::thread::spawn(move || {
                        use std::io::BufRead;
                        let stdin = std::io::stdin();
                        for line in stdin.lock().lines().map_while(Result::ok) {
                            if tx.send(line).is_err() {
                                break;
                            }
                        }
                    });
                    Mutex::new(rx)
                });
                let line = rx.lock().unwrap().try_recv().unwrap_or_default();
                return Ok(Value::Text(line));
            }
            if name == "orion_dir_subdirs" {
                let Some(Value::Text(dir)) = args.first() else {
                    return Ok(Value::Text(String::new()));
                };
                let mut names: Vec<String> = Vec::new();
                if let Ok(rd) = std::fs::read_dir(dir.as_str()) {
                    for e in rd.flatten() {
                        let fname = e.file_name().to_string_lossy().into_owned();
                        if e.path().is_dir() && !fname.starts_with('.') {
                            names.push(fname);
                        }
                    }
                }
                return Ok(Value::Text(names.join("\n")));
            }
            if name == "orion_embedded_list" {
                return Ok(Value::Text(String::new()));
            }
            if name == "orion_file_stamp" {
                let Some(Value::Text(path)) = args.first() else {
                    return Ok(Value::Int(0));
                };
                let stamp = std::fs::metadata(path.as_str())
                    .ok()
                    .map(|m| {
                        let mtime = m
                            .modified()
                            .ok()
                            .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
                            .map(|d| d.as_secs() as i64)
                            .unwrap_or(0);
                        mtime * 131 + m.len() as i64
                    })
                    .unwrap_or(0);
                return Ok(Value::Int(stamp));
            }
            if name.starts_with("orion_alloc_") || name.starts_with("orion_embedded_") {
                return Ok(Value::Int(0));
            }
            return Err(run_err(format!("extern fn `{name}` has no registered impl")));
        };
        f(args)
    }

    pub(crate) fn bind_params(&self, params: &[Param], args: Vec<Value>, who: &str) -> Result<Env, RunError> {
        if args.len() > params.len() {
            return Err(run_err(format!("`{who}` takes {} argument(s), got {}", params.len(), args.len())));
        }
        let mut env = Env::default();
        for (i, p) in params.iter().enumerate() {
            let v = match args.get(i) {
                Some(v) => v.clone(),
                None => match &p.default {
                    Some(d) => self.eval(d, &mut Env::default())?,
                    None => return Err(run_err(format!("missing argument `{}` for `{who}`", p.name))),
                },
            };
            env.insert(p.name.clone(), v);
        }
        Ok(env)
    }

    /// Unwrap a block's flow into a value — a stray `break`/`continue` at the
    /// top level of a fn body is a runtime error (the static checker already
    /// rejects most cases; this guards interp-only paths).
    pub(crate) fn finish(&self, flow: Flow) -> Result<Value, RunError> {
        match flow {
            Flow::Normal(v) | Flow::Return(v) => Ok(v),
            _ => Err(run_err("`break`/`continue` outside a loop")),
        }
    }

    pub(crate) fn as_bool(&self, v: Value) -> Result<bool, RunError> {
        match v {
            Value::Bool(b) => Ok(b),
            other => Err(run_err(format!("expected a boolean, got {other:?}"))),
        }
    }
}

/// Run every statement in `stmts`; the block's value is its last bare-expr
/// value, or `Unit`. A `break`/`continue` short-circuits and bubbles up.
pub(crate) fn run_block_impl(
    interp: &Interp<'_>,
    stmts: &[Stmt],
    env: &mut Env,
) -> Result<Flow, RunError> {
    let mut last = Value::Unit;
    for s in stmts {
        match interp.exec(s, env)? {
            Flow::Normal(v) => last = v,
            other => return Ok(other),
        }
    }
    Ok(Flow::Normal(last))
}

impl Interp<'_> {
    pub(crate) fn run_block(&self, stmts: &[Stmt], env: &mut Env) -> Result<Flow, RunError> {
        run_block_impl(self, stmts, env)
    }
}
