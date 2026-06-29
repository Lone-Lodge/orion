//! Tests for collections — maps and list operations. Run with `cargo test`.

use orion::interp::Interp;
use orion::value::Value;
use orion::{lex, parse};

fn run(src: &str) -> Value {
    Interp::new(&parse(&lex(src).unwrap()).unwrap())
        .call("f", vec![])
        .unwrap()
}

#[test]
fn map_get_or_hit() {
    assert_eq!(run("fn f() -> int = get_or({\"a\": 10, \"b\": 20}, \"b\", 0)"), Value::Int(20));
}

#[test]
fn map_get_or_default() {
    assert_eq!(run("fn f() -> int = get_or({\"a\": 1}, \"z\", 99)"), Value::Int(99));
}

#[test]
fn map_set_then_has() {
    assert_eq!(run("fn f() -> bool = has(set({}, \"x\", 1), \"x\")"), Value::Bool(true));
}

#[test]
fn map_len() {
    assert_eq!(run("fn f() -> int = len({1: 10, 2: 20, 3: 30})"), Value::Int(3));
}

#[test]
fn list_push_and_at() {
    assert_eq!(run("fn f() -> int = at(push([1, 2], 3), 2)"), Value::Int(3));
}

#[test]
fn list_len() {
    assert_eq!(run("fn f() -> int = len([10, 20, 30])"), Value::Int(3));
}
