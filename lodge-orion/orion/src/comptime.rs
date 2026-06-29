//! §10 — comptime constant folding.
//!
//! Walks the AST after parsing and reduces every `Expr::Comptime(inner)`
//! to a literal when `inner` is a pure-constant expression: arithmetic
//! on literals, comparisons, `and`/`or`/`not`, conditionals with a
//! constant condition, and string concatenation. Anything more dynamic
//! (variable lookup, function call, field access) keeps the original
//! sub-tree and the interpreter handles it at runtime — graceful
//! fallback in the spirit of "comptime is sugar that the compiler
//! tries hard to evaluate, not an error if it can't".
//!
//! True Zig-style "comptime can call any pure fn" extends this: load
//! the fn body, recursively fold. M3+.

use crate::ast::{BinOp, Decl, Expr, FnBody, Program, Stmt, UnOp};

/// Recursively fold every `comptime` node in a program.
pub fn fold_program(program: &mut Program) {
    for decl in &mut program.decls {
        match decl {
            Decl::Fn(f) => match &mut f.body {
                FnBody::Expr(e) => fold_expr(e),
                FnBody::Block(stmts) => fold_stmts(stmts),
                FnBody::Extern => {}
            },
            Decl::System(s) => fold_stmts(&mut s.body),
            Decl::Query(q) => fold_expr(&mut q.body),
            Decl::Impl(i) => {
                for m in &mut i.methods {
                    match &mut m.body {
                        FnBody::Expr(e) => fold_expr(e),
                        FnBody::Block(stmts) => fold_stmts(stmts),
                        FnBody::Extern => {}
                    }
                }
            }
            Decl::Trait(_) | Decl::Data(_) | Decl::Enum(_) => {}
        }
    }
}

fn fold_stmts(stmts: &mut [Stmt]) {
    for s in stmts {
        fold_stmt(s);
    }
}

fn fold_stmt(s: &mut Stmt) {
    match s {
        Stmt::Bind { value, .. } => fold_expr(value),
        Stmt::Assign { target, value, .. } => {
            fold_expr(target);
            fold_expr(value);
        }
        Stmt::Destroy(e) | Stmt::Expr(e) => fold_expr(e),
        Stmt::Require(e) | Stmt::Ensure(e) => fold_expr(e),
        Stmt::For { filter, body, .. } => {
            if let Some(f) = filter { fold_expr(f); }
            fold_stmts(body);
        }
        Stmt::ForIn { iter, body, .. } => {
            fold_expr(iter);
            fold_stmts(body);
        }
        Stmt::If { cond, then, otherwise } => {
            fold_expr(cond);
            fold_stmts(then);
            fold_stmts(otherwise);
        }
        Stmt::Loop(body) | Stmt::Raw(body) => fold_stmts(body),
        Stmt::Parallel(inner) => fold_stmt(inner),
        Stmt::Break | Stmt::Continue => {}
        Stmt::Return(e) => fold_expr(e),
    }
}

fn fold_expr(e: &mut Expr) {
    // Recurse first — so nested `comptime` inside a `comptime` is
    // collapsed bottom-up.
    walk_children(e, fold_expr);
    if let Expr::Comptime(inner) = e {
        fold_expr(inner);
        if let Some(constant) = try_eval(inner) {
            *e = constant;
        }
    }
}

fn walk_children<F: FnMut(&mut Expr)>(e: &mut Expr, mut f: F) {
    match e {
        Expr::Int(_) | Expr::Float(_) | Expr::Str(_) | Expr::Bool(_)
        | Expr::None | Expr::Var(..) => {}
        Expr::Field { base, .. } => f(base),
        Expr::Call { callee, args } => {
            f(callee);
            for a in args { f(a); }
        }
        Expr::Unary { rhs, .. } => f(rhs),
        Expr::Binary { lhs, rhs, .. } => { f(lhs); f(rhs); }
        Expr::If { cond, then, otherwise } => { f(cond); f(then); f(otherwise); }
        Expr::Range { lo, hi, .. } => { f(lo); f(hi); }
        Expr::List(items) => items.iter_mut().for_each(f),
        Expr::Map(pairs) => for (k, v) in pairs { f(k); f(v); },
        Expr::OrElse { value, default } => { f(value); f(default); }
        Expr::Comprehension { projection, filter, .. } => {
            f(projection);
            if let Some(filt) = filter { f(filt); }
        }
        Expr::Struct { fields, .. } => for (_, v) in fields { f(v); },
        Expr::Spawn(parts) => parts.iter_mut().for_each(f),
        Expr::Match { scrutinee, arms } => {
            f(scrutinee);
            for arm in arms { f(&mut arm.body); }
        }
        Expr::Interp(parts) => parts.iter_mut().for_each(f),
        Expr::Lambda { body, .. } => f(body),
        Expr::Comptime(inner) => f(inner),
        Expr::NamedArg { value, .. } => f(value),
    }
}

