//! Static analysis over an Astra `Program` — the engine reads what authored code
//! TELLS it it will touch, and uses that to pick the layout. The current question
//! it answers: which `(kind, field)` pairs are HOT — read inside a loop bound to
//! `all <Kind>` — so the host can materialize them as dense columns automatically.
//! No author-side directives, no runtime profiling: the language is the signal.

use crate::ast::{BinOp, Expr, Program, Stmt, TestAction, TestDecl, ViewElem};
use std::collections::BTreeSet;

/// Derive auto-tests from every rule's `require` clauses. For each invertible
/// guard, emit a TestDecl that seeds the failing state, applies the rule, and
/// expects the failing field to be UNCHANGED — proving the require's silent
/// no-op holds. The author writes ZERO of these; the engine reads intent and
/// generates the test for free, the same way it auto-materializes hot columns.
pub fn auto_require_tests(src: &str) -> Vec<TestDecl> {
    let Ok(tokens) = crate::lex(src) else {
        return Vec::new();
    };
    let Ok(program) = crate::parse(&tokens) else {
        return Vec::new();
    };
    let mut out = Vec::new();
    for rule in &program.rules {
        // Handlers (`on Event`) are not callable by name — they only fire from
        // a matching `emit` through `dispatch`. Skip them; their tests would
        // need the emit cascade to set up the event, not a bare `apply`.
        if rule.trigger.is_some() {
            continue;
        }
        // Negative cases — one auto-test per invertible `require`.
        for require in rule.body.iter().filter_map(require_expr) {
            if let Some((field, failing_value, op)) = invert_require(require) {
                out.push(TestDecl {
                    name: format!("auto_{}_silent_when_{}_{}", rule.name, field, op),
                    actions: vec![
                        TestAction::Set {
                            field: field.clone(),
                            value: Expr::Int(failing_value),
                        },
                        TestAction::Apply(rule.name.clone()),
                    ],
                    expects: vec![(field, Expr::Int(failing_value))],
                });
            }
        }
        // Positive case — one auto-test per rule with inline `expect` lines.
        if !rule.expects.is_empty() {
            out.push(TestDecl {
                name: format!("auto_{}_yields_its_expects", rule.name),
                actions: vec![TestAction::Apply(rule.name.clone())],
                expects: rule.expects.clone(),
            });
        }
    }
    out
}

fn require_expr(stmt: &Stmt) -> Option<&Expr> {
    match stmt {
        Stmt::Require(e) => Some(e),
        _ => None,
    }
}

/// Given a `require` expression, return `(field, value_that_makes_it_false, label)`
/// for the supported shapes. Compound expressions and ones referencing fields
/// beyond `by.X` are skipped — the author writes those tests by hand.
fn invert_require(expr: &Expr) -> Option<(String, i64, &'static str)> {
    let Expr::Binary { op, lhs, rhs } = expr else {
        return None;
    };
    let field = by_field(lhs)?;
    let n = literal_int(rhs)?;
    let (failing, label) = match op {
        BinOp::Gt => (n, "is_at_floor"),     // X > N → set X = N
        BinOp::Ge => (n - 1, "is_below"),    // X >= N → set X = N-1
        BinOp::Lt => (n, "is_at_ceiling"),   // X < N → set X = N
        BinOp::Le => (n + 1, "is_above"),    // X <= N → set X = N+1
        BinOp::Eq => (n + 1, "differs"),     // X == N → set X = N+1
        BinOp::Ne => (n, "equals"),          // X != N → set X = N
        _ => return None,
    };
    Some((field, failing, label))
}

/// `by.<field>` reads as `Expr::Field { base: Var("by"), name }`.
fn by_field(expr: &Expr) -> Option<String> {
    match expr {
        Expr::Field { base, name } => match base.as_ref() {
            Expr::Var(v) if v == "by" => Some(name.clone()),
            _ => None,
        },
        _ => None,
    }
}

fn literal_int(expr: &Expr) -> Option<i64> {
    match expr {
        Expr::Int(n) => Some(*n),
        _ => None,
    }
}

/// Scan `src` for hot column hints — `(kind, field)` pairs that the code reads
/// in a tight loop over `all <Kind>`. Returns a sorted, deduplicated set so the
/// host can materialize them deterministically. Malformed sources yield no hints
/// (silent failure is intentional — the typechecker is the place to complain).
pub fn hot_columns(src: &str) -> BTreeSet<(String, String)> {
    let Ok(tokens) = crate::lex(src) else {
        return BTreeSet::new();
    };
    let Ok(program) = crate::parse(&tokens) else {
        return BTreeSet::new();
    };
    let mut out = BTreeSet::new();
    walk_program(&program, &mut out);
    out
}

fn walk_program(p: &Program, out: &mut BTreeSet<(String, String)>) {
    for rule in &p.rules {
        for stmt in &rule.body {
            walk_stmt(stmt, out);
        }
    }
    for view in &p.views {
        walk_view(&view.root, out);
    }
}

fn walk_view(elem: &ViewElem, out: &mut BTreeSet<(String, String)>) {
    match elem {
        ViewElem::Element { args, children, .. } => {
            for arg in args {
                walk_expr(arg, None, out);
            }
            for child in children {
                walk_view(child, out);
            }
        }
        ViewElem::For { var, source, body } => {
            let bound_kind = kind_of_all(source);
            // The body's references to `var.field` are hot columns of that kind.
            walk_view_with(body, var, bound_kind.as_deref(), out);
            // The source itself may also contain `all`-loop reads worth tracking.
            walk_expr(source, None, out);
        }
    }
}

