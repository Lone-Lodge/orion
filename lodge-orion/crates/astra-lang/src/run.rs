//! The embedder's two calls: source plus a rule name (or an event), an actor, its
//! arguments, and a host — out comes an [`Outcome`], the proposed effects and the
//! reads they were folded from, or a located error. This is the whole surface a
//! host like Atlas needs; lexer, parser and evaluator stay behind it. A refused
//! guard is *not* an error — it returns an empty effect list, the silent no-op the
//! host folds to nothing.

use crate::ast::{Program, Rule};
use crate::check::{CheckError, check};
use crate::eval::{RunError, eval_rule, eval_view, run_error};
use crate::{Host, LexError, Outcome, ParseError, Rendered, Value, lex, parse};

/// Why a run failed before producing effects — one stage of the pipeline, or a
/// name the source never declared.
#[derive(Debug)]
pub enum Error {
    Lex(LexError),
    Parse(ParseError),
    Check(CheckError),
    Run(RunError),
    NoSuchRule(String),
    NoSuchView(String),
}

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Error::Lex(e) => write!(f, "lex error (line {}): {}", e.line, e.message),
            Error::Parse(e) => write!(f, "parse error (line {}): {}", e.line, e.message),
            Error::Check(e) => write!(f, "type error: {}", e.message),
            Error::Run(e) => write!(f, "run error: {}", e.message),
            Error::NoSuchRule(name) => write!(f, "no such rule `{name}`"),
            Error::NoSuchView(name) => write!(f, "no such view `{name}`"),
        }
    }
}

impl std::error::Error for Error {}

/// Lex, parse, typecheck and evaluate `rule` from `src` against `host`, returning
/// the [`Outcome`] — the effects it proposes and the reads it made. The whole file
/// must typecheck before any rule in it runs — a type error is caught here, once,
/// never at a half-applied effect. Only plain rules are callable: an `on` handler
/// is never reached by name, only by [`dispatch`].
pub fn run(
    src: &str,
    rule: &str,
    by: u64,
    args: &[Value],
    host: &dyn Host,
) -> Result<Outcome, Error> {
    let program = compile(src)?;
    let found: &Rule = program
        .rules
        .iter()
        .find(|r| r.name == rule && r.trigger.is_none())
        .ok_or_else(|| Error::NoSuchRule(rule.to_string()))?;
    eval_rule(found, by, args, host).map_err(Error::Run)
}

/// Fire every `on Event` handler in `src` for `event`, in source order, and merge
/// the [`Outcome`]s they propose — effects concatenated, reads unioned. This is the
/// host's re-injection seam: nothing in the language turns an `Emit` into a
/// `dispatch`, so the host owns the cascade — and therefore its depth and
/// termination. Each handler's parameters are bound from `fields` by name; `by` is
/// the actor the host attributes the reaction to. The file must typecheck, exactly
/// as for [`run`].
pub fn dispatch(
    src: &str,
    event: &str,
    by: u64,
    fields: &[(String, Value)],
    host: &dyn Host,
) -> Result<Outcome, Error> {
    let program = compile(src)?;
    let mut outcome = Outcome::default();
    for handler in program
        .rules
        .iter()
        .filter(|r| r.trigger.as_deref() == Some(event))
    {
        let args = bind(handler, fields)?;
        outcome.merge(eval_rule(handler, by, &args, host).map_err(Error::Run)?);
    }
    Ok(outcome)
}

/// Lex, parse, typecheck and evaluate `view` from `src` against `host`, returning
/// the [`Rendered`] tree it produces — the read-side analogue of [`run`]. Same
/// pipeline; the whole file typechecks once before any view renders.
pub fn render(
    src: &str,
    view: &str,
    by: u64,
    args: &[Value],
    host: &dyn Host,
) -> Result<Rendered, Error> {
    let program = compile(src)?;
    let found = program
        .views
        .iter()
        .find(|v| v.name == view)
        .ok_or_else(|| Error::NoSuchView(view.to_string()))?;
    eval_view(found, by, args, host).map_err(Error::Run)
}

/// Lex, parse and typecheck a whole unit — the prefix `run` and `dispatch` share.
fn compile(src: &str) -> Result<Program, Error> {
    let tokens = lex(src).map_err(Error::Lex)?;
    let program = parse(&tokens).map_err(Error::Parse)?;
    check(&program).map_err(Error::Check)?;
    Ok(program)
}

/// Reorder an event's named `fields` into a handler's positional parameter list,
/// binding by name. A parameter the event does not carry is a run error — the
/// emitter and the handler disagree on the event's shape.
fn bind(handler: &Rule, fields: &[(String, Value)]) -> Result<Vec<Value>, Error> {
    handler
        .params
        .iter()
        .map(|p| {
            fields
                .iter()
                .find(|(n, _)| n == &p.name)
                .map(|(_, v)| v.clone())
                .ok_or_else(|| {
                    Error::Run(run_error(format!(
                        "event `{}` has no field `{}`",
                        handler.name, p.name
                    )))
                })
        })
        .collect()
}
