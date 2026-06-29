//! `log` — leveled logger, fully pure Orion.
//!
//! See `orbs/log/lib.or` — level state via `slot_get`/`slot_set`, output
//! via `eprint`, timestamp via `time.now`.

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/log/lib.or");

pub fn register(_interp: &Interp) {}
