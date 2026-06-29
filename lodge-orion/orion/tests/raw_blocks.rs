//! Tests for the §4 `raw:` escape hatch — Rust's `unsafe` equivalent in Orion.

use orion::interp::Interp;
use orion::value::Value;
use orion::{lex, parse};

fn parse_check(src: &str) -> orion::ast::Program {
    let p = parse(&lex(src).unwrap()).unwrap();
    orion::check::check(&p).unwrap();
    orion::typeck::check_types(&p).unwrap();
    p
}

#[test]
fn raw_block_parses_and_runs_normal_code() {
    let src = "\
fn f() -> int:
    raw:
        x = 1 + 2
        x * 10
";
    let p = parse_check(src);
    let r = Interp::new(&p).call("f", vec![]).unwrap();
    assert_eq!(r, Value::Int(30));
}

#[test]
fn raw_block_relaxes_move_checking() {
    // Outside `raw`, this would normally be flagged by ownership.rs (we're
    // forwarding a value that the linter treats as moved). Inside `raw`, the
    // checker leaves it alone — caller takes responsibility (§4).
    let src = "\
fn consume(s: take Text) -> int = 0
fn use_after_take(s: Text) -> int:
    raw:
        a = consume(s)
        b = consume(s)
        a + b

fn f() -> int = use_after_take(\"hi\")
";
    let p = parse_check(src);
    let r = Interp::new(&p).call("f", vec![]).unwrap();
    assert_eq!(r, Value::Int(0));
}

#[test]
fn raw_can_call_extern_fns_as_ffi_surface() {
    // `extern fn` is the FFI surface; a `raw` block is the natural place to
    // call it from. The host registers the implementation.
    let src = "\
extern fn os_pid() -> int

fn current_pid() -> int:
    raw:
        os_pid()

fn f() -> int = current_pid()
";
    let p = parse_check(src);
    let interp = Interp::new(&p);
    interp.register_extern("os_pid", |_| Ok(Value::Int(std::process::id() as i64)));
    let r = interp.call("f", vec![]).unwrap();
    let Value::Int(pid) = r else { panic!("expected int") };
    assert!(pid > 0);
}

#[test]
fn nested_raw_in_loop_works() {
    let src = "\
fn f() -> int:
    mut sum = 0
    for i in 0..<5:
        raw:
            sum += i
    sum
";
    let p = parse_check(src);
    let r = Interp::new(&p).call("f", vec![]).unwrap();
    // 0+1+2+3+4 = 10
    assert_eq!(r, Value::Int(10));
}

#[test]
fn raw_block_returns_tail_value() {
    let src = "\
fn f() -> int:
    raw:
        100 + 23
";
    let p = parse_check(src);
    let r = Interp::new(&p).call("f", vec![]).unwrap();
    assert_eq!(r, Value::Int(123));
}
