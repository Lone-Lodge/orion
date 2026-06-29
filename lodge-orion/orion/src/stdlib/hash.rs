//! `hash` — fast 64-bit hashing (FNV-1a + SplitMix64).
//!
//! Implemented entirely in Orion (`orbs/hash/lib.or`) on top of the
//! `bytes` orb and built-in i64 wrapping arithmetic — the original Rust
//! implementation has been retired. Kept as a registered orb only to ship
//! the source with the binary.

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/hash/lib.or");

pub fn register(_interp: &Interp) {}
