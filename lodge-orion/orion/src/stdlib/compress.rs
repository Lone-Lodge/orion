//! `compress` — run-length encoding for byte arrays.
//!
//! Implemented entirely in Orion (`orbs/compress/lib.or`) on top of the
//! `bytes` orb — the Rust implementation has been retired. Kept as a
//! registered orb only to ship the source with the binary.

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/compress/lib.or");

pub fn register(_interp: &Interp) {}
