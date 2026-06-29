//! Tiny TOML reader/writer for Orbit.toml. Supports `[section]` headers and
//! `key = "value"` lines. Comments are ignored. That's all orbit needs.
//!
//! Sections: `[package]` for project metadata, `[orbs]` for the project's orbs.

use std::collections::BTreeMap;
use std::fs;

#[derive(Default)]
pub struct OrbitToml {
    pub package: BTreeMap<String, String>,
    /// The project's orbs (dependencies). Each key is an orb name, each value
    /// is its version (`"stdlib"` for bundled, semver for registry orbs later).
    pub orbs: BTreeMap<String, String>,
    /// Order in which sections first appeared, so `render` round-trips cleanly.
    sections: Vec<String>,
}

impl OrbitToml {
    pub fn read(path: &str) -> Result<OrbitToml, String> {
        let src = fs::read_to_string(path).map_err(|e| format!("cannot read {path}: {e}"))?;
        Ok(parse(&src))
    }

    pub fn write(&self, path: &str) -> Result<(), String> {
        fs::write(path, self.render()).map_err(|e| format!("cannot write {path}: {e}"))
    }

    pub fn render(&self) -> String {
        let mut out = String::new();
        let mut order: Vec<String> = self.sections.clone();
        for s in ["package", "orbs"] {
            if !order.iter().any(|x| x == s) {
                order.push(s.into());
            }
        }
        for (i, name) in order.iter().enumerate() {
            let table = match name.as_str() {
                "package" => &self.package,
                "orbs" => &self.orbs,
                _ => continue,
            };
            if i > 0 {
                out.push('\n');
            }
            out.push_str(&format!("[{name}]\n"));
            for (k, v) in table {
                out.push_str(&format!("{k} = \"{v}\"\n"));
            }
        }
        out
    }
}

pub fn parse(src: &str) -> OrbitToml {
    let mut t = OrbitToml::default();
    let mut current = String::new();
    for line in src.lines() {
        let line = strip_comment(line).trim();
        if line.is_empty() {
            continue;
        }
        if let Some(name) = line.strip_prefix('[').and_then(|s| s.strip_suffix(']')) {
            current = name.trim().to_string();
            if !t.sections.contains(&current) {
                t.sections.push(current.clone());
            }
            continue;
        }
        let Some((key, value)) = line.split_once('=') else { continue };
        let key = key.trim().to_string();
        let value = unquote(value.trim());
        match current.as_str() {
            "package" => { t.package.insert(key, value); }
            "orbs" => { t.orbs.insert(key, value); }
            _ => {}
        }
    }
    t
}

fn strip_comment(line: &str) -> &str {
    line.split_once('#').map(|(l, _)| l).unwrap_or(line)
}

fn unquote(s: &str) -> String {
    let s = s.trim();
    if s.len() >= 2 && (s.starts_with('"') && s.ends_with('"')) {
        s[1..s.len() - 1].to_string()
    } else {
        s.to_string()
    }
}
