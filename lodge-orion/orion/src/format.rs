//! §17 — `orbit fmt` rich formatter built on the AST.
//!
//! Walks a parsed `Program` and emits canonical Orion source. The
//! existing whitespace formatter (`orbit_main.or::cmd_fmt`) only knows
//! tabs-to-spaces and trailing-whitespace; this one understands the
//! structure: indentation follows offside rules from the AST shape,
//! every `data` field gets a single space after the colon, expressions
//! parenthesise where precedence demands.
//!
//! Comments are not in the AST today, so this formatter strips them.
//! A future round-trip pass would preserve trivia tokens.

use crate::ast::{
    AssignOp, BinOp, Decl, Expr, FnBody, FnDecl, Param, Pattern, Program, Qualifier,
    Stmt, SystemDecl, Type, UnOp,
};

pub fn format(program: &Program) -> String {
    let mut out = String::new();
    for (i, decl) in program.decls.iter().enumerate() {
        if i > 0 {
            out.push('\n');
        }
        emit_decl(decl, &mut out);
    }
    if !out.ends_with('\n') {
        out.push('\n');
    }
    out
}

fn emit_decl(decl: &Decl, out: &mut String) {
    match decl {
        Decl::Data(d) => {
            if d.public { out.push_str("pub "); }
            out.push_str("data ");
            out.push_str(&d.name);
            if d.repr_c { out.push_str(" repr(c)"); }
            out.push_str(": ");
            for (i, f) in d.fields.iter().enumerate() {
                if i > 0 { out.push_str(", "); }
                out.push_str(&f.name);
                out.push_str(": ");
                emit_type(&f.ty, out);
            }
            out.push('\n');
        }
        Decl::Enum(e) => {
            if e.public { out.push_str("pub "); }
            out.push_str("enum ");
            out.push_str(&e.name);
            out.push_str(":\n");
            for v in &e.variants {
                out.push_str("    ");
                out.push_str(&v.name);
                if !v.payload.is_empty() {
                    out.push('(');
                    for (i, t) in v.payload.iter().enumerate() {
                        if i > 0 { out.push_str(", "); }
                        emit_type(t, out);
                    }
                    out.push(')');
                }
                out.push('\n');
            }
        }
        Decl::Fn(f) => emit_fn(f, out),
        Decl::System(s) => emit_system(s, out),
        Decl::Query(q) => {
            if q.public { out.push_str("pub "); }
            out.push_str("query ");
            out.push_str(&q.name);
            emit_params(&q.params, out);
            if let Some(ret) = &q.ret {
                out.push_str(" -> ");
                emit_type(ret, out);
            }
            out.push_str(" = ");
            emit_expr(&q.body, out, 0);
            out.push('\n');
        }
        Decl::Trait(t) => {
            if t.public { out.push_str("pub "); }
            out.push_str("trait ");
            out.push_str(&t.name);
            out.push_str(":\n");
            for m in &t.methods {
                out.push_str("    fn ");
                out.push_str(&m.name);
                emit_params(&m.params, out);
                if let Some(ret) = &m.ret {
                    out.push_str(" -> ");
                    emit_type(ret, out);
                }
                out.push('\n');
            }
        }
        Decl::Impl(i) => {
            out.push_str("impl ");
            out.push_str(&i.trait_name);
            out.push_str(" for ");
            out.push_str(&i.for_type);
            out.push_str(":\n");
            for m in &i.methods {
                emit_fn_indented(m, out, 1);
            }
        }
    }
}

fn emit_fn(f: &FnDecl, out: &mut String) {
    if f.public { out.push_str("pub "); }
    if f.deterministic { out.push_str("deterministic "); }
    if matches!(&f.body, FnBody::Extern) {
        out.push_str("extern fn ");
    } else {
        out.push_str("fn ");
    }
    out.push_str(&f.name);
    emit_params(&f.params, out);
    if let Some(ret) = &f.ret {
        out.push_str(" -> ");
        emit_type(ret, out);
    }
    match &f.body {
        FnBody::Expr(e) => {
            out.push_str(" = ");
            emit_expr(e, out, 0);
            out.push('\n');
        }
        FnBody::Block(stmts) => {
            out.push_str(":\n");
            for s in stmts {
                emit_stmt(s, out, 1);
            }
        }
        FnBody::Extern => out.push('\n'),
    }
}

