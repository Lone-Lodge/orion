//! `sysinfo` — basic host info. Public API is pure Orion
//! (`orbs/sysinfo/lib.or`); only the OS bridges stay native.

use crate::interp::Interp;
use crate::value::Value;

pub const SOURCE: &str = include_str!("../../../orbs/sysinfo/lib.or");

pub fn register(interp: &Interp) {
    interp.register_extern("__os_cpu_count", |_args| {
        let n = std::thread::available_parallelism()
            .map(|n| n.get() as i64)
            .unwrap_or(1);
        Ok(Value::Int(n))
    });
    interp.register_extern("__os_name", |_args| Ok(Value::Text(std::env::consts::OS.into())));
    interp.register_extern("__os_family", |_args| Ok(Value::Text(std::env::consts::FAMILY.into())));
    interp.register_extern("__os_arch", |_args| Ok(Value::Text(std::env::consts::ARCH.into())));
}
