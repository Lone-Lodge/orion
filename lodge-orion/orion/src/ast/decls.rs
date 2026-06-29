//! Top-level declarations and the pieces they're made of (params, fields).
//!
//! Each `*Decl` carries `file: u32` — the source file id it was declared in,
//! used by the checker to enforce cross-module privacy.

use super::{Expr, Stmt, Type};

#[derive(Clone, Debug, PartialEq)]
pub enum Decl {
    Data(DataDecl),
    Enum(EnumDecl),
    Fn(FnDecl),
    System(SystemDecl),
    Query(QueryDecl),
    /// `trait Name:` + indented method-signature list (§14).
    Trait(TraitDecl),
    /// `impl Trait for Data:` + indented method bodies (§14).
    Impl(ImplDecl),
}

/// `data Name: field: Type, …` — a row schema (columns), not a class.
#[derive(Clone, Debug, PartialEq)]
pub struct DataDecl {
    pub public: bool,
    /// §16 — `repr(c)` locks the field layout to C-compatible struct
    /// ordering, *opting out* of §5's layout polymorphism. Used for
    /// FFI: a `data Vec3 repr(c): x: f32, y: f32, z: f32` is binary-
    /// compatible with the corresponding C struct.
    pub repr_c: bool,
    /// §5 — explicit layout override. `data Pixel layout(soa): …`
    /// forces struct-of-arrays even if the compiler would pick AoS;
    /// `layout(packed)` requests bit-tight integer packing for
    /// range-typed fields. `LayoutHint::Auto` (the default) leaves it
    /// to the planner.
    pub layout: LayoutHint,
    pub name: String,
    pub fields: Vec<Field>,
    pub file: u32,
}

/// Spec section 19, "kvarvarande detaljbeslut": layout-override hint
/// syntax. The compiler still chooses by default; this only forces
/// the planner when you want fine control over the physical layout.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum LayoutHint {
    Auto,
    Soa,
    Aos,
    Packed,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Field {
    pub name: String,
    pub ty: Type,
}

/// `enum Shape:` + variants, each with an optional positional payload.
#[derive(Clone, Debug, PartialEq)]
pub struct EnumDecl {
    pub public: bool,
    pub name: String,
    pub variants: Vec<Variant>,
    pub file: u32,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Variant {
    pub name: String,
    pub payload: Vec<Type>,
}

/// `fn name(params) -> ret = expr`  or  `fn name(params):` + indented block.
#[derive(Clone, Debug, PartialEq)]
pub struct FnDecl {
    pub public: bool,
    /// §9: marked with the `deterministic` keyword. The checker forbids
    /// calls to non-deterministic helpers (random, time, fast-math)
    /// inside the body — guarantees lockstep-safe replay for netcode.
    pub deterministic: bool,
    pub name: String,
    /// Generic type parameters from `fn name<T, U>(...)`. Empty for
    /// non-generic fns. Names appearing here are treated as type variables
    /// in `params` and `ret` — substituted by the typechecker at call sites.
    pub generics: Vec<String>,
    pub params: Vec<Param>,
    pub ret: Option<Type>,
    pub body: FnBody,
    pub file: u32,
}

#[derive(Clone, Debug, PartialEq)]
pub enum FnBody {
    Expr(Expr),
    Block(Vec<Stmt>),
    /// `extern fn name(args) -> ret` — no body. The host registers an
    /// implementation by name via `Interp::register_extern`.
    Extern,
}

/// `system name(params):` + a block that runs over the world.
#[derive(Clone, Debug, PartialEq)]
pub struct SystemDecl {
    pub public: bool,
    /// §9 — same semantics as `FnDecl::deterministic` but for systems
    /// (typical use: lockstep-safe `physics_step`).
    pub deterministic: bool,
    /// §15 — explicit ordering hints. `system ai() before movement: …`
    /// → `before = ["movement"]`. Added to the conflict-graph edges the
    /// parallel scheduler builds from footprints, so a system can be
    /// pinned to a specific position even when its data is disjoint.
    pub before: Vec<String>,
    pub after: Vec<String>,
    pub name: String,
    pub params: Vec<Param>,
    pub body: Vec<Stmt>,
    pub file: u32,
}

/// `query name(params) -> ret = <comprehension>` — a named, planner-eligible
/// read over the world.
#[derive(Clone, Debug, PartialEq)]
pub struct QueryDecl {
    pub public: bool,
    pub name: String,
    pub params: Vec<Param>,
    pub ret: Option<Type>,
    pub body: Expr,
    pub file: u32,
}

/// `trait Name:` — a list of method signatures (no bodies). Each requirement
/// is a `FnDecl` whose body is `FnBody::Extern` (no body yet — bound by impls).
#[derive(Clone, Debug, PartialEq)]
pub struct TraitDecl {
    pub public: bool,
    pub name: String,
    pub methods: Vec<FnDecl>,
    pub file: u32,
}

/// `impl Trait for Data:` — the methods that fulfill `Trait` for `Data`. The
/// first parameter of every method is `self` (its type is implicit `Data`).
#[derive(Clone, Debug, PartialEq)]
pub struct ImplDecl {
    pub trait_name: String,
    pub for_type: String,
    pub methods: Vec<FnDecl>,
    pub file: u32,
}

/// `name`, `name: Type`, `name: mut Type`, or `name: Type = default`.
#[derive(Clone, Debug, PartialEq)]
pub struct Param {
    pub name: String,
    pub qualifier: Option<Qualifier>,
    pub ty: Option<Type>,
    pub default: Option<Expr>,
}

/// Parameter-passing convention. Read-only is the default (no keyword).
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Qualifier {
    /// `mut` — mutate the argument in place.
    Mut,
    /// `take` — consume / take ownership of the argument.
    Take,
}
