//! Tests for the builtin stdlib. Run with `cargo test`.

use orion::interp::Interp;
use orion::typeck::check_types;
use orion::value::Value;
use orion::{lex, parse};

fn val(src: &str) -> Value {
    let p = parse(&lex(src).unwrap()).unwrap();
    Interp::new(&p).call("f", vec![]).unwrap()
}

fn ty(src: &str) -> Result<(), String> {
    check_types(&parse(&lex(src).unwrap()).unwrap()).map_err(|e| e.message)
}

#[test]
fn clamp_keeps_int() {
    assert_eq!(val("fn f() -> int = clamp(15, 0, 10)"), Value::Int(10));
    assert_eq!(val("fn f() -> int = clamp(-3, 0, 10)"), Value::Int(0));
}

#[test]
fn pow_and_floor_and_sign() {
    assert_eq!(val("fn f() -> f64 = pow(2.0, 10.0)"), Value::Float(1024.0));
    assert_eq!(val("fn f() -> f64 = floor(3.7)"), Value::Float(3.0));
    assert_eq!(val("fn f() -> int = sign(0 - 5)"), Value::Int(-1));
}

#[test]
fn len_of_text() {
    assert_eq!(val("fn f() -> int = len(\"hello\")"), Value::Int(5));
}

#[test]
fn len_of_a_number_is_a_type_error() {
    assert!(ty("fn f() -> int = len(5)").is_err());
}

#[test]
fn trig_returns_float() {
    if let Value::Float(x) = val("fn f() -> f64 = sin(0.0)") {
        assert!(x.abs() < 1e-12);
    } else { panic!("sin should return float"); }
    if let Value::Float(x) = val("fn f() -> f64 = cos(0.0)") {
        assert!((x - 1.0).abs() < 1e-12);
    } else { panic!("cos should return float"); }
}

#[test]
fn atan2_two_args() {
    // atan2(1, 1) = pi/4
    if let Value::Float(x) = val("fn f() -> f64 = atan2(1.0, 1.0)") {
        assert!((x - std::f64::consts::FRAC_PI_4).abs() < 1e-12);
    } else { panic!("atan2 should return float"); }
}

#[test]
fn exp_and_ln_roundtrip() {
    // ln(exp(2)) ~ 2
    if let Value::Float(x) = val("fn f() -> f64 = ln(exp(2.0))") {
        assert!((x - 2.0).abs() < 1e-12);
    } else { panic!("ln(exp(x)) should return float"); }
}

#[test]
fn log2_of_power_of_two() {
    if let Value::Float(x) = val("fn f() -> f64 = log2(1024.0)") {
        assert!((x - 10.0).abs() < 1e-12);
    } else { panic!("log2 should return float"); }
}

#[test]
fn math_builtin_takes_numbers_only() {
    assert!(ty("fn f() -> f64 = sin(\"oops\")").is_err());
}

#[test]
fn sign_returns_int_even_for_floats() {
    // sign : number -> int
    assert!(ty("fn f() -> int = sign(2.5)").is_ok());
}
