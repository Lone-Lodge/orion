//! The typechecker — a table-lookup pass from a parsed `Program` to either
//! nothing or the first type error. No inference and no unification engine: every
//! expression's type is read off its shape and its operands, so the whole pass is
//! a fold over the tree (the deliberate smallness the lib header promises). The
//! one give is `Unknown`, the type of a field read on an unmodelled kind: it
//! satisfies any expectation, so the world boundary stays gradual until a `record`
//! declares the kind's fields. A file must check as a whole before any of its rules
//! will run. Statement checks live here; expression typing is the `exprs` sibling
//! and the field schema the `records` one.

use crate::ast::{Param, Program, Rule, Stmt, View, ViewElem};
use crate::types::Type;

mod exprs;
mod records;
use exprs::{expect, type_of};
use records::Records;

/// Why a program failed to typecheck. No span yet — the message names the
/// construct and the types that clashed; line-accurate spans arrive with the
/// diagnostics slice.
#[derive(Debug, PartialEq)]
pub struct CheckError {
    pub message: String,
}

pub(crate) fn err<T>(message: impl Into<String>) -> Result<T, CheckError> {
    Err(CheckError {
        message: message.into(),
    })
}

/// Typecheck every rule in a program against its records. The schema is built
/// first — a malformed `record` is an error before any rule reads a field.
pub fn check(program: &Program) -> Result<(), CheckError> {
    let records = Records::build(&program.records)?;
    for rule in &program.rules {
        check_rule(rule, &records)?;
    }
    for view in &program.views {
        check_view(view, &records)?;
    }
    Ok(())
}

fn check_rule(rule: &Rule, records: &Records) -> Result<(), CheckError> {
    // `by` is the actor — an entity reference of unknown kind. Each param takes its
    // declared type; an unannotated param is gradual `Unknown` until annotated.
    let mut scope: Vec<(String, Type)> = vec![("by".to_string(), Type::Ref(None))];
    for p in &rule.params {
        scope.push((p.name.clone(), param_type(p)));
    }
    for stmt in &rule.body {
        check_stmt(stmt, &mut scope, records)?;
    }
    Ok(())
}

/// A param's declared type. `Int`/`Text`/`Bool` name primitives; any other name is
/// a kind, so the param is a reference of that kind; absence is gradual `Unknown`.
fn param_type(p: &Param) -> Type {
    match p.ty.as_deref() {
        Some("Int") => Type::Int,
        Some("Text") => Type::Text,
        Some("Bool") => Type::Bool,
        Some(kind) => Type::Ref(Some(kind.to_string())),
        None => Type::Unknown,
    }
}

/// Typecheck a view against the records — its expressions (args, `for` sources,
/// field reads) type exactly as a rule's do, with each `for` binding its var to
/// the source list's element kind. Node kinds are NOT checked: the core names no
/// UI; what `surface`/`text` mean is the host's call.
fn check_view(view: &View, records: &Records) -> Result<(), CheckError> {
    let mut scope: Vec<(String, Type)> = vec![("by".to_string(), Type::Ref(None))];
    for p in &view.params {
        scope.push((p.name.clone(), param_type(p)));
    }
    check_elem(&view.root, &scope, records)
}

fn check_elem(
    elem: &ViewElem,
    scope: &[(String, Type)],
    records: &Records,
) -> Result<(), CheckError> {
    match elem {
        ViewElem::Element { args, children, .. } => {
            for arg in args {
                // An argument is drawn content/a role — a stored value, not a list.
                storable(&type_of(arg, scope, records)?, "view argument")?;
            }
            for child in children {
                check_elem(child, scope, records)?;
            }
            Ok(())
        }
        ViewElem::For { var, source, body } => {
            let elem_kind = match type_of(source, scope, records)? {
                Type::List(elem) => elem,
                other => return err(format!("`for` expects a list, found {other}")),
            };
            let mut inner = scope.to_vec();
            inner.push((var.clone(), Type::Ref(elem_kind)));
            check_elem(body, &inner, records)
        }
    }
}

fn check_stmt(
    stmt: &Stmt,
    scope: &mut Vec<(String, Type)>,
    records: &Records,
) -> Result<(), CheckError> {
    match stmt {
        Stmt::Require(cond) => expect(&type_of(cond, scope, records)?, Type::Bool, "require"),
        Stmt::Let { name, value } => {
            let t = type_of(value, scope, records)?;
            scope.push((name.clone(), t));
            Ok(())
        }
        Stmt::Set { entity, field, value } => {
            let v = type_of(value, scope, records)?;
            match type_of(entity, scope, records)? {
                Type::Ref(Some(kind)) => records.field_set(&kind, field, &v),
                Type::Ref(None) | Type::Unknown => storable(&v, field),
                base => err(format!("`set {field}` needs an entity on the left, found {base}")),
            }
        }
        Stmt::Destroy { entity } => match type_of(entity, scope, records)? {
            Type::Ref(_) | Type::Unknown => Ok(()),
            base => err(format!("`destroy` needs an entity, found {base}")),
        },
        Stmt::Spawn { fields, .. } | Stmt::Emit { fields, .. } => {
            for (field, value) in fields {
                storable(&type_of(value, scope, records)?, field)?;
            }
            Ok(())
        }
    }
}

/// A field stores a stored value — never `empty` or a list. The universal rule,
/// shared by `spawn`, `emit`, an unmodelled `set`, and the `records` schema check,
/// mirroring the runtime's `to_value`.
pub(crate) fn storable(value: &Type, field: &str) -> Result<(), CheckError> {
    match value {
        Type::Empty | Type::List(_) => err(format!("cannot store {value} in field `{field}`")),
        _ => Ok(()),
    }
}
