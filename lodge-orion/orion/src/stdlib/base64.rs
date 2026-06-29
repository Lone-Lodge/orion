//! `base64` — RFC 4648 alphabet with `=` padding.
//!
//! Implemented entirely in Orion (`orbs/base64/lib.or`) on top of the
//! `bytes` orb and the built-in bit-ops — the first algorithm orb that
//! lives outside Rust. Kept as a registered orb only to ship the source
//! with the binary.

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/base64/lib.or");

pub fn register(_interp: &Interp) {}
