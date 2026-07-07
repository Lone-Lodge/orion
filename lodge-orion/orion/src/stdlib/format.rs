//! `format` — typed format helpers (width, padding, radix conversion).
//!
//! Fully pure Orion (`orbs/format/lib.or`). `fmt_float` is now a
//! round-then-split-int-and-frac implementation in Orion — see the
//! orb for the algorithm.

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/format/lib.or");

pub fn register(_interp: &Interp) {}
