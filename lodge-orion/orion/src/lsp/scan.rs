//! AST-walking helpers for goto-def: find a name's defining line, or its first
//! source span if it isn't a top-level decl.

use crate::ast::{AssignOp, Decl, Expr, FnBody, FnDecl, Param, Pattern, Program, Qualifier, Span, Stmt, Type};

const DECL_KEYWORDS: &[&str] = &["fn ", "data ", "enum ", "system ", "query "];

/// Source line where `name` is declared, or first-use line if no top-level
/// decl matches.
pub(super) fn decl_span(src: &str, program: &Program, name: &str) -> Option<(u32, u32)> {
    if is_top_level(program, name) {
        if let Some(line) = find_decl_line(src, name) {
            return Some((line, 0));
        }
    }
    if let Some(line) = enum_owner_line(src, program, name) {
        return Some((line, 0));
    }
    first_var_span(program, name).map(|s| (s.line, s.col))
}

fn is_top_level(program: &Program, name: &str) -> bool {
    program.decls.iter().any(|d| match d {
        Decl::Fn(f) => f.name == name,
        Decl::Data(d) => d.name == name,
        Decl::Enum(e) => e.name == name,
        Decl::System(s) => s.name == name,
        Decl::Query(q) => q.name == name,
        Decl::Trait(t) => t.name == name,
        // Impls are nameless — addressed via (trait, type) — so they don't
        // collide with top-level names.
        Decl::Impl(_) => false,
    })
}

fn enum_owner_line(src: &str, program: &Program, name: &str) -> Option<u32> {
    for decl in &program.decls {
        if let Decl::Enum(e) = decl {
            if e.variants.iter().any(|v| v.name == name) {
                return find_decl_line(src, &e.name);
            }
        }
    }
    None
}

fn first_var_span(program: &Program, name: &str) -> Option<Span> {
    let mut found = None;
    for decl in &program.decls {
        scan_decl(decl, name, &mut found);
        if found.is_some() {
            return found;
        }
    }
    None
}

/// Hover description for `name` when it's a parameter or a local binding
/// inside whatever `fn` contains `cursor_line`. Returns `None` if `name` isn't
/// local to that fn — caller can then fall back to top-level / orb-dep lookup.
///
/// `user_program` is parsed from the file the user is editing (so we find the
/// enclosing fn by its source line). `inference_program` is the same program
/// optionally prefixed with the orb-dep prelude — that's what type inference
/// runs against so calls to `byte_at` / `bytes_length` / … resolve to their
/// declared return types.
pub(super) fn local_hover(
    src: &str,
    user_program: &Program,
    inference_program: &Program,
    name: &str,
    cursor_line: u32,
) -> Option<String> {
    let f = enclosing_fn(src, user_program, cursor_line)?;
    if let Some(p) = f.params.iter().find(|p| p.name == name) {
        return Some(format_param(p, &f.name));
    }
    // Try inference — gives "int" / "[int]" / "Text" / etc.
    let inferred = crate::typeck::infer_local_in_fn(inference_program, &f.name, name);
    match &f.body {
        FnBody::Block(stmts) => local_in_block(stmts, name, &f.name, inferred.as_deref()),
        FnBody::Expr(_) | FnBody::Extern => None,
    }
}

/// Pick the fn whose declaration line is the closest one *at or above* the
/// cursor. Walking source for fn-start positions matches the same heuristic
/// goto-def uses (`find_decl_line`), so the two stay in sync.
fn enclosing_fn<'a>(src: &str, program: &'a Program, cursor_line: u32) -> Option<&'a FnDecl> {
    let mut best: Option<(&FnDecl, u32)> = None;
    for decl in &program.decls {
        if let Decl::Fn(f) = decl {
            if let Some(start) = find_decl_line(src, &f.name) {
                if start <= cursor_line && best.is_none_or(|(_, b)| start > b) {
                    best = Some((f, start));
                }
            }
        }
    }
    best.map(|(f, _)| f)
}

