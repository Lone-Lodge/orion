//! The static type vocabulary — what the checker assigns to every expression and
//! the surface a `record` refines. Small on purpose, mirroring the value universe:
//! the four data shapes, the two the evaluator needs (`List`, `Empty`), and one
//! gradual seam (`Unknown`) for the world boundary. No `any`: `Unknown` is produced
//! only by a field read on an unmodelled kind, never written by an author, and is
//! narrowed away the moment a `record` declares a kind's fields.
//!
//! A `Ref` and a `List` carry the *kind* they are of (`Some("Cell")`), or `None`
//! when it is not known — `by`, an unannotated parameter, or two kinds unified.
//! Carrying the kind is what lets `cell.mark` type against `record Cell`. The kind
//! makes the type non-`Copy`; it stays `Clone`, threaded by reference.

/// The type of an Astra expression.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Type {
    /// A 64-bit integer — every number literal and all arithmetic.
    Int,
    /// A text string.
    Text,
    /// A boolean — what a `require`, `where`, and `if` condition must be.
    Bool,
    /// A reference to a host entity of a kind — `Some("Cell")` once a parameter or
    /// `count` binding names it, `None` when the kind is unknown (`by`, an
    /// unannotated param). The kind keys field reads against a `record`.
    Ref(Option<String>),
    /// A list of entity handles of a kind — what `all Kind` yields (`Some(kind)`)
    /// and `count` folds over. The kind flows to the bound row.
    List(Option<String>),
    /// The type of the `empty` literal: absence. Comparable to any type with
    /// `==`/`!=`, storable in no field.
    Empty,
    /// The world boundary: the type of a field read on a kind no `record` models.
    /// Satisfies any expectation and unifies with any type — the one gradual seam,
    /// removed for a kind the moment a `record` gives its fields a declared type.
    Unknown,
}

impl std::fmt::Display for Type {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Type::Int => f.write_str("Int"),
            Type::Text => f.write_str("Text"),
            Type::Bool => f.write_str("Bool"),
            Type::Ref(Some(kind)) => f.write_str(kind),
            Type::Ref(None) => f.write_str("Ref"),
            Type::List(_) => f.write_str("List"),
            Type::Empty => f.write_str("empty"),
            Type::Unknown => f.write_str("unknown"),
        }
    }
}
