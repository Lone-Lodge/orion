//! `regex` — glob + tiny regex subset.
//!
//! Fully pure Orion (`orbs/regex/lib.or`). Predicates are inlined via
//! `atom_length` + `atom_matches`, dodging the Rust closure-typing trap.

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/regex/lib.or");

pub fn register(_interp: &Interp) {}
