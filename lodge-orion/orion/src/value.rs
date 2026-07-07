//! Runtime values — what the interpreter computes with.
//!
//! M2 had the four scalars. M3 adds `Entity` (a key into the relational store —
//! ORION.md §4: refs are keys, not pointers) and `List` (the result of a query
//! comprehension).

use std::collections::HashMap;
use std::fmt;
use std::sync::Arc;

use crate::ast::Expr;

impl Value {
    /// Return the integer value of this `Value` as `i64`, widening from
    /// any packed variant or `Int`. Returns `None` for non-integer
    /// values (Float, Bool, Text, etc.). This is the helper every
    /// arithmetic / comparison site should use — keeps match arms tight
    /// when new narrow variants land.
    pub fn as_int(&self) -> Option<i64> {
        match self {
            Value::Int(n) => Some(*n),
            Value::Packed(p) => Some(p.widen()),
            _ => None,
        }
    }
}

/// A narrow integer the store can pack into less than 8 bytes. Created
/// by `set_field` when the field's declared type is a range that fits
/// — `0...255` → `U8`, `0...1000` → `U16`, etc. Arithmetic widens to
/// `Value::Int(i64)` automatically; `set_field` re-packs on write.
///
/// §8 of ORION.md — the `data Pixel: r: 0...255` field stores as `u8`,
/// not `i64`, when wrapped in a `PackedInt`.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum PackedInt {
    U8(u8), U16(u16), U32(u32),
    I8(i8), I16(i16), I32(i32),
}

impl PackedInt {
    pub fn widen(&self) -> i64 {
        match self {
            PackedInt::U8(n) => *n as i64,
            PackedInt::U16(n) => *n as i64,
            PackedInt::U32(n) => *n as i64,
            PackedInt::I8(n) => *n as i64,
            PackedInt::I16(n) => *n as i64,
            PackedInt::I32(n) => *n as i64,
        }
    }
    pub fn kind(&self) -> &'static str {
        match self {
            PackedInt::U8(_) => "u8",
            PackedInt::U16(_) => "u16",
            PackedInt::U32(_) => "u32",
            PackedInt::I8(_) => "i8",
            PackedInt::I16(_) => "i16",
            PackedInt::I32(_) => "i32",
        }
    }
    /// Storage bytes used by this variant.
    pub fn bytes(&self) -> usize {
        match self {
            PackedInt::U8(_) | PackedInt::I8(_) => 1,
            PackedInt::U16(_) | PackedInt::I16(_) => 2,
            PackedInt::U32(_) | PackedInt::I32(_) => 4,
        }
    }
    /// Pack an `i64` into the smallest variant that fits the declared
    /// range `[lo, hi]`. Returns `None` if the value is out of range
    /// (the caller already validated; this is paranoia).
    pub fn pack_for_range(value: i64, lo: i64, hi: i64) -> Option<PackedInt> {
        if value < lo || value > hi { return None; }
        if lo >= 0 {
            if hi <= u8::MAX as i64 { return Some(PackedInt::U8(value as u8)); }
            if hi <= u16::MAX as i64 { return Some(PackedInt::U16(value as u16)); }
            if hi <= u32::MAX as i64 { return Some(PackedInt::U32(value as u32)); }
        } else {
            if lo >= i8::MIN as i64 && hi <= i8::MAX as i64 { return Some(PackedInt::I8(value as i8)); }
            if lo >= i16::MIN as i64 && hi <= i16::MAX as i64 { return Some(PackedInt::I16(value as i16)); }
            if lo >= i32::MIN as i64 && hi <= i32::MAX as i64 { return Some(PackedInt::I32(value as i32)); }
        }
        None
    }
}

