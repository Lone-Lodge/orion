//! End-to-end test for `orion link`: takes Orion source, produces a standalone
//! executable, runs it, checks the output. Skipped if no driver (rustc or cc)
//! is available — this matches CI environments without Rust toolchain.

use std::path::PathBuf;
use std::process::Command;

use orion::ast::Program;

fn parse_src(src: &str) -> Program {
    let toks = orion::lex(src).unwrap();
    let p = orion::parse(&toks).unwrap();
    orion::check::check(&p).unwrap();
    orion::typeck::check_types(&p).unwrap();
    p
}

fn driver_available() -> bool {
    let cmd_exists = |name: &str| {
        Command::new(name).arg("--version").output().is_ok()
    };
    cmd_exists("rustc") || cmd_exists("cc") || cmd_exists("gcc") || cmd_exists("clang")
}

fn tmp_path(name: &str) -> PathBuf {
    let dir = std::env::temp_dir().join(format!("orion_link_test_{}", std::process::id()));
    let _ = std::fs::create_dir_all(&dir);
    dir.join(name)
}

#[test]
fn link_produces_runnable_int_executable() {
    if !driver_available() {
        eprintln!("no compiler driver on PATH — skipping");
        return;
    }
    let p = parse_src("\
fn fib(n: int) -> int:
    mut a = 0
    mut b = 1
    for i in 0..<n:
        t = a + b
        a = b
        b = t
    a
");
    let out = tmp_path(if cfg!(windows) { "fib_test.exe" } else { "fib_test" });
    let out_str = out.to_str().unwrap();
    orion::link::build_executable(&p, "fib", out_str).expect("link should succeed");

    let r = Command::new(&out).arg("10").output().expect("run");
    assert!(r.status.success());
    assert_eq!(String::from_utf8_lossy(&r.stdout).trim(), "55");

    let r = Command::new(&out).arg("20").output().expect("run");
    assert_eq!(String::from_utf8_lossy(&r.stdout).trim(), "6765");

    let _ = std::fs::remove_file(&out);
}

#[test]
fn link_produces_runnable_float_executable() {
    if !driver_available() {
        eprintln!("no compiler driver on PATH — skipping");
        return;
    }
    let p = parse_src("fn add_one(x: f64) -> f64 = x + 1.0");
    let out = tmp_path(if cfg!(windows) { "addone_test.exe" } else { "addone_test" });
    let out_str = out.to_str().unwrap();
    orion::link::build_executable(&p, "add_one", out_str).expect("link should succeed");

    let r = Command::new(&out).arg("2.5").output().expect("run");
    assert!(r.status.success());
    let stdout = String::from_utf8_lossy(&r.stdout);
    let val: f64 = stdout.trim().parse().expect("output should be a number");
    assert!((val - 3.5).abs() < 1e-9);

    let _ = std::fs::remove_file(&out);
}

#[test]
fn link_rejects_text_param() {
    // Text/list params can't go through the C ABI yet; should fail gracefully.
    let p = parse_src("fn echo(s: Text) -> int = 0");
    let out = tmp_path("never.exe");
    let r = orion::link::build_executable(&p, "echo", out.to_str().unwrap());
    assert!(r.is_err());
    assert!(r.unwrap_err().contains("not linkable"));
}
