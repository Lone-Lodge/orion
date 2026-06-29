//! `string` — text manipulation.
//!
//! Almost all string operations are now pure Orion (`orbs/string/lib.or`)
//! built on the `bytes` orb. Only `str_upper` and `str_lower` stay native
//! — full Unicode case folding requires multi-megabyte tables that
//! aren't worth carrying in Orion code.

use crate::interp::Interp;
use crate::value::Value;

pub const SOURCE: &str = include_str!("../../../orbs/string/lib.or");

pub fn register(interp: &Interp) {
    interp.register_extern("__os_str_upper", |args| {
        Ok(Value::Text(as_text(&args[0]).to_uppercase()))
    });
    interp.register_extern("__os_str_lower", |args| {
        Ok(Value::Text(as_text(&args[0]).to_lowercase()))
    });
}

fn as_text(v: &Value) -> String {
    match v {
        Value::Text(s) => s.clone(),
        other => other.to_string(),
    }
}
