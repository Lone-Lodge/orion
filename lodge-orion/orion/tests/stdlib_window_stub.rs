//! Tests for the `window` orb — verifies the API parses, registers, and
//! reports its backend status. We do NOT actually open a window from
//! tests (that would steal focus on dev machines and hang headless CI);
//! the live `examples/hello_window.or` is the manual smoke test.

use orion::interp::Interp;
use orion::stdlib;
use orion::value::Value;

#[test]
fn window_ready_reports_platform_backend() {
    let pkg = stdlib::find("window").expect("window");
    let src = format!("{}\nfn f() -> bool = window_ready()\n", pkg.source);
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (pkg.register)(&interp);
    // True on Windows where the Win32 backend is wired; false on other
    // platforms until Cocoa/Wayland land.
    let expected = cfg!(windows);
    assert_eq!(interp.call("f", vec![]).unwrap(), Value::Bool(expected));
}

#[test]
fn orion_code_can_branch_on_window_ready() {
    let pkg = stdlib::find("window").expect("window");
    // Graceful-degrade pattern users will write to support headless runs.
    let src = format!(
        "{}\nfn f() -> int:\n    if window_ready() then run() else fallback()\n\
         fn run() -> int = 1\nfn fallback() -> int = 99\n",
        pkg.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (pkg.register)(&interp);
    let expected = if cfg!(windows) { 1 } else { 99 };
    assert_eq!(interp.call("f", vec![]).unwrap(), Value::Int(expected));
}

#[test]
fn window_orb_is_in_the_registry() {
    let names: Vec<&str> = stdlib::ORBS.iter().map(|p| p.name).collect();
    assert!(names.contains(&"window"), "window orb missing: {names:?}");
}

#[test]
fn gpu_orb_is_in_the_registry() {
    let names: Vec<&str> = stdlib::ORBS.iter().map(|p| p.name).collect();
    assert!(names.contains(&"gpu"), "gpu orb missing: {names:?}");
}
