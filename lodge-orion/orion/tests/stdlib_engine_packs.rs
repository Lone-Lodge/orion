//! Tests for the collections, easing, and noise packages.

use orion::interp::Interp;
use orion::stdlib;
use orion::value::Value;

fn run_with_pkg(pkg_name: &str, user: &str, fname: &str) -> Value {
    let pkg = stdlib::find(pkg_name).expect(pkg_name);
    let src = format!("{}\n{}", pkg.source, user);
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    orion::check::check(&p).unwrap();
    orion::typeck::check_types(&p).unwrap();
    let interp = Interp::new(&p);
    (pkg.register)(&interp);
    interp.call(fname, vec![]).unwrap()
}

// ---- collections ----

#[test]
fn list_sort_asc_orders_floats() {
    let src = "fn f() -> int = len(list_sort_asc([3.0, 1.0, 2.0]))";
    assert_eq!(run_with_pkg("collections", src, "f"), Value::Int(3));
}

#[test]
fn list_sort_asc_first_is_min() {
    let src = "\
fn f() -> f64:
    sorted = list_sort_asc([3.0, 1.0, 2.0, 0.5])
    at(sorted, 0)
";
    assert_eq!(run_with_pkg("collections", src, "f"), Value::Float(0.5));
}

#[test]
fn list_reverse_flips_order() {
    let src = "\
fn f() -> f64:
    rev = list_reverse([1.0, 2.0, 3.0])
    at(rev, 0)
";
    assert_eq!(run_with_pkg("collections", src, "f"), Value::Float(3.0));
}

#[test]
fn list_sum_and_avg() {
    let pkg = stdlib::find("collections").unwrap();
    let src = format!("{}\nfn s() -> f64 = list_sum([1.0, 2.0, 3.0, 4.0])\nfn a() -> f64 = list_avg([1.0, 2.0, 3.0, 4.0])\n", pkg.source);
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (pkg.register)(&interp);
    assert_eq!(interp.call("s", vec![]).unwrap(), Value::Float(10.0));
    assert_eq!(interp.call("a", vec![]).unwrap(), Value::Float(2.5));
}

#[test]
fn list_min_max() {
    let pkg = stdlib::find("collections").unwrap();
    let src = format!("{}\nfn lo() -> f64 = list_min([3.0, 1.0, 2.0])\nfn hi() -> f64 = list_max([3.0, 1.0, 2.0])\n", pkg.source);
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (pkg.register)(&interp);
    assert_eq!(interp.call("lo", vec![]).unwrap(), Value::Float(1.0));
    assert_eq!(interp.call("hi", vec![]).unwrap(), Value::Float(3.0));
}