#[derive(Clone, Debug, PartialEq)]
pub enum Value {
    /// A lazy derived binding created by `fact name = expr`. Held in the env
    /// under `name`; `eval_var` re-evaluates the expr in the current scope on
    /// every read, so a fact never escapes into general computation.
    Fact(Arc<crate::ast::Expr>),
    Int(i64),
    /// §8 packed-int storage — `Value::Packed(PackedInt::U8(200))` is
    /// stored as one byte but participates in arithmetic as `i64`.
    Packed(PackedInt),
    Float(f64),
    Bool(bool),
    Text(String),
    /// A handle into the store. Following it is a lookup, never a pointer deref.
    Entity(u64),
    /// The result of a `[expr for e with C]` comprehension.
    /// Arc-shared, clone-on-write — same rationale as Map (eval_var clones).
    List(Arc<Vec<Value>>),
    /// An enum value: a variant name and its payload.
    Enum {
        variant: String,
        payload: Vec<Value>,
    },
    /// A map, stored as insertion-ordered key/value pairs.
    ///
    /// Arc-shared so cloning a Value::Map is a refcount bump, not a full
    /// deep clone of every (k, v) pair. Mutations go through Arc::make_mut
    /// (clone-on-write — only pays a real clone when the map is shared).
    /// This is the single biggest perf lever in the interpreter: `eval_var`
    /// does `env.get(name).cloned()` on every variable access, and a parser
    /// touching `token.kind` would otherwise deep-clone the whole token map
    /// every time. Refcount bump = O(1) instead of O(N).
    Map(Arc<Vec<(Value, Value)>>),
    /// A `data`-typed value carrying its declared type name so method calls
    /// (§14) can dispatch to the right `impl`. Fields are insertion-ordered.
    Data {
        type_name: String,
        fields: Vec<(String, Value)>,
    },
    /// A closure — anonymous fn that captured its enclosing environment
    /// at the moment it was evaluated. `Arc`-shared so the closure can
    /// be sent across threads (foundation for `parallel for` — the body
    /// + captured env need to cross thread boundaries safely).
    Closure {
        params: Vec<String>,
        body: Arc<Expr>,
        captured: Arc<HashMap<String, Value>>,
    },
    /// A raw byte pointer/handle for FFI use — opaque integer addressing
    /// memory the host owns. Manipulated only inside `raw:` blocks.
    Raw(u64),
    /// A handle returned by `spawn job EXPR`. `.await` unwraps it.
    /// Today the work runs immediately at spawn time (sequential
    /// model); after Phase C this becomes a real `Future`-equivalent.
    Job(Arc<Value>),
    /// The absent optional value.
    None,
    Unit,
}

impl fmt::Display for Value {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Value::Fact(_) => write!(f, "<fact>"),
            Value::Int(n) => write!(f, "{n}"),
            Value::Packed(p) => write!(f, "{}", p.widen()),
            Value::Float(x) => write!(f, "{x}"),
            Value::Bool(b) => write!(f, "{b}"),
            Value::Text(s) => write!(f, "{s}"),
            Value::Entity(id) => write!(f, "entity#{id}"),
            Value::List(items) => {
                write!(f, "[")?;
                for (i, v) in items.iter().enumerate() {
                    if i > 0 {
                        write!(f, ", ")?;
                    }
                    write!(f, "{v}")?;
                }
                write!(f, "]")
            }
            Value::Closure { params, .. } => write!(f, "<fn({})>", params.join(", ")),
            Value::Raw(addr) => write!(f, "raw#{addr:#x}"),
            Value::Job(inner) => write!(f, "<job → {}>", inner),
            Value::Enum { variant, payload } => {
                write!(f, "{variant}")?;
                if !payload.is_empty() {
                    write!(f, "(")?;
                    for (i, v) in payload.iter().enumerate() {
                        if i > 0 {
                            write!(f, ", ")?;
                        }
                        write!(f, "{v}")?;
                    }
                    write!(f, ")")?;
                }
                Ok(())
            }
            Value::Map(pairs) => {
                write!(f, "{{")?;
                for (i, (k, v)) in pairs.iter().enumerate() {
                    if i > 0 {
                        write!(f, ", ")?;
                    }
                    write!(f, "{k}: {v}")?;
                }
                write!(f, "}}")
            }
            Value::Data { type_name, fields } => {
                write!(f, "{type_name} {{")?;
                for (i, (k, v)) in fields.iter().enumerate() {
                    if i > 0 {
                        write!(f, ", ")?;
                    }
                    write!(f, "{k}: {v}")?;
                }
                write!(f, "}}")
            }
            Value::None => write!(f, "none"),
            Value::Unit => write!(f, "()"),
        }
    }
}
