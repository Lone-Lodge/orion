//! `csv` — RFC 4180-ish parser and serializer.
//!
//! Pure Orion (`orbs/csv/lib.or`) built on the `bytes` orb. The Rust
//! implementation has been retired.

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/csv/lib.or");

pub fn register(_interp: &Interp) {}
