//! What a `view` yields: a host-agnostic tree of nodes — the read-side analogue
//! of `Effect` on the write side. The core names no UI; it hands the host a tree
//! of `(kind, args, children)` and the host maps it to whatever it draws with
//! (Atlas maps it to a Veil display list). Pure: identical `(view, by, args,
//! world)` yield an identical `Rendered`.

use crate::Value;

/// One node of a rendered view. `kind` is the node kind the author wrote
/// (`"surface"`, `"text"`, …); `args` are its evaluated arguments (roles,
/// content); `children` are the nodes nested under it.
#[derive(Clone, Debug, PartialEq)]
pub struct Rendered {
    pub kind: String,
    pub args: Vec<Value>,
    pub children: Vec<Rendered>,
}