#[test]
fn list_take_skip() {
    let pkg = stdlib::find("collections").unwrap();
    let src = format!(
        "{}\nfn t() -> int = len(list_take([1.0,2.0,3.0,4.0,5.0], 3))\nfn s() -> int = len(list_skip([1.0,2.0,3.0,4.0,5.0], 3))\n",
        pkg.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (pkg.register)(&interp);
    assert_eq!(interp.call("t", vec![]).unwrap(), Value::Int(3));
    assert_eq!(interp.call("s", vec![]).unwrap(), Value::Int(2));
}

#[test]
fn list_index_of_finds_and_misses() {
    let pkg = stdlib::find("collections").unwrap();
    let src = format!(
        "{}\nfn hit() -> int = list_index_of([10.0, 20.0, 30.0], 20.0)\nfn miss() -> int = list_index_of([10.0, 20.0, 30.0], 99.0)\n",
        pkg.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (pkg.register)(&interp);
    assert_eq!(interp.call("hit", vec![]).unwrap(), Value::Int(1));
    assert_eq!(interp.call("miss", vec![]).unwrap(), Value::Int(-1));
}

#[test]
fn list_count_in_range() {
    let src = "fn f() -> int = list_count_in([0.5, 1.5, 2.5, 3.5, 4.5], 1.0, 3.0)";
    assert_eq!(run_with_pkg("collections", src, "f"), Value::Int(2));
}

// ---- easing ----

#[test]
fn ease_at_endpoints() {
    // every easing function returns 0 at t=0 and 1 at t=1
    let pkg = stdlib::find("easing").unwrap();
    let src = format!(
        "{}\nfn z() -> f64 = ease_out_cubic(0.0)\nfn o() -> f64 = ease_out_cubic(1.0)\nfn m() -> f64 = ease_in_out_quad(0.5)\n",
        pkg.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    orion::check::check(&p).unwrap();
    let interp = Interp::new(&p);
    let z = interp.call("z", vec![]).unwrap();
    let o = interp.call("o", vec![]).unwrap();
    let m = interp.call("m", vec![]).unwrap();
    assert!(matches!(z, Value::Float(x) if x.abs() < 1e-9), "ease(0) got {z:?}");
    assert!(matches!(o, Value::Float(x) if (x - 1.0).abs() < 1e-9), "ease(1) got {o:?}");
    assert!(matches!(m, Value::Float(x) if (x - 0.5).abs() < 1e-9), "ease_in_out(0.5) got {m:?}");
}

#[test]
fn smoothstep_monotonic() {
    let pkg = stdlib::find("easing").unwrap();
    let src = format!(
        "{}\nfn a() -> f64 = smoothstep(0.25)\nfn b() -> f64 = smoothstep(0.75)\n",
        pkg.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    let a = interp.call("a", vec![]).unwrap();
    let b = interp.call("b", vec![]).unwrap();
    let (Value::Float(av), Value::Float(bv)) = (a, b) else { panic!() };
    assert!(av < bv, "smoothstep should be monotonic: {av} < {bv}");
    assert!(av > 0.0 && av < 1.0);
}

// ---- noise ----

#[test]
fn noise_hash_is_deterministic() {
    let pkg = stdlib::find("noise").unwrap();
    let src = format!("{}\nfn h(x: int, y: int) -> f64 = noise_hash(x, y, 42)\n", pkg.source);
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (pkg.register)(&interp);
    let a = interp.call("h", vec![Value::Int(5), Value::Int(7)]).unwrap();
    let b = interp.call("h", vec![Value::Int(5), Value::Int(7)]).unwrap();
    assert_eq!(a, b, "same input should hash the same");
}

#[test]
fn noise_hash_is_in_signed_unit() {
    let pkg = stdlib::find("noise").unwrap();
    let src = format!("{}\nfn h(x: int) -> f64 = noise_hash(x, 0, 0)\n", pkg.source);
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (pkg.register)(&interp);
    for x in 0..100 {
        let v = interp.call("h", vec![Value::Int(x)]).unwrap();
        if let Value::Float(f) = v {
            assert!((-1.0..=1.0).contains(&f), "hash({x}) = {f} out of [-1,1]");
        }
    }
}

#[test]
fn value_noise_returns_in_bounds() {
    let pkg = stdlib::find("noise").unwrap();
    let src = format!("{}\nfn n(x: f64, y: f64) -> f64 = value_noise_2d(x, y, 7)\n", pkg.source);
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    orion::check::check(&p).unwrap();
    let interp = Interp::new(&p);
    (pkg.register)(&interp);
    for i in 0..20 {
        let f = (i as f64) * 0.37;
        let v = interp.call("n", vec![Value::Float(f), Value::Float(f * 1.7)]).unwrap();
        if let Value::Float(x) = v {
            assert!((-1.5..=1.5).contains(&x), "noise out of expected range: {x}");
        }
    }
}

#[test]
fn fbm_combines_octaves() {
    let pkg = stdlib::find("noise").unwrap();
    let src = format!("{}\nfn f() -> f64 = fbm_2d(0.5, 0.5, 4, 1)\n", pkg.source);
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (pkg.register)(&interp);
    let v = interp.call("f", vec![]).unwrap();
    assert!(matches!(v, Value::Float(_)));
}

// ---- registry ----

#[test]
fn ten_packages_registered() {
    let names: Vec<&str> = stdlib::ORBS.iter().map(|p| p.name).collect();
    for needed in ["time", "math", "io", "test", "random", "string", "log", "collections", "easing", "noise"] {
        assert!(names.contains(&needed), "missing: {needed}");
    }
}
