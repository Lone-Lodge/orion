//! `env` — process args, env vars, exit. Public API lives in
//! `orbs/env/lib.or`; only the OS bridges stay native.

use std::process;

use crate::interp::Interp;
use crate::value::Value;

pub const SOURCE: &str = include_str!("../../../orbs/env/lib.or");

pub fn register(interp: &Interp) {
    interp.register_extern("__os_arg_count", |_args| {
        Ok(Value::Int(std::env::args().count() as i64))
    });
    interp.register_extern("__os_arg", |args| {
        let i = as_int(&args[0]).max(0) as usize;
        Ok(Value::Text(std::env::args().nth(i).unwrap_or_default()))
    });
    interp.register_extern("__os_env_var", |args| {
        let name = as_text(&args[0]);
        Ok(Value::Text(std::env::var(name).unwrap_or_default()))
    });
    interp.register_extern("__os_exit", |args| {
        process::exit(as_int(&args[0]) as i32);
    });
}

fn as_text(v: &Value) -> String {
    match v {
        Value::Text(s) => s.clone(),
        other => other.to_string(),
    }
}

fn as_int(v: &Value) -> i64 {
    match v {
        Value::Int(n) => *n,
        Value::Float(x) => *x as i64,
        _ => 0,
    }
}
