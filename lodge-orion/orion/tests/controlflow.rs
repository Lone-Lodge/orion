//! Tests for loop / break / continue and the statement `if`.

use orion::check::check;
use orion::interp::Interp;
use orion::value::Value;
use orion::{lex, parse};

fn run(src: &str) -> Value {
    Interp::new(&parse(&lex(src).unwrap()).unwrap())
        .call("f", vec![])
        .unwrap()
}

#[test]
fn break_outside_a_loop_is_a_compile_error() {
    let p = parse(&lex("fn f() -> int:\n    break\n    0\n").unwrap()).unwrap();
    assert!(check(&p).is_err());
}

#[test]
fn break_inside_a_loop_is_fine() {
    let p = parse(&lex("fn f() -> int:\n    loop:\n        break\n    0\n").unwrap()).unwrap();
    assert!(check(&p).is_ok());
}

#[test]
fn loop_with_break() {
    // smallest i with i*i > 20 is 5 (25 > 20)
    let src = "fn f() -> int:\n    mut i = 0\n    loop:\n        i += 1\n        if i * i > 20:\n            break\n    i\n";
    assert_eq!(run(src), Value::Int(5));
}

#[test]
fn continue_skips_the_rest_of_the_body() {
    // sum the even numbers in 0..=10 by `continue`-ing on odds
    let src = "fn f() -> int:\n    mut s = 0\n    for i in 0...10:\n        if i % 2 == 1:\n            continue\n        s += i\n    s\n";
    assert_eq!(run(src), Value::Int(30)); // 0+2+4+6+8+10
}

#[test]
fn statement_if_else() {
    let src = "fn f() -> int:\n    mut x = 0\n    if 1 < 2:\n        x = 10\n    else:\n        x = 20\n    x\n";
    assert_eq!(run(src), Value::Int(10));
}

#[test]
fn break_out_of_a_for_loop() {
    // stop at the first element >= 3
    let src = "fn f() -> int:\n    mut found = 0\n    for i in 0...100:\n        if i >= 3:\n            found = i\n            break\n    found\n";
    assert_eq!(run(src), Value::Int(3));
}
