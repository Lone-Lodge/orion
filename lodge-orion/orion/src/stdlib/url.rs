//! `url` — percent-encoding and minimal URL parsing.
//!
//! Fully pure Orion (`orbs/url/lib.or`). `url_encode`/`url_decode` and
//! now `url_parse` (which builds a `{scheme, host, port, path, query}`
//! Map) are all implemented in Orion on top of the `bytes` orb.

use crate::interp::Interp;

pub const SOURCE: &str = include_str!("../../../orbs/url/lib.or");

pub fn register(_interp: &Interp) {}
