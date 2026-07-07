//! `test` — assert helpers built on Orion contracts. Each `assert_*` calls
//! `require` so `orbit test` reports the assertion site on failure.

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/test/lib.or");

/// No native impls — assertions are pure Orion code (`require` is built in).
pub fn register(_interp: &Interp) {}
