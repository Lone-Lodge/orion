//! Ownership / move checking.
//!
//! One rule needs static enforcement: passing a variable to a `take` parameter
//! consumes it, and using it afterwards is a "use of moved value". Branches
//! (`if`/`match`) are checked independently and their moves unioned, so a value
//! used after a *conditional* move is also flagged.

use std::collections::{HashMap, HashSet};

use crate::ast::{Decl, Expr, FnBody, Pattern, Program, Span, Stmt};

#[derive(Debug, PartialEq)]
pub struct MoveError {
    pub message: String,
    pub span: Option<Span>,
}

pub fn check(program: &Program) -> Result<(), MoveError> {
    let mv = Mv { takes: gather_takes(program) };
    for d in &program.decls {
        check_decl(&mv, d)?;
    }
    Ok(())
}

/// Per fn/system/query: which parameters are `take` (consuming).
fn gather_takes(program: &Program) -> HashMap<String, Vec<bool>> {
    let mut out = HashMap::new();
    for d in &program.decls {
        let (name, params) = match d {
            Decl::Fn(f) => (&f.name, &f.params),
            Decl::System(s) => (&s.name, &s.params),
            Decl::Query(q) => (&q.name, &q.params),
            _ => continue,
        };
        let flags = params.iter()
            .map(|p| p.qualifier == Some(crate::ast::Qualifier::Take))
            .collect();
        out.insert(name.clone(), flags);
    }
    out
}

fn check_decl(mv: &Mv, d: &Decl) -> Result<(), MoveError> {
    let mut moved = HashSet::new();
    match d {
        Decl::Fn(f) => match &f.body {
            FnBody::Expr(e) => mv.expr(e, &mut moved),
            FnBody::Block(stmts) => mv.block(stmts, &mut moved),
            FnBody::Extern => Ok(()),
        },
        Decl::System(s) => mv.block(&s.body, &mut moved),
        Decl::Query(q) => mv.expr(&q.body, &mut moved),
        _ => Ok(()),
    }
}

struct Mv {
    takes: HashMap<String, Vec<bool>>,
}

impl Mv {
    fn block(&self, stmts: &[Stmt], moved: &mut HashSet<String>) -> Result<(), MoveError> {
        for s in stmts {
            self.stmt(s, moved)?;
        }
        Ok(())
    }

    fn stmt(&self, s: &Stmt, moved: &mut HashSet<String>) -> Result<(), MoveError> {
        match s {
            Stmt::Require(e) | Stmt::Ensure(e) | Stmt::Expr(e) => self.expr(e, moved),
            Stmt::Destroy(e) => self.stmt_destroy(e, moved),
            Stmt::Bind { name, value } => {
                self.expr(value, moved)?;
                moved.remove(name);
                Ok(())
            }
            Stmt::Fact { name, expr } => {
                self.expr(expr, moved)?;
                moved.remove(name);
                Ok(())
            }
            Stmt::Assign { target, value, .. } => self.stmt_assign(target, value, moved),
            Stmt::For { filter, body, .. } => {
                if let Some(f) = filter {
                    self.expr(f, moved)?;
                }
                self.block_scoped(body, moved)
            }
            Stmt::ForIn { iter, body, .. } => {
                self.expr(iter, moved)?;
                self.block_scoped(body, moved)
            }
            Stmt::If { cond, then, otherwise } => {
                self.expr(cond, moved)?;
                self.union_branches(moved, |this, m| this.block(then, m), |this, m| this.block(otherwise, m))
            }
            Stmt::Loop(body) => self.block_scoped(body, moved),
            // §4: `raw` is the escape hatch — Rust's `unsafe` equivalent.
            // The move-checker skips the body entirely; the contract is
            // "I, the human, have read this and know what I'm doing".
            Stmt::Raw(_) => Ok(()),
            Stmt::Parallel(inner) => self.stmt(inner, moved),
            Stmt::Break | Stmt::Continue => Ok(()),
            Stmt::Return(_) => Ok(()),
        }
    }

    fn stmt_destroy(&self, e: &Expr, moved: &mut HashSet<String>) -> Result<(), MoveError> {
        self.expr(e, moved)?;
        if let Expr::Var(n, _) = e {
            moved.insert(n.clone()); // destroy consumes the entity
        }
        Ok(())
    }

    fn stmt_assign(&self, target: &Expr, value: &Expr, moved: &mut HashSet<String>) -> Result<(), MoveError> {
        self.expr(value, moved)?;
        match target {
            Expr::Var(name, _) => {
                moved.remove(name); // reassignment re-initialises
                Ok(())
            }
            _ => self.expr(target, moved),
        }
    }