fn emit_fn_indented(f: &FnDecl, out: &mut String, indent: usize) {
    let pad = "    ".repeat(indent);
    out.push_str(&pad);
    emit_fn(f, out);
}

fn emit_system(s: &SystemDecl, out: &mut String) {
    if s.public { out.push_str("pub "); }
    if s.deterministic { out.push_str("deterministic "); }
    out.push_str("system ");
    out.push_str(&s.name);
    emit_params(&s.params, out);
    if !s.before.is_empty() {
        out.push_str(" before ");
        out.push_str(&s.before.join(", "));
    }
    if !s.after.is_empty() {
        out.push_str(" after ");
        out.push_str(&s.after.join(", "));
    }
    out.push_str(":\n");
    for st in &s.body {
        emit_stmt(st, out, 1);
    }
}

fn emit_params(params: &[Param], out: &mut String) {
    out.push('(');
    for (i, p) in params.iter().enumerate() {
        if i > 0 { out.push_str(", "); }
        out.push_str(&p.name);
        if let Some(q) = p.qualifier {
            out.push_str(": ");
            match q {
                Qualifier::Mut => out.push_str("mut "),
                Qualifier::Take => out.push_str("take "),
            }
            if let Some(t) = &p.ty { emit_type(t, out); }
        } else if let Some(t) = &p.ty {
            out.push_str(": ");
            emit_type(t, out);
        }
        if let Some(default) = &p.default {
            out.push_str(" = ");
            emit_expr(default, out, 0);
        }
    }
    out.push(')');
}

fn emit_type(t: &Type, out: &mut String) {
    match t {
        Type::Named(n) => out.push_str(n),
        Type::Range { lo, hi, inclusive } => {
            out.push_str(&lo.to_string());
            out.push_str(if *inclusive { "..." } else { "..<" });
            out.push_str(&hi.to_string());
        }
        Type::List(inner) => {
            out.push('[');
            emit_type(inner, out);
            out.push(']');
        }
        Type::Optional(inner) => {
            emit_type(inner, out);
            out.push('?');
        }
    }
}

fn emit_stmt(s: &Stmt, out: &mut String, indent: usize) {
    let pad = "    ".repeat(indent);
    match s {
        Stmt::Bind { name, value } => {
            out.push_str(&pad);
            out.push_str(name);
            out.push_str(" = ");
            emit_expr(value, out, indent);
            out.push('\n');
        }
        Stmt::Assign { target, op, value } => {
            out.push_str(&pad);
            emit_expr(target, out, indent);
            out.push_str(match op {
                AssignOp::Set => " = ",
                AssignOp::Add => " += ",
                AssignOp::Sub => " -= ",
            });
            emit_expr(value, out, indent);
            out.push('\n');
        }
        Stmt::Destroy(e) => {
            out.push_str(&pad);
            out.push_str("destroy ");
            emit_expr(e, out, indent);
            out.push('\n');
        }
        Stmt::Expr(e) => {
            out.push_str(&pad);
            emit_expr(e, out, indent);
            out.push('\n');
        }
        Stmt::Require(e) => {
            out.push_str(&pad);
            out.push_str("require ");
            emit_expr(e, out, indent);
            out.push('\n');
        }
        Stmt::Ensure(e) => {
            out.push_str(&pad);
            out.push_str("ensure ");
            emit_expr(e, out, indent);
            out.push('\n');
        }
        Stmt::For { var, components, filter, body } => {
            out.push_str(&pad);
            out.push_str("for ");
            out.push_str(var);
            if !components.is_empty() {
                out.push_str(" with ");
                out.push_str(&components.join(", "));
            }
            if let Some(f) = filter {
                out.push_str(" where ");
                emit_expr(f, out, indent);
            }
            out.push_str(":\n");
            for st in body { emit_stmt(st, out, indent + 1); }
        }
        Stmt::ForIn { var, index_var, iter, body } => {
            out.push_str(&pad);
            out.push_str("for ");
            if let Some(idx) = index_var {
                out.push_str(idx);
                out.push_str(", ");
            }
            out.push_str(var);
            out.push_str(" in ");
            emit_expr(iter, out, indent);
            out.push_str(":\n");
            for st in body { emit_stmt(st, out, indent + 1); }
        }
        Stmt::If { cond, then, otherwise } => {
            out.push_str(&pad);
            out.push_str("if ");
            emit_expr(cond, out, indent);
            out.push_str(":\n");
            for st in then { emit_stmt(st, out, indent + 1); }
            if !otherwise.is_empty() {
                out.push_str(&pad);
                out.push_str("else:\n");
                for st in otherwise { emit_stmt(st, out, indent + 1); }
            }
        }
        Stmt::Loop(body) => {
            out.push_str(&pad);
            out.push_str("loop:\n");
            for st in body { emit_stmt(st, out, indent + 1); }
        }
        Stmt::Raw(body) => {
            out.push_str(&pad);
            out.push_str("raw:\n");
            for st in body { emit_stmt(st, out, indent + 1); }
        }
        Stmt::Parallel(inner) => {
            out.push_str(&pad);
            out.push_str("parallel ");
            // The wrapper applies to `for` statements; remove the indent
            // we just emitted from the inner one to avoid double-pad.
            let mut sub = String::new();
            emit_stmt(inner, &mut sub, 0);
            // Strip the leading-blank prefix on the first line and re-pad.
            for (i, line) in sub.lines().enumerate() {
                if i == 0 {
                    out.push_str(line);
                    out.push('\n');
                } else {
                    out.push_str(&pad);
                    out.push_str(line);
                    out.push('\n');
                }
            }
        }
        Stmt::Break => { out.push_str(&pad); out.push_str("break\n"); }
        Stmt::Continue => { out.push_str(&pad); out.push_str("continue\n"); }
        Stmt::Return(e) => {
            out.push_str(&pad);
            out.push_str("return ");
            emit_expr(e, out, indent);
            out.push('\n');
        }
    }
}

