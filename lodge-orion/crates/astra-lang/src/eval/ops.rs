//! The value operations the evaluator leans on: conversions to and from the host
//! `Value`, the runtime type checks (`as_bool`/`as_ref`/`as_list`/`as_int`), and
//! the unary/binary operators. Equality spans every shape — including `empty`, so
//! `cell.mark == empty` is just `Val::Empty == Val::Empty`. Integer arithmetic is
//! checked, so overflow and division by zero are errors, never panics.

use super::{RunError, Val, run_error};
use crate::Value;
use crate::ast::{BinOp, UnOp};

pub(super) fn from_value(v: &Value) -> Val {
    match v {
        Value::Int(n) => Val::Int(*n),
        Value::Text(s) => Val::Text(s.clone()),
        Value::Bool(b) => Val::Bool(*b),
        Value::Ref(id) => Val::Ref(*id),
    }
}

pub(super) fn to_value(v: Val) -> Result<Value, RunError> {
    match v {
        Val::Int(n) => Ok(Value::Int(n)),
        Val::Text(s) => Ok(Value::Text(s)),
        Val::Bool(b) => Ok(Value::Bool(b)),
        Val::Ref(id) => Ok(Value::Ref(id)),
        Val::Empty => Err(run_error("cannot store `empty` in a field")),
        Val::List(_) => Err(run_error("cannot store a list in a field")),
    }
}

pub(super) fn as_bool(v: Val) -> Result<bool, RunError> {
    match v {
        Val::Bool(b) => Ok(b),
        other => Err(run_error(format!("expected a boolean, found {other:?}"))),
    }
}

pub(super) fn as_ref(v: Val) -> Result<u64, RunError> {
    match v {
        Val::Ref(id) => Ok(id),
        other => Err(run_error(format!(
            "expected an entity reference, found {other:?}"
        ))),
    }
}

pub(super) fn as_list(v: Val) -> Result<Vec<u64>, RunError> {
    match v {
        Val::List(ids) => Ok(ids),
        other => Err(run_error(format!("expected a list, found {other:?}"))),
    }
}

/// Render a value for a trace — display only, never parsed back. Mirrors the host
/// notation: `#7` for a ref, `empty` for absence, `[#1, #2]` for a list, quoted
/// text, plain ints and bools.
pub(super) fn show(v: &Val) -> String {
    match v {
        Val::Int(n) => n.to_string(),
        Val::Text(s) => format!("{s:?}"),
        Val::Bool(b) => b.to_string(),
        Val::Ref(id) => format!("#{id}"),
        Val::Empty => "empty".to_string(),
        Val::List(ids) => {
            let items = ids
                .iter()
                .map(|id| format!("#{id}"))
                .collect::<Vec<_>>()
                .join(", ");
            format!("[{items}]")
        }
    }
}

fn as_int(v: Val) -> Result<i64, RunError> {
    match v {
        Val::Int(n) => Ok(n),
        other => Err(run_error(format!("expected an integer, found {other:?}"))),
    }
}

pub(super) fn unary(op: UnOp, v: Val) -> Result<Val, RunError> {
    match op {
        UnOp::Not => Ok(Val::Bool(!as_bool(v)?)),
        UnOp::Neg => Ok(Val::Int(-as_int(v)?)),
    }
}

pub(super) fn binary(op: BinOp, a: Val, b: Val) -> Result<Val, RunError> {
    use BinOp::*;
    match op {
        Eq => Ok(Val::Bool(a == b)),
        Ne => Ok(Val::Bool(a != b)),
        // `and`/`or` overload on lists as set intersection/union, so the natural
        // graph query reads `all animal and hostile`. The lists come from `all`
        // exprs (kind or tag membership); the operators compose them. On bools
        // they keep the usual short-form logical meaning.
        And => match (a, b) {
            (Val::List(x), Val::List(y)) => Ok(Val::List(intersect(x, y))),
            (a, b) => Ok(Val::Bool(as_bool(a)? && as_bool(b)?)),
        },
        Or => match (a, b) {
            (Val::List(x), Val::List(y)) => Ok(Val::List(union(x, y))),
            (a, b) => Ok(Val::Bool(as_bool(a)? || as_bool(b)?)),
        },
        Lt | Le | Gt | Ge => Ok(Val::Bool(compare(op, as_int(a)?, as_int(b)?))),
        Add => match (&a, &b) {
            // Either side Text => concatenation. The other side renders the same
            // way it shows in a `text` view element, so an int counter folds in
            // naturally: `"Day " + by.days_survived` -> `"Day 3"`.
            (Val::Text(_), _) | (_, Val::Text(_)) => Ok(Val::Text(format!("{}{}", as_text(&a), as_text(&b)))),
            _ => Ok(Val::Int(arith(op, as_int(a)?, as_int(b)?)?)),
        },
        Sub | Mul | Div | Rem => Ok(Val::Int(arith(op, as_int(a)?, as_int(b)?)?)),
    }
}

/// Render a runtime value the way a `text` view element would — the form the
/// `+` operator uses when one side is Text. Empty renders blank, refs render
/// `#id`, lists render as their length (the only sensible scalar shape).
fn as_text(v: &Val) -> String {
    match v {
        Val::Int(n) => n.to_string(),
        Val::Text(s) => s.clone(),
        Val::Bool(b) => b.to_string(),
        Val::Ref(id) => format!("#{id}"),
        Val::Empty => String::new(),
        Val::List(xs) => xs.len().to_string(),
    }
}

/// Intersect two id lists (ascending input from `host.all`), keeping ascending
/// order so query results are deterministic. Linear in the shorter list.
fn intersect(mut a: Vec<u64>, mut b: Vec<u64>) -> Vec<u64> {
    if a.len() > b.len() {
        std::mem::swap(&mut a, &mut b);
    }
    let set: std::collections::BTreeSet<u64> = b.into_iter().collect();
    a.into_iter().filter(|id| set.contains(id)).collect()
}

/// Union of two ascending id lists, deduplicated, ascending.
fn union(a: Vec<u64>, b: Vec<u64>) -> Vec<u64> {
    let mut set: std::collections::BTreeSet<u64> = a.into_iter().collect();
    set.extend(b);
    set.into_iter().collect()
}

fn compare(op: BinOp, a: i64, b: i64) -> bool {
    match op {
        BinOp::Lt => a < b,
        BinOp::Le => a <= b,
        BinOp::Gt => a > b,
        BinOp::Ge => a >= b,
        _ => unreachable!("compare only handles the four orderings"),
    }
}

fn arith(op: BinOp, a: i64, b: i64) -> Result<i64, RunError> {
    let r = match op {
        BinOp::Add => a.checked_add(b),
        BinOp::Sub => a.checked_sub(b),
        BinOp::Mul => a.checked_mul(b),
        BinOp::Div if b != 0 => a.checked_div(b),
        BinOp::Rem if b != 0 => a.checked_rem(b),
        BinOp::Div | BinOp::Rem => None,
        _ => unreachable!("arith only handles the five integer operators"),
    };
    r.ok_or_else(|| run_error("integer overflow or division by zero"))
}
