//! `time_format` — ISO 8601 date/time formatting and parsing.
//!
//! Pure Orion (`orbs/time_format/lib.or`) — Howard Hinnant's days_from_civil
//! algorithm carried over verbatim, plus a hand-rolled ISO 8601 parser. The
//! Rust implementation has been retired.

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/time_format/lib.or");

pub fn register(_interp: &Interp) {}
