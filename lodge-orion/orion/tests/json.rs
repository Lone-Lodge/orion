//! Tests for the tiny JSON parser/encoder used by `orion-lsp`.

use orion::json::{Value, parse};

#[test]
fn parses_primitives() {
    assert_eq!(parse("null").unwrap(), Value::Null);
    assert_eq!(parse("true").unwrap(), Value::Bool(true));
    assert_eq!(parse("false").unwrap(), Value::Bool(false));
    assert_eq!(parse("42").unwrap(), Value::Int(42));
    assert_eq!(parse("-7").unwrap(), Value::Int(-7));
    assert_eq!(parse("3.14").unwrap(), Value::Float(3.14));
    assert_eq!(parse("\"hi\"").unwrap(), Value::Str("hi".into()));
}

#[test]
fn parses_string_escapes() {
    let v = parse(r#""line\nbreak""#).unwrap();
    assert_eq!(v, Value::Str("line\nbreak".into()));
    let v = parse(r#""quoted: \"x\"""#).unwrap();
    assert_eq!(v, Value::Str("quoted: \"x\"".into()));
}

#[test]
fn parses_arrays_and_objects() {
    let v = parse(r#"[1, 2, "three"]"#).unwrap();
    let Value::Array(items) = v else {
        panic!("expected array");
    };
    assert_eq!(items.len(), 3);

    let v = parse(r#"{ "method": "initialize", "id": 1 }"#).unwrap();
    assert_eq!(v.get("method").unwrap().as_str(), Some("initialize"));
    assert_eq!(v.get("id").unwrap().as_int(), Some(1));
}

#[test]
fn parses_nested_lsp_request() {
    let src = r#"{
        "jsonrpc": "2.0",
        "id": 7,
        "method": "textDocument/hover",
        "params": {
            "textDocument": {"uri": "file:///tmp/x.or"},
            "position": {"line": 3, "character": 10}
        }
    }"#;
    let v = parse(src).unwrap();
    assert_eq!(v.get("method").unwrap().as_str(), Some("textDocument/hover"));
    let pos = v.get("params").unwrap().get("position").unwrap();
    assert_eq!(pos.get("line").unwrap().as_int(), Some(3));
    assert_eq!(pos.get("character").unwrap().as_int(), Some(10));
}

#[test]
fn round_trips_through_to_string() {
    let src = r#"{"id":1,"jsonrpc":"2.0","method":"x"}"#;
    let v = parse(src).unwrap();
    // BTreeMap orders keys alphabetically — predictable output.
    assert_eq!(v.to_string(), src);
}

#[test]
fn empty_objects_and_arrays_round_trip() {
    assert_eq!(parse("{}").unwrap().to_string(), "{}");
    assert_eq!(parse("[]").unwrap().to_string(), "[]");
}

#[test]
fn floats_keep_their_decimal_point() {
    let v = Value::Float(1.0);
    assert_eq!(v.to_string(), "1.0");
}

#[test]
fn malformed_input_errors() {
    assert!(parse("{").is_err());
    assert!(parse("\"unterminated").is_err());
    assert!(parse("nope").is_err());
}
