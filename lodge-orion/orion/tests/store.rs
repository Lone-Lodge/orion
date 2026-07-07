//! Tests for the M3 store-backed interpreter. Run with `cargo test`.

use orion::interp::Interp;
use orion::value::Value;
use orion::{lex, parse};

fn prog(src: &str) -> orion::ast::Program {
    parse(&lex(src).unwrap()).unwrap()
}

#[test]
fn spawn_and_for_query_count() {
    let src = "data Health: hp: 0...1000, max: 0...1000\n\
               fn demo() -> int:\n\
               \x20   spawn Health{hp: 10, max: 10}\n\
               \x20   spawn Health{hp: 3, max: 10}\n\
               \x20   spawn Health{hp: 1, max: 10}\n\
               \x20   mut wounded = 0\n\
               \x20   for e with Health where e.Health.hp < 5:\n\
               \x20       wounded += 1\n\
               \x20   wounded\n";
    let program = prog(src);
    let v = Interp::new(&program).call("demo", vec![]).unwrap();
    assert_eq!(v, Value::Int(2));
}

#[test]
fn comprehension_returns_a_list() {
    let src = "data Health: hp: 0...1000, max: 0...1000\n\
               fn low() -> [int]:\n\
               \x20   spawn Health{hp: 8, max: 10}\n\
               \x20   spawn Health{hp: 2, max: 10}\n\
               \x20   [e.Health.hp for e with Health where e.Health.hp < 5]\n";
    let program = prog(src);
    let v = Interp::new(&program).call("low", vec![]).unwrap();
    // After §8 packing the `hp` value comes back as Packed(U16) — the
    // declared type was `0...1000`. Widen to compare on the integer
    // value rather than the storage shape.
    let orion::value::Value::List(items) = v else { panic!("expected list, got {v:?}") };
    assert_eq!(items.len(), 1);
    assert_eq!(items[0].as_int(), Some(2));
}

#[test]
fn system_mutates_the_world_in_place() {
    let src = "data Health: hp: 0...1000, max: 0...1000\n\
               fn seed():\n\
               \x20   spawn Health{hp: 1, max: 10}\n\
               system regen(amount: int):\n\
               \x20   for e with Health:\n\
               \x20       e.Health.hp += amount\n\
               fn healthy() -> int:\n\
               \x20   mut n = 0\n\
               \x20   for e with Health where e.Health.hp >= 5:\n\
               \x20       n += 1\n\
               \x20   n\n";
    let program = prog(src);
    // One interpreter so the store persists between calls.
    let it = Interp::new(&program);
    it.call("seed", vec![]).unwrap();
    assert_eq!(it.call("healthy", vec![]).unwrap(), Value::Int(0)); // hp 1 < 5
    it.call("regen", vec![Value::Int(5)]).unwrap(); // hp -> 6
    assert_eq!(it.call("healthy", vec![]).unwrap(), Value::Int(1)); // hp 6 >= 5
}

#[test]
fn range_expression_makes_a_list() {
    let src = "fn r() -> [int] = 0...3";
    let program = prog(src);
    let v = Interp::new(&program).call("r", vec![]).unwrap();
    assert_eq!(
        v,
        Value::List(vec![Value::Int(0), Value::Int(1), Value::Int(2), Value::Int(3)])
    );
}
