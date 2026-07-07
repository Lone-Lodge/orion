//! `json` — JSON parse / stringify on top of Orion's built-in JSON. Bridges
//! `json::Value` to `value::Value`: objects become Maps, arrays become Lists,
//! numbers keep their int-vs-float distinction.

use crate::interp::Interp;
use crate::json;
use crate::value::Value;

pub const SOURCE: &str = include_str!("../../../orbs/json/lib.or");

pub fn register(_interp: &Interp) {
    // Both json_parse and json_stringify are now pure Orion. The
    // `crate::json` module stays for the LSP/orbit-internal JSON
    // round-trip but isn't exposed here as an extern.
}

#[allow(dead_code)] // kept for the day a host embedding wants to bridge json::Value back
fn json_to_orion(v: json::Value) -> Value {
    match v {
        json::Value::Null => Value::None,
        json::Value::Bool(b) => Value::Bool(b),
        json::Value::Int(n) => Value::Int(n),
        json::Value::Float(x) => Value::Float(x),
        json::Value::Str(s) => Value::Text(s),
        json::Value::Array(items) => Value::List(std::sync::Arc::new(items.into_iter().map(json_to_orion).collect())),
        json::Value::Object(pairs) => {
            let map: Vec<(Value, Value)> = pairs
                .into_iter()
                .map(|(k, v)| (Value::Text(k), json_to_orion(v)))
                .collect();
            Value::Map(std::sync::Arc::new(map))
        }
    }
}

#[allow(dead_code)]
fn orion_to_json(v: &Value) -> json::Value {
    match v {
        Value::Fact(_) | Value::None | Value::Unit => json::Value::Null,
        Value::Bool(b) => json::Value::Bool(*b),
        Value::Int(n) => json::Value::Int(*n),
        Value::Float(x) => json::Value::Float(*x),
        Value::Text(s) => json::Value::Str(s.clone()),
        Value::Closure { .. } | Value::Raw(_) | Value::Job(_) => json::Value::Null,
        Value::Packed(p) => json::Value::Int(p.widen()),
        Value::List(items) => json::Value::Array(items.iter().map(orion_to_json).collect()),
        Value::Map(pairs) => {
            let mut obj = json::Value::obj();
            for (k, v) in pairs.iter() {
                obj.insert(as_text(k), orion_to_json(v));
            }
            json::Value::Object(obj)
        }
        Value::Entity(id) => json::Value::Int(*id as i64),
        Value::Enum { variant, payload } => {
            let mut obj = json::Value::obj();
            obj.insert("variant".into(), json::Value::Str(variant.clone()));
            obj.insert(
                "payload".into(),
                json::Value::Array(payload.iter().map(orion_to_json).collect()),
            );
            json::Value::Object(obj)
        }
        // A `data`-typed value serialises as a plain object — same shape as a
        // Map. The `type_name` is dropped because JSON has no schema for it.
        Value::Data { fields, .. } => {
            let mut obj = json::Value::obj();
            for (k, v) in fields {
                obj.insert(k.clone(), orion_to_json(v));
            }
            json::Value::Object(obj)
        }
    }
}

#[allow(dead_code)]
fn as_text(v: &Value) -> String {
    match v {
        Value::Text(s) => s.clone(),
        other => other.to_string(),
    }
}
