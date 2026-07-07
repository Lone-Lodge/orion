//! Tests for the ownership (move) checker. Run with `cargo test`.

use orion::ownership::check;
use orion::{lex, parse};

fn mv(src: &str) -> Result<(), String> {
    check(&parse(&lex(src).unwrap()).unwrap()).map_err(|e| e.message)
}

const CONSUME: &str = "fn consume(x: take int) -> int = x\n";

#[test]
fn use_after_move_is_an_error() {
    let src = format!("{CONSUME}fn bad() -> int:\n    t = 5\n    consume(t)\n    consume(t)\n");
    assert!(mv(&src).is_err());
}

#[test]
fn a_single_move_is_fine() {
    let src = format!("{CONSUME}fn ok() -> int:\n    t = 5\n    consume(t)\n");
    assert!(mv(&src).is_ok());
}

#[test]
fn rebinding_after_a_move_is_fine() {
    let src = format!("{CONSUME}fn ok() -> int:\n    mut t = 5\n    consume(t)\n    t = 9\n    consume(t)\n");
    assert!(mv(&src).is_ok());
}

#[test]
fn a_read_parameter_does_not_consume() {
    // passing to a non-`take` parameter leaves the value usable
    let src = "fn read(x: int) -> int = x\nfn ok() -> int:\n    t = 5\n    read(t)\n    read(t)\n";
    assert!(mv(src).is_ok());
}

#[test]
fn use_after_conditional_move_is_an_error() {
    // moved on one branch -> using it afterwards is flagged conservatively
    let src = format!(
        "{CONSUME}fn f(b: bool) -> int:\n    t = 5\n    if b then consume(t) else 0\n    consume(t)\n"
    );
    assert!(mv(&src).is_err());
}
