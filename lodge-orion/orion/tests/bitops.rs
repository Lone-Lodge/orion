//! Tests for bitwise operators (& | ^ ~ << >>). Run through interp and JIT.

use orion::interp::Interp;
use orion::jit::Jit;
use orion::value::Value;
use orion::{lex, parse};

fn run(src: &str) -> Value {
    let p = parse(&lex(src).unwrap()).unwrap();
    orion::check::check(&p).unwrap();
    orion::typeck::check_types(&p).unwrap();
    Interp::new(&p).call("f", vec![]).unwrap()
}

fn jit_run(src: &str) -> i64 {
    let p = parse(&lex(src).unwrap()).unwrap();
    orion::check::check(&p).unwrap();
    let mut jit = Jit::new().unwrap();
    let cf = jit.compile(&p, "f").unwrap();
    jit.run_int(cf.id, &[]).unwrap()
}

// ---- interp ----

#[test]
fn bit_and_known_vector() {
    assert_eq!(run("fn f() -> int = 0xff & 0x0f"), Value::Int(0x0f));
}

#[test]
fn bit_or_known_vector() {
    assert_eq!(run("fn f() -> int = 0xf0 | 0x0f"), Value::Int(0xff));
}

#[test]
fn bit_xor_known_vector() {
    assert_eq!(run("fn f() -> int = 0xff ^ 0x0f"), Value::Int(0xf0));
}

#[test]
fn bit_not_inverts_bits() {
    // ~0 = -1 (two's complement, all bits set)
    assert_eq!(run("fn f() -> int = ~0"), Value::Int(-1));
}

#[test]
fn shl_doubles() {
    assert_eq!(run("fn f() -> int = 1 << 4"), Value::Int(16));
}

#[test]
fn shr_halves() {
    assert_eq!(run("fn f() -> int = 32 >> 2"), Value::Int(8));
}

#[test]
fn read_u32_be_via_bit_ops() {
    // Compose 0x89504E47 (PNG magic) from 4 bytes via shifts and ors.
    let src = "\
fn f() -> int:
    b0 = 137
    b1 = 80
    b2 = 78
    b3 = 71
    (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
";
    assert_eq!(run(src), Value::Int(0x89504E47));
}

#[test]
fn extract_byte_via_shift_and_mask() {
    // Extract the 3rd byte of 0xDEADBEEF.
    let src = "fn f() -> int = (0xDEADBEEF >> 8) & 0xff";
    assert_eq!(run(src), Value::Int(0xBE));
}

// ---- precedence ----

#[test]
fn shift_binds_tighter_than_or() {
    // `1 << 3 | 1 << 1` should parse as `(1 << 3) | (1 << 1)` = 8 | 2 = 10
    assert_eq!(run("fn f() -> int = 1 << 3 | 1 << 1"), Value::Int(10));
}

#[test]
fn and_binds_tighter_than_or() {
    // `0xF | 0x10 & 0x30` = `0xF | (0x10 & 0x30)` = 0xF | 0x10 = 0x1F
    assert_eq!(run("fn f() -> int = 0xF | 0x10 & 0x30"), Value::Int(0x1F));
}

#[test]
fn arithmetic_binds_tighter_than_shift() {
    // `1 + 2 << 1` = `(1 + 2) << 1` = 6
    assert_eq!(run("fn f() -> int = 1 + 2 << 1"), Value::Int(6));
}

// ---- typeck ----

#[test]
fn bit_op_on_float_is_a_type_error() {
    let src = "fn f() -> int = 1.0 & 1";
    let p = parse(&lex(src).unwrap()).unwrap();
    orion::check::check(&p).unwrap();
    let err = orion::typeck::check_types(&p).unwrap_err();
    assert!(err.message.contains("bitwise"));
}

#[test]
fn bit_not_on_float_is_a_type_error() {
    let src = "fn f() -> int = ~1.0";
    let p = parse(&lex(src).unwrap()).unwrap();
    let err = orion::typeck::check_types(&p).unwrap_err();
    assert!(err.message.contains("`~`"));
}

// ---- JIT ----

#[test]
fn jit_compiles_bit_and() {
    assert_eq!(jit_run("fn f() -> int = 0xff & 0x0f"), 0x0f);
}

#[test]
fn jit_compiles_bit_or() {
    assert_eq!(jit_run("fn f() -> int = 0xf0 | 0x0f"), 0xff);
}

#[test]
fn jit_compiles_bit_xor() {
    assert_eq!(jit_run("fn f() -> int = 0xff ^ 0x0f"), 0xf0);
}

#[test]
fn jit_compiles_shl() {
    assert_eq!(jit_run("fn f() -> int = 1 << 8"), 256);
}

#[test]
fn jit_compiles_shr() {
    assert_eq!(jit_run("fn f() -> int = 256 >> 4"), 16);
}

#[test]
fn jit_compiles_bit_not() {
    assert_eq!(jit_run("fn f() -> int = ~5"), !5i64);
}

#[test]
fn jit_compose_u32_be() {
    let src = "fn f() -> int = (137 << 24) | (80 << 16) | (78 << 8) | 71";
    assert_eq!(jit_run(src), 0x89504E47);
}
