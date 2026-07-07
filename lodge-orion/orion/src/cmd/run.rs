//! Run a function: tree-walking interpreter, JIT, or AOT compile to object.

use orion::ast::Program;
use orion::interp::Interp;
use orion::jit::Jit;
use orion::value::Value;

use super::{arg_to_value, die};

pub fn run(rest: &[String], program: &Program) {
    let fname = rest.get(1).map(|s| s.as_str())
        .unwrap_or_else(|| die("usage: orion run <file.or> <fn> [args...]"));
    let args: Vec<Value> = rest[2..].iter().map(|s| arg_to_value(s)).collect();
    match Interp::new(program).call(fname, args) {
        Ok(v) => println!("{v}"),
        Err(e) => die(&format!("run error: {}", e.message)),
    }
}

pub fn jit(rest: &[String], program: &Program) {
    let fname = rest.get(1).map(|s| s.as_str())
        .unwrap_or_else(|| die("usage: orion jit <file.or> <fn> [int args...]"));
    let mut jit = Jit::new().unwrap_or_else(|e| die(&format!("jit init error: {e}")));
    let cf = jit.compile(program, fname).unwrap_or_else(|e| die(&format!("jit compile error: {e}")));
    match jit.run_cli(&cf, &rest[2..]) {
        Ok(v) => println!("{v}"),
        Err(e) => die(&format!("jit run error: {e}")),
    }
}

pub fn aot(rest: &[String], program: &Program) {
    let fname = rest.get(1).map(|s| s.as_str())
        .unwrap_or_else(|| die("usage: orion aot <file.or> <fn> [out.o]"));
    let out = rest.get(2).cloned().unwrap_or_else(|| format!("{fname}.o"));
    match orion::aot::compile_object(program, fname, &out) {
        Ok(bytes) => {
            println!("wrote {out} ({bytes} bytes) — a native object file for `{fname}`");
            println!("link it with your platform's linker to make a standalone binary");
        }
        Err(e) => die(&format!("aot error: {e}")),
    }
}

pub fn link(rest: &[String], program: &Program) {
    let fname = rest.get(1).map(|s| s.as_str())
        .unwrap_or_else(|| die("usage: orion link <file.or> <fn> [out_exe]"));
    let default_out = if cfg!(windows) { format!("{fname}.exe") } else { fname.to_string() };
    let out = rest.get(2).cloned().unwrap_or(default_out);
    match orion::link::build_executable(program, fname, &out) {
        Ok(()) => {
            println!("built {out} — run it directly, no runtime needed");
        }
        Err(e) => die(&format!("link error: {e}")),
    }
}