fn walk_view_with(
    elem: &ViewElem,
    bound_var: &str,
    bound_kind: Option<&str>,
    out: &mut BTreeSet<(String, String)>,
) {
    match elem {
        ViewElem::Element { args, children, .. } => {
            for arg in args {
                walk_expr(arg, Some((bound_var, bound_kind)), out);
            }
            for child in children {
                walk_view_with(child, bound_var, bound_kind, out);
            }
        }
        ViewElem::For { var, source, body } => {
            // The outer binding still applies to `source`; the body's own var shadows it.
            walk_expr(source, Some((bound_var, bound_kind)), out);
            let inner_kind = kind_of_all(source);
            walk_view_with(body, var, inner_kind.as_deref(), out);
        }
    }
}

fn walk_stmt(stmt: &Stmt, out: &mut BTreeSet<(String, String)>) {
    match stmt {
        Stmt::Require(e) | Stmt::Destroy { entity: e } => walk_expr(e, None, out),
        Stmt::Let { value, .. } => walk_expr(value, None, out),
        Stmt::Set { entity, value, .. } => {
            walk_expr(entity, None, out);
            walk_expr(value, None, out);
        }
        Stmt::Spawn { fields, .. } | Stmt::Emit { fields, .. } => {
            for (_, e) in fields {
                walk_expr(e, None, out);
            }
        }
    }
}

/// `binding` is `Some((var, kind))` when we're inside a `for var in all <Kind>`
/// loop — a `var.field` read inside that scope contributes `(kind, field)`. A
/// `count(c in all <Kind> where ...)` does the same for its body.
fn walk_expr(
    expr: &Expr,
    binding: Option<(&str, Option<&str>)>,
    out: &mut BTreeSet<(String, String)>,
) {
    match expr {
        Expr::Field { base, name } => {
            if let Expr::Var(v) = base.as_ref() {
                if let Some((bound_var, Some(kind))) = binding {
                    if v == bound_var {
                        out.insert((kind.to_owned(), name.clone()));
                    }
                }
            }
            walk_expr(base, binding, out);
        }
        Expr::Unary { rhs, .. } => walk_expr(rhs, binding, out),
        Expr::Binary { lhs, rhs, .. } => {
            walk_expr(lhs, binding, out);
            walk_expr(rhs, binding, out);
        }
        Expr::If { cond, then, otherwise } => {
            walk_expr(cond, binding, out);
            walk_expr(then, binding, out);
            walk_expr(otherwise, binding, out);
        }
        Expr::Count { var, source, filter } => {
            walk_expr(source, binding, out);
            let kind = kind_of_all(source);
            let inner = Some((var.as_str(), kind.as_deref()));
            if let Some(f) = filter {
                walk_expr(f, inner, out);
            }
        }
        Expr::Call { args, .. } => {
            for a in args {
                walk_expr(a, binding, out);
            }
        }
        Expr::All { .. } | Expr::Var(_) | Expr::Int(_) | Expr::Str(_) | Expr::Bool(_) | Expr::Empty => {}
    }
}

/// If `e` is `all <Kind>` (possibly composed with `and`/`or` — both sides shaped
/// the same), return the kind name. A more elaborate query still uses the same
/// indexes; we only need the FIELD-bearing kind for column materialization.
fn kind_of_all(e: &Expr) -> Option<String> {
    match e {
        Expr::All { kind } => Some(kind.clone()),
        // `all a and all b` / `all a or all b` — the loop variable lives in the
        // intersection/union; both sides' kinds are equally hot, but for column
        // sizing we conservatively pick the first.
        Expr::Binary { lhs, .. } => kind_of_all(lhs),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn h(src: &str) -> Vec<(String, String)> {
        // For tests, surface parse failures so we don't get a silent empty.
        let toks = crate::lex(src).unwrap_or_else(|e| panic!("lex: {e:?}"));
        let _p = crate::parse(&toks).unwrap_or_else(|e| panic!("parse: {e:?}"));
        hot_columns(src).into_iter().collect()
    }

    #[test]
    fn a_view_loop_reads_become_hot_columns() {
        let hot = h(
            "view list():\n    surface \"p\" {\n        for w in all wolf {\n            text \"value\" w.health\n        }\n    }\n",
        );
        assert!(
            hot.contains(&("wolf".into(), "health".into())),
            "`w.health` inside `for w in all wolf` is a (wolf, health) hot column"
        );
    }

    #[test]
    fn count_with_where_marks_fields_too() {
        let hot = h(
            "rule sweep():\n    let n = count(c in all cell where c.mark != empty)\n    set by.total = n\n",
        );
        assert!(hot.contains(&("cell".into(), "mark".into())));
    }

    #[test]
    fn nested_loops_track_each_binding_separately() {
        let hot = h(
            "view list():\n    surface \"p\" {\n        for w in all wolf {\n            for p in all pack {\n                text \"value\" p.size\n            }\n        }\n    }\n",
        );
        assert!(hot.contains(&("pack".into(), "size".into())));
    }

    #[test]
    fn a_bare_field_outside_a_loop_is_not_a_hot_column() {
        // `by.fire` is a parameter read, not a loop over a kind. No hint.
        let hot = h("rule feed():\n    set by.fire = by.fire + 1\n");
        assert!(hot.is_empty(), "no `all`-loop means no hot column hint");
    }
}
