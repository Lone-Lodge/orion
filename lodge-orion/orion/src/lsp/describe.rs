//! Hover descriptions for declarations + their pieces.

use crate::ast::{Decl, Type};

#[derive(Debug, PartialEq)]
pub struct Symbol {
    pub name: String,
    pub kind: SymbolKind,
    pub line: u32,
}

#[derive(Debug, PartialEq)]
pub enum SymbolKind {
    Fn,
    Data,
    Enum,
    System,
    Query,
    Trait,
    Impl,
}

/// A signature one-liner for `name` if `decl` declares it (or an enum variant).
pub(super) fn describe(decl: &Decl, name: &str) -> Option<String> {
    match decl {
        Decl::Fn(f) if f.name == name => Some(describe_fn(f)),
        Decl::Data(d) if d.name == name => Some(describe_data(d)),
        Decl::Enum(e) if e.name == name => Some(describe_enum(e)),
        Decl::Enum(e) => describe_variant(e, name),
        Decl::System(s) if s.name == name => Some(describe_system(s)),
        Decl::Query(q) if q.name == name => Some(describe_query(q)),
        _ => None,
    }
}

fn describe_fn(f: &crate::ast::FnDecl) -> String {
    let params: Vec<String> = f.params.iter().map(format_param).collect();
    let ret = f.ret.as_ref().map(|t| format!(" -> {}", show_type(t))).unwrap_or_default();
    format!("{}fn {}({}){}", vis(f.public), f.name, params.join(", "), ret)
}

fn describe_data(d: &crate::ast::DataDecl) -> String {
    let fields: Vec<String> = d.fields.iter()
        .map(|f| format!("{}: {}", f.name, show_type(&f.ty)))
        .collect();
    format!("{}data {}: {}", vis(d.public), d.name, fields.join(", "))
}

fn describe_enum(e: &crate::ast::EnumDecl) -> String {
    let variants: Vec<String> = e.variants.iter().map(|v| v.name.clone()).collect();
    format!("{}enum {}: {}", vis(e.public), e.name, variants.join(" | "))
}

fn describe_variant(e: &crate::ast::EnumDecl, name: &str) -> Option<String> {
    let v = e.variants.iter().find(|v| v.name == name)?;
    let payload = if v.payload.is_empty() {
        String::new()
    } else {
        let ts: Vec<String> = v.payload.iter().map(show_type).collect();
        format!("({})", ts.join(", "))
    };
    Some(format!("variant {}{} of enum {}", v.name, payload, e.name))
}

fn describe_system(s: &crate::ast::SystemDecl) -> String {
    format!("{}system {}(...)", vis(s.public), s.name)
}

fn describe_query(q: &crate::ast::QueryDecl) -> String {
    let ret = q.ret.as_ref().map(|t| format!(" -> {}", show_type(t))).unwrap_or_default();
    format!("{}query {}(...){ret}", vis(q.public), q.name)
}

fn format_param(p: &crate::ast::Param) -> String {
    match &p.ty {
        Some(t) => format!("{}: {}", p.name, show_type(t)),
        None => p.name.clone(),
    }
}

fn vis(public: bool) -> &'static str {
    if public { "pub " } else { "" }
}

fn show_type(t: &Type) -> String {
    match t {
        Type::Named(n) => n.clone(),
        Type::Range { lo, hi, inclusive } => {
            if *inclusive { format!("{lo}...{hi}") } else { format!("{lo}..<{hi}") }
        }
        Type::List(inner) => format!("[{}]", show_type(inner)),
        Type::Optional(inner) => format!("{}?", show_type(inner)),
    }
}
