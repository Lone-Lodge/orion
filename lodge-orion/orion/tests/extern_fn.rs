//! Tests for `extern fn` — the FFI seam. A host registers a callback by name;
//! Orion calls into it like any other fn.

use orion::interp::Interp;
use orion::value::Value;
use orion::{lex, parse};

#[test]
fn extern_fn_parses_and_checks() {
    // No body — host provides the impl.
    let src = "extern fn host_draw(x: f64, y: f64)\nfn caller() = host_draw(1.0, 2.0)\n";
    let p = parse(&lex(src).unwrap()).unwrap();
    orion::check::check(&p).unwrap();
    orion::typeck::check_types(&p).unwrap();
}

#[test]
fn calling_unregistered_extern_is_a_runtime_error() {
    let src = "extern fn missing() -> int\nfn f() -> int = missing()\n";
    let p = parse(&lex(src).unwrap()).unwrap();
    let err = Interp::new(&p).call("f", vec![]).unwrap_err();
    assert!(err.message.contains("no registered impl"));
}

#[test]
fn host_can_register_extern_and_orion_can_call_it() {
    let src = "extern fn host_add(a: int, b: int) -> int\nfn f() -> int = host_add(3, 4)\n";
    let p = parse(&lex(src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    interp.register_extern("host_add", |args| {
        let (a, b) = match (&args[0], &args[1]) {
            (Value::Int(a), Value::Int(b)) => (*a, *b),
            _ => panic!("expected ints"),
        };
        Ok(Value::Int(a + b))
    });
    assert_eq!(interp.call("f", vec![]).unwrap(), Value::Int(7));
}

#[test]
fn extern_fn_can_have_side_effects() {
    use std::sync::{Arc, Mutex};
    let src = "extern fn log(msg: Text)\nfn f():\n    log(\"hello\")\n    log(\"world\")\n";
    let p = parse(&lex(src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    let captured: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
    let cap = captured.clone();
    interp.register_extern("log", move |args| {
        if let Value::Text(s) = &args[0] {
            cap.lock().unwrap().push(s.clone());
        }
        Ok(Value::Unit)
    });
    interp.call("f", vec![]).unwrap();
    assert_eq!(*captured.lock().unwrap(), vec!["hello", "world"]);
}

#[test]
fn pub_extern_visible_across_modules_is_fine() {
    // privacy applies the same way as any other fn.
    let src = "\
pub extern fn sin(x: f64) -> f64
fn f() -> f64 = sin(0.0)
";
    let p = parse(&lex(src).unwrap()).unwrap();
    orion::check::check(&p).unwrap();
}
