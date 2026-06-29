//! Tests for M7 AOT object emission. Run with `cargo test`.

use orion::aot::compile_object;
use orion::{lex, parse};

#[test]
fn emits_a_native_object_file() {
    let program = parse(&lex("fn fib(n: int) -> int = if n < 2 then n else fib(n-1) + fib(n-2)").unwrap())
        .unwrap();

    let mut path = std::env::temp_dir();
    path.push("orion_aot_test_fib.o");
    let out = path.to_str().unwrap();

    let bytes = compile_object(&program, "fib", out).unwrap();
    assert!(bytes > 64, "object file should be non-trivial, got {bytes} bytes");

    let on_disk = std::fs::read(out).unwrap();
    assert_eq!(on_disk.len(), bytes);

    let _ = std::fs::remove_file(out);
}
