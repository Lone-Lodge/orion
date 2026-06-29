//! Tests for the M4 Cranelift JIT. Run with `cargo test`.
//!
//! These compile Orion functions to native machine code and call them, asserting
//! the native result matches the interpreter.

use orion::jit::Jit;
use orion::{lex, parse};

fn jit_run(src: &str, name: &str, args: &[i64]) -> i64 {
    let program = parse(&lex(src).unwrap()).unwrap();
    let mut jit = Jit::new().unwrap();
    let cf = jit.compile(&program, name).unwrap();
    jit.run_int(cf.id, args).unwrap()
}

fn jit_run_float(src: &str, name: &str, args: &[f64]) -> f64 {
    let program = parse(&lex(src).unwrap()).unwrap();
    let mut jit = Jit::new().unwrap();
    let cf = jit.compile(&program, name).unwrap();
    jit.run_float(cf.id, args).unwrap()
}

#[test]
fn native_arithmetic() {
    assert_eq!(jit_run("fn double(x: int) -> int = x * 2 + 1", "double", &[10]), 21);
}

#[test]
fn native_if() {
    let src = "fn clamp(v: int, lo: int, hi: int) -> int = if v < lo then lo else if v > hi then hi else v";
    assert_eq!(jit_run(src, "clamp", &[50, 0, 10]), 10);
    assert_eq!(jit_run(src, "clamp", &[-3, 0, 10]), 0);
    assert_eq!(jit_run(src, "clamp", &[5, 0, 10]), 5);
}

#[test]
fn native_recursion() {
    let src = "fn fib(n: int) -> int = if n < 2 then n else fib(n - 1) + fib(n - 2)";
    assert_eq!(jit_run(src, "fib", &[10]), 55);
    assert_eq!(jit_run(src, "fib", &[20]), 6765);
}

#[test]
fn native_floats() {
    // hyp(3, 4) == 5.0, compiled with fadd/fmul/fsqrt and int->float promotion.
    let src = "fn hyp(a: f64, b: f64) -> f64 = sqrt(a * a + b * b)";
    assert_eq!(jit_run_float(src, "hyp", &[3.0, 4.0]), 5.0);
}

#[test]
fn compiles_only_reachable_functions() {
    // `hyp` uses floats/sqrt (unsupported in M4), but compiling `fib` must still
    // succeed because `hyp` is unreachable from it.
    let src = "fn fib(n: int) -> int = if n < 2 then n else fib(n - 1) + fib(n - 2)\n\
               fn hyp(a: f32, b: f32) -> f32 = sqrt(a * a + b * b)";
    assert_eq!(jit_run(src, "fib", &[15]), 610);
}
