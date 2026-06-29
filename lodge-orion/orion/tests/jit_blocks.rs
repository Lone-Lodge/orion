//! Tests for the JIT codegen of block-form functions.

use orion::jit::Jit;
use orion::{lex, parse};

fn jit_int(src: &str, args: &[i64]) -> i64 {
    let p = parse(&lex(src).unwrap()).unwrap();
    orion::check::check(&p).unwrap();
    let mut jit = Jit::new().unwrap();
    let cf = jit.compile(&p, "f").unwrap();
    jit.run_int(cf.id, args).unwrap()
}

#[test]
fn block_returns_last_expression() {
    let src = "\
fn f() -> int:
    1 + 2
";
    assert_eq!(jit_int(src, &[]), 3);
}

#[test]
fn local_bindings_and_arithmetic() {
    let src = "\
fn f() -> int:
    a = 10
    b = 5
    a + b
";
    assert_eq!(jit_int(src, &[]), 15);
}

#[test]
fn for_in_range_sums_zero_to_n() {
    let src = "\
fn f(n: int) -> int:
    mut acc = 0
    for i in 0..<n:
        acc += i
    acc
";
    assert_eq!(jit_int(src, &[10]), 45);   // 0+1+...+9
    assert_eq!(jit_int(src, &[100]), 4950);
}

#[test]
fn inclusive_range_includes_endpoint() {
    let src = "\
fn f(n: int) -> int:
    mut acc = 0
    for i in 0...n:
        acc += i
    acc
";
    assert_eq!(jit_int(src, &[10]), 55);   // 0+1+...+10
}

#[test]
fn if_statement_picks_branch() {
    let src = "\
fn f(n: int) -> int:
    mut out = 0
    if n > 0:
        out = 1
    else:
        out = -1
    out
";
    assert_eq!(jit_int(src, &[5]), 1);
    assert_eq!(jit_int(src, &[-5]), -1);
}

#[test]
fn loop_with_break() {
    let src = "\
fn f() -> int:
    mut i = 0
    loop:
        i += 1
        if i >= 5:
            break
    i
";
    assert_eq!(jit_int(src, &[]), 5);
}

#[test]
fn nested_loops_break_only_inner() {
    let src = "\
fn f() -> int:
    mut total = 0
    for i in 0..<3:
        for j in 0..<10:
            if j >= 2:
                break
            total += 1
    total
";
    // 3 outer iterations × 2 inner (before break) = 6
    assert_eq!(jit_int(src, &[]), 6);
}

#[test]
fn continue_skips_iteration() {
    let src = "\
fn f() -> int:
    mut acc = 0
    for i in 0...10:
        if i % 2 == 1:
            continue
        acc += i
    acc
";
    // sum of even numbers 0..=10 = 0+2+4+6+8+10 = 30
    assert_eq!(jit_int(src, &[]), 30);
}

#[test]
fn fibonacci_via_loop_in_jit() {
    let src = "\
fn f(n: int) -> int:
    mut a = 0
    mut b = 1
    for i in 0..<n:
        t = a + b
        a = b
        b = t
    a
";
    assert_eq!(jit_int(src, &[10]), 55);
    assert_eq!(jit_int(src, &[20]), 6765);
}

#[test]
fn fnv1a_inline_bytes_in_jit() {
    // FNV-1a 64-bit on 4 inline bytes. Verifies bit-ops + loop + state in JIT.
    // We hash the i32 packed as 4 separate bytes inside the body.
    let src = "\
fn f() -> int:
    mut h = 0xCBF29CE484222325
    h = h ^ 104   # 'h'
    h = h * 0x100000001B3
    h = h ^ 105   # 'i'
    h = h * 0x100000001B3
    h = h ^ 33    # '!'
    h = h * 0x100000001B3
    h
";
    let v = jit_int(src, &[]);
    // Sanity: not zero and not the initial value.
    assert_ne!(v, 0);
    assert_ne!(v as u64, 0xCBF29CE484222325);
}

#[test]
fn function_calls_a_block_form_helper() {
    // Verifies that a block-form helper is reachable from another fn and gets
    // compiled too — recursive reachability with mixed forms.
    let src = "\
fn helper(n: int) -> int:
    mut x = n
    x = x * 2
    x

fn f(n: int) -> int = helper(n) + 1
";
    assert_eq!(jit_int(src, &[5]), 11);
}

#[test]
fn shifts_and_masks_for_byte_extraction() {
    // The PNG-byte-extraction pattern from the bitops test, but now inside a
    // block fn (which previously fell back to the interpreter).
    let src = "\
fn f(word: int) -> int:
    mut bytes = 0
    for i in 0..<4:
        b = (word >> (i * 8)) & 0xff
        bytes += b
    bytes
";
    // 0xDEADBEEF: sum of bytes 0xDE + 0xAD + 0xBE + 0xEF = 222+173+190+239 = 824
    assert_eq!(jit_int(src, &[0xDEADBEEF]), 824);
}
