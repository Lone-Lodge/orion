//! The relational store — where entities live (M3).
//!
//! This is the in-memory world the engine queries. It is deliberately the
//! simplest thing that captures the model from ORION.md §5: an entity is a row, a
//! component (`data`) is a bag of named fields, and a query selects entities that
//! *have* a set of components. Atlas's design (EAV + columnar caches + reverse
//! indexes) is the production target; this is the readable starting point. Fast
//! columnar layout, archetypes and indexes come with M5.
//!
//! Every mutation also lands in `events` — the event log that powers §12
//! (replay / time-travel) and §13 (`added(X)` / `changed(X)` / `removed(X)`
//! change-detection filters). Cleared per tick by the engine driver.

use std::collections::HashMap;

use crate::value::Value;

/// A single component instance: its fields and their values.
pub type Component = HashMap<String, Value>;

/// One mutation to the world. The store accumulates a Vec of these so
/// reactive queries can ask "what changed since last tick?" without
/// re-scanning everything.
#[derive(Debug, Clone, PartialEq)]
pub enum Event {
    Spawned { id: u64, components: Vec<String> },
    Destroyed { id: u64 },
    ComponentAdded { id: u64, component: String },
    ComponentRemoved { id: u64, component: String },
    FieldSet { id: u64, component: String, field: String },
}

/// The world: a monotonic id counter and a table of entities, each holding a map
/// of component-name -> component.
#[derive(Default)]
pub struct Store {
    next: u64,
    entities: HashMap<u64, HashMap<String, Component>>,
    /// Append-only event log for the current tick. The engine clears this
    /// between ticks via `take_events` so `added(X)` / `changed(X)` /
    /// `removed(X)` see only this-tick deltas.
    events: Vec<Event>,
}

impl Store {
    pub fn new() -> Self {
        Store::default()
    }

    /// Create an entity carrying the given components; returns its id (a key).
    pub fn spawn(&mut self, components: HashMap<String, Component>) -> u64 {
        let id = self.next;
        self.next += 1;
        let comp_names: Vec<String> = components.keys().cloned().collect();
        self.entities.insert(id, components);
        self.events.push(Event::Spawned { id, components: comp_names });
        id
    }

    /// Retire an entity. A later lookup of a destroyed id simply misses.
    pub fn destroy(&mut self, id: u64) {
        if self.entities.remove(&id).is_some() {
            self.events.push(Event::Destroyed { id });
        }
    }

    /// Drain the event log — typically called by the engine driver at the
    /// start of each tick so per-tick reactive queries see a fresh slate.
    pub fn take_events(&mut self) -> Vec<Event> {
        std::mem::take(&mut self.events)
    }

    /// Read-only access for `added(X)` / `changed(X)` / `removed(X)`
    /// filters without consuming the log.
    pub fn events(&self) -> &[Event] {
        &self.events
    }

    /// Entities that GAINED `component` since the last tick. The order
    /// matches the event-log order (insertion order ≈ deterministic).
    pub fn added(&self, component: &str) -> Vec<u64> {
        self.events
            .iter()
            .filter_map(|e| match e {
                Event::Spawned { id, components } if components.iter().any(|c| c == component) => Some(*id),
                Event::ComponentAdded { id, component: c } if c == component => Some(*id),
                _ => None,
            })
            .collect()
    }

    /// Entities whose `component` had any field write since last tick.
    pub fn changed(&self, component: &str) -> Vec<u64> {
        use std::collections::BTreeSet;
        let mut ids: BTreeSet<u64> = BTreeSet::new();
        for e in &self.events {
            if let Event::FieldSet { id, component: c, .. } = e {
                if c == component {
                    ids.insert(*id);
                }
            }
        }
        ids.into_iter().collect()
    }

    /// Entities that LOST `component` since the last tick.
    pub fn removed(&self, component: &str) -> Vec<u64> {
        self.events
            .iter()
            .filter_map(|e| match e {
                Event::ComponentRemoved { id, component: c } if c == component => Some(*id),
                _ => None,
            })
            .collect()
    }

    /// Does this entity carry a given component? Used by `?.` to short-circuit.
    pub fn has_component(&self, id: u64, component: &str) -> bool {
        self.entities
            .get(&id)
            .map(|comps| comps.contains_key(component))
            .unwrap_or(false)
    }

    /// Read a whole component as `(field, value)` pairs — used by the
    /// Hylo/Val "take a local copy" pattern (`mut h = entity.Component`).
    pub fn get_component(&self, id: u64, component: &str) -> Option<Vec<(String, Value)>> {
        let comp = self.entities.get(&id)?.get(component)?;
        // Sort fields for stable iteration. Keeps interp output deterministic.
        let mut pairs: Vec<(String, Value)> = comp.iter().map(|(k, v)| (k.clone(), v.clone())).collect();
        pairs.sort_by(|a, b| a.0.cmp(&b.0));
        Some(pairs)
    }

