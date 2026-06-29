//! A tiny JSON parser/encoder — just what `orion-lsp` needs to read LSP
//! messages without dragging in serde. Round-trips through `parse` → `to_string`.
//! The encoder writes one compact line per value — what LSP expects over stdio.

mod parse;
mod write;

use std::collections::BTreeMap;

pub use parse::parse;

#[derive(Clone, Debug, PartialEq)]
pub enum Value {
    Null,
    Bool(bool),
    /// LSP integers fit in i64; we never see fractional ids/positions.
    Int(i64),
    Float(f64),
    Str(String),
    Array(Vec<Value>),
    /// `BTreeMap` keeps keys in stable order — nicer diffs when an editor
    /// echoes back what we sent.
    Object(BTreeMap<String, Value>),
}

impl Value {
    pub fn obj() -> BTreeMap<String, Value> {
        BTreeMap::new()
    }

    pub fn get(&self, key: &str) -> Option<&Value> {
        if let Value::Object(m) = self { m.get(key) } else { None }
    }

    pub fn as_str(&self) -> Option<&str> {
        if let Value::Str(s) = self { Some(s.as_str()) } else { None }
    }

    pub fn as_int(&self) -> Option<i64> {
        match self {
            Value::Int(n) => Some(*n),
            Value::Float(x) => Some(*x as i64),
            _ => None,
        }
    }

    pub fn to_string(&self) -> String {
        let mut out = String::new();
        write::write(self, &mut out);
        out
    }
}
