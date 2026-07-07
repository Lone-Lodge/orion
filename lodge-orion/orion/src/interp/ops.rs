//! Pure operations on runtime values — arithmetic, comparison, equality.

use super::{RunError, run_err};
use crate::ast::{AssignOp, BinOp};
use crate::value::Value;

pub(super) fn assign_binop(op: AssignOp) -> BinOp {
    match op {
        AssignOp::Add => BinOp::Add,
        AssignOp::Sub => BinOp::Sub,
        AssignOp::Set => unreachable!("Set is handled without a binary op"),
    }
}

pub(super) fn as_f64(v: &Value) -> Option<f64> {
    match v {
        Value::Int(n) => Some(*n as f64),
        Value::Packed(p) => Some(p.widen() as f64),
        Value::Float(x) => Some(*x),
        _ => None,
    }
}

pub(crate) fn apply_binary(op: BinOp, a: Value, b: Value) -> Result<Value, RunError> {
    use BinOp::*;
    match op {
        Add | Sub | Mul | Div | Rem => arithmetic(op, a, b),
        Lt | Le | Gt | Ge => compare(op, &a, &b),
        Eq => Ok(Value::Bool(values_equal(&a, &b))),
        Ne => Ok(Value::Bool(!values_equal(&a, &b))),
        BitOr | BitXor | BitAnd | Shl | Shr => bitwise(op, &a, &b),
        And | Or => unreachable!("and/or are short-circuited in eval"),
    }
}

fn bitwise(op: BinOp, a: &Value, b: &Value) -> Result<Value, RunError> {
    // §8 — same widen path as int_arithmetic. Packed → i64 → result.
    let (x, y) = match (a.as_int(), b.as_int()) {
        (Some(x), Some(y)) => (x, y),
        _ => return Err(run_err(format!("bitwise operator requires int, got {a:?} and {b:?}"))),
    };
    use BinOp::*;
    Ok(Value::Int(match op {
        BitOr => x | y,
        BitXor => x ^ y,
        BitAnd => x & y,
        Shl => x.wrapping_shl(y as u32),
        Shr => x.wrapping_shr(y as u32),
        _ => unreachable!(),
    }))
}

fn arithmetic(op: BinOp, a: Value, b: Value) -> Result<Value, RunError> {
    if let Some(v) = int_arithmetic(op, &a, &b)? {
        return Ok(v);
    }
    if let Some(v) = float_arithmetic(op, &a, &b) {
        return Ok(v);
    }
    if let (BinOp::Add, Value::Text(x), Value::Text(y)) = (op, &a, &b) {
        return Ok(Value::Text(format!("{x}{y}")));
    }
    Err(run_err(format!("cannot apply {op:?} to {a:?} and {b:?}")))
}

fn int_arithmetic(op: BinOp, a: &Value, b: &Value) -> Result<Option<Value>, RunError> {
    // §8 — packed-int variants widen to i64 for arithmetic. The result
    // comes back as plain `Value::Int(i64)`; the store re-packs to the
    // narrower type when assigned to a range-typed field.
    let (x, y) = match (a.as_int(), b.as_int()) {
        (Some(x), Some(y)) => (x, y),
        _ => return Ok(None),
    };
    // Wrapping semantics — algorithm code (FNV-1a primes, SHA-256 mixing,
    // counter rollover) relies on modular int math. The JIT already wraps;
    // matching here means tolk and JIT produce identical bits.
    Ok(Some(match op {
        BinOp::Add => Value::Int(x.wrapping_add(y)),
        BinOp::Sub => Value::Int(x.wrapping_sub(y)),
        BinOp::Mul => Value::Int(x.wrapping_mul(y)),
        BinOp::Div if y == 0 => return Err(run_err("integer division by zero")),
        BinOp::Rem if y == 0 => return Err(run_err("integer remainder by zero")),
        BinOp::Div => Value::Int(x.wrapping_div(y)),
        BinOp::Rem => Value::Int(x.wrapping_rem(y)),
        _ => unreachable!(),
    }))
}

fn float_arithmetic(op: BinOp, a: &Value, b: &Value) -> Option<Value> {
    let (x, y) = (as_f64(a)?, as_f64(b)?);
    Some(match op {
        BinOp::Add => Value::Float(x + y),
        BinOp::Sub => Value::Float(x - y),
        BinOp::Mul => Value::Float(x * y),
        BinOp::Div => Value::Float(x / y),
        BinOp::Rem => Value::Float(x % y),
        _ => unreachable!(),
    })
}

fn compare(op: BinOp, a: &Value, b: &Value) -> Result<Value, RunError> {
    let (Some(x), Some(y)) = (as_f64(a), as_f64(b)) else {
        return Err(run_err(format!("cannot compare {a:?} and {b:?}")));
    };
    Ok(Value::Bool(match op {
        BinOp::Lt => x < y,
        BinOp::Le => x <= y,
        BinOp::Gt => x > y,
        BinOp::Ge => x >= y,
        _ => unreachable!(),
    }))
}

pub(super) fn values_equal(a: &Value, b: &Value) -> bool {
    if let (Some(x), Some(y)) = (as_f64(a), as_f64(b)) {
        return x == y;
    }
    a == b
}
