//! `crypto` — SHA-256 (FIPS 180-4).
//!
//! Implemented entirely in Orion (`orbs/crypto/lib.or`) on top of the
//! `bytes` orb + built-in bit-ops and wrapping arithmetic. The Rust
//! implementation has been retired — keeping the source bundled is all
//! this file does now.

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/crypto/lib.or");

pub fn register(_interp: &Interp) {}
