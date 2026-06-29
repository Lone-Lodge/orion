//! Tests for crypto, uuid, url orbs.

use orion::interp::Interp;
use orion::stdlib;
use orion::value::Value;

fn run_with_orb(orb: &str, user: &str, fname: &str) -> Value {
    // Pull in declared deps too so pure-Orion orbs that delegate to
    // bytes/string still resolve when loaded by these isolation tests.
    let mut chain: Vec<&str> = Vec::new();
    let target = stdlib::find(orb).expect(orb);
    for d in target.deps {
        chain.push(*d);
    }
    chain.push(orb);
    let resolved: Vec<&stdlib::Orb> = chain.iter().map(|n| stdlib::find(n).expect(n)).collect();
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

// ---- crypto: sha256 against FIPS-180-4 known vectors ----

#[test]
fn sha256_empty_string_matches_spec() {
    let src = "fn f() -> Text = sha256(\"\")";
    assert_eq!(
        run_with_orb("crypto", src, "f"),
        Value::Text("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855".into())
    );
}

#[test]
fn sha256_abc_matches_spec() {
    let src = "fn f() -> Text = sha256(\"abc\")";
    assert_eq!(
        run_with_orb("crypto", src, "f"),
        Value::Text("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad".into())
    );
}

#[test]
fn sha256_long_input_matches_spec() {
    // 56-byte input — crosses the padding boundary.
    let src = "fn f() -> Text = sha256(\"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq\")";
    assert_eq!(
        run_with_orb("crypto", src, "f"),
        Value::Text("248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1".into())
    );
}

#[test]
fn sha256_short_returns_8_chars() {
    let src = "fn f() -> int = len(sha256_short(\"orion\"))";
    assert_eq!(run_with_orb("crypto", src, "f"), Value::Int(8));
}

// ---- uuid ----

#[test]
fn uuid_v4_has_canonical_length() {
    let src = "fn f() -> int = len(uuid_v4())";
    assert_eq!(run_with_orb("uuid", src, "f"), Value::Int(36));
}

#[test]
fn uuid_v4_compact_is_32_chars() {
    let src = "fn f() -> int = len(uuid_v4_compact())";
    assert_eq!(run_with_orb("uuid", src, "f"), Value::Int(32));
}

#[test]
fn uuid_v4_has_4_at_version_slot() {
    // str_contains is provided by the `string` orb in our test harness,
    // so we just need uuid + string loaded together via run_with_orb.
    let src = "fn f() -> bool:\n    candidate = uuid_v4()\n    str_contains(candidate, \"-4\")";
    let result = run_with_orbs(&["bytes", "string", "uuid"], src, "f");
    assert_eq!(result, Value::Bool(true));
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

#[test]
fn uuid_v4_two_calls_differ() {
    let src = "fn f() -> Text = uuid_v4()";
    let a = run_with_orbs(&["bytes", "uuid"], src, "f");
    let b = run_with_orbs(&["bytes", "uuid"], src, "f");
    // run_with_orbs creates a fresh slot per Interp, so each Interp's
    // first call has the same default-seeded output — drive both calls in
    // the same interp instead.
    let _ = (a, b);
    let src_seq = "fn first() -> Text = uuid_v4()\nfn second() -> Text = uuid_v4()";
    let a = run_with_orbs(&["bytes", "uuid"], src_seq, "first");
    let b = run_with_orbs(&["bytes", "uuid"], src_seq, "second");
    let interp_continued = {
        let resolved: Vec<&stdlib::Orb> = ["bytes", "uuid"].iter().map(|n| stdlib::find(n).expect(n)).collect();
        let mut src = String::new();
        for o in &resolved {
            src.push_str(o.source);
            src.push('\n');
        }
        src.push_str(src_seq);
        let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
        orion::check::check(&p).unwrap();
        orion::typeck::check_types(&p).unwrap();
        let interp = Interp::new(&p);
        for o in &resolved {
            (o.register)(&interp);
        }
        let first = interp.call("first", vec![]).unwrap();
        let second = interp.call("second", vec![]).unwrap();
        (first, second)
    };
    let (a, b) = interp_continued;
    assert_ne!(a, b, "two UUIDs should differ");
}

// ---- url ----

#[test]
fn url_encode_special_chars() {
    let src = "fn f() -> Text = url_encode(\"hello world!\")";
    assert_eq!(run_with_orb("url", src, "f"), Value::Text("hello%20world%21".into()));
}

#[test]
fn url_encode_keeps_unreserved() {
    let src = "fn f() -> Text = url_encode(\"abc-_.~XYZ123\")";
    assert_eq!(run_with_orb("url", src, "f"), Value::Text("abc-_.~XYZ123".into()));
}

#[test]
fn url_decode_round_trip() {
    let src = "fn f() -> Text = url_decode(url_encode(\"a b/c?d=e\"))";
    assert_eq!(run_with_orb("url", src, "f"), Value::Text("a b/c?d=e".into()));
}

#[test]
fn url_decode_plus_is_space() {
    let src = "fn f() -> Text = url_decode(\"hello+world\")";
    assert_eq!(run_with_orb("url", src, "f"), Value::Text("hello world".into()));
}

#[test]
fn url_parse_returns_scheme_host_path() {
    let src = "\
fn parse_scheme() -> Text = get(url_parse(\"https://example.com/path?q=1\"), \"scheme\")
fn parse_host() -> Text = get(url_parse(\"https://example.com/path?q=1\"), \"host\")
fn parse_path() -> Text = get(url_parse(\"https://example.com/path?q=1\"), \"path\")
fn parse_query() -> Text = get(url_parse(\"https://example.com/path?q=1\"), \"query\")
";
    assert_eq!(run_with_orb("url", src, "parse_scheme"), Value::Text("https".into()));
    assert_eq!(run_with_orb("url", src, "parse_host"), Value::Text("example.com".into()));
    assert_eq!(run_with_orb("url", src, "parse_path"), Value::Text("/path".into()));
    assert_eq!(run_with_orb("url", src, "parse_query"), Value::Text("q=1".into()));
}

#[test]
fn url_parse_includes_port() {
    let src = "fn f() -> Text = get(url_parse(\"http://localhost:8080/\"), \"port\")";
    assert_eq!(run_with_orb("url", src, "f"), Value::Text("8080".into()));
}

// ---- registry ----

#[test]
fn crypto_uuid_url_are_registered() {
    let names: Vec<&str> = stdlib::ORBS.iter().map(|o| o.name).collect();
    for needed in ["crypto", "uuid", "url"] {
        assert!(names.contains(&needed), "missing: {needed}");
    }
}
