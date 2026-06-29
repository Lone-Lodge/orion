//! Type checker. Runs after scope/mutability checking. Gradual: an unannotated
//! parameter or unmodelled component is `Ty::Unknown` and matches anything; only
//! genuine contradictions are reported.

mod call;
mod expr;
mod stmt;

use std::collections::{HashMap, HashSet};

use crate::ast::{Decl, Expr, FnBody, Program, Span, Type};

#[derive(Debug, PartialEq)]
pub struct TypeError {
    pub message: String,
    pub span: Option<Span>,
}

#[derive(Clone, PartialEq, Debug)]
pub(crate) enum Ty {
    Int,
    Float,
    Bool,
    Text,
    Entity,
    Unit,
    List(Box<Ty>),
    Enum(String),
    /// A user-declared `data` type — needed to dispatch method calls to the
    /// correct `impl Trait for Data` block (§14).
    Data(String),
    /// Type variable from `fn name<T, U>(...)` — substituted at call sites
    /// by `call_user_fn`. Acts as `Unknown` (wildcard) for assignability.
    Var(String),
    /// Gradual seam — compatible with everything.
    Unknown,
}

impl Ty {
    pub(crate) fn show(&self) -> String {
        match self {
            Ty::Int => "int".into(),
            Ty::Float => "float".into(),
            Ty::Bool => "bool".into(),
            Ty::Text => "Text".into(),
            Ty::Entity => "Entity".into(),
            Ty::Unit => "()".into(),
            Ty::List(t) => format!("[{}]", t.show()),
            Ty::Enum(n) => n.clone(),
            Ty::Data(n) => n.clone(),
            Ty::Var(n) => n.clone(),
            Ty::Unknown => "?".into(),
        }
    }
}

pub(crate) fn ty_of(t: &Type, enums: &HashSet<String>) -> Ty {
    ty_of_with_generics(t, enums, &[])
}

pub(crate) fn ty_of_with_generics(t: &Type, enums: &HashSet<String>, generics: &[String]) -> Ty {
    match t {
        Type::Named(n) => match n.as_str() {
            "int" => Ty::Int,
            "f32" | "f64" | "float" => Ty::Float,
            "bool" => Ty::Bool,
            "Text" => Ty::Text,
            "Entity" => Ty::Entity,
            _ if generics.iter().any(|g| g == n) => Ty::Var(n.clone()),
            _ if enums.contains(n) => Ty::Enum(n.clone()),
            _ => Ty::Unknown,
        },
        Type::Range { .. } => Ty::Int,
        Type::List(inner) => Ty::List(Box::new(ty_of_with_generics(inner, enums, generics))),
        Type::Optional(inner) => ty_of_with_generics(inner, enums, generics),
    }
}

pub(crate) fn numeric(t: &Ty) -> bool {
    matches!(t, Ty::Int | Ty::Float | Ty::Unknown)
}

/// Is `source` usable where `target` is expected? Unknown matches anything; an
/// int promotes to a float; a `List<S>` is assignable to `List<T>` if `S` is
/// assignable to `T` (so `[]: List<?>` flows into any `List<T>` parameter).
pub(crate) fn assignable(target: &Ty, source: &Ty) -> bool {
    if target == source || *target == Ty::Unknown || *source == Ty::Unknown {
        return true;
    }
    // Type variables match anything — they get pinned by substitution at the
    // call site. Without this, generic params would reject all real values.
    if matches!(target, Ty::Var(_)) || matches!(source, Ty::Var(_)) {
        return true;
    }
    if *target == Ty::Float && *source == Ty::Int {
        return true;
    }
    if let (Ty::List(t), Ty::List(s)) = (target, source) {
        return assignable(t, s);
    }
    false
}

pub(crate) fn unify(a: &Ty, b: &Ty) -> Option<Ty> {
    match (a, b) {
        _ if a == b => Some(a.clone()),
        (Ty::Unknown, t) | (t, Ty::Unknown) => Some(t.clone()),
        (Ty::Int, Ty::Float) | (Ty::Float, Ty::Int) => Some(Ty::Float),
        _ => None,
    }
}

pub(crate) fn err<T>(msg: impl Into<String>, span: Option<Span>) -> Result<T, TypeError> {
    Err(TypeError { message: msg.into(), span })
}

/// The nearest source span inside an expression — leftmost name — for carets.
pub(crate) fn span_of(e: &Expr) -> Option<Span> {
    match e {
        Expr::Var(_, s) => Some(*s),
        Expr::Unary { rhs, .. } => span_of(rhs),
        Expr::Binary { lhs, rhs, .. } => span_of(lhs).or_else(|| span_of(rhs)),
        Expr::Field { base, .. } => span_of(base),
        Expr::Call { callee, args } => span_of(callee).or_else(|| args.iter().find_map(span_of)),
        Expr::If { cond, then, otherwise } => {
            span_of(cond).or_else(|| span_of(then)).or_else(|| span_of(otherwise))
        }
        Expr::Range { lo, hi, .. } => span_of(lo).or_else(|| span_of(hi)),
        Expr::List(items) => items.iter().find_map(span_of),
        Expr::Struct { fields, .. } => fields.iter().find_map(|(_, v)| span_of(v)),
        Expr::Spawn(comps) => comps.iter().find_map(span_of),
        Expr::Comprehension { projection, .. } => span_of(projection),
        _ => None,
    }
}

