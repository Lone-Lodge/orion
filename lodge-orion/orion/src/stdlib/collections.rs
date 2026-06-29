//! `collections` — list helpers. Fully pure Orion now
//! (`orbs/collections/lib.or`); the Rust shim is just the SOURCE bundle.

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/collections/lib.or");

pub fn register(_interp: &Interp) {}