/// Try to evaluate `e` as a pure constant. Returns `Some(literal)` if
/// the whole sub-tree reduces to a literal, `None` otherwise.
fn try_eval(e: &Expr) -> Option<Expr> {
    match e {
        Expr::Int(_) | Expr::Float(_) | Expr::Str(_) | Expr::Bool(_) | Expr::None => Some(e.clone()),
        Expr::Comptime(inner) => try_eval(inner),
        Expr::NamedArg { value, .. } => try_eval(value),
        Expr::Unary { op, rhs } => {
            let r = try_eval(rhs)?;
            match (op, &r) {
                (UnOp::Neg, Expr::Int(n)) => Some(Expr::Int(-n)),
                (UnOp::Neg, Expr::Float(x)) => Some(Expr::Float(-x)),
                (UnOp::Not, Expr::Bool(b)) => Some(Expr::Bool(!b)),
                (UnOp::BitNot, Expr::Int(n)) => Some(Expr::Int(!n)),
                _ => None,
            }
        }
        Expr::Binary { op, lhs, rhs } => {
            let l = try_eval(lhs)?;
            let r = try_eval(rhs)?;
            fold_binary(*op, &l, &r)
        }
        Expr::If { cond, then, otherwise } => {
            let c = try_eval(cond)?;
            let Expr::Bool(b) = c else { return None };
            try_eval(if b { then } else { otherwise })
        }
        _ => None,
    }
}

fn fold_binary(op: BinOp, l: &Expr, r: &Expr) -> Option<Expr> {
    use BinOp::*;
    match (l, r) {
        (Expr::Int(a), Expr::Int(b)) => match op {
            Add => Some(Expr::Int(a + b)),
            Sub => Some(Expr::Int(a - b)),
            Mul => Some(Expr::Int(a * b)),
            Div => if *b == 0 { None } else { Some(Expr::Int(a / b)) },
            Rem => if *b == 0 { None } else { Some(Expr::Int(a % b)) },
            BitAnd => Some(Expr::Int(a & b)),
            BitOr => Some(Expr::Int(a | b)),
            BitXor => Some(Expr::Int(a ^ b)),
            Shl => Some(Expr::Int(a.wrapping_shl(*b as u32))),
            Shr => Some(Expr::Int(a.wrapping_shr(*b as u32))),
            Eq => Some(Expr::Bool(a == b)),
            Ne => Some(Expr::Bool(a != b)),
            Lt => Some(Expr::Bool(a < b)),
            Le => Some(Expr::Bool(a <= b)),
            Gt => Some(Expr::Bool(a > b)),
            Ge => Some(Expr::Bool(a >= b)),
            And | Or => None,
        },
        (Expr::Float(a), Expr::Float(b)) => match op {
            Add => Some(Expr::Float(a + b)),
            Sub => Some(Expr::Float(a - b)),
            Mul => Some(Expr::Float(a * b)),
            Div => Some(Expr::Float(a / b)),
            Eq => Some(Expr::Bool(a == b)),
            Ne => Some(Expr::Bool(a != b)),
            Lt => Some(Expr::Bool(a < b)),
            Le => Some(Expr::Bool(a <= b)),
            Gt => Some(Expr::Bool(a > b)),
            Ge => Some(Expr::Bool(a >= b)),
            _ => None,
        },
        (Expr::Str(a), Expr::Str(b)) => match op {
            Add => Some(Expr::Str(format!("{a}{b}"))),
            Eq => Some(Expr::Bool(a == b)),
            Ne => Some(Expr::Bool(a != b)),
            _ => None,
        },
        (Expr::Bool(a), Expr::Bool(b)) => match op {
            And => Some(Expr::Bool(*a && *b)),
            Or => Some(Expr::Bool(*a || *b)),
            Eq => Some(Expr::Bool(a == b)),
            Ne => Some(Expr::Bool(a != b)),
            _ => None,
        },
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::lexer::lex;
    use crate::parser::parse;

    fn folds_to(src: &str, expect_literal: Expr) {
        let toks = lex(src).expect("lex");
        let mut program = parse(&toks).expect("parse");
        fold_program(&mut program);
        let Decl::Fn(f) = &program.decls[0] else { panic!() };
        let FnBody::Expr(e) = &f.body else { panic!("expected expr body") };
        assert_eq!(e, &expect_literal);
    }

    #[test]
    fn folds_arithmetic() {
        folds_to("fn main() -> int = comptime 1024 + 256 * 2", Expr::Int(1536));
    }

    #[test]
    fn folds_string_concat() {
        folds_to(r#"fn main() -> Text = comptime "hello, " + "world""#, Expr::Str("hello, world".into()));
    }

    #[test]
    fn folds_conditional() {
        folds_to("fn main() -> int = comptime if true then 42 else 0", Expr::Int(42));
    }
}
