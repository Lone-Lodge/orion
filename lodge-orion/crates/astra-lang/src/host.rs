//! The seam — everything the core cannot do for itself. A pure evaluator still
//! has to read a world and find imported source; it does both through these two
//! traits and nothing else. Atlas implements them over its `Store` and Code
//! bucket; a web or Unreal embedding implements the same methods over its own
//! world. This file is the whole of what "host-agnostic" means in practice.

use crate::Value;

/// The world as the core may read it — read-only. The core never writes here; it
/// proposes `Effect`s the host folds. Two windows are enough for a rule: one
/// field, and every entity of a kind (what `all Cell` iterates before folding a
/// predicate over the handles).
pub trait Host {
    /// One field on one entity, or `None` when absent (`empty`).
    fn field(&self, entity: u64, name: &str) -> Option<Value>;

    /// Every entity handle of a kind — the host owns the index; the core only
    /// counts or filters what it returns.
    fn all(&self, kind: &str) -> Vec<u64>;

    /// A host-registered builtin call (atlas-i18n's `t`, atlas-math's `max`).
    /// Returns `None` when the name is unknown — the eval surfaces that as a
    /// `RunError`. Default `None` keeps existing hosts (no builtins) working.
    fn call(&self, _name: &str, _args: &[Value]) -> Option<Value> {
        None
    }
}

/// Module resolution: a name -> its source. The language defines `import`; where
/// the source lives is the host's call. Atlas resolves a name to a file in the
/// Project's Code bucket; a future content-addressed registry would resolve it to
/// source by hash — same import, swappable resolver, no dependency hell. Reserved:
/// Slice 1's `place_mark` is one self-contained module and resolves nothing.
pub trait Resolver {
    /// The source of a named module, or `None` when it cannot be found.
    fn resolve(&self, module: &str) -> Option<String>;
}
