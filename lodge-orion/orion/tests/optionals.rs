//! Tests for optionals — `none`, `else`, and `get`. Run with `cargo test`.

use orion::interp::Interp;
use orion::value::Value;
use orion::{lex, parse};

fn run(src: &str) -> Value {
    Interp::new(&parse(&lex(src).unwrap()).unwrap())
        .call("f", vec![])
        .unwrap()
}

#[test]
fn missing_key_falls_back_to_default() {
    assert_eq!(run("fn f() -> int = get({1: 10}, 2) else 99"), Value::Int(99));
}

#[test]
fn present_value_passes_through_else() {
    assert_eq!(run("fn f() -> int = get({1: 10}, 1) else 99"), Value::Int(10));
}

#[test]
fn none_literal_falls_back() {
    assert_eq!(run("fn f() -> int = none else 7"), Value::Int(7));
}

#[test]
fn a_present_value_ignores_else() {
    assert_eq!(run("fn f() -> int = 5 else 99"), Value::Int(5));
}

// ----- ?. (safe field access) -----

fn run_world(src: &str) -> Value {
    Interp::new(&parse(&lex(src).unwrap()).unwrap())
        .call("f", vec![])
        .unwrap()
}

#[test]
fn safe_field_on_present_component_reads_the_value() {
    // `e?.Health?.hp` on an entity that has Health reads hp.
    let src = "\
data Health: hp: int
fn f() -> int:
    e = spawn Health{hp: 42}
    e?.Health?.hp else 0
";
    assert_eq!(run_world(src), Value::Int(42));
}

#[test]
fn safe_field_on_missing_component_yields_none() {
    // The entity has Position, not Health — `e?.Health?.hp` is none, so `else` fires.
    let src = "\
data Position: x: int, y: int
data Health: hp: int
fn f() -> int:
    e = spawn Position{x: 0, y: 0}
    e?.Health?.hp else -1
";
    assert_eq!(run_world(src), Value::Int(-1));
}

#[test]
fn safe_field_keeps_full_value_when_present() {
    // `?.` is just sugar on the way down; reading a present chain returns the value.
    let src = "\
data Health: hp: int
fn f() -> int:
    e = spawn Health{hp: 7}
    e?.Health?.hp
";
    assert_eq!(run_world(src), Value::Int(7));
}
