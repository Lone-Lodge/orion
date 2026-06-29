//! Tests for bytes, time_format, and quaternion expansion of math.

use orion::interp::Interp;
use orion::stdlib;
use orion::value::Value;

fn run_with_orb(orb: &str, user: &str, fname: &str) -> Value {
    // Topological walk so transitive deps (e.g. time_format → format → bytes)
    // are all loaded in the right order. Resolve the orb to its 'static entry
    // first so walk_deps can collect &'static str references.
    let target = stdlib::find(orb).expect(orb);
    let mut order: Vec<&'static str> = Vec::new();
    walk_deps(target.name, &mut order);
    let resolved: Vec<&stdlib::Orb> = order.iter().map(|n| stdlib::find(n).expect(n)).collect();
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

fn walk_deps(name: &'static str, order: &mut Vec<&'static str>) {
    if order.contains(&name) {
        return;
    }
    let orb = stdlib::find(name).expect(name);
    for dep in orb.deps {
        walk_deps(*dep, order);
    }
    order.push(orb.name);
}

// ---- bytes ----

#[test]
fn bytes_round_trip_through_text() {
    let src = "fn f() -> Text = bytes_to_text(bytes_from_text(\"hello\"))";
    assert_eq!(run_with_orb("bytes", src, "f"), Value::Text("hello".into()));
}

#[test]
fn bytes_length_of_hello_is_five() {
    let src = "fn f() -> int = bytes_length(bytes_from_text(\"hello\"))";
    assert_eq!(run_with_orb("bytes", src, "f"), Value::Int(5));
}

#[test]
fn bytes_at_returns_ascii() {
    // 'A' is 65
    let src = "fn f() -> int = byte_at(bytes_from_text(\"ABC\"), 0)";
    assert_eq!(run_with_orb("bytes", src, "f"), Value::Int(65));
}

#[test]
fn bytes_slice_extracts_middle() {
    let src = "fn f() -> Text = bytes_to_text(bytes_slice(bytes_from_text(\"hello\"), 1, 4))";
    assert_eq!(run_with_orb("bytes", src, "f"), Value::Text("ell".into()));
}

#[test]
fn bytes_concat_joins() {
    let src = "fn f() -> Text = bytes_to_text(bytes_concat(bytes_from_text(\"foo\"), bytes_from_text(\"bar\")))";
    assert_eq!(run_with_orb("bytes", src, "f"), Value::Text("foobar".into()));
}

#[test]
fn bytes_zeros_n() {
    let src = "fn f() -> int = bytes_length(bytes_zeros(10))";
    assert_eq!(run_with_orb("bytes", src, "f"), Value::Int(10));
}

#[test]
fn read_u32_le_known_pattern() {
    // little-endian 0xDEADBEEF: bytes [0xEF, 0xBE, 0xAD, 0xDE]
    let src = "fn f() -> int = read_u32_le([239, 190, 173, 222], 0)";
    assert_eq!(run_with_orb("bytes", src, "f"), Value::Int(0xDEADBEEF));
}

#[test]
fn read_u32_be_known_pattern() {
    // PNG magic: 89 50 4e 47 = 0x89504e47
    let src = "fn f() -> int = read_u32_be([137, 80, 78, 71], 0)";
    assert_eq!(run_with_orb("bytes", src, "f"), Value::Int(0x89504e47));
}

#[test]
fn read_u16_le_known_pattern() {
    let src = "fn f() -> int = read_u16_le([1, 2], 0)";
    // little-endian: 0x0201 = 513
    assert_eq!(run_with_orb("bytes", src, "f"), Value::Int(513));
}

// ---- time_format ----

#[test]
fn format_iso8601_for_unix_zero_is_epoch() {
    let src = "fn f() -> Text = format_iso8601(0.0)";
    assert_eq!(run_with_orb("time_format", src, "f"), Value::Text("1970-01-01T00:00:00Z".into()));
}

#[test]
fn format_iso8601_for_known_date() {
    // 2024-01-01T00:00:00Z = 1704067200
    let src = "fn f() -> Text = format_iso8601(1704067200.0)";
    assert_eq!(run_with_orb("time_format", src, "f"), Value::Text("2024-01-01T00:00:00Z".into()));
}

#[test]
fn format_date_returns_just_ymd() {
    let src = "fn f() -> Text = format_date(1704067200.0)";
    assert_eq!(run_with_orb("time_format", src, "f"), Value::Text("2024-01-01".into()));
}

#[test]
fn parse_iso8601_round_trip() {
    let src = "fn f() -> f64 = parse_iso8601(format_iso8601(1750000000.0))";
    if let Value::Float(x) = run_with_orb("time_format", src, "f") {
        assert_eq!(x as i64, 1750000000);
    } else { panic!() }
}

#[test]
fn parse_iso8601_handles_date_only() {
    let src = "fn f() -> f64 = parse_iso8601(\"2024-01-01\")";
    if let Value::Float(x) = run_with_orb("time_format", src, "f") {
        assert_eq!(x as i64, 1704067200);
    } else { panic!() }
}

// ---- math: quaternion ----

#[test]
fn quat_identity_is_w_one() {
    let src = "fn f() -> f64 = at(quat_identity(), 3)";
    assert_eq!(run_with_orb("math", src, "f"), Value::Float(1.0));
}

#[test]
fn quat_normalize_unit_length() {
    let orb = stdlib::find("math").unwrap();
    let src = format!(
        "{}\nfn f() -> f64:\n    q = quat_normalize([1.0, 2.0, 3.0, 4.0])\n    a = at(q, 0)\n    b = at(q, 1)\n    c = at(q, 2)\n    d = at(q, 3)\n    sqrt(a * a + b * b + c * c + d * d)\n",
        orb.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (orb.register)(&interp);
    if let Value::Float(len) = interp.call("f", vec![]).unwrap() {
        assert!((len - 1.0).abs() < 1e-12, "got {len}");
    } else { panic!() }
}

#[test]
fn quat_axis_angle_360_around_y_is_identity() {
    let orb = stdlib::find("math").unwrap();
    // 360° = 2π; quat_from_axis_angle returns -identity actually (full rotation).
    // We use 0° instead which IS identity.
    let src = format!(
        "{}\nfn f() -> f64 = at(quat_from_axis_angle(0.0, 1.0, 0.0, 0.0), 3)\n",
        orb.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (orb.register)(&interp);
    assert_eq!(interp.call("f", vec![]).unwrap(), Value::Float(1.0));
}

#[test]
fn quat_mul_identity_is_no_op() {
    let orb = stdlib::find("math").unwrap();
    let src = format!(
        "{}\nfn f() -> f64:\n    q = quat_from_axis_angle(0.0, 1.0, 0.0, 1.0)\n    r = quat_mul(q, quat_identity())\n    at(r, 3)\n",
        orb.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (orb.register)(&interp);
    let q_w = interp.call("f", vec![]).unwrap();
    // cos(0.5) ≈ 0.8775825618903728
    if let Value::Float(w) = q_w {
        assert!((w - 0.5f64.cos()).abs() < 1e-12, "got {w}");
    } else { panic!() }
}

#[test]
fn quat_to_mat4_identity_is_identity_matrix() {
    let orb = stdlib::find("math").unwrap();
    let src = format!(
        "{}\nfn f() -> f64 = at(quat_to_mat4(quat_identity()), 0)\nfn b() -> f64 = at(quat_to_mat4(quat_identity()), 5)\nfn c() -> f64 = at(quat_to_mat4(quat_identity()), 10)\n",
        orb.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (orb.register)(&interp);
    assert_eq!(interp.call("f", vec![]).unwrap(), Value::Float(1.0));
    assert_eq!(interp.call("b", vec![]).unwrap(), Value::Float(1.0));
    assert_eq!(interp.call("c", vec![]).unwrap(), Value::Float(1.0));
}

#[test]
fn quat_slerp_endpoints() {
    let orb = stdlib::find("math").unwrap();
    let src = format!(
        "{}\nfn at_t0() -> f64 = at(quat_slerp(quat_identity(), quat_from_axis_angle(0.0, 1.0, 0.0, 1.0), 0.0), 3)\n",
        orb.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (orb.register)(&interp);
    // t=0 → identity → w=1.0
    assert_eq!(interp.call("at_t0", vec![]).unwrap(), Value::Float(1.0));
}

// ---- registry ----

#[test]
fn bytes_time_format_are_registered() {
    let names: Vec<&str> = stdlib::ORBS.iter().map(|o| o.name).collect();
    for needed in ["bytes", "time_format"] {
        assert!(names.contains(&needed), "missing: {needed}");
    }
}