pub(crate) struct Cx {
    /// component name -> field name -> type
    pub(crate) data: HashMap<String, HashMap<String, Ty>>,
    /// function/query name -> (parameter types, return type, generic type-param names)
    pub(crate) fns: HashMap<String, (Vec<Ty>, Ty, Vec<String>)>,
    /// enum name -> its variant names (for exhaustiveness)
    pub(crate) enums: HashMap<String, Vec<String>>,
    /// variant name -> (enum name, payload types)
    pub(crate) variants: HashMap<String, (String, Vec<Ty>)>,
}

pub fn check_types(program: &Program) -> Result<(), TypeError> {
    let enums_set: HashSet<String> = program
        .decls
        .iter()
        .filter_map(|d| if let Decl::Enum(e) = d { Some(e.name.clone()) } else { None })
        .collect();
    let cx = build_cx(program, &enums_set);
    for d in &program.decls {
        check_decl(d, &cx, &enums_set)?;
    }
    Ok(())
}

fn build_cx(program: &Program, enums_set: &HashSet<String>) -> Cx {
    let resolve = |t: &Type| ty_of(t, enums_set);
    let mut data = HashMap::new();
    let mut fns = HashMap::new();
    let mut enums = HashMap::new();
    let mut variants = HashMap::new();
    for d in &program.decls {
        match d {
            Decl::Data(dd) => {
                let fields = dd.fields.iter().map(|f| (f.name.clone(), resolve(&f.ty))).collect();
                data.insert(dd.name.clone(), fields);
            }
            Decl::Enum(ed) => {
                enums.insert(ed.name.clone(), ed.variants.iter().map(|v| v.name.clone()).collect());
                for v in &ed.variants {
                    let payload = v.payload.iter().map(&resolve).collect();
                    variants.insert(v.name.clone(), (ed.name.clone(), payload));
                }
            }
            Decl::Fn(f) => {
                let ps: Vec<Ty> = f.params.iter()
                    .map(|p| p.ty.as_ref()
                        .map(|t| ty_of_with_generics(t, enums_set, &f.generics))
                        .unwrap_or(Ty::Unknown))
                    .collect();
                let ret = f.ret.as_ref()
                    .map(|t| ty_of_with_generics(t, enums_set, &f.generics))
                    .unwrap_or(Ty::Unknown);
                fns.insert(f.name.clone(), (ps, ret, f.generics.clone()));
            }
            Decl::Query(q) => {
                let ps = q.params.iter().map(|p| p.ty.as_ref().map(&resolve).unwrap_or(Ty::Unknown)).collect();
                let ret = q.ret.as_ref().map(&resolve).unwrap_or(Ty::Unknown);
                fns.insert(q.name.clone(), (ps, ret, Vec::new()));
            }
            Decl::System(s) => {
                // Systems are callable from a tick driver; they return Unit.
                let ps = s.params.iter().map(|p| p.ty.as_ref().map(&resolve).unwrap_or(Ty::Unknown)).collect();
                fns.insert(s.name.clone(), (ps, Ty::Unit, Vec::new()));
            }
            Decl::Impl(_) | Decl::Trait(_) => {
                // Methods register at check-time via a separate pass — they're
                // not addressable as top-level fns.
            }
        }
    }
    Cx { data, fns, enums, variants }
}

fn check_decl(d: &Decl, cx: &Cx, enums_set: &HashSet<String>) -> Result<(), TypeError> {
    let resolve = |t: &Type| ty_of(t, enums_set);
    match d {
        Decl::Fn(f) => {
            let mut scope = param_scope(&f.params, enums_set);
            let declared = f.ret.as_ref().map(&resolve).unwrap_or(Ty::Unknown);
            match &f.body {
                FnBody::Expr(e) => {
                    let got = cx.infer(e, &scope)?;
                    if !assignable(&declared, &got) {
                        return err(
                            format!("`{}` returns {} but its body is {}", f.name, declared.show(), got.show()),
                            span_of(e),
                        );
                    }
                }
                FnBody::Block(stmts) => cx.block(stmts, &mut scope)?,
                FnBody::Extern => {} // no body — caller's args are checked at the call site
            }
        }
        Decl::System(s) => {
            let mut scope = param_scope(&s.params, enums_set);
            cx.block(&s.body, &mut scope)?;
        }
        Decl::Query(q) => {
            let scope = param_scope(&q.params, enums_set);
            cx.infer(&q.body, &scope)?;
        }
        Decl::Impl(i) => {
            for m in &i.methods {
                // `self` carries the impl's `for_type`; rest follow declared types.
                let mut scope = param_scope(&m.params, enums_set);
                if let Some(self_p) = m.params.first() {
                    if self_p.name == "self" {
                        scope.insert("self".into(), Ty::Data(i.for_type.clone()));
                    }
                }
                let declared = m.ret.as_ref().map(&resolve).unwrap_or(Ty::Unknown);
                match &m.body {
                    FnBody::Expr(e) => {
                        let got = cx.infer(e, &scope)?;
                        if !assignable(&declared, &got) {
                            return err(
                                format!("`{}::{}` returns {} but its body is {}", i.for_type, m.name, declared.show(), got.show()),
                                span_of(e),
                            );
                        }
                    }
                    FnBody::Block(stmts) => cx.block(stmts, &mut scope)?,
                    FnBody::Extern => {}
                }
            }
        }
        Decl::Trait(_) | Decl::Data(_) | Decl::Enum(_) => {}
    }
    Ok(())
}

