//! `uuid` — UUID v4 generation, fully pure Orion.
//!
//! See `orbs/uuid/lib.or` — SplitMix state lives in `slot_get`/`slot_set`.

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/uuid/lib.or");

pub fn register(_interp: &Interp) {}
