//! Tests for §14 trait + impl with static dispatch via `obj.method(args)`.

use orion::interp::Interp;
use orion::value::Value;
use orion::{lex, parse};

fn run(src: &str, fname: &str) -> Value {
    let p = parse(&lex(src).unwrap()).unwrap();
    orion::check::check(&p).unwrap();
    orion::typeck::check_types(&p).unwrap();
    Interp::new(&p).call(fname, vec![]).unwrap()
}

#[test]
fn parses_trait_and_impl() {
    let src = "\
data Counter: n: int

trait Bumpable:
    fn bump(self) -> Counter

impl Bumpable for Counter:
    fn bump(self) -> Counter = Counter { n: self.n + 1 }

fn f() -> int:
    c = Counter { n: 0 }
    c2 = c.bump()
    c2.n
";
    assert_eq!(run(src, "f"), Value::Int(1));
}

#[test]
fn method_can_take_extra_args() {
    let src = "\
data Adder: state: int

trait Add:
    fn add(self, x: int) -> Adder

impl Add for Adder:
    fn add(self, x: int) -> Adder = Adder { state: self.state + x }

fn f() -> int:
    a = Adder { state: 10 }
    b = a.add(5)
    b.state
";
    assert_eq!(run(src, "f"), Value::Int(15));
}

#[test]
fn chained_method_calls_use_static_dispatch() {
    let src = "\
data Counter: n: int

trait Bumpable:
    fn bump(self) -> Counter

impl Bumpable for Counter:
    fn bump(self) -> Counter = Counter { n: self.n + 1 }

fn f() -> int:
    c = Counter { n: 0 }
    c.bump().bump().bump().n
";
    assert_eq!(run(src, "f"), Value::Int(3));
}

#[test]
fn data_value_can_be_read_via_field() {
    let src = "\
data Pair: a: int, b: int

fn f() -> int:
    p = Pair { a: 7, b: 3 }
    p.a + p.b
";
    assert_eq!(run(src, "f"), Value::Int(10));
}

#[test]
fn missing_method_errors_clearly() {
    let src = "\
data Empty: x: int

fn f() -> int:
    e = Empty { x: 1 }
    e.no_such_method()
";
    let p = parse(&lex(src).unwrap()).unwrap();
    orion::check::check(&p).unwrap();
    let interp = Interp::new(&p);
    let err = interp.call("f", vec![]).unwrap_err();
    assert!(err.message.contains("no method"), "got: {}", err.message);
}

#[test]
fn block_body_in_impl_works() {
    let src = "\
data State: h: int

trait Update:
    fn step(self, x: int) -> State

impl Update for State:
    fn step(self, x: int) -> State:
        mut acc = self.h
        for i in 0..<4:
            acc = acc + x
        State { h: acc }

fn f() -> int:
    s = State { h: 100 }
    s2 = s.step(5)
    s2.h
";
    assert_eq!(run(src, "f"), Value::Int(120));
}

#[test]
fn impl_methods_use_bit_ops_for_real_algorithm() {
    let src = "\
data Fnv: h: int

trait Hasher:
    fn step(self, b: int) -> Fnv

impl Hasher for Fnv:
    fn step(self, b: int) -> Fnv:
        x = self.h ^ b
        Fnv { h: x * 0x100000001B3 }

fn f() -> int:
    s = Fnv { h: 0xCBF29CE484222325 }
    s2 = s.step(104).step(105).step(33)
    s2.h
";
    let v = run(src, "f");
    let Value::Int(n) = v else { panic!("expected int") };
    assert_ne!(n, 0);
    assert_ne!(n as u64, 0xCBF29CE484222325);
}
