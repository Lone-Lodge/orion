//! `color` — RGBA colors with lerp/clamp/brightness/HSV/hex conversion.
//!
//! Fully pure Orion (`orbs/color/lib.or`) — the `_hex_to_rgba` and
//! `_rgba_to_hex` bridges that used to live here are now Orion functions
//! built on top of `bytes` + `string` + `format` builtins.

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/color/lib.or");

pub fn register(_interp: &Interp) {}
