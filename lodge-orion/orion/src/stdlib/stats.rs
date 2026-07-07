//! `stats` — summary statistics over `[f64]`.
//!
//! Pure Orion (`orbs/stats/lib.or`) built on `len`/`at`/`floor`/`ceil`/
//! `sqrt`/`clamp`/`to_int`/`to_float` builtins plus the `collections` orb's
//! `list_sort_asc`. The Rust implementation has been retired.

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/stats/lib.or");

pub fn register(_interp: &Interp) {}
