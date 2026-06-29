//! Tests for the random, string, and log packages.

use orion::interp::Interp;
use orion::stdlib;
use orion::value::Value;

fn run_with_pkg(pkg_name: &str, user: &str, fname: &str) -> Value {
    // Topological dep walk so transitive deps (e.g. log → format → bytes)
    // all load when the package depends on others.
    let target = stdlib::find(pkg_name).expect(pkg_name);
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

// ---- random ----

#[test]
fn random_int_is_in_range() {
    let src = "\
fn f() -> int:
    seed(42)
    mut acc = 0
    for i in 0..<100:
        n = random_int(10, 20)
        if n >= 10 and n < 20:
            acc += 1
    acc
";
    assert_eq!(run_with_pkg("random", src, "f"), Value::Int(100));
}

#[test]
fn random_float_is_in_unit_interval() {
    let src = "\
fn f() -> int:
    seed(1)
    mut acc = 0
    for i in 0..<100:
        x = random_float()
        if x >= 0.0 and x < 1.0:
            acc += 1
    acc
";
    assert_eq!(run_with_pkg("random", src, "f"), Value::Int(100));
}

#[test]
fn seed_makes_runs_deterministic() {
    let pkg = stdlib::find("random").unwrap();
    let src = format!("{}\nfn f(s: int) -> f64:\n    seed(s)\n    random_float()\n", pkg.source);
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();

    let i1 = Interp::new(&p);
    (pkg.register)(&i1);
    let r1 = i1.call("f", vec![Value::Int(123)]).unwrap();

    let i2 = Interp::new(&p);
    (pkg.register)(&i2);
    let r2 = i2.call("f", vec![Value::Int(123)]).unwrap();

    assert_eq!(r1, r2, "same seed should give same first draw");
}

#[test]
fn random_range_respects_bounds() {
    let src = "\
fn f() -> int:
    seed(7)
    mut ok = 0
    for i in 0..<200:
        x = random_range(-3.0, 3.0)
        if x >= -3.0 and x < 3.0:
            ok += 1
    ok
";
    assert_eq!(run_with_pkg("random", src, "f"), Value::Int(200));
}

// ---- string ----

#[test]
fn str_split_basic() {
    let src = "fn f() -> int = len(str_split(\"a,b,c\", \",\"))";
    assert_eq!(run_with_pkg("string", src, "f"), Value::Int(3));
}

#[test]
fn str_trim_removes_whitespace() {
    let src = "fn f() -> Text = str_trim(\"  hi  \")";
    assert_eq!(run_with_pkg("string", src, "f"), Value::Text("hi".into()));
}

#[test]
fn str_replace_substitutes() {
    let src = "fn f() -> Text = str_replace(\"hello world\", \"world\", \"orion\")";
    assert_eq!(run_with_pkg("string", src, "f"), Value::Text("hello orion".into()));
}

#[test]
fn str_case_conversion() {
    let src = "fn up() -> Text = str_upper(\"hi\")\nfn lo() -> Text = str_lower(\"HI\")";
    assert_eq!(run_with_pkg("string", src, "up"), Value::Text("HI".into()));
    assert_eq!(run_with_pkg("string", src, "lo"), Value::Text("hi".into()));
}

#[test]
fn str_predicates() {
    let src = "fn a() -> bool = str_starts_with(\"hello\", \"hel\")\nfn b() -> bool = str_ends_with(\"hello\", \"lo\")\nfn c() -> bool = str_contains(\"hello\", \"ll\")";
    assert_eq!(run_with_pkg("string", src, "a"), Value::Bool(true));
    assert_eq!(run_with_pkg("string", src, "b"), Value::Bool(true));
    assert_eq!(run_with_pkg("string", src, "c"), Value::Bool(true));
}

#[test]
fn str_parse_numbers() {
    let pkg = stdlib::find("string").unwrap();
    let src = format!(
        "{}\nfn i() -> int = str_to_int(\"42\")\nfn f() -> f64 = str_to_float(\"3.14\")\n",
        pkg.source
    );
    let _ = src;
    let inline = "fn i() -> int = str_to_int(\"42\")\nfn f() -> f64 = str_to_float(\"3.14\")";
    assert_eq!(run_with_pkg("string", inline, "i"), Value::Int(42));
    assert_eq!(run_with_pkg("string", inline, "f"), Value::Float(3.14));
}

#[test]
fn str_join_with_separator() {
    let src = "fn f() -> Text = str_join([\"a\", \"b\", \"c\"], \"-\")";
    assert_eq!(run_with_pkg("string", src, "f"), Value::Text("a-b-c".into()));
}

#[test]
fn str_repeat_works() {
    let src = "fn f() -> Text = str_repeat(\"ab\", 3)";
    assert_eq!(run_with_pkg("string", src, "f"), Value::Text("ababab".into()));
}

// ---- log ----

#[test]
fn log_can_be_called_without_crashing() {
    let src = "\
fn f():
    set_log_level(3)
    log_error(\"boom\")
    log_warn(\"hmm\")
    log_info(\"hi\")
    log_debug(\"detail\")
";
    assert_eq!(run_with_pkg("log", src, "f"), Value::Unit);
}

// ---- registry ----

#[test]
fn seven_packages_registered() {
    let names: Vec<&str> = stdlib::ORBS.iter().map(|p| p.name).collect();
    for needed in ["time", "math", "io", "test", "random", "string", "log"] {
        assert!(names.contains(&needed), "missing package: {needed}");
    }
}
