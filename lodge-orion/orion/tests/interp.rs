//! Tests for the M2 interpreter. Run with `cargo test`.

use orion::interp::Interp;
use orion::value::Value;
use orion::{lex, parse};

fn run(src: &str, name: &str, args: Vec<Value>) -> Result<Value, String> {
    let program = parse(&lex(src).unwrap()).unwrap();
    Interp::new(&program)
        .call(name, args)
        .map_err(|e| e.message)
}

#[test]
fn arithmetic_and_precedence() {
    let v = run("fn f(x: int) -> int = x * 2 + 1", "f", vec![Value::Int(10)]).unwrap();
    assert_eq!(v, Value::Int(21));
}

#[test]
fn if_expression() {
    let src = "fn clamp(v: int, lo: int, hi: int) -> int = if v < lo then lo else if v > hi then hi else v";
    assert_eq!(
        run(src, "clamp", vec![Value::Int(50), Value::Int(0), Value::Int(10)]).unwrap(),
        Value::Int(10)
    );
    assert_eq!(
        run(src, "clamp", vec![Value::Int(-3), Value::Int(0), Value::Int(10)]).unwrap(),
        Value::Int(0)
    );
}

#[test]
fn recursion() {
    let src = "fn fib(n: int) -> int = if n < 2 then n else fib(n - 1) + fib(n - 2)";
    assert_eq!(run(src, "fib", vec![Value::Int(10)]).unwrap(), Value::Int(55));
}

#[test]
fn builtin_and_float_promotion() {
    // sqrt(3*3 + 4*4) == 5.0
    let src = "fn hyp(a: f32, b: f32) -> f32 = sqrt(a * a + b * b)";
    assert_eq!(
        run(src, "hyp", vec![Value::Int(3), Value::Int(4)]).unwrap(),
        Value::Float(5.0)
    );
}

#[test]
fn contract_failure_is_an_error() {
    // The `require` fails for a non-positive amount.
    let src = "fn check_amount(amount: int):\n    require amount > 0\n";
    assert!(run(src, "check_amount", vec![Value::Int(0)]).is_err());
    assert!(run(src, "check_amount", vec![Value::Int(5)]).is_ok());
}

#[test]
fn print_builtin_returns_unit() {
    // `print` outputs its argument and yields Unit (the value programs can finally
    // produce visible output with).
    assert_eq!(run("fn f() = print(42)", "f", vec![]).unwrap(), Value::Unit);
}

#[test]
fn default_argument_is_used() {
    let src = "fn inc(x: int, by: int = 1) -> int = x + by";
    assert_eq!(run(src, "inc", vec![Value::Int(10)]).unwrap(), Value::Int(11));
    assert_eq!(
        run(src, "inc", vec![Value::Int(10), Value::Int(5)]).unwrap(),
        Value::Int(15)
    );
}