fn emit_expr(e: &Expr, out: &mut String, _indent: usize) {
    match e {
        Expr::Int(n) => out.push_str(&n.to_string()),
        Expr::Float(x) => out.push_str(&x.to_string()),
        Expr::ForCollect { var, iter, filter, body } => {
            out.push_str("for ");
            out.push_str(var);
            out.push_str(" in ");
            emit_expr(iter, out, _indent);
            if let Some(f) = filter {
                out.push_str(" where ");
                emit_expr(f, out, _indent);
            }
            out.push_str(": ");
            emit_expr(body, out, _indent);
        }
        Expr::Str(s) => {
            out.push('"');
            for ch in s.chars() {
                match ch {
                    '"' => out.push_str("\\\""),
                    '\\' => out.push_str("\\\\"),
                    '\n' => out.push_str("\\n"),
                    '\t' => out.push_str("\\t"),
                    _ => out.push(ch),
                }
            }
            out.push('"');
        }
        Expr::Bool(b) => out.push_str(if *b { "true" } else { "false" }),
        Expr::None => out.push_str("none"),
        Expr::Var(name, _) => out.push_str(name),
        Expr::Field { base, name, safe } => {
            emit_expr(base, out, _indent);
            out.push_str(if *safe { "?." } else { "." });
            out.push_str(name);
        }
        Expr::Call { callee, args } => {
            emit_expr(callee, out, _indent);
            out.push('(');
            for (i, a) in args.iter().enumerate() {
                if i > 0 { out.push_str(", "); }
                emit_expr(a, out, _indent);
            }
            out.push(')');
        }
        Expr::Unary { op, rhs } => {
            out.push_str(match op {
                UnOp::Not => "not ",
                UnOp::Neg => "-",
                UnOp::BitNot => "~",
            });
            emit_expr(rhs, out, _indent);
        }
        Expr::Binary { op, lhs, rhs } => {
            out.push('(');
            emit_expr(lhs, out, _indent);
            out.push(' ');
            out.push_str(binop_str(*op));
            out.push(' ');
            emit_expr(rhs, out, _indent);
            out.push(')');
        }
        Expr::If { cond, then, otherwise } => {
            out.push_str("if ");
            emit_expr(cond, out, _indent);
            out.push_str(" then ");
            emit_expr(then, out, _indent);
            out.push_str(" else ");
            emit_expr(otherwise, out, _indent);
        }
        Expr::Range { lo, hi, inclusive } => {
            emit_expr(lo, out, _indent);
            out.push_str(if *inclusive { "..." } else { "..<" });
            emit_expr(hi, out, _indent);
        }
        Expr::List(items) => {
            out.push('[');
            for (i, it) in items.iter().enumerate() {
                if i > 0 { out.push_str(", "); }
                emit_expr(it, out, _indent);
            }
            out.push(']');
        }
        Expr::Map(pairs) => {
            out.push('{');
            for (i, (k, v)) in pairs.iter().enumerate() {
                if i > 0 { out.push_str(", "); }
                emit_expr(k, out, _indent);
                out.push_str(": ");
                emit_expr(v, out, _indent);
            }
            out.push('}');
        }
        Expr::OrElse { value, default } => {
            emit_expr(value, out, _indent);
            out.push_str(" else ");
            emit_expr(default, out, _indent);
        }
        Expr::Comprehension { projection, var, components, filter } => {
            out.push('[');
            emit_expr(projection, out, _indent);
            out.push_str(" for ");
            out.push_str(var);
            if !components.is_empty() {
                out.push_str(" with ");
                out.push_str(&components.join(", "));
            }
            if let Some(f) = filter {
                out.push_str(" where ");
                emit_expr(f, out, _indent);
            }
            out.push(']');
        }
        Expr::Struct { name, fields } => {
            out.push_str(name);
            out.push('{');
            for (i, (k, v)) in fields.iter().enumerate() {
                if i > 0 { out.push_str(", "); }
                out.push_str(k);
                out.push_str(": ");
                emit_expr(v, out, _indent);
            }
            out.push('}');
        }
        Expr::Spawn(parts) => {
            out.push_str("spawn ");
            for (i, p) in parts.iter().enumerate() {
                if i > 0 { out.push_str(", "); }
                emit_expr(p, out, _indent);
            }
        }
        Expr::Match { scrutinee, arms } => {
            out.push_str("match ");
            emit_expr(scrutinee, out, _indent);
            out.push_str(":\n");
            for arm in arms {
                out.push_str("    ");
                emit_pattern(&arm.pattern, out);
                out.push_str(" -> ");
                emit_expr(&arm.body, out, _indent);
                out.push('\n');
            }
        }
        Expr::Interp(parts) => {
            out.push('"');
            for p in parts {
                match p {
                    Expr::Str(s) => out.push_str(s),
                    other => {
                        out.push('{');
                        emit_expr(other, out, _indent);
                        out.push('}');
                    }
                }
            }
            out.push('"');
        }
        Expr::Lambda { params, body } => {
            out.push_str("fn(");
            for (i, p) in params.iter().enumerate() {
                if i > 0 { out.push_str(", "); }
                out.push_str(p);
            }
            out.push_str(") = ");
            emit_expr(body, out, _indent);
        }
        Expr::Comptime(inner) => {
            out.push_str("comptime ");
            emit_expr(inner, out, _indent);
        }
        Expr::NamedArg { name, value } => {
            out.push_str(name);
            out.push_str(" = ");
            emit_expr(value, out, _indent);
        }
    }
}

fn binop_str(op: BinOp) -> &'static str {
    use BinOp::*;
    match op {
        Add => "+", Sub => "-", Mul => "*", Div => "/", Rem => "%",
        Eq => "==", Ne => "!=", Lt => "<", Le => "<=", Gt => ">", Ge => ">=",
        And => "and", Or => "or",
        BitAnd => "&", BitOr => "|", BitXor => "^",
        Shl => "<<", Shr => ">>",
    }
}

fn emit_pattern(p: &Pattern, out: &mut String) {
    match p {
        Pattern::Wildcard => out.push('_'),
        Pattern::Str(s) => {
            out.push('"');
            out.push_str(s);
            out.push('"');
        }
        Pattern::Int(n) => out.push_str(&n.to_string()),
        Pattern::Variant { name, bindings, .. } => {
            out.push_str(name);
            if !bindings.is_empty() {
                out.push(' ');
                out.push_str(&bindings.join(" "));
            }
        }
    }
}