fn local_in_block(
    stmts: &[Stmt],
    name: &str,
    fn_name: &str,
    inferred: Option<&str>,
) -> Option<String> {
    for s in stmts {
        if let Some(d) = describe_local_stmt(s, name, fn_name, inferred) {
            return Some(d);
        }
        if let Some(d) = local_in_nested(s, name, fn_name, inferred) {
            return Some(d);
        }
    }
    None
}

fn local_in_nested(
    s: &Stmt,
    name: &str,
    fn_name: &str,
    inferred: Option<&str>,
) -> Option<String> {
    match s {
        Stmt::ForIn { body, .. } | Stmt::For { body, .. } | Stmt::Loop(body) | Stmt::Raw(body) => {
            local_in_block(body, name, fn_name, inferred)
        }
        Stmt::If { then, otherwise, .. } => local_in_block(then, name, fn_name, inferred)
            .or_else(|| local_in_block(otherwise, name, fn_name, inferred)),
        _ => None,
    }
}

fn describe_local_stmt(
    s: &Stmt,
    name: &str,
    fn_name: &str,
    inferred: Option<&str>,
) -> Option<String> {
    let ty_suffix = inferred.map(|t| format!(": {t}")).unwrap_or_default();
    match s {
        Stmt::Bind { name: n, .. } if n == name => {
            Some(format!("mut {n}{ty_suffix}  # local in fn `{fn_name}`"))
        }
        Stmt::ForIn { var, iter: _, .. } if var == name => Some(format!(
            "for {var}{ty_suffix} in ...  # loop variable in fn `{fn_name}`"
        )),
        Stmt::For { var, components, .. } if var == name => Some(format!(
            "for {var}{ty_suffix} with {}  # query variable in fn `{fn_name}`",
            components.join(", "),
        )),
        Stmt::Assign { target: Expr::Var(n, _), op: AssignOp::Set, .. } if n == name => {
            Some(format!("{n}{ty_suffix}  # local in fn `{fn_name}`"))
        }
        _ => None,
    }
}

