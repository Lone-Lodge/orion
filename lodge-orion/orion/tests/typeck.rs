//! Tests for the type checker. Run with `cargo test`.

use orion::typeck::check_types;
use orion::{lex, parse};

fn ty(src: &str) -> Result<(), String> {
    check_types(&parse(&lex(src).unwrap()).unwrap()).map_err(|e| e.message)
}

#[test]
fn non_bool_condition_is_an_error() {
    assert!(ty("fn f(n: int) -> int:\n    require n\n    n\n").is_err());
    assert!(ty("fn f(n: int) -> int:\n    require n > 0\n    n\n").is_ok());
}

#[test]
fn arithmetic_on_a_bool_is_an_error() {
    assert!(ty("fn f() -> int = 1 + true").is_err());
}

#[test]
fn wrong_argument_type_is_an_error() {
    let src = "fn g(x: int) -> int = x\nfn f() -> int = g(true)";
    assert!(ty(src).is_err());
}

#[test]
fn unknown_field_on_a_known_component_is_an_error() {
    let src = "data Health: hp: 0...100, max: 0...100\n\
               system s():\n\
               \x20   for e with Health:\n\
               \x20       e.Health.bogus = 1\n";
    assert!(ty(src).is_err());
}

#[test]
fn return_type_mismatch_is_an_error() {
    assert!(ty("fn f() -> int = true").is_err());
    assert!(ty("fn f() -> bool = 1 < 2").is_ok());
}

#[test]
fn unannotated_types_are_gradual() {
    // No annotations -> Unknown -> compatible with everything (no false errors).
    assert!(ty("fn id(x) = x\nfn f() -> int = id(5)").is_ok());
}

#[test]
fn float_promotion_is_allowed() {
    // an int flows into a float parameter
    assert!(ty("fn g(x: f64) -> f64 = x\nfn f() -> f64 = g(3)").is_ok());
}
