//! Tests for csv, base64, and the math orb's Mat4 expansion.

use orion::interp::Interp;
use orion::stdlib;
use orion::value::Value;

fn run_with_orb(orb: &str, user: &str, fname: &str) -> Value {
    // Pull declared deps in too so pure-Orion orbs that delegate to bytes
    // still resolve here.
    let target = stdlib::find(orb).expect(orb);
    let mut chain: Vec<&str> = target.deps.iter().copied().collect();
    chain.push(orb);
    run_with_orbs(&chain, user, fname)
}

fn run_with_orbs(orbs: &[&str], user: &str, fname: &str) -> Value {
    let resolved: Vec<&stdlib::Orb> = orbs.iter().map(|n| stdlib::find(n).expect(n)).collect();
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

// ---- csv ----

#[test]
fn csv_parse_three_row_table() {
    let src = r#"fn f() -> int = len(csv_parse("a,b,c\n1,2,3\n4,5,6\n"))"#;
    assert_eq!(run_with_orb("csv", src, "f"), Value::Int(3));
}

#[test]
fn csv_parse_handles_quoted_fields() {
    // The middle cell has a comma inside quotes.
    let src = r#"fn f() -> int = len(at(csv_parse("a,\"b,still b\",c\n"), 0))"#;
    assert_eq!(run_with_orb("csv", src, "f"), Value::Int(3));
}

#[test]
fn csv_round_trip() {
    let src = "\
fn f() -> Text:
    rows = csv_parse(\"a,b\\n1,2\\n\")
    csv_serialize(rows)
";
    assert_eq!(run_with_orb("csv", src, "f"), Value::Text("a,b\n1,2\n".into()));
}

#[test]
fn csv_serialize_quotes_commas() {
    let src = r#"fn f() -> Text = csv_serialize([["hello, world", "ok"]])"#;
    let v = run_with_orb("csv", src, "f");
    if let Value::Text(s) = v {
        assert!(s.starts_with("\"hello, world\""), "got {s}");
    } else { panic!() }
}

// ---- base64 ----

// base64 is pure Orion now and depends on the bytes orb for byte_at /
// bytes_from_text / bytes_to_text — list both when loading.
#[test]
fn base64_encode_known_string() {
    let src = "fn f() -> Text = base64_encode(\"Hello\")";
    assert_eq!(run_with_orbs(&["bytes", "base64"], src, "f"), Value::Text("SGVsbG8=".into()));
}

#[test]
fn base64_decode_known_string() {
    let src = "fn f() -> Text = base64_decode(\"SGVsbG8=\")";
    assert_eq!(run_with_orbs(&["bytes", "base64"], src, "f"), Value::Text("Hello".into()));
}

#[test]
fn base64_round_trip() {
    let src = "fn f() -> Text = base64_decode(base64_encode(\"orion engine\"))";
    assert_eq!(run_with_orbs(&["bytes", "base64"], src, "f"), Value::Text("orion engine".into()));
}

#[test]
fn base64_padding_one_char() {
    // 1 byte -> 2 base64 chars + ==
    let src = "fn f() -> Text = base64_encode(\"a\")";
    assert_eq!(run_with_orbs(&["bytes", "base64"], src, "f"), Value::Text("YQ==".into()));
}

// Walk the canonical RFC 4648 padding ladder (Section 10): "" through "foobar"
// covers 0, 1, and 2 trailing bytes in both encode and decode paths.
#[test]
fn base64_rfc4648_vectors() {
    let vectors: &[(&str, &str)] = &[
        ("", ""),
        ("f", "Zg=="),
        ("fo", "Zm8="),
        ("foo", "Zm9v"),
        ("foob", "Zm9vYg=="),
        ("fooba", "Zm9vYmE="),
        ("foobar", "Zm9vYmFy"),
    ];
    for (plain, encoded) in vectors {
        let enc_src = format!("fn f() -> Text = base64_encode(\"{plain}\")");
        assert_eq!(
            run_with_orbs(&["bytes", "base64"], &enc_src, "f"),
            Value::Text((*encoded).into()),
            "encode({plain:?})",
        );
        let dec_src = format!("fn f() -> Text = base64_decode(\"{encoded}\")");
        assert_eq!(
            run_with_orbs(&["bytes", "base64"], &dec_src, "f"),
            Value::Text((*plain).into()),
            "decode({encoded:?})",
        );
    }
}

// ---- mat4 ----

#[test]
fn mat4_identity_is_16_floats() {
    let src = "fn f() -> int = len(mat4_identity())";
    assert_eq!(run_with_orb("math", src, "f"), Value::Int(16));
}

#[test]
fn mat4_identity_diagonal_is_1() {
    let orb = stdlib::find("math").unwrap();
    let src = format!("{}\nfn f(i: int) -> f64 = at(mat4_identity(), i)\n", orb.source);
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (orb.register)(&interp);
    for idx in &[0, 5, 10, 15] {
        assert_eq!(
            interp.call("f", vec![Value::Int(*idx)]).unwrap(),
            Value::Float(1.0),
            "diagonal index {idx} should be 1.0"
        );
    }
    for idx in &[1, 2, 3, 4] {
        assert_eq!(
            interp.call("f", vec![Value::Int(*idx)]).unwrap(),
            Value::Float(0.0),
            "off-diagonal {idx} should be 0.0"
        );
    }
}

#[test]
fn mat4_translate_carries_translation() {
    // Column-major: translation lives in m[12..14].
    let orb = stdlib::find("math").unwrap();
    let src = format!(
        "{}\nfn x() -> f64 = at(mat4_translate(5.0, 7.0, 9.0), 12)\nfn y() -> f64 = at(mat4_translate(5.0, 7.0, 9.0), 13)\nfn z() -> f64 = at(mat4_translate(5.0, 7.0, 9.0), 14)\n",
        orb.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (orb.register)(&interp);
    assert_eq!(interp.call("x", vec![]).unwrap(), Value::Float(5.0));
    assert_eq!(interp.call("y", vec![]).unwrap(), Value::Float(7.0));
    assert_eq!(interp.call("z", vec![]).unwrap(), Value::Float(9.0));
}

#[test]
fn mat4_identity_times_anything_is_anything() {
    let orb = stdlib::find("math").unwrap();
    // mul(identity, translate(5)) == translate(5)
    let src = format!(
        "{}\nfn f() -> f64 = at(mat4_mul(mat4_identity(), mat4_translate(5.0, 0.0, 0.0)), 12)\n",
        orb.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (orb.register)(&interp);
    assert_eq!(interp.call("f", vec![]).unwrap(), Value::Float(5.0));
}

#[test]
fn mat4_transform_translates_point() {
    let orb = stdlib::find("math").unwrap();
    let src = format!(
        "{}\nfn f() -> f64:\n    m = mat4_translate(10.0, 0.0, 0.0)\n    p = mat4_transform_point(m, 1.0, 2.0, 3.0)\n    at(p, 0)\n",
        orb.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (orb.register)(&interp);
    assert_eq!(interp.call("f", vec![]).unwrap(), Value::Float(11.0));
}

#[test]
fn mat4_rotate_y_at_90_swaps_axes() {
    let orb = stdlib::find("math").unwrap();
    // 90deg rotation around Y sends (1,0,0) to roughly (0,0,-1).
    let src = format!(
        "{}\nfn f() -> f64:\n    m = mat4_rotate_y(1.5707963267948966)\n    p = mat4_transform_point(m, 1.0, 0.0, 0.0)\n    at(p, 2)\n",
        orb.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (orb.register)(&interp);
    if let Value::Float(z) = interp.call("f", vec![]).unwrap() {
        assert!((z - (-1.0)).abs() < 1e-9, "expected ~-1, got {z}");
    } else { panic!() }
}

// ---- registry ----

#[test]
fn csv_base64_math_are_in_the_registry() {
    let names: Vec<&str> = stdlib::ORBS.iter().map(|o| o.name).collect();
    for needed in ["csv", "base64", "math"] {
        assert!(names.contains(&needed), "missing: {needed}");
    }
}
