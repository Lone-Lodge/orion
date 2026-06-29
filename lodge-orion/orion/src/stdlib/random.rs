//! `random` — PCG-32 RNG. Fully pure Orion.
//!
//! Implementation in `orbs/random/lib.or` — state lives in a thread-local
//! `slot_get`/`slot_set` rather than the previous `Arc<Mutex<Pcg32>>`.

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/random/lib.or");

pub fn register(_interp: &Interp) {}
