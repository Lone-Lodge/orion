//! Tests for string interpolation. Run with `cargo test`.

use orion::interp::Interp;
use orion::value::Value;
use orion::{lex, parse};

fn run(src: &str, name: &str) -> Value {
    Interp::new(&parse(&lex(src).unwrap()).unwrap())
        .call(name, vec![])
        .unwrap()
}

#[test]
fn interpolates_a_variable() {
    let src = "fn m(n: int) -> Text = \"n is {n}\"\nfn demo() -> Text = m(5)";
    assert_eq!(run(src, "demo"), Value::Text("n is 5".into()));
}

#[test]
fn interpolates_an_expression() {
    assert_eq!(run("fn demo() -> Text = \"{2 + 3}!\"", "demo"), Value::Text("5!".into()));
}

#[test]
fn a_plain_string_is_unchanged() {
    assert_eq!(run("fn demo() -> Text = \"hello\"", "demo"), Value::Text("hello".into()));
}
