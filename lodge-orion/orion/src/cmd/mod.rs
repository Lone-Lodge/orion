//! CLI command implementations — one focused function per subcommand. `main.rs`
//! parses argv and dispatches here. Submodules group commands by intent.

mod bench;
mod engine;
mod inspect;
mod run;

use std::process;

use orion::ast::{Decl, Program};
use orion::value::Value;

pub use bench::{aosoa, gatherbench, parbench, parrun, select, simd};
pub use engine::{ai_context, analyze, bench, build_cache, call, check_all, completion, contracts, contracts_fuzz, contracts_test, docs, explain, features, fmt_rich, footprint, graph, init, layout, lint, llvm, outline, pack_info, repl, sample, search, sim, sim_jit, size, stats, topics, version, watch};
pub use inspect::{check_ok, goto, hover, lex, parse, symbols};
pub use run::{aot, jit, link, run};

// ---- shared helpers ----

pub fn arg_to_value(s: &str) -> Value {
    if let Ok(i) = s.parse::<i64>() {
        Value::Int(i)
    } else if let Ok(f) = s.parse::<f64>() {
        Value::Float(f)
    } else {
        Value::Text(s.to_string())
    }
}

pub(crate) fn parse_params(rest: &[String], from: usize) -> Vec<f64> {
    rest[from.min(rest.len())..].iter().map(|s| s.parse().unwrap_or(1.0)).collect()
}

pub(crate) fn defines(program: &Program, name: &str) -> bool {
    program.decls.iter().any(|d| match d {
        Decl::Fn(f) => f.name == name,
        Decl::System(s) => s.name == name,
        _ => false,
    })
}

pub(crate) fn defines_fn(program: &Program, name: &str) -> bool {
    program.decls.iter().any(|d| matches!(d, Decl::Fn(f) if f.name == name))
}

pub(crate) fn read(path: &str) -> String {
    std::fs::read_to_string(path).unwrap_or_else(|e| die(&format!("cannot read {path}: {e}")))
}

#[track_caller]
pub fn die(msg: &str) -> ! {
    eprintln!("{msg}");
    process::exit(1);
}
