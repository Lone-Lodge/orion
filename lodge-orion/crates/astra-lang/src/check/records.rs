//! The record schema — the table a field access types against. `record Cell { mark:
//! Text }` declares that a `Cell` has a `Text` field `mark` and *only* the fields it
//! lists: reading or writing any other field of a `Cell` is an error, while a kind
//! with no record stays gradual (`Unknown`). This is what closes the one seam the
//! type vocabulary leaves open — built once per program, then consulted by the
//! field-read fold in `exprs` and the `set` check in the parent module.

use std::collections::HashMap;

use super::{CheckError, err, storable};
use crate::ast::RecordDecl;
use crate::types::Type;

/// Every kind's declared fields: `kind -> (field -> type)`. A kind absent from the
/// map is unmodelled — its fields read as `Unknown`, the gradual seam left open.
pub(super) struct Records {
    kinds: HashMap<String, HashMap<String, Type>>,
}

impl Records {
    /// Fold the declarations into the lookup table, rejecting a kind declared twice
    /// or a field named twice within one kind — the schema must be unambiguous
    /// before any field types against it.
    pub(super) fn build(decls: &[RecordDecl]) -> Result<Self, CheckError> {
        let mut kinds: HashMap<String, HashMap<String, Type>> = HashMap::new();
        for decl in decls {
            let mut fields = HashMap::new();
            for field in &decl.fields {
                if fields.insert(field.name.clone(), resolve(&field.ty)).is_some() {
                    return err(format!(
                        "record `{}` declares field `{}` twice",
                        decl.name, field.name
                    ));
                }
            }
            if kinds.insert(decl.name.clone(), fields).is_some() {
                return err(format!("record `{}` is declared twice", decl.name));
            }
        }
        Ok(Self { kinds })
    }

    /// The type of reading `name` off an entity of `kind`: the declared field type,
    /// `Unknown` if the kind has no record (gradual), or an error if the record
    /// exists but does not list the field (the schema is closed).
    pub(super) fn field_read(&self, kind: &str, name: &str) -> Result<Type, CheckError> {
        match self.kinds.get(kind) {
            None => Ok(Type::Unknown),
            Some(fields) => fields.get(name).cloned().ok_or_else(|| CheckError {
                message: format!("`{kind}` has no field `{name}`"),
            }),
        }
    }

    /// Check writing `value` into `field` of an entity of `kind`. With no record the
    /// kind stays gradual and only the universal storable rule applies; with one the
    /// field must exist and accept the value.
    pub(super) fn field_set(
        &self,
        kind: &str,
        field: &str,
        value: &Type,
    ) -> Result<(), CheckError> {
        match self.kinds.get(kind) {
            None => storable(value, field),
            Some(fields) => match fields.get(field) {
                None => err(format!("`{kind}` has no field `{field}`")),
                Some(declared) => assignable(value, declared, field),
            },
        }
    }
}

/// Resolve a written field type name to a `Type`: the three primitives by name,
/// any other name a reference to that kind — exactly the convention a parameter
/// annotation follows, so `target: Player` reads the same in both places.
fn resolve(ty: &str) -> Type {
    match ty {
        "Int" => Type::Int,
        "Text" => Type::Text,
        "Bool" => Type::Bool,
        other => Type::Ref(Some(other.to_string())),
    }
}

/// Whether `value` may be stored into a field declared as `declared`. A gradual
/// value defers; `empty` and a list are never storable; any reference satisfies a
/// reference field (refs are interchangeable handles at runtime); otherwise the
/// shapes must match.
fn assignable(value: &Type, declared: &Type, field: &str) -> Result<(), CheckError> {
    match (value, declared) {
        (Type::Unknown, _) => Ok(()),
        (Type::Empty | Type::List(_), _) => storable(value, field),
        (Type::Ref(_), Type::Ref(_)) => Ok(()),
        _ if value == declared => Ok(()),
        _ => err(format!(
            "cannot store {value} in field `{field}`, which holds {declared}"
        )),
    }
}