    /// Read one field. `None` if the entity, component, or field is absent —
    /// a stale key is a missed lookup, not a crash (ORION.md §4).
    pub fn get_field(&self, id: u64, component: &str, field: &str) -> Option<Value> {
        self.entities
            .get(&id)?
            .get(component)?
            .get(field)
            .cloned()
    }

    /// Write one field. Returns false if the entity/component doesn't exist.
    pub fn set_field(&mut self, id: u64, component: &str, field: &str, value: Value) -> bool {
        match self
            .entities
            .get_mut(&id)
            .and_then(|comps| comps.get_mut(component))
        {
            Some(c) => {
                c.insert(field.to_string(), value);
                self.events.push(Event::FieldSet {
                    id,
                    component: component.to_string(),
                    field: field.to_string(),
                });
                true
            }
            None => false,
        }
    }

    /// Add a whole component to an entity that doesn't carry it yet.
    /// Logs `ComponentAdded` so `added(X)` can pick it up.
    pub fn add_component(&mut self, id: u64, name: &str, comp: Component) -> bool {
        match self.entities.get_mut(&id) {
            Some(comps) if !comps.contains_key(name) => {
                comps.insert(name.to_string(), comp);
                self.events.push(Event::ComponentAdded { id, component: name.to_string() });
                true
            }
            _ => false,
        }
    }

    /// Remove a component from an entity. Logs `ComponentRemoved` so
    /// `removed(X)` can pick it up.
    pub fn remove_component(&mut self, id: u64, name: &str) -> bool {
        let removed = self.entities
            .get_mut(&id)
            .map(|comps| comps.remove(name).is_some())
            .unwrap_or(false);
        if removed {
            self.events.push(Event::ComponentRemoved { id, component: name.to_string() });
        }
        removed
    }

    /// Every entity that has all the named components, in ascending id order
    /// (deterministic iteration — the basis for replay, ORION.md §9).
    pub fn with(&self, components: &[String]) -> Vec<u64> {
        let mut ids: Vec<u64> = self
            .entities
            .iter()
            .filter(|(_, comps)| components.iter().all(|c| comps.contains_key(c)))
            .map(|(id, _)| *id)
            .collect();
        ids.sort_unstable();
        ids
    }

    /// Pull every `Component.field` listed in `keys` into a parallel
    /// `Vec<f64>` per key, one row per matching entity. The row order matches
    /// `entities_for(keys)`, so the natively-compiled kernel can read/write
    /// these columns and the snapshot stays consistent.
    ///
    /// Non-numeric values stand in as `0.0` — the native kernel only handles
    /// `f64`; the interpreter still owns anything else.
    pub fn snapshot_columns(
        &self,
        components: &[String],
        keys: &[(String, String)],
    ) -> (Vec<u64>, Vec<Vec<f64>>) {
        let ids = self.with(components);
        let mut cols: Vec<Vec<f64>> = vec![Vec::with_capacity(ids.len()); keys.len()];
        for id in &ids {
            for (ki, (comp, field)) in keys.iter().enumerate() {
                let v = self
                    .get_field(*id, comp, field)
                    .map(|v| match v {
                        Value::Int(n) => n as f64,
                        Value::Float(x) => x,
                        Value::Bool(b) => if b { 1.0 } else { 0.0 },
                        _ => 0.0,
                    })
                    .unwrap_or(0.0);
                cols[ki].push(v);
            }
        }
        (ids, cols)
    }

    /// Mirror of `snapshot_columns`: write each `(component, field)` column
    /// back into the entities at the matching row id.
    pub fn writeback_columns(
        &mut self,
        ids: &[u64],
        keys: &[(String, String)],
        cols: &[Vec<f64>],
    ) {
        for (ki, (comp, field)) in keys.iter().enumerate() {
            let col = match cols.get(ki) {
                Some(c) => c,
                None => continue,
            };
            for (row, id) in ids.iter().enumerate() {
                if let Some(v) = col.get(row) {
                    // Pick int vs float by what the entity already holds; new
                    // fields default to float (the engine kernel's native type).
                    let existing = self.get_field(*id, comp, field);
                    let new = match existing {
                        Some(Value::Int(_)) => Value::Int(*v as i64),
                        _ => Value::Float(*v),
                    };
                    self.set_field(*id, comp, field, new);
                }
            }
        }
    }
}
