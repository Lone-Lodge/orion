//! `math` — Vec2/Vec3/Mat4/Quaternion.
//!
//! Fully pure Orion (`orbs/math/lib.or`). The compound matrix and
//! quaternion operations have been ported using a flat list-of-floats
//! representation that fits Orion's gradual typing.

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/math/lib.or");

pub fn register(_interp: &Interp) {}
