//! `wgsl` — pure-Orion WGSL → HLSL/MSL/GLSL translator. The Rust side
//! is intentionally empty — the orb is entirely Orion code that does
//! string-based translation. Lives in stdlib so `use wgsl` works in
//! every orbit project without an explicit dependency.

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/wgsl/lib.or");

pub fn register(_interp: &Interp) {
    // Pure Orion — no externs to wire.
}
