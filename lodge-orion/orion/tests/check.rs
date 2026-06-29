//! Tests for the M2 checker. Run with `cargo test`.

use orion::check::check;
use orion::{lex, parse};

fn chk(src: &str) -> Result<(), String> {
    let program = parse(&lex(src).unwrap()).unwrap();
    check(&program).map_err(|e| e.message)
}

#[test]
fn errors_carry_a_source_span() {
    // A semantic error points at the offending name, so the CLI can draw a caret.
    let program = parse(&lex("fn area(w: int) -> int = w * height").unwrap()).unwrap();
    let e = orion::check::check(&program).unwrap_err();
    let span = e.span.expect("check error should carry a span");
    assert_eq!(span.line, 1);
    assert!(span.col > 0);
}

#[test]
fn unknown_name_is_an_error() {
    assert!(chk("fn f() -> int = y").is_err());
    assert!(chk("fn f(y: int) -> int = y").is_ok());
}

#[test]
fn reassigning_an_immutable_binding_is_an_error() {
    // `x = 1` introduces an immutable binding; `x = 2` then fails.
    assert!(chk("fn f():\n    x = 1\n    x = 2\n").is_err());
}

#[test]
fn mutable_binding_can_be_reassigned() {
    assert!(chk("fn f():\n    mut x = 1\n    x = 2\n    x += 5\n").is_ok());
}

#[test]
fn mutating_an_immutable_is_an_error() {
    assert!(chk("fn f():\n    x = 1\n    x += 1\n").is_err());
}

#[test]
fn wrong_arity_is_an_error() {
    let src = "fn g(a: int) -> int = a\nfn f() -> int = g(1, 2)";
    assert!(chk(src).is_err());
}

#[test]
fn builtin_arity_is_checked() {
    assert!(chk("fn f() -> int = max(1)").is_err());
    assert!(chk("fn f() -> int = max(1, 2)").is_ok());
}
