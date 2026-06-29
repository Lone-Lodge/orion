//! `path` — filesystem path manipulation.
//!
//! Pure-string ops live in `orbs/path/lib.or`. Only `current_dir` is a
//! syscall and stays native.

use crate::interp::Interp;
use crate::value::Value;

pub const SOURCE: &str = include_str!("../../../orbs/path/lib.or");

pub fn register(interp: &Interp) {
    interp.register_extern("__os_current_dir", |_args| {
        let s = std::env::current_dir()
            .map(|p| p.to_string_lossy().into_owned())
            .unwrap_or_default();
        Ok(Value::Text(s))
    });
}
