//! Tests for numeric / list `for` loops. Run with `cargo test`.

use orion::interp::Interp;
use orion::value::Value;
use orion::{lex, parse};

fn run(src: &str) -> Value {
    Interp::new(&parse(&lex(src).unwrap()).unwrap())
        .call("f", vec![])
        .unwrap()
}

#[test]
fn inclusive_range_loop() {
    let src = "fn f() -> int:\n    mut s = 0\n    for i in 0...10:\n        s += i\n    s\n";
    assert_eq!(run(src), Value::Int(55));
}

#[test]
fn exclusive_range_loop() {
    let src = "fn f() -> int:\n    mut s = 0\n    for i in 0..<5:\n        s += i\n    s\n";
    assert_eq!(run(src), Value::Int(10));
}

#[test]
fn loop_over_a_list() {
    let src = "fn f() -> int:\n    mut s = 0\n    for x in [10, 20, 30]:\n        s += x\n    s\n";
    assert_eq!(run(src), Value::Int(60));
}
