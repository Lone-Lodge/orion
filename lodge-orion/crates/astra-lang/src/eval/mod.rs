//! The evaluator — a parsed `Rule` to the effects it proposes, walked against a
//! `Host`. Pure: identical (rule, by, args, world) yield identical effects. A
//! `require` whose condition is false returns no effects at all — the silent
//! no-op that lets an illegal move commit nothing without being an error.

mod ops;
mod record;

use crate::ast::{Expr, Rule, Stmt, View, ViewElem};
use crate::{Effect, Host, Outcome, Rendered, TraceEntry, Value};
use ops::{as_bool, as_list, as_ref, binary, from_value, show, to_value, unary};
use record::Recorder;

/// A runtime value: the four stored shapes plus two the evaluator needs but a
/// field never holds — `Empty` (an absent read, the `empty` literal) and `List`
/// (what `all Kind` yields for a comprehension to fold).
#[derive(Clone, Debug, PartialEq)]
pub(crate) enum Val {
    Int(i64),
    Text(String),
    Bool(bool),
    Ref(u64),
    Empty,
    List(Vec<u64>),
}

/// Why evaluation failed — a type the source could not satisfy, or an unknown
/// name. A *refused guard* is not here: that is a normal empty result.
#[derive(Debug, PartialEq)]
pub struct RunError {
    pub message: String,
}

pub(crate) fn run_error(message: impl Into<String>) -> RunError {
    RunError {
        message: message.into(),
    }
}

/// Evaluate one rule against a host: an [`Outcome`] of the effects it proposes,
/// the reads it made, and the decision path it took. The host is wrapped in a
/// [`Recorder`] so the dependency footprint falls out of the very `field`/`all`
/// calls the walk already makes — no second pass; the trace is folded in the walk
/// beside the effects.
pub(crate) fn eval_rule(
    rule: &Rule,
    by: u64,
    args: &[Value],
    host: &dyn Host,
) -> Result<Outcome, RunError> {
    let recorder = Recorder::new(host);
    let (effects, trace) = run_body(rule, by, args, &recorder)?;
    Ok(Outcome {
        effects,
        reads: recorder.into_reads(),
        trace,
    })
}

/// Walk the rule body, returning the effects it proposes and the decision path it
/// took. `eval_rule` calls this with a recording host, so the walk need not know
/// its reads are captured — only its effects and trace are explicit here.
fn run_body(
    rule: &Rule,
    by: u64,
    args: &[Value],
    host: &dyn Host,
) -> Result<(Vec<Effect>, Vec<TraceEntry>), RunError> {
    let mut scope: Vec<(String, Val)> = vec![("by".to_string(), Val::Ref(by))];
    for (i, p) in rule.params.iter().enumerate() {
        let v = args
            .get(i)
            .ok_or_else(|| run_error(format!("missing argument for `{}`", p.name)))?;
        scope.push((p.name.clone(), from_value(v)));
    }
    let mut effects = Vec::new();
    let mut trace = Vec::new();
    for stmt in &rule.body {
        match stmt {
            Stmt::Require(cond) => {
                let passed = as_bool(eval(cond, &scope, host)?)?;
                trace.push(TraceEntry::Require { passed });
                if !passed {
                    return Ok((Vec::new(), trace));
                }
            }
            Stmt::Let { name, value } => {
                let v = eval(value, &scope, host)?;
                trace.push(TraceEntry::Let {
                    name: name.clone(),
                    value: show(&v),
                });
                scope.push((name.clone(), v));
            }
            Stmt::Set {
                entity,
                field,
                value,
            } => {
                let id = as_ref(eval(entity, &scope, host)?)?;
                let v = to_value(eval(value, &scope, host)?)?;
                effects.push(Effect::Set {
                    entity: id,
                    field: field.clone(),
                    value: v,
                });
            }
            Stmt::Spawn { kind, fields } => {
                let mut fs = Vec::with_capacity(fields.len());
                for (name, value) in fields {
                    fs.push((name.clone(), to_value(eval(value, &scope, host)?)?));
                }
                effects.push(Effect::Spawn {
                    kind: kind.clone(),
                    fields: fs,
                });
            }
            Stmt::Destroy { entity } => {
                let id = as_ref(eval(entity, &scope, host)?)?;
                effects.push(Effect::Destroy { entity: id });
            }
            Stmt::Emit { event, fields } => {
                let mut fs = Vec::with_capacity(fields.len());
                for (name, value) in fields {
                    fs.push((name.clone(), to_value(eval(value, &scope, host)?)?));
                }
                effects.push(Effect::Emit {
                    event: event.clone(),
                    fields: fs,
                });
            }
        }
    }
    Ok((effects, trace))
}

