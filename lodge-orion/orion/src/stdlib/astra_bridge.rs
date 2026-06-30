//! `astra` — bridge Orion <-> the Astra rule language.
//!
//! Each extern compiles + runs Astra source and returns the proposed
//! effects as a list of `AstraEffect` structs (data type defined in the
//! orb's lib.or). Hosts fold these into their own effect log.
//!
//! The Host that Astra runs against is a thread-local stub for now —
//! field lookups return None, `all Kind` returns empty. Atlas-aware
//! reads land in a future revision once atlas_ecs exposes its store
//! through this bridge.

use crate::interp::Interp;
use crate::value::Value;
use astra::{Effect as AstraEffect, Host, Value as AstraValue, dispatch as astra_dispatch_fn, run as astra_run_fn};
use std::sync::Arc;

pub const SOURCE: &str = include_str!("../../../orbs/astra/lib.or");

struct StubHost;

impl Host for StubHost {
    fn field(&self, _entity: u64, _name: &str) -> Option<AstraValue> {
        None
    }
    fn all(&self, _kind: &str) -> Vec<u64> {
        Vec::new()
    }
}

pub fn register(interp: &Interp) {
    interp.register_extern("__os_astra_run_count", |args| {
        let source = match args.first() {
            Some(Value::Text(s)) => s.clone(),
            _ => return Ok(Value::Int(0)),
        };
        let rule = match args.get(1) {
            Some(Value::Text(s)) => s.clone(),
            _ => return Ok(Value::Int(0)),
        };
        let host = StubHost;
        match astra_run_fn(&source, &rule, 0, &[], &host) {
            Ok(outcome) => Ok(Value::Int(outcome.effects.len() as i64)),
            Err(e) => {
                eprintln!("[astra] run error: {e}");
                Ok(Value::Int(-1))
            }
        }
    });

    interp.register_extern("__os_astra_run", |args| {
        let source = match args.first() {
            Some(Value::Text(s)) => s.clone(),
            _ => return Ok(Value::List(Arc::new(Vec::new()))),
        };
        let rule = match args.get(1) {
            Some(Value::Text(s)) => s.clone(),
            _ => return Ok(Value::List(Arc::new(Vec::new()))),
        };
        let host = StubHost;
        match astra_run_fn(&source, &rule, 0, &[], &host) {
            Ok(outcome) => Ok(effects_to_value(&outcome.effects)),
            Err(e) => {
                eprintln!("[astra] run error: {e}");
                Ok(Value::List(Arc::new(Vec::new())))
            }
        }
    });

    interp.register_extern("__os_astra_dispatch_simple", |args| {
        let source = match args.first() {
            Some(Value::Text(s)) => s.clone(),
            _ => return Ok(Value::List(Arc::new(Vec::new()))),
        };
        let event = match args.get(1) {
            Some(Value::Text(s)) => s.clone(),
            _ => return Ok(Value::List(Arc::new(Vec::new()))),
        };
        let host = StubHost;
        match astra_dispatch_fn(&source, &event, 0, &[], &host) {
            Ok(outcome) => Ok(effects_to_value(&outcome.effects)),
            Err(e) => {
                eprintln!("[astra] dispatch error: {e}");
                Ok(Value::List(Arc::new(Vec::new())))
            }
        }
    });
}

fn effects_to_value(effects: &[AstraEffect]) -> Value {
    let list: Vec<Value> = effects.iter().map(effect_to_data).collect();
    Value::List(Arc::new(list))
}

/// Pack one Astra effect into the `AstraEffect` data struct defined in
/// orbs/astra/lib.or. Unused fields default to 0 / "" — Orion can read
/// them but only the kind-relevant ones carry data.
fn effect_to_data(eff: &AstraEffect) -> Value {
    let (kind, entity, field, value_text, kind_name, event, fnames, fvalues) = match eff {
        AstraEffect::Set { entity, field, value } => (
            "Set",
            *entity as i64,
            field.clone(),
            render_value(value),
            String::new(),
            String::new(),
            String::new(),
            String::new(),
        ),
        AstraEffect::Spawn { kind, fields } => (
            "Spawn",
            0,
            String::new(),
            String::new(),
            kind.clone(),
            String::new(),
            csv_names(fields),
            csv_values(fields),
        ),
        AstraEffect::Destroy { entity } => (
            "Destroy",
            *entity as i64,
            String::new(),
            String::new(),
            String::new(),
            String::new(),
            String::new(),
            String::new(),
        ),
        AstraEffect::Emit { event, fields } => (
            "Emit",
            0,
            String::new(),
            String::new(),
            String::new(),
            event.clone(),
            csv_names(fields),
            csv_values(fields),
        ),
    };
    Value::Data {
        type_name: "AstraEffect".into(),
        fields: vec![
            ("kind".into(), Value::Text(kind.into())),
            ("entity".into(), Value::Int(entity)),
            ("field".into(), Value::Text(field)),
            ("value_text".into(), Value::Text(value_text)),
            ("kind_name".into(), Value::Text(kind_name)),
            ("event".into(), Value::Text(event)),
            ("field_names_csv".into(), Value::Text(fnames)),
            ("field_values_csv".into(), Value::Text(fvalues)),
        ],
    }
}

fn render_value(v: &AstraValue) -> String {
    match v {
        AstraValue::Int(n) => n.to_string(),
        AstraValue::Text(s) => s.clone(),
        AstraValue::Bool(b) => b.to_string(),
        AstraValue::Ref(id) => id.to_string(),
    }
}

fn csv_names(pairs: &[(String, AstraValue)]) -> String {
    pairs.iter().map(|(n, _)| n.clone()).collect::<Vec<_>>().join(",")
}

fn csv_values(pairs: &[(String, AstraValue)]) -> String {
    pairs.iter().map(|(_, v)| render_value(v)).collect::<Vec<_>>().join(",")
}
