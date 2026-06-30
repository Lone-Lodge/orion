//! The data the core computes over, and the effects it proposes. Both are owned
//! here, not borrowed from a host: `Ref` is an opaque `u64` handle the host
//! minted and understands (Atlas reads it as an `EntityId`), so the core needs
//! no host type to talk about entities. Absence is not a value — a field that
//! does not exist reads as `None`, the `empty` the rules compare against.

/// A single typed datum: what a field holds, what an expression evaluates to.
/// Four shapes, mirroring the host wire vocabulary but independent of it.
#[derive(Clone, Debug, PartialEq)]
pub enum Value {
    Int(i64),
    Text(String),
    Bool(bool),
    /// An opaque reference to a host entity — a handle, not the host's id type.
    Ref(u64),
}

/// What a rule proposes — the small, closed set of writes Astra can express. The
/// host folds each into one logged event (`Set` -> a field write, `Spawn` -> a
/// fresh entity, `Destroy` -> retiring one, `Emit` -> an event the host may feed
/// back to `on` handlers) and records THAT, never the run, so replay is exact.
/// There is no IO or mutation variant: the missing cases are the sandbox.
#[derive(Clone, Debug, PartialEq)]
pub enum Effect {
    /// Write one field on one entity: tic-tac-toe's whole move is a single `Set`.
    Set {
        entity: u64,
        field: String,
        value: Value,
    },
    /// Mint a fresh entity of a kind, carrying initial fields. The host allocates
    /// the id (the core never invents one), so the log is identical on replay.
    Spawn {
        kind: String,
        fields: Vec<(String, Value)>,
    },
    /// Retire an entity the host already knows — `Spawn`'s inverse. The core only
    /// names the id; what retiring means (tombstone, free, archive) is the host's.
    Destroy { entity: u64 },
    /// Announce that something happened, carrying named data. The core never acts
    /// on it: the host decides whether to feed it back to `on` handlers (via
    /// `dispatch`), so any cascade — and its termination — lives outside the rule.
    Emit {
        event: String,
        fields: Vec<(String, Value)>,
    },
}
