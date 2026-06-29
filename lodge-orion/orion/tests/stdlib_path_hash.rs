//! Tests for path and hash packages.

use orion::interp::Interp;
use orion::stdlib;
use orion::value::Value;

fn run_with_pkg(pkg: &str, user: &str, fname: &str) -> Value {
    let target = stdlib::find(pkg).expect(pkg);
    let mut order: Vec<&'static str> = Vec::new();
    walk_deps(target.name, &mut order);
    let names: Vec<&'static str> = order.into_iter().collect();
    run_with_pkgs(&names, user, fname)
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

fn run_with_pkgs(pkgs: &[&str], user: &str, fname: &str) -> Value {
    let resolved: Vec<&stdlib::Orb> = pkgs.iter().map(|n| stdlib::find(n).expect(n)).collect();
    let mut src = String::new();
    for p in &resolved {
        src.push_str(p.source);
        src.push('\n');
    }
    src.push_str(user);
    let parsed = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    orion::check::check(&parsed).unwrap();
    orion::typeck::check_types(&parsed).unwrap();
    let interp = Interp::new(&parsed);
    for p in &resolved {
        (p.register)(&interp);
    }
    interp.call(fname, vec![]).unwrap()
}

// ---- path ----

#[test]
fn path_join_works() {
    let src = "fn f() -> Text = path_join(\"a\", \"b.txt\")";
    let v = run_with_pkg("path", src, "f");
    if let Value::Text(s) = v {
        assert!(s.ends_with("b.txt"), "got {s}");
        assert!(s.starts_with('a'), "got {s}");
    } else { panic!() }
}

#[test]
fn path_parent_strips_last() {
    let src = "fn f() -> Text = path_parent(\"/usr/local/bin\")";
    let v = run_with_pkg("path", src, "f");
    if let Value::Text(s) = v {
        assert!(s.ends_with("local") || s.ends_with("local/"), "got {s}");
    } else { panic!() }
}

#[test]
fn path_filename_extracts() {
    let src = "fn f() -> Text = path_filename(\"/usr/local/main.or\")";
    assert_eq!(run_with_pkg("path", src, "f"), Value::Text("main.or".into()));
}

#[test]
fn path_stem_drops_extension() {
    let src = "fn f() -> Text = path_stem(\"main.or\")";
    assert_eq!(run_with_pkg("path", src, "f"), Value::Text("main".into()));
}

#[test]
fn path_extension_extracts() {
    let src = "fn f() -> Text = path_extension(\"main.or\")";
    assert_eq!(run_with_pkg("path", src, "f"), Value::Text("or".into()));
}

#[test]
fn path_is_absolute_detects_root() {
    let abs_path = if cfg!(windows) { "C:\\\\Users" } else { "/usr/bin" };
    let src = format!(
        "fn rel() -> bool = path_is_absolute(\"foo/bar\")\nfn abs() -> bool = path_is_absolute(\"{abs_path}\")"
    );
    assert_eq!(run_with_pkg("path", &src, "rel"), Value::Bool(false));
    assert_eq!(run_with_pkg("path", &src, "abs"), Value::Bool(true));
}

#[test]
fn path_normalize_resolves_dotdot() {
    let src = "fn f() -> Text = path_normalize(\"a/b/../c\")";
    let v = run_with_pkg("path", src, "f");
    if let Value::Text(s) = v {
        // Either forward or backslash, but no `..` after normalization.
        assert!(!s.contains(".."), "{s} still has ..");
        assert!(s.contains("c"), "{s} should end with c");
    } else { panic!() }
}

#[test]
fn current_dir_returns_something() {
    let src = "fn f() -> int = len(current_dir())";
    if let Value::Int(n) = run_with_pkg("path", src, "f") {
        assert!(n > 0);
    } else { panic!() }
}

// ---- hash ----

// hash is pure Orion now and depends on the bytes orb for bytes_from_text.
#[test]
fn hash_text_is_deterministic() {
    let src = "fn f() -> int = hash_text(\"orion\")";
    let a = run_with_pkgs(&["bytes", "hash"], src, "f");
    let b = run_with_pkgs(&["bytes", "hash"], src, "f");
    assert_eq!(a, b);
}

#[test]
fn hash_text_differs_for_different_inputs() {
    let src = "fn a() -> int = hash_text(\"orion\")\nfn b() -> int = hash_text(\"rion\")";
    let a = run_with_pkgs(&["bytes", "hash"], src, "a");
    let b = run_with_pkgs(&["bytes", "hash"], src, "b");
    assert_ne!(a, b);
}


#[test]
fn hash_int_is_pure() {
    let pkg = stdlib::find("hash").unwrap();
    let src = format!("{}\nfn f(n: int) -> int = hash_int(n)\n", pkg.source);
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (pkg.register)(&interp);
    let a = interp.call("f", vec![Value::Int(42)]).unwrap();
    let b = interp.call("f", vec![Value::Int(42)]).unwrap();
    assert_eq!(a, b);
}

#[test]
fn hash_combine_is_order_sensitive() {
    let pkg = stdlib::find("hash").unwrap();
    let src = format!(
        "{}\nfn ab() -> int = hash_combine(1, 2)\nfn ba() -> int = hash_combine(2, 1)\n",
        pkg.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (pkg.register)(&interp);
    let ab = interp.call("ab", vec![]).unwrap();
    let ba = interp.call("ba", vec![]).unwrap();
    assert_ne!(ab, ba);
}

// ---- registry ----

#[test]
fn fifteen_packages_registered() {
    let names: Vec<&str> = stdlib::ORBS.iter().map(|p| p.name).collect();
    for needed in ["time", "math", "io", "test", "random", "string", "log",
                   "collections", "easing", "noise", "json", "color", "env",
                   "path", "hash"] {
        assert!(names.contains(&needed), "missing: {needed}");
    }
}
