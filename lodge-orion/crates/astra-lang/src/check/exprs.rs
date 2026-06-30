//! Expression typing — the `type_of` fold the statement checker leans on. Every
//! node's type is read from its shape and operands; a field read narrows against
//! the `record` schema, or yields the gradual `Unknown` when the kind is unknown or
//! unmodelled. The `Type` carries a kind but is not `Copy`, so the helpers borrow.

use super::records::Records;
use super::{CheckError, err};
use crate::ast::{BinOp, Expr, UnOp};
use crate::types::Type;

pub(super) fn type_of(
    expr: &Expr,
    scope: &[(String, Type)],
    records: &Records,
) -> Result<Type, CheckError> {
    match expr {
        Expr::Int(_) => Ok(Type::Int),
        Expr::Str(_) => Ok(Type::Text),
        Expr::Bool(_) => Ok(Type::Bool),
        Expr::Empty => Ok(Type::Empty),
        Expr::Var(name) => lookup(scope, name),
        Expr::Field { base, name } => match type_of(base, scope, records)? {
            Type::Ref(Some(kind)) => records.field_read(&kind, name),
            Type::Ref(None) | Type::Unknown => Ok(Type::Unknown),
            other => err(format!("`.{name}` needs an entity, found {other}")),
        },
        Expr::Unary { op, rhs } => {
            let t = type_of(rhs, scope, records)?;
            match op {
                UnOp::Not => expect(&t, Type::Bool, "not").map(|_| Type::Bool),
                UnOp::Neg => expect(&t, Type::Int, "-").map(|_| Type::Int),
            }
        }
        Expr::Binary { op, lhs, rhs } => {
            let (l, r) = (type_of(lhs, scope, records)?, type_of(rhs, scope, records)?);
            type_binary(*op, &l, &r)
        }
        Expr::If {
            cond,
            then,
            otherwise,
        } => {
            expect(&type_of(cond, scope, records)?, Type::Bool, "if")?;
            let (t, e) = (
                type_of(then, scope, records)?,
                type_of(otherwise, scope, records)?,
            );
            unify(&t, &e).ok_or_else(|| CheckError {
                message: format!("if branches disagree: {t} vs {e}"),
            })
        }
        Expr::All { kind } => Ok(Type::List(Some(kind.clone()))),
        Expr::Count {
            var,
            source,
            filter,
        } => {
            let elem = match type_of(source, scope, records)? {
                Type::List(elem) => elem,
                other => return err(format!("count expects a list, found {other}")),
            };
            if let Some(f) = filter {
                let mut inner = scope.to_vec();
                inner.push((var.clone(), Type::Ref(elem)));
                expect(&type_of(f, &inner, records)?, Type::Bool, "where")?;
            }
            Ok(Type::Int)
        }
        // A host-builtin call — its arguments must typecheck, but the return
        // is gradual. Plugins know their own signatures; the language stays
        // out of it. Same seam as a record-less Field read.
        Expr::Call { args, .. } => {
            for arg in args {
                type_of(arg, scope, records)?;
            }
            Ok(Type::Unknown)
        }
    }
}

/// Type an infix operator from its operands, mirroring the evaluator's `binary`:
/// `==`/`!=` over comparable shapes, the logical pair over `Bool`, the orderings
/// and arithmetic over `Int`.
fn type_binary(op: BinOp, a: &Type, b: &Type) -> Result<Type, CheckError> {
    use BinOp::*;
    match op {
        Eq | Ne if comparable(a, b) => Ok(Type::Bool),
        Eq | Ne => err(format!("cannot compare {a} with {b}")),
        And | Or => match (a, b) {
            // List-on-list: set intersection / union — `all foo and all bar`.
            (Type::List(x), Type::List(y)) => {
                Ok(Type::List(if x == y { x.clone() } else { None }))
            }
            _ => {
                expect(a, Type::Bool, "`and`/`or`")?;
                expect(b, Type::Bool, "`and`/`or`").map(|_| Type::Bool)
            }
        },
        Lt | Le | Gt | Ge => {
            expect(a, Type::Int, "comparison")?;
            expect(b, Type::Int, "comparison").map(|_| Type::Bool)
        }
        Add => {
            // `+` is overloaded: a *known* Text on either side concatenates (the
            // other side renders the same way a `text` element would). Unknown
            // stays gradual — it defers to runtime, the same as for arithmetic,
            // so `by.tick_of_day + 1` still flows through subsequent Int ops.
            match (a, b) {
                (Type::Text, _) | (_, Type::Text) => Ok(Type::Text),
                _ => {
                    expect(a, Type::Int, "arithmetic")?;
                    expect(b, Type::Int, "arithmetic").map(|_| Type::Int)
                }
            }
        }
        Sub | Mul | Div | Rem => {
            expect(a, Type::Int, "arithmetic")?;
            expect(b, Type::Int, "arithmetic").map(|_| Type::Int)
        }
    }
}

/// `==`/`!=` are total at runtime; statically we still refuse the nonsense ones,
/// but `empty` compares with anything (presence tests), `Unknown` defers, and two
/// references compare whatever their kinds (handles are interchangeable).
fn comparable(a: &Type, b: &Type) -> bool {
    use Type::*;
    matches!(
        (a, b),
        (Unknown, _) | (_, Unknown) | (Empty, _) | (_, Empty) | (Ref(_), Ref(_))
    ) || a == b
}

/// The least type both branches inhabit: equal types as themselves, `Unknown`
/// yielding to the other, two kinds widening to a kindless ref or list. `None` when
/// they genuinely disagree.
fn unify(a: &Type, b: &Type) -> Option<Type> {
    use Type::*;
    match (a, b) {
        (Unknown, t) | (t, Unknown) => Some(t.clone()),
        (Ref(x), Ref(y)) => Some(Ref(if x == y { x.clone() } else { None })),
        (List(x), List(y)) => Some(List(if x == y { x.clone() } else { None })),
        _ if a == b => Some(a.clone()),
        _ => None,
    }
}

/// `Unknown` satisfies any expectation — the gradual seam — otherwise the type
/// must match exactly.
pub(super) fn expect(actual: &Type, wanted: Type, ctx: &str) -> Result<(), CheckError> {
    if *actual == wanted || *actual == Type::Unknown {
        Ok(())
    } else {
        err(format!("{ctx} expects {wanted}, found {actual}"))
    }
}

fn lookup(scope: &[(String, Type)], name: &str) -> Result<Type, CheckError> {
    scope
        .iter()
        .rev()
        .find(|(n, _)| n == name)
        .map(|(_, t)| t.clone())
        .ok_or_else(|| CheckError {
            message: format!("unknown name `{name}`"),
        })
}
