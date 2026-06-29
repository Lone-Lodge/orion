//! `process` — spawn external commands. Public API is pure Orion
//! (`orbs/process/lib.or`); only the OS bridges stay native.

use crate::interp::Interp;
use crate::value::Value;

pub const SOURCE: &str = include_str!("../../../orbs/process/lib.or");

pub fn register(interp: &Interp) {
    interp.register_extern("__os_run_command", |args| {
        let (cmd, items) = parse_args(&args);
        let status = std::process::Command::new(cmd).args(items).status();
        Ok(Value::Int(
            status.ok().and_then(|s| s.code()).unwrap_or(-1) as i64
        ))
    });
    interp.register_extern("__os_capture_stdout", |args| {
        let (cmd, items) = parse_args(&args);
        let out = std::process::Command::new(cmd).args(items).output();
        Ok(Value::Text(
            out.map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
                .unwrap_or_default(),
        ))
    });
    interp.register_extern("__os_capture_stderr", |args| {
        let (cmd, items) = parse_args(&args);
        let out = std::process::Command::new(cmd).args(items).output();
        Ok(Value::Text(
            out.map(|o| String::from_utf8_lossy(&o.stderr).into_owned())
                .unwrap_or_default(),
        ))
    });
}

fn parse_args(args: &[Value]) -> (String, Vec<String>) {
    let cmd = as_text(&args[0]);
    let items: Vec<String> = match &args[1] {
        Value::List(items) => items.iter().map(as_text).collect(),
        _ => Vec::new(),
    };
    (cmd, items)
}

fn as_text(v: &Value) -> String {
    match v {
        Value::Text(s) => s.clone(),
        other => other.to_string(),
    }
}
