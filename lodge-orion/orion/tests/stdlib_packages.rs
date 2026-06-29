//! Tests for the bundled orbit packages: math, io, test.

use orion::interp::Interp;
use orion::stdlib;
use orion::value::Value;

fn run_with_pkg(pkg_name: &str, user: &str, fname: &str) -> Value {
    let pkg = stdlib::find(pkg_name).unwrap_or_else(|| panic!("package {pkg_name}"));
    let src = format!("{}\n{}", pkg.source, user);
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    orion::check::check(&p).unwrap();
    orion::typeck::check_types(&p).unwrap();
    let interp = Interp::new(&p);
    (pkg.register)(&interp);
    interp.call(fname, vec![]).unwrap()
}

// ---- math ----

#[test]
fn v2_arithmetic() {
    let src = "\
fn f() -> f64:
    a = v2(3.0, 4.0)
    v2_length(a)
";
    assert_eq!(run_with_pkg("math", src, "f"), Value::Float(5.0));
}

#[test]
fn v2_dot_product() {
    let src = "\
fn f() -> f64:
    a = v2(1.0, 2.0)
    b = v2(3.0, 4.0)
    v2_dot(a, b)
";
    assert_eq!(run_with_pkg("math", src, "f"), Value::Float(11.0));
}

#[test]
fn v2_normalize_unit_length() {
    let src = "\
fn f() -> f64:
    a = v2(3.0, 4.0)
    n = v2_normalize(a)
    v2_length(n)
";
    if let Value::Float(l) = run_with_pkg("math", src, "f") {
        assert!((l - 1.0).abs() < 1e-12, "got {l}");
    } else { panic!() }
}

#[test]
fn v3_cross_product_is_right_handed() {
    // x cross y = z
    let src = "\
fn f() -> f64:
    a = v3(1.0, 0.0, 0.0)
    b = v3(0.0, 1.0, 0.0)
    c = v3_cross(a, b)
    c.Vec3.z
";
    assert_eq!(run_with_pkg("math", src, "f"), Value::Float(1.0));
}

#[test]
fn deg_to_rad_round_trip() {
    let src = "\
fn f() -> f64:
    rad_to_deg(deg_to_rad(180.0))
";
    if let Value::Float(d) = run_with_pkg("math", src, "f") {
        assert!((d - 180.0).abs() < 1e-9, "got {d}");
    } else { panic!() }
}

#[test]
fn lerp_at_zero_and_one() {
    let src = "fn f() -> f64 = lerp(10.0, 20.0, 0.25)";
    assert_eq!(run_with_pkg("math", src, "f"), Value::Float(12.5));
}

// ---- io ----

#[test]
fn io_file_round_trip() {
    let tmp = std::env::temp_dir().join(format!("orion_io_test_{}.txt", std::process::id()));
    let path_str = tmp.to_str().unwrap().replace('\\', "\\\\");
    let src = format!("\
fn f() -> Text:
    write_file(\"{path_str}\", \"hello from orion\")
    read_file(\"{path_str}\")
");
    let v = run_with_pkg("io", &src, "f");
    assert_eq!(v, Value::Text("hello from orion".into()));
    let _ = std::fs::remove_file(&tmp);
}

#[test]
fn io_file_exists_false_then_true() {
    let tmp = std::env::temp_dir().join(format!("orion_io_exists_{}.txt", std::process::id()));
    let path = tmp.to_str().unwrap().replace('\\', "\\\\");
    let _ = std::fs::remove_file(&tmp);
    let src = format!("\
fn f() -> bool:
    before = file_exists(\"{path}\")
    write_file(\"{path}\", \"x\")
    after = file_exists(\"{path}\")
    not before and after
");
    let v = run_with_pkg("io", &src, "f");
    assert_eq!(v, Value::Bool(true));
    let _ = std::fs::remove_file(&tmp);
}

// ---- test framework ----

#[test]
fn assert_eq_int_passes_when_equal() {
    let src = "\
fn f():
    assert_eq_int(2 + 2, 4)
";
    assert_eq!(run_with_pkg("test", src, "f"), Value::Unit);
}

#[test]
fn assert_eq_int_fails_when_unequal() {
    let pkg = stdlib::find("test").unwrap();
    let src = format!("{}\nfn f(): assert_eq_int(2 + 2, 5)\n", pkg.source);
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    orion::check::check(&p).unwrap();
    let interp = Interp::new(&p);
    let err = interp.call("f", vec![]).unwrap_err();
    assert!(err.message.contains("require"), "got: {}", err.message);
}

#[test]
fn assert_near_uses_tolerance() {
    let src = "\
fn f():
    assert_near(3.14159, 3.14, 0.01)
";
    assert_eq!(run_with_pkg("test", src, "f"), Value::Unit);
}

#[test]
fn assert_in_range_inclusive() {
    let src = "\
fn f():
    assert_in_range(0.5, 0.0, 1.0)
    assert_in_range(0.0, 0.0, 1.0)
    assert_in_range(1.0, 0.0, 1.0)
";
    assert_eq!(run_with_pkg("test", src, "f"), Value::Unit);
}

// ---- registry inventory ----

#[test]
fn all_four_packages_are_registered() {
    let names: Vec<&str> = stdlib::ORBS.iter().map(|p| p.name).collect();
    assert!(names.contains(&"time"));
    assert!(names.contains(&"math"));
    assert!(names.contains(&"io"));
    assert!(names.contains(&"test"));
}
