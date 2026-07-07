//! `time` — clock and sleep. Public API is pure Orion (`orbs/time/lib.or`);
//! only the two OS primitives stay native.

use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use crate::interp::Interp;
use crate::value::Value;

pub const SOURCE: &str = include_str!("../../../orbs/time/lib.or");

pub fn register(interp: &Interp) {
    interp.register_extern("__os_unix_time", |_args| Ok(Value::Float(now_seconds())));
    interp.register_extern("__os_sleep_seconds", |args| {
        let secs = as_f64(&args[0]).max(0.0);
        std::thread::sleep(Duration::from_secs_f64(secs));
        Ok(Value::Unit)
    });
}

fn now_seconds() -> f64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs_f64())
        .unwrap_or_else(|_| Instant::now().elapsed().as_secs_f64())
}

fn as_f64(v: &Value) -> f64 {
    match v {
        Value::Int(n) => *n as f64,
        Value::Float(x) => *x,
        _ => 0.0,
    }
}
