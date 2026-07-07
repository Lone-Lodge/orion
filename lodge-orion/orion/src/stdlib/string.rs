//! `string` — text manipulation.
//!
//! All string operations are now pure Orion (`orbs/string/lib.or`)
//! built on the `bytes` orb. This file only provides the SOURCE constant
//! and an empty registrar (no extern fns remain).

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/string/lib.or");

pub fn register(_interp: &Interp) {}