/// Evaluate one view against a host into a [`Rendered`] tree: its root element,
/// every argument expression evaluated, every `for` expanded to one node per row.
/// Pure like `eval_rule` — a read projection of the world, proposing no effects.
pub(crate) fn eval_view(
    view: &View,
    by: u64,
    args: &[Value],
    host: &dyn Host,
) -> Result<Rendered, RunError> {
    let mut scope: Vec<(String, Val)> = vec![("by".to_string(), Val::Ref(by))];
    for (i, p) in view.params.iter().enumerate() {
        let v = args
            .get(i)
            .ok_or_else(|| run_error(format!("missing argument for `{}`", p.name)))?;
        scope.push((p.name.clone(), from_value(v)));
    }
    render_elem(&view.root, &scope, host)
}

/// Render one element: evaluate its args, recurse into its children. A bare `for`
/// is not a valid root — a view is a tree with a single element at the top.
fn render_elem(
    elem: &ViewElem,
    scope: &[(String, Val)],
    host: &dyn Host,
) -> Result<Rendered, RunError> {
    match elem {
        ViewElem::Element {
            kind,
            args,
            children,
        } => {
            let args = args
                .iter()
                .map(|e| arg_value(eval(e, scope, host)?))
                .collect::<Result<Vec<_>, _>>()?;
            let children = render_children(children, scope, host)?;
            Ok(Rendered {
                kind: kind.clone(),
                args,
                children,
            })
        }
        ViewElem::For { .. } => Err(run_error("a view's root must be an element, not a `for`")),
    }
}

/// Expand a child list: an element yields one node, a `for` yields one per row of
/// its source — the same comprehension `count` folds, here emitting nodes.
fn render_children(
    children: &[ViewElem],
    scope: &[(String, Val)],
    host: &dyn Host,
) -> Result<Vec<Rendered>, RunError> {
    let mut out = Vec::new();
    for child in children {
        match child {
            ViewElem::Element { .. } => out.push(render_elem(child, scope, host)?),
            ViewElem::For { var, source, body } => {
                let ids = as_list(eval(source, scope, host)?)?;
                for id in ids {
                    let mut inner = scope.to_vec();
                    inner.push((var.clone(), Val::Ref(id)));
                    out.push(render_elem(body, &inner, host)?);
                }
            }
        }
    }
    Ok(out)
}

/// A view argument as a stored `Value`: an absent read (`empty`) renders as empty
/// text rather than failing — a missing field is a blank, not an error.
fn arg_value(v: Val) -> Result<Value, RunError> {
    match v {
        Val::Empty => Ok(Value::Text(String::new())),
        other => to_value(other),
    }
}

fn eval(expr: &Expr, scope: &[(String, Val)], host: &dyn Host) -> Result<Val, RunError> {
    match expr {
        Expr::Int(n) => Ok(Val::Int(*n)),
        Expr::Str(s) => Ok(Val::Text(s.clone())),
        Expr::Bool(b) => Ok(Val::Bool(*b)),
        Expr::Empty => Ok(Val::Empty),
        Expr::Var(name) => lookup(scope, name),
        Expr::Field { base, name } => {
            let id = as_ref(eval(base, scope, host)?)?;
            Ok(host.field(id, name).map_or(Val::Empty, |v| from_value(&v)))
        }
        Expr::Unary { op, rhs } => unary(*op, eval(rhs, scope, host)?),
        Expr::Binary { op, lhs, rhs } => {
            binary(*op, eval(lhs, scope, host)?, eval(rhs, scope, host)?)
        }
        Expr::If {
            cond,
            then,
            otherwise,
        } => {
            let branch = if as_bool(eval(cond, scope, host)?)? {
                then
            } else {
                otherwise
            };
            eval(branch, scope, host)
        }
        Expr::All { kind } => Ok(Val::List(host.all(kind))),
        Expr::Count {
            var,
            source,
            filter,
        } => {
            let ids = as_list(eval(source, scope, host)?)?;
            let mut n = 0i64;
            for id in ids {
                let mut inner = scope.to_vec();
                inner.push((var.clone(), Val::Ref(id)));
                let keep = match filter {
                    Some(f) => as_bool(eval(f, &inner, host)?)?,
                    None => true,
                };
                if keep {
                    n += 1;
                }
            }
            Ok(Val::Int(n))
        }
        Expr::Call { name, args } => {
            let mut evaluated = Vec::with_capacity(args.len());
            for a in args {
                evaluated.push(arg_value(eval(a, scope, host)?)?);
            }
            match host.call(name, &evaluated) {
                Some(v) => Ok(from_value(&v)),
                None => Err(run_error(format!("unknown builtin `{name}`"))),
            }
        }
    }
}

fn lookup(scope: &[(String, Val)], name: &str) -> Result<Val, RunError> {
    scope
        .iter()
        .rev()
        .find(|(n, _)| n == name)
        .map(|(_, v)| v.clone())
        .ok_or_else(|| run_error(format!("unknown name `{name}`")))
}
