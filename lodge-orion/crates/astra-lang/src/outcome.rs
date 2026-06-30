//! What a run yields: the effects a rule proposes, and the orthogonal channels
//! the evaluator folds beside them. Only `effects` may be *committed* by a host;
//! the rest is pure metadata it reads or ignores. The shape grows by adding a
//! channel here — never by a new effect, never by IO — so one return type carries
//! every future read-side signal without breaking the callers again.

use crate::Effect;

/// The full result of evaluating a rule. `effects` is the proposal a host folds
/// into its log; `reads` is the dependency footprint it may key a cache on; and
/// `trace` is the decision path it may surface to explain the result. All three
/// are pure functions of `(by, args, world)` — identical inputs yield an identical
/// `Outcome` — and a host is free to ignore any channel it does not need.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Outcome {
    /// What the rule proposes: the writes and signals the host may commit.
    pub effects: Vec<Effect>,
    /// What the rule read from the world while deciding — never committed.
    pub reads: Reads,
    /// The decision path the rule took: each guard it weighed and each binding it
    /// formed, in order — pure diagnostics, most useful when `effects` is empty.
    pub trace: Vec<TraceEntry>,
}

impl Outcome {
    /// Fold another outcome in: effects appended in order, reads unioned, traces
    /// concatenated. This is how `dispatch` aggregates the fan-out across an
    /// event's handlers into one result — one proposal list, one merged dependency
    /// set, and one decision path read end to end.
    pub(crate) fn merge(&mut self, other: Outcome) {
        self.effects.extend(other.effects);
        self.reads.merge(other.reads);
        self.trace.extend(other.trace);
    }
}

/// A rule's dependency footprint: the fields it read and the kinds it enumerated.
/// A host that keys derived state on this re-runs the rule only when one of these
/// inputs changes — the derived-store seam, falling straight out of the reads the
/// evaluator already makes. Deduplicated, in first-touch order.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Reads {
    /// Each `(entity, field)` the rule read through `host.field`.
    pub fields: Vec<(u64, String)>,
    /// Each kind the rule enumerated through `all Kind` (`host.all`).
    pub kinds: Vec<String>,
}

impl Reads {
    pub(crate) fn record_field(&mut self, entity: u64, name: &str) {
        let pair = (entity, name.to_string());
        if !self.fields.contains(&pair) {
            self.fields.push(pair);
        }
    }

    pub(crate) fn record_kind(&mut self, kind: &str) {
        if !self.kinds.iter().any(|k| k == kind) {
            self.kinds.push(kind.to_string());
        }
    }

    fn merge(&mut self, other: Reads) {
        for (entity, name) in other.fields {
            self.record_field(entity, &name);
        }
        for kind in other.kinds {
            self.record_kind(&kind);
        }
    }
}

/// One step on a rule's decision path: the record of *why* it produced what it
/// did. A `Require` carries whether its guard held — a `false` is the silent no-op
/// made legible. A `Let` carries the name it bound and that value rendered. The
/// writes are deliberately absent: those are the effects, while the trace is the
/// reasoning that led to them — at its most useful when there are none.
#[derive(Clone, Debug, PartialEq)]
pub enum TraceEntry {
    /// A `require` guard was weighed; `passed` is whether evaluation continued.
    Require { passed: bool },
    /// A `let` bound `name` to `value`, rendered for display — never re-parsed.
    Let { name: String, value: String },
}
