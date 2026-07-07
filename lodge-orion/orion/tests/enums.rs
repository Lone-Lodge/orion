//! Tests for enums + match. Run with `cargo test`.

use orion::interp::Interp;
use orion::typeck::check_types;
use orion::value::Value;
use orion::{lex, parse};

fn run(src: &str, name: &str) -> Value {
    Interp::new(&parse(&lex(src).unwrap()).unwrap())
        .call(name, vec![])
        .unwrap()
}

fn ty(src: &str) -> Result<(), String> {
    check_types(&parse(&lex(src).unwrap()).unwrap()).map_err(|e| e.message)
}

const COLOR: &str = "enum Color:\n\
\x20   Red\n\
\x20   Green\n\
\x20   Blue\n\
fn code(c: Color) -> int:\n\
\x20   match c:\n\
\x20       Red -> 1\n\
\x20       Green -> 2\n\
\x20       Blue -> 3\n\
fn demo() -> int = code(Green)\n";

#[test]
fn match_evaluates() {
    assert_eq!(run(COLOR, "demo"), Value::Int(2));
}

#[test]
fn payload_is_bound_by_the_pattern() {
    let src = "enum Shape:\n\
\x20   Circle(int)\n\
\x20   Empty\n\
fn radius(s: Shape) -> int:\n\
\x20   match s:\n\
\x20       Circle(x) -> x\n\
\x20       Empty -> 0\n\
fn demo() -> int = radius(Circle(7))\n";
    assert_eq!(run(src, "demo"), Value::Int(7));
}

#[test]
fn non_exhaustive_match_is_a_type_error() {
    let src = "enum Color:\n\
\x20   Red\n\
\x20   Green\n\
\x20   Blue\n\
fn code(c: Color) -> int:\n\
\x20   match c:\n\
\x20       Red -> 1\n\
\x20       Green -> 2\n";
    assert!(ty(src).is_err());
}

#[test]
fn wildcard_makes_a_match_exhaustive() {
    let src = "enum Color:\n\
\x20   Red\n\
\x20   Green\n\
\x20   Blue\n\
fn code(c: Color) -> int:\n\
\x20   match c:\n\
\x20       Red -> 1\n\
\x20       _ -> 0\n";
    assert!(ty(src).is_ok());
}

#[test]
fn wrong_variant_payload_type_is_an_error() {
    let src = "enum Box:\n\
\x20   Num(int)\n\
fn make() -> Box = Num(true)\n";
    assert!(ty(src).is_err());
}
