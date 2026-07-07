//! Tests for codegen-level type inference. Functions without explicit `-> T`
//! or `: T` annotations should still JIT correctly when the body pins the
//! type unambiguously.

use orion::jit::Jit;
use orion::{lex, parse};

fn jit_int(src: &str, fname: &str, args: &[i64]) -> i64 {
    let p = parse(&lex(src).unwrap()).unwrap();
    orion::check::check(&p).unwrap();
    let mut jit = Jit::new().unwrap();
    let cf = jit.compile(&p, fname).unwrap();
    jit.run_int(cf.id, args).unwrap()
}

fn jit_float(src: &str, fname: &str, args: &[f64]) -> f64 {
    let p = parse(&lex(src).unwrap()).unwrap();
    orion::check::check(&p).unwrap();
    let mut jit = Jit::new().unwrap();
    let cf = jit.compile(&p, fname).unwrap();
    jit.run_float(cf.id, args).unwrap()
}

#[test]
fn return_type_inferred_from_int_literal() {
    // No `-> int` annotation.
    let src = "fn f() = 42";
    assert_eq!(jit_int(src, "f", &[]), 42);
}

#[test]
fn return_type_inferred_from_float_literal() {
    let src = "fn f() = 3.14";
    assert!((jit_float(src, "f", &[]) - 3.14).abs() < 1e-9);
}

#[test]
fn return_type_inferred_from_binary_op() {
    let src = "fn f() = 1 + 2";
    assert_eq!(jit_int(src, "f", &[]), 3);
}

#[test]
fn return_type_inferred_via_float_in_binary() {
    // 1 + 2.0 promotes to float.
    let src = "fn f() = 1 + 2.0";
    assert!((jit_float(src, "f", &[]) - 3.0).abs() < 1e-9);
}

#[test]
fn param_type_inferred_as_int_by_default() {
    // No annotation on x; default Int.
    let src = "fn double(x) = x * 2";
    assert_eq!(jit_int(src, "double", &[7]), 14);
}

#[test]
fn param_type_inferred_as_float_from_usage() {
    // x is paired with 1.0 → infer Float.
    let src = "fn add_one(x) = x + 1.0";
    assert!((jit_float(src, "add_one", &[2.5]) - 3.5).abs() < 1e-9);
}

#[test]
fn return_inferred_from_block_tail() {
    // Block-form fn, no `-> int`. Tail is `a + b`, both ints.
    let src = "\
fn f():
    a = 10
    b = 5
    a + b
";
    assert_eq!(jit_int(src, "f", &[]), 15);
}

#[test]
fn return_inferred_from_call_to_annotated_fn() {
    let src = "\
fn double(x: int) -> int = x * 2
fn caller() = double(7)
";
    assert_eq!(jit_int(src, "caller", &[]), 14);
}

#[test]
fn fully_unannotated_loop_works() {
    // Realistic: a fib function with no annotations anywhere.
    let src = "\
fn fib(n):
    mut a = 0
    mut b = 1
    for i in 0..<n:
        t = a + b
        a = b
        b = t
    a
";
    assert_eq!(jit_int(src, "fib", &[10]), 55);
    assert_eq!(jit_int(src, "fib", &[20]), 6765);
}