fn param_scope(params: &[crate::ast::Param], enums: &HashSet<String>) -> HashMap<String, Ty> {
    params
        .iter()
        .map(|p| (p.name.clone(), p.ty.as_ref().map(|t| ty_of(t, enums)).unwrap_or(Ty::Unknown)))
        .collect()
}

// ---- public inference for hovers ----

/// Try to infer the static type of a local named `target_local` inside the fn
/// named `fn_name`. Walks the body in source order, maintaining a scope, and
/// returns the first hit. Returns `None` if the binding isn't reachable or
/// inference yields `Ty::Unknown`.
///
/// Handles parameters, `mut x = ...`, immutable `x = ...` introductions,
/// `for x in iter:` loop variables (using the iterator's element type), and
/// recurses into nested `for`, `loop`, `raw`, and `if` blocks.
pub fn infer_local_in_fn(program: &Program, fn_name: &str, target_local: &str) -> Option<String> {
    use crate::ast::{Decl, FnBody};

    let enums_set: HashSet<String> = program
        .decls
        .iter()
        .filter_map(|d| if let Decl::Enum(e) = d { Some(e.name.clone()) } else { None })
        .collect();
    let cx = build_cx(program, &enums_set);

    let f = program.decls.iter().find_map(|d| match d {
        Decl::Fn(f) if f.name == fn_name => Some(f),
        _ => None,
    })?;

    if let Some(p) = f.params.iter().find(|p| p.name == target_local) {
        return Some(p.ty.as_ref().map(|t| ty_of(t, &enums_set)).unwrap_or(Ty::Unknown).show());
    }

    let mut scope = param_scope(&f.params, &enums_set);
    let body = match &f.body {
        FnBody::Block(stmts) => stmts,
        FnBody::Expr(_) | FnBody::Extern => return None,
    };
    let found = walk_for_binding(body, target_local, &mut scope, &cx)?;
    let s = found.show();
    if s == "?" { None } else { Some(s) }
}

fn walk_for_binding(
    stmts: &[crate::ast::Stmt],
    target: &str,
    scope: &mut HashMap<String, Ty>,
    cx: &Cx,
) -> Option<Ty> {
    use crate::ast::{AssignOp, Expr, Stmt};

    for s in stmts {
        match s {
            Stmt::Bind { name, value } => {
                if name == target {
                    return cx.infer(value, scope).ok();
                }
                let ty = cx.infer(value, scope).unwrap_or(Ty::Unknown);
                scope.insert(name.clone(), ty);
            }
            Stmt::Assign { target: Expr::Var(name, _), op: AssignOp::Set, value } => {
                if name == target {
                    return cx.infer(value, scope).ok();
                }
                if !scope.contains_key(name) {
                    let ty = cx.infer(value, scope).unwrap_or(Ty::Unknown);
                    scope.insert(name.clone(), ty);
                }
            }
            Stmt::ForIn { var, iter, body, .. } => {
                let iter_ty = cx.infer(iter, scope).unwrap_or(Ty::Unknown);
                let var_ty = element_ty(&iter_ty);
                if var == target {
                    return Some(var_ty);
                }
                let mut inner = scope.clone();
                inner.insert(var.clone(), var_ty);
                if let Some(found) = walk_for_binding(body, target, &mut inner, cx) {
                    return Some(found);
                }
            }
            Stmt::For { var, body, .. } => {
                if var == target {
                    return Some(Ty::Entity);
                }
                let mut inner = scope.clone();
                inner.insert(var.clone(), Ty::Entity);
                if let Some(found) = walk_for_binding(body, target, &mut inner, cx) {
                    return Some(found);
                }
            }
            Stmt::If { then, otherwise, .. } => {
                let mut inner = scope.clone();
                if let Some(found) = walk_for_binding(then, target, &mut inner, cx) {
                    return Some(found);
                }
                let mut inner = scope.clone();
                if let Some(found) = walk_for_binding(otherwise, target, &mut inner, cx) {
                    return Some(found);
                }
            }
            Stmt::Loop(body) | Stmt::Raw(body) => {
                let mut inner = scope.clone();
                if let Some(found) = walk_for_binding(body, target, &mut inner, cx) {
                    return Some(found);
                }
            }
            _ => {}
        }
    }
    None
}

fn element_ty(t: &Ty) -> Ty {
    match t {
        Ty::List(inner) => (**inner).clone(),
        _ => Ty::Unknown,
    }
}
