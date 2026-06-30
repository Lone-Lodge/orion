//! Orion's bundled standard library. Each *orb* exports:
//!   * `SOURCE` — the `.or` text the loader compiles (declares `extern fn`s).
//!   * `register(interp)` — registers the Rust implementations of those externs.
//!
//! Orbit reads a project's `Orbit.toml` `[orbs]`, materializes each requested
//! orb's SOURCE to `target/orbit_modules/<name>.or`, and calls `register` on
//! the live `Interp` before executing user code.

mod astra_bridge;
mod audio;
mod base64;
mod bytes;
mod collections;
mod compress;
mod color;
mod crypto;
mod csv;
mod easing;
mod env;
mod format;
mod fs;
mod hash;
mod hex;
mod image;
mod io;
mod json;
mod log;
mod math;
mod net;
mod noise;
mod path;
mod process;
mod random;
mod regex;
mod stats;
mod string;
mod sysinfo;
mod test;
mod time;
mod time_format;
mod url;
mod uuid;
mod window;
mod gpu;
mod wgsl;
mod xml;

use crate::interp::Interp;

/// One bundled orb — its name, its `.or` source, a Rust registrar, and the
/// names of other built-in orbs it depends on. `deps` is empty for most
/// orbs; pure-Orion orbs that call externs from another orb list them so
/// orbit (and isolation tests) know what to load alongside.
pub struct Orb {
    pub name: &'static str,
    pub source: &'static str,
    pub register: fn(&Interp),
    pub deps: &'static [&'static str],
}

/// Every stdlib orb orbit knows about.
pub const ORBS: &[Orb] = &[
    Orb { name: "time",        source: time::SOURCE,        register: time::register,        deps: &[] },
    Orb { name: "math",        source: math::SOURCE,        register: math::register,        deps: &[] },
    Orb { name: "io",          source: io::SOURCE,          register: io::register,          deps: &[] },
    Orb { name: "test",        source: test::SOURCE,        register: test::register,        deps: &[] },
    Orb { name: "random",      source: random::SOURCE,      register: random::register,      deps: &[] },
    Orb { name: "string",      source: string::SOURCE,      register: string::register,      deps: &["bytes"] },
    Orb { name: "log",         source: log::SOURCE,         register: log::register,         deps: &["time", "format"] },
    Orb { name: "collections", source: collections::SOURCE, register: collections::register, deps: &[] },
    Orb { name: "easing",      source: easing::SOURCE,      register: easing::register,      deps: &[] },
    Orb { name: "noise",       source: noise::SOURCE,       register: noise::register,       deps: &[] },
    Orb { name: "json",        source: json::SOURCE,        register: json::register,        deps: &["bytes", "string", "format"] },
    Orb { name: "color",       source: color::SOURCE,       register: color::register,       deps: &["bytes", "string"] },
    Orb { name: "env",         source: env::SOURCE,         register: env::register,         deps: &[] },
    Orb { name: "path",        source: path::SOURCE,        register: path::register,        deps: &["bytes"] },
    Orb { name: "hash",        source: hash::SOURCE,        register: hash::register,        deps: &["bytes"] },
    Orb { name: "hex",         source: hex::SOURCE,         register: hex::register,         deps: &["bytes"] },
    Orb { name: "window",      source: window::SOURCE,      register: window::register,      deps: &[] },
    Orb { name: "csv",         source: csv::SOURCE,         register: csv::register,         deps: &["bytes"] },
    Orb { name: "base64",      source: base64::SOURCE,      register: base64::register,      deps: &["bytes"] },
    Orb { name: "regex",       source: regex::SOURCE,       register: regex::register,       deps: &["bytes"] },
    Orb { name: "process",     source: process::SOURCE,     register: process::register,     deps: &[] },
    Orb { name: "fs",          source: fs::SOURCE,          register: fs::register,          deps: &[] },
    Orb { name: "format",      source: format::SOURCE,      register: format::register,      deps: &["bytes", "string"] },
    Orb { name: "sysinfo",     source: sysinfo::SOURCE,     register: sysinfo::register,     deps: &[] },
    Orb { name: "crypto",      source: crypto::SOURCE,      register: crypto::register,      deps: &["bytes"] },
    Orb { name: "uuid",        source: uuid::SOURCE,        register: uuid::register,        deps: &["bytes"] },
    Orb { name: "url",         source: url::SOURCE,         register: url::register,         deps: &["bytes"] },
    Orb { name: "net",         source: net::SOURCE,         register: net::register,         deps: &[] },
    Orb { name: "bytes",       source: bytes::SOURCE,       register: bytes::register,       deps: &[] },
    Orb { name: "time_format", source: time_format::SOURCE, register: time_format::register, deps: &["bytes", "string", "format"] },
    Orb { name: "xml",         source: xml::SOURCE,         register: xml::register,         deps: &["bytes"] },
    Orb { name: "compress",    source: compress::SOURCE,    register: compress::register,    deps: &["bytes"] },
    Orb { name: "stats",       source: stats::SOURCE,       register: stats::register,       deps: &["collections"] },
    Orb { name: "image",       source: image::SOURCE,       register: image::register,       deps: &["bytes"] },
    Orb { name: "audio",       source: audio::SOURCE,       register: audio::register,       deps: &[] },
    Orb { name: "gpu",         source: gpu::SOURCE,         register: gpu::register,         deps: &["window"] },
    Orb { name: "wgsl",        source: wgsl::SOURCE,        register: wgsl::register,        deps: &[] },
    Orb { name: "astra",       source: astra_bridge::SOURCE, register: astra_bridge::register, deps: &[] },
];

/// Find a bundled orb by name, or `None` if it's not part of the stdlib.
pub fn find(name: &str) -> Option<&'static Orb> {
    ORBS.iter().find(|o| o.name == name)
}
