//! `noise` — value noise + fbm for procedural generation.
//!
//! Pure Orion (`orbs/noise/lib.or`) — the SplitMix-style integer hash
//! is implemented directly in Orion using wrapping i64 arithmetic and
//! the `to_int`/`to_float` builtins.

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/noise/lib.or");

pub fn register(_interp: &Interp) {}