fn format_param(p: &Param, fn_name: &str) -> String {
    let qual = match p.qualifier {
        Some(Qualifier::Mut) => "mut ",
        Some(Qualifier::Take) => "take ",
        None => "",
    };
    let ty = p.ty.as_ref().map(|t| format!(": {}", show_type(t))).unwrap_or_default();
    format!("{qual}{}{ty}  # parameter of fn `{fn_name}`", p.name)
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

/// Text-scan for the line declaring `name` — finds `[pub] (fn|data|enum|...) name`.
pub(super) fn find_decl_line(src: &str, name: &str) -> Option<u32> {
    for (i, line) in src.lines().enumerate() {
        let trimmed = line.trim_start().strip_prefix("pub ").unwrap_or_else(|| line.trim_start());
        for kw in DECL_KEYWORDS {
            if let Some(rest) = trimmed.strip_prefix(kw) {
                if let Some(after) = rest.strip_prefix(name) {
                    if after.starts_with(|c: char| matches!(c, '(' | ':' | ' ')) || after.is_empty() {
                        return Some((i + 1) as u32);
                    }
                }
            }
        }
    }
    None
}

fn scan_decl(decl: &Decl, name: &str, out: &mut Option<Span>) {
    match decl {
        Decl::Fn(f) => match &f.body {
            FnBody::Expr(e) => scan_expr(e, name, out),
            FnBody::Block(stmts) => scan_block(stmts, name, out),
            FnBody::Extern => {}
        },
        Decl::System(s) => scan_block(&s.body, name, out),
        Decl::Query(q) => scan_expr(&q.body, name, out),
        Decl::Impl(i) => {
            for m in &i.methods {
                match &m.body {
                    FnBody::Expr(e) => scan_expr(e, name, out),
                    FnBody::Block(stmts) => scan_block(stmts, name, out),
                    FnBody::Extern => {}
                }
                if out.is_some() { return; }
            }
        }
        Decl::Trait(_) | Decl::Data(_) | Decl::Enum(_) => {}
    }
}

fn scan_block(stmts: &[Stmt], name: &str, out: &mut Option<Span>) {
    for s in stmts {
        scan_stmt(s, name, out);
        if out.is_some() {
            return;
        }
    }
}

fn scan_stmt(s: &Stmt, name: &str, out: &mut Option<Span>) {
    if out.is_some() {
        return;
    }
    match s {
        Stmt::Require(e) | Stmt::Ensure(e) | Stmt::Expr(e) | Stmt::Destroy(e) => scan_expr(e, name, out),
        Stmt::Bind { value, .. } => scan_expr(value, name, out),
        Stmt::Fact { expr, .. } => scan_expr(expr, name, out),
        Stmt::Assign { target, value, .. } => {
            scan_expr(target, name, out);
            scan_expr(value, name, out);
        }
        Stmt::For { filter, body, .. } => {
            if let Some(f) = filter {
                scan_expr(f, name, out);
            }
            scan_block(body, name, out);
        }
        Stmt::ForIn { iter, body, .. } => {
            scan_expr(iter, name, out);
            scan_block(body, name, out);
        }
        Stmt::If { cond, then, otherwise } => {
            scan_expr(cond, name, out);
            scan_block(then, name, out);
            scan_block(otherwise, name, out);
        }
        Stmt::Loop(body) | Stmt::Raw(body) => scan_block(body, name, out),
        Stmt::Parallel(inner) => scan_stmt(inner, name, out),
        Stmt::Break | Stmt::Continue => {}
        Stmt::Return(e) => scan_expr(e, name, out),
    }
}

fn scan_expr(e: &Expr, name: &str, out: &mut Option<Span>) {
    if out.is_some() {
        return;
    }
    match e {
        Expr::Var(n, sp) if n == name => *out = Some(*sp),
        Expr::Var(_, _) | Expr::Int(_) | Expr::Float(_) | Expr::Str(_) | Expr::Bool(_) | Expr::None => {}
        Expr::Field { base, .. } => scan_expr(base, name, out),
        Expr::ForCollect { iter, filter, body, .. } => {
            scan_expr(iter, name, out);
            if let Some(f) = filter { scan_expr(f, name, out); }
            scan_expr(body, name, out);
        }
        Expr::Call { callee, args } => {
            scan_expr(callee, name, out);
            args.iter().for_each(|a| scan_expr(a, name, out));
        }
        Expr::Unary { rhs, .. } => scan_expr(rhs, name, out),
        Expr::Binary { lhs, rhs, .. } => {
            scan_expr(lhs, name, out);
            scan_expr(rhs, name, out);
        }
        Expr::If { cond, then, otherwise } => {
            scan_expr(cond, name, out);
            scan_expr(then, name, out);
            scan_expr(otherwise, name, out);
        }
        Expr::Range { lo, hi, .. } => {
            scan_expr(lo, name, out);
            scan_expr(hi, name, out);
        }
        Expr::List(items) => items.iter().for_each(|i| scan_expr(i, name, out)),
        Expr::Map(pairs) => pairs.iter().for_each(|(k, v)| {
            scan_expr(k, name, out);
            scan_expr(v, name, out);
        }),
        Expr::OrElse { value, default } => {
            scan_expr(value, name, out);
            scan_expr(default, name, out);
        }
        Expr::Struct { fields, .. } => fields.iter().for_each(|(_, v)| scan_expr(v, name, out)),
        Expr::Spawn(comps) => comps.iter().for_each(|c| scan_expr(c, name, out)),
        Expr::Comprehension { projection, filter, .. } => {
            scan_expr(projection, name, out);
            if let Some(f) = filter {
                scan_expr(f, name, out);
            }
        }
        Expr::Match { scrutinee, arms } => {
            scan_expr(scrutinee, name, out);
            for arm in arms {
                if let Pattern::Variant { name: vname, span, .. } = &arm.pattern {
                    if vname == name {
                        *out = Some(*span);
                        return;
                    }
                }
                scan_expr(&arm.body, name, out);
            }
        }
        Expr::Interp(parts) => parts.iter().for_each(|p| scan_expr(p, name, out)),
        Expr::Lambda { body, .. } => scan_expr(body, name, out),
        Expr::Comptime(inner) => scan_expr(inner, name, out),
        Expr::NamedArg { value, .. } => scan_expr(value, name, out),
    }
}
