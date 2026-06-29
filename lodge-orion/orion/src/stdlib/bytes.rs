//! `bytes` — raw byte arrays as `[int]`.
//!
//! Almost everything moved to `orbs/bytes/lib.or` as pure Orion. Only the
//! Text ↔ [int] bridge and `read_f32_le` (IEEE-754 bit cast) stay native.

use crate::interp::Interp;
use crate::value::Value;

pub const SOURCE: &str = include_str!("../../../orbs/bytes/lib.or");

pub fn register(interp: &Interp) {
    interp.register_extern("__os_bytes_from_text", |args| {
        let s = as_text(&args[0]);
        Ok(Value::List(std::sync::Arc::new(s.bytes().map(|b| Value::Int(b as i64)).collect())))
    });
    interp.register_extern("__os_bytes_to_text", |args| {
        let bytes = as_bytes(&args[0]);
        Ok(Value::Text(String::from_utf8_lossy(&bytes).into_owned()))
    });
    interp.register_extern("__os_read_f32_le", |args| {
        let b = as_bytes(&args[0]);
        let o = as_int(&args[1]).max(0) as usize;
        if o + 4 > b.len() {
            return Ok(Value::Float(0.0));
        }
        let bits = u32::from_le_bytes([b[o], b[o + 1], b[o + 2], b[o + 3]]);
        Ok(Value::Float(f32::from_bits(bits) as f64))
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

fn as_bytes(v: &Value) -> Vec<u8> {
    match v {
        Value::List(items) => items
            .iter()
            .map(|x| match x {
                Value::Int(n) => (*n).max(0).min(255) as u8,
                Value::Float(f) => (*f as i64).max(0).min(255) as u8,
                _ => 0,
            })
            .collect(),
        _ => Vec::new(),
    }
}
