//! Tests for the `hex` orb — lowercase hex encode/decode for byte arrays.
//!
//! The orb lives in `orbs/hex/lib.or` (pure Orion on top of `bytes`).
//! `orbs/hex/LEARN.md` retells how it was built — useful when authoring
//! a new orb from scratch.

use orion::interp::Interp;
use orion::stdlib;
use orion::value::Value;

fn run(user: &str, fname: &str) -> Value {
    let resolved: Vec<&stdlib::Orb> = ["bytes", "hex"]
        .iter()
        .map(|n| stdlib::find(n).expect(n))
        .collect();
    let mut src = String::new();
    for o in &resolved {
        src.push_str(o.source);
        src.push('\n');
    }
    src.push_str(user);
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    orion::check::check(&p).unwrap();
    orion::typeck::check_types(&p).unwrap();
    let interp = Interp::new(&p);
    for o in &resolved {
        (o.register)(&interp);
    }
    interp.call(fname, vec![]).unwrap()
}

#[test]
fn hex_encode_two_bytes() {
    let src = "fn f() -> Text = hex_encode([72, 105])";
    assert_eq!(run(src, "f"), Value::Text("4869".into()));
}

#[test]
fn hex_encode_is_lowercase() {
    let src = "fn f() -> Text = hex_encode([255, 0, 171])";
    assert_eq!(run(src, "f"), Value::Text("ff00ab".into()));
}

#[test]
fn hex_encode_empty() {
    let src = "fn f() -> Text = hex_encode([])";
    assert_eq!(run(src, "f"), Value::Text("".into()));
}

#[test]
fn hex_decode_round_trip() {
    let src = "fn f() -> int = len(hex_decode(hex_encode([1, 2, 3, 4, 5])))";
    assert_eq!(run(src, "f"), Value::Int(5));
}

#[test]
fn hex_decode_is_case_insensitive() {
    let src = "fn f() -> int = at(hex_decode(\"FF00aB\"), 0)";
    assert_eq!(run(src, "f"), Value::Int(255));
}

#[test]
fn hex_decode_odd_length_returns_empty() {
    let src = "fn f() -> int = len(hex_decode(\"4\"))";
    assert_eq!(run(src, "f"), Value::Int(0));
}

#[test]
fn hex_orb_is_registered() {
    let names: Vec<&str> = stdlib::ORBS.iter().map(|o| o.name).collect();
    assert!(names.contains(&"hex"), "hex orb should be registered");
}
