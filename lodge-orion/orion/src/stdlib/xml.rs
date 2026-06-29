//! `xml` — minimal DOM-style XML parser.
//!
//! Fully pure Orion (`orbs/xml/lib.or`) — recursive-descent parser using
//! the same Map-based position-threading pattern as the JSON port.

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/xml/lib.or");

pub fn register(_interp: &Interp) {}