    fn expr(&self, e: &Expr, moved: &mut HashSet<String>) -> Result<(), MoveError> {
        match e {
            Expr::Var(name, span) => self.expr_var(name, *span, moved),
            Expr::Call { callee, args } => self.expr_call(callee, args, moved),
            Expr::Field { base, .. } | Expr::Unary { rhs: base, .. } => self.expr(base, moved),
            Expr::Binary { lhs, rhs, .. } | Expr::Range { lo: lhs, hi: rhs, .. } | Expr::OrElse { value: lhs, default: rhs } => {
                self.expr(lhs, moved)?;
                self.expr(rhs, moved)
            }
            Expr::If { cond, then, otherwise } => {
                self.expr(cond, moved)?;
                self.union_branches(moved, |this, m| this.expr(then, m), |this, m| this.expr(otherwise, m))
            }
            Expr::Match { scrutinee, arms } => self.expr_match(scrutinee, arms, moved),
            Expr::List(items) | Expr::Spawn(items) | Expr::Interp(items) => self.check_all(items, moved),
            Expr::Map(pairs) => {
                for (k, v) in pairs {
                    self.expr(k, moved)?;
                    self.expr(v, moved)?;
                }
                Ok(())
            }
            Expr::Struct { fields, .. } => {
                for (_, v) in fields {
                    self.expr(v, moved)?;
                }
                Ok(())
            }
            Expr::Comprehension { projection, filter, .. } => {
                if let Some(f) = filter {
                    self.expr(f, moved)?;
                }
                self.expr(projection, moved)
            }
            _ => Ok(()),
        }
    }

    fn expr_var(&self, name: &str, span: Span, moved: &HashSet<String>) -> Result<(), MoveError> {
        if moved.contains(name) {
            return Err(MoveError {
                message: format!("use of moved value `{name}`"),
                span: Some(span),
            });
        }
        Ok(())
    }

    fn expr_call(&self, callee: &Expr, args: &[Expr], moved: &mut HashSet<String>) -> Result<(), MoveError> {
        let flags = match callee {
            Expr::Var(n, _) => self.takes.get(n).cloned(),
            _ => {
                self.expr(callee, moved)?;
                None
            }
        };
        for (i, a) in args.iter().enumerate() {
            self.expr(a, moved)?; // use first (errors if already moved)
            let consumed = flags.as_ref().and_then(|f| f.get(i)).copied().unwrap_or(false);
            if consumed {
                if let Expr::Var(n, _) = a {
                    moved.insert(n.clone());
                }
            }
        }
        Ok(())
    }

    fn expr_match(&self, scrutinee: &Expr, arms: &[crate::ast::MatchArm], moved: &mut HashSet<String>) -> Result<(), MoveError> {
        self.expr(scrutinee, moved)?;
        let mut union = moved.clone();
        for arm in arms {
            let mut m = moved.clone();
            if let Pattern::Variant { bindings, .. } = &arm.pattern {
                for b in bindings {
                    m.remove(b); // arm bindings are fresh
                }
            }
            self.expr(&arm.body, &mut m)?;
            union.extend(m);
        }
        *moved = union;
        Ok(())
    }

    fn check_all(&self, items: &[Expr], moved: &mut HashSet<String>) -> Result<(), MoveError> {
        for it in items {
            self.expr(it, moved)?;
        }
        Ok(())
    }

    /// A loop body runs many times — check it on a fresh copy of `moved` so a
    /// move inside doesn't leak out, but is still validated.
    fn block_scoped(&self, stmts: &[Stmt], moved: &HashSet<String>) -> Result<(), MoveError> {
        let mut inner = moved.clone();
        self.block(stmts, &mut inner)
    }

    /// Check two branches independently against the same starting `moved` set,
    /// then merge their moves back. A value moved in either branch is moved.
    fn union_branches<F, G>(&self, moved: &mut HashSet<String>, first: F, second: G) -> Result<(), MoveError>
    where
        F: FnOnce(&Self, &mut HashSet<String>) -> Result<(), MoveError>,
        G: FnOnce(&Self, &mut HashSet<String>) -> Result<(), MoveError>,
    {
        let mut m1 = moved.clone();
        first(self, &mut m1)?;
        let mut m2 = moved.clone();
        second(self, &mut m2)?;
        moved.extend(m1);
        moved.extend(m2);
        Ok(())
    }
}
