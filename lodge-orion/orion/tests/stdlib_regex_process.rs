//! Tests for the regex and process orbs.

use orion::interp::Interp;
use orion::stdlib;
use orion::value::Value;

fn run_with_orb(orb: &str, user: &str, fname: &str) -> Value {
    // Topological dep walk so pure-Orion orbs that delegate to bytes still
    // resolve when loaded by these isolation tests.
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

// ---- regex / glob ----

#[test]
fn glob_star_matches_run() {
    let src = r#"fn f() -> bool = match_glob("hello.or", "*.or")"#;
    assert_eq!(run_with_orb("regex", src, "f"), Value::Bool(true));
}

#[test]
fn glob_question_matches_single_char() {
    let src = r#"fn f() -> bool = match_glob("cat", "c?t")"#;
    assert_eq!(run_with_orb("regex", src, "f"), Value::Bool(true));
}

#[test]
fn glob_question_rejects_zero_chars() {
    let src = r#"fn f() -> bool = match_glob("ct", "c?t")"#;
    assert_eq!(run_with_orb("regex", src, "f"), Value::Bool(false));
}

#[test]
fn glob_extension_match() {
    let src = "fn a() -> bool = match_glob(\"main.or\", \"*.or\")\nfn b() -> bool = match_glob(\"main.rs\", \"*.or\")";
    assert_eq!(run_with_orb("regex", src, "a"), Value::Bool(true));
    assert_eq!(run_with_orb("regex", src, "b"), Value::Bool(false));
}

#[test]
fn regex_literal_match() {
    let src = r#"fn f() -> bool = match_regex("orion engine", "engine")"#;
    assert_eq!(run_with_orb("regex", src, "f"), Value::Bool(true));
}

#[test]
fn regex_dot_matches_any() {
    let src = r#"fn f() -> bool = match_regex("car", "c.r")"#;
    assert_eq!(run_with_orb("regex", src, "f"), Value::Bool(true));
}

#[test]
fn regex_star_matches_zero_or_more() {
    let src = "fn a() -> bool = match_regex(\"aaab\", \"a*b\")\nfn b() -> bool = match_regex(\"b\", \"a*b\")";
    assert_eq!(run_with_orb("regex", src, "a"), Value::Bool(true));
    assert_eq!(run_with_orb("regex", src, "b"), Value::Bool(true));
}

#[test]
fn regex_class_range() {
    let src = r#"fn f() -> bool = match_regex("hello42", "[0-9]")"#;
    assert_eq!(run_with_orb("regex", src, "f"), Value::Bool(true));
}

#[test]
fn regex_anchor_at_start() {
    let src = "fn a() -> bool = match_regex(\"hello world\", \"^hello\")\nfn b() -> bool = match_regex(\"say hello\", \"^hello\")";
    assert_eq!(run_with_orb("regex", src, "a"), Value::Bool(true));
    assert_eq!(run_with_orb("regex", src, "b"), Value::Bool(false));
}

#[test]
fn regex_find_returns_match() {
    let src = r#"fn f() -> Text = regex_find("foo123bar", "[0-9]+")"#;
    assert_eq!(run_with_orb("regex", src, "f"), Value::Text("123".into()));
}

#[test]
fn regex_find_returns_empty_on_miss() {
    let src = r#"fn f() -> Text = regex_find("foobar", "[0-9]+")"#;
    assert_eq!(run_with_orb("regex", src, "f"), Value::Text(String::new()));
}

// ---- process ----

#[test]
fn run_command_returns_exit_code() {
    let pkg = stdlib::find("process").unwrap();
    // `cmd /c exit 0` on Windows, `true` on Unix.
    let (cmd, args) = if cfg!(windows) {
        ("cmd", vec!["/c", "exit", "0"])
    } else {
        ("true", vec![])
    };
    let args_lit = args.iter()
        .map(|a| format!("\"{a}\""))
        .collect::<Vec<_>>()
        .join(", ");
    let src = format!(
        "{}\nfn f() -> int = run_command(\"{cmd}\", [{args_lit}])\n",
        pkg.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (pkg.register)(&interp);
    assert_eq!(interp.call("f", vec![]).unwrap(), Value::Int(0));
}

#[test]
fn capture_stdout_returns_text() {
    let pkg = stdlib::find("process").unwrap();
    // `cmd /c echo hi` on Windows, `echo hi` on Unix.
    let (cmd, args) = if cfg!(windows) {
        ("cmd", vec!["/c", "echo", "hi"])
    } else {
        ("echo", vec!["hi"])
    };
    let args_lit = args.iter()
        .map(|a| format!("\"{a}\""))
        .collect::<Vec<_>>()
        .join(", ");
    let src = format!(
        "{}\nfn f() -> Text = capture_stdout(\"{cmd}\", [{args_lit}])\n",
        pkg.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (pkg.register)(&interp);
    if let Value::Text(s) = interp.call("f", vec![]).unwrap() {
        assert!(s.contains("hi"), "got: {s:?}");
    } else { panic!() }
}

#[test]
fn run_unknown_command_returns_negative() {
    let pkg = stdlib::find("process").unwrap();
    let src = format!(
        "{}\nfn f() -> int = run_command(\"this_command_does_not_exist_xyzqq\", [])\n",
        pkg.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (pkg.register)(&interp);
    assert_eq!(interp.call("f", vec![]).unwrap(), Value::Int(-1));
}

// ---- registry ----

#[test]
fn regex_and_process_are_registered() {
    let names: Vec<&str> = stdlib::ORBS.iter().map(|o| o.name).collect();
    assert!(names.contains(&"regex"));
    assert!(names.contains(&"process"));
}
