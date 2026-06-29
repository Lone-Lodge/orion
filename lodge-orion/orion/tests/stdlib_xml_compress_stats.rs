//! Tests for xml, compress, and stats orbs.

use orion::interp::Interp;
use orion::stdlib;
use orion::value::Value;

fn run_with_orb(orb: &str, user: &str, fname: &str) -> Value {
    // Pull in declared deps too so pure-Orion orbs that delegate to
    // bytes/collections/string still resolve when loaded by these tests.
    let target = stdlib::find(orb).expect(orb);
    let mut chain: Vec<&str> = target.deps.iter().copied().collect();
    chain.push(orb);
    run_with_orbs(&chain, user, fname)
}

fn run_with_orbs(orbs: &[&str], user: &str, fname: &str) -> Value {
    let resolved: Vec<&stdlib::Orb> = orbs.iter().map(|n| stdlib::find(n).expect(n)).collect();
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

// ---- xml ----

#[test]
fn xml_parse_root_tag() {
    let src = r#"fn f() -> Text = get(xml_parse("<root></root>"), "tag")"#;
    assert_eq!(run_with_orb("xml", src, "f"), Value::Text("root".into()));
}

#[test]
fn xml_parse_self_closing() {
    let src = r#"fn f() -> Text = get(xml_parse("<br/>"), "tag")"#;
    assert_eq!(run_with_orb("xml", src, "f"), Value::Text("br".into()));
}

#[test]
fn xml_parse_text_content() {
    let src = r#"fn f() -> Text = get(xml_parse("<msg>hello world</msg>"), "text")"#;
    assert_eq!(run_with_orb("xml", src, "f"), Value::Text("hello world".into()));
}

#[test]
fn xml_parse_attributes() {
    let src = "\
fn f() -> Text:
    doc = xml_parse(\"<item id=\\\"42\\\" name=\\\"orb\\\"/>\")
    get(get(doc, \"attrs\"), \"name\")
";
    assert_eq!(run_with_orb("xml", src, "f"), Value::Text("orb".into()));
}

#[test]
fn xml_parse_nested_children() {
    let src = "fn f() -> int = len(get(xml_parse(\"<root><a/><b/><c/></root>\"), \"children\"))";
    assert_eq!(run_with_orb("xml", src, "f"), Value::Int(3));
}

#[test]
fn xml_parse_skips_prolog_and_comments() {
    let src = r#"fn f() -> Text = get(xml_parse("<?xml version=\"1.0\"?><!-- comment --><doc/>"), "tag")"#;
    assert_eq!(run_with_orb("xml", src, "f"), Value::Text("doc".into()));
}

// ---- compress (RLE) ----
// compress is pure Orion now — depends on the bytes orb for byte_at /
// bytes_length / bytes_to_text. Tests pull both in.

#[test]
fn rle_round_trip_simple() {
    let src = "\
fn f() -> Text:
    enc = rle_encode([65, 65, 65, 66, 66, 67])
    dec = rle_decode(enc)
    bytes_to_text(dec)
";
    assert_eq!(
        run_with_orbs(&["bytes", "compress"], src, "f"),
        Value::Text("AAABBC".into()),
    );
}

#[test]
fn rle_compresses_runs() {
    // 5 zero bytes → encoded as [5, 0], first byte (count) is 5.
    let src = "fn f() -> int = at(rle_encode([0, 0, 0, 0, 0]), 0)";
    assert_eq!(run_with_orbs(&["bytes", "compress"], src, "f"), Value::Int(5));
}

#[test]
fn rle_empty_round_trip() {
    let src = "fn f() -> int = len(rle_decode(rle_encode([])))";
    assert_eq!(run_with_orbs(&["bytes", "compress"], src, "f"), Value::Int(0));
}

// ---- stats ----

#[test]
fn stats_mean_of_known_set() {
    let src = "fn f() -> f64 = stats_mean([1.0, 2.0, 3.0, 4.0])";
    assert_eq!(run_with_orb("stats", src, "f"), Value::Float(2.5));
}

#[test]
fn stats_median_even_count() {
    let src = "fn f() -> f64 = stats_median([1.0, 2.0, 3.0, 4.0])";
    assert_eq!(run_with_orb("stats", src, "f"), Value::Float(2.5));
}

#[test]
fn stats_median_odd_count() {
    let src = "fn f() -> f64 = stats_median([1.0, 2.0, 100.0])";
    assert_eq!(run_with_orb("stats", src, "f"), Value::Float(2.0));
}

#[test]
fn stats_stddev_known() {
    // variance of [2, 4, 4, 4, 5, 5, 7, 9] is 4; stddev is 2
    let src = "fn f() -> f64 = stats_stddev([2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0])";
    if let Value::Float(s) = run_with_orb("stats", src, "f") {
        assert!((s - 2.0).abs() < 1e-9, "got {s}");
    } else { panic!() }
}

#[test]
fn stats_percentile_50_is_median() {
    let src = "fn f() -> f64 = stats_percentile([1.0, 2.0, 3.0, 4.0, 5.0], 50.0)";
    assert_eq!(run_with_orb("stats", src, "f"), Value::Float(3.0));
}

#[test]
fn stats_percentile_0_and_100() {
    let src = "\
fn lo() -> f64 = stats_percentile([3.0, 1.0, 5.0, 2.0, 4.0], 0.0)
fn hi() -> f64 = stats_percentile([3.0, 1.0, 5.0, 2.0, 4.0], 100.0)
";
    assert_eq!(run_with_orb("stats", src, "lo"), Value::Float(1.0));
    assert_eq!(run_with_orb("stats", src, "hi"), Value::Float(5.0));
}

#[test]
fn stats_sum_and_count() {
    let src = "\
fn s() -> f64 = stats_sum([1.0, 2.0, 3.0])
fn c() -> int = stats_count([1.0, 2.0, 3.0, 4.0, 5.0])
";
    assert_eq!(run_with_orb("stats", src, "s"), Value::Float(6.0));
    assert_eq!(run_with_orb("stats", src, "c"), Value::Int(5));
}

// ---- registry ----

#[test]
fn xml_compress_stats_are_registered() {
    let names: Vec<&str> = stdlib::ORBS.iter().map(|o| o.name).collect();
    for needed in ["xml", "compress", "stats"] {
        assert!(names.contains(&needed), "missing: {needed}");
    }
}
