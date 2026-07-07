//! `easing` — interpolation curves for animation. All take `t` in [0, 1] and
//! return a value in [0, 1]. Pure Orion on top of math builtins.

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/easing/lib.or");

pub fn register(_interp: &Interp) {}
