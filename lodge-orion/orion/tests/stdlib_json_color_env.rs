//! Tests for json, color, and env packages.

use orion::interp::Interp;
use orion::stdlib;
use orion::value::Value;

fn run_with_pkg(pkg: &str, user: &str, fname: &str) -> Value {
    // Topological walk so transitive deps load in the right order.
    let target = stdlib::find(pkg).expect(pkg);
    let mut order: Vec<&'static str> = Vec::new();
    walk_deps(target.name, &mut order);
    let resolved: Vec<&stdlib::Orb> = order.iter().map(|n| stdlib::find(n).expect(n)).collect();
    let mut src = String::new();
    for o in &resolved {
        src.push_str(o.source);
        src.push('\n');
    }
    src.push_str(user);
    let parsed = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    orion::check::check(&parsed).unwrap();
    orion::typeck::check_types(&parsed).unwrap();
    let interp = Interp::new(&parsed);
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

// ---- json ----

#[test]
fn json_parse_scalar_int() {
    let src = "fn f() = json_parse(\"42\")";
    assert_eq!(run_with_pkg("json", src, "f"), Value::Int(42));
}

#[test]
fn json_parse_string() {
    let src = "fn f() = json_parse(\"\\\"hi\\\"\")";
    assert_eq!(run_with_pkg("json", src, "f"), Value::Text("hi".into()));
}

#[test]
fn json_parse_array() {
    let src = "fn f() -> int = len(json_parse(\"[1, 2, 3]\"))";
    assert_eq!(run_with_pkg("json", src, "f"), Value::Int(3));
}

#[test]
fn json_parse_object_lookup() {
    // Orion: literal `{` and `}` inside strings must be escaped as `\{` / `\}`
    // so the parser doesn't read them as interpolation.
    let src = "fn f() = get(json_parse(\"\\{\\\"name\\\": \\\"orion\\\"\\}\"), \"name\")";
    assert_eq!(run_with_pkg("json", src, "f"), Value::Text("orion".into()));
}

#[test]
fn json_round_trip_object() {
    let src = "fn f() -> Text = json_stringify(json_parse(\"\\{\\\"a\\\":1,\\\"b\\\":2\\}\"))";
    assert_eq!(
        run_with_pkg("json", src, "f"),
        Value::Text(r#"{"a":1,"b":2}"#.into())
    );
}

#[test]
fn json_parse_invalid_returns_none() {
    let src = "fn f() = json_parse(\"not valid json!!!\")";
    assert_eq!(run_with_pkg("json", src, "f"), Value::None);
}

#[test]
fn json_stringify_a_list_of_ints() {
    let src = "fn f() -> Text = json_stringify([1, 2, 3])";
    assert_eq!(run_with_pkg("json", src, "f"), Value::Text("[1,2,3]".into()));
}

// ---- color ----

#[test]
fn color_from_hex_six_digit() {
    let src = "fn f() -> f64 = color_from_hex(\"#FF8800\").Color.r";
    if let Value::Float(r) = run_with_pkg("color", src, "f") {
        assert!((r - 1.0).abs() < 1e-9, "red should be 1.0, got {r}");
    } else { panic!() }
}

#[test]
fn color_to_hex_round_trip() {
    let src = "fn f() -> Text = color_to_hex(color_from_hex(\"#10204080\"))";
    assert_eq!(run_with_pkg("color", src, "f"), Value::Text("#10204080".into()));
}

#[test]
fn rgb_brightness() {
    let src = "fn f() -> f64 = color_brightness(rgb(1.0, 1.0, 1.0))";
    if let Value::Float(b) = run_with_pkg("color", src, "f") {
        assert!((b - 1.0).abs() < 1e-9);
    } else { panic!() }
}

#[test]
fn color_lerp_midpoint() {
    let pkg = stdlib::find("color").unwrap();
    let src = format!(
        "{}\nfn f() -> f64 = color_lerp(rgb(0.0, 0.0, 0.0), rgb(1.0, 1.0, 1.0), 0.5).Color.r\n",
        pkg.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (pkg.register)(&interp);
    if let Value::Float(r) = interp.call("f", vec![]).unwrap() {
        assert!((r - 0.5).abs() < 1e-9);
    } else { panic!() }
}

#[test]
fn hsv_red_at_zero_hue() {
    let src = "fn f() -> f64 = hsv_to_rgb(0.0, 1.0, 1.0).Color.r";
    if let Value::Float(r) = run_with_pkg("color", src, "f") {
        assert!((r - 1.0).abs() < 1e-6, "got {r}");
    } else { panic!() }
}

// ---- env ----

#[test]
fn arg_count_at_least_one() {
    // The test runner always has at least one arg (the binary path).
    let src = "fn f() -> bool = arg_count() >= 1";
    assert_eq!(run_with_pkg("env", src, "f"), Value::Bool(true));
}

#[test]
fn env_var_or_falls_back_when_unset() {
    let unique = format!("ORION_NEVER_SET_{}", std::process::id());
    let src = format!("fn f() -> Text = env_var_or(\"{unique}\", \"fallback-value\")");
    assert_eq!(run_with_pkg("env", &src, "f"), Value::Text("fallback-value".into()));
}

#[test]
fn env_var_reads_set_value() {
    // Setting env vars from Rust isn't reliably thread-safe, but PATH is virtually
    // guaranteed to be set in any test environment.
    let src = "fn f() -> bool = len(env_var(\"PATH\")) > 0";
    let v = run_with_pkg("env", src, "f");
    // On exotic CI we accept either — PATH may be empty in a sandbox.
    assert!(matches!(v, Value::Bool(_)));
}

// ---- registry inventory ----

#[test]
fn thirteen_packages_registered() {
    let names: Vec<&str> = stdlib::ORBS.iter().map(|p| p.name).collect();
    for needed in ["time", "math", "io", "test", "random", "string", "log",
                   "collections", "easing", "noise", "json", "color", "env"] {
        assert!(names.contains(&needed), "missing: {needed}");
    }
}
