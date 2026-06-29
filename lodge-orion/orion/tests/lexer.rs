//! Tests for the M0 lexer. Run with `cargo test`.

use orion::{Tok, lex};

/// Pull just the `Tok`s out (dropping line/col) for compact assertions.
fn toks(src: &str) -> Vec<Tok> {
    lex(src).unwrap().into_iter().map(|t| t.tok).collect()
}

#[test]
fn data_declaration() {
    assert_eq!(
        toks("data Position: x: f32"),
        vec![
            Tok::Data,
            Tok::Ident("Position".into()),
            Tok::Colon,
            Tok::Ident("x".into()),
            Tok::Colon,
            Tok::Ident("f32".into()),
            Tok::Newline,
        ]
    );
}

#[test]
fn floats_and_ints_are_distinct() {
    assert_eq!(toks("3.14 42"), vec![Tok::Float(3.14), Tok::Int(42), Tok::Newline]);
}

#[test]
fn scientific_notation_is_a_float() {
    assert_eq!(
        toks("1e9 2.5e-3 1E+2"),
        vec![Tok::Float(1e9), Tok::Float(2.5e-3), Tok::Float(1e2), Tok::Newline]
    );
}

#[test]
fn range_is_not_a_float() {
    // `0..<10` must be Int(0), RangeExcl, Int(10) — NOT a float `0.` something.
    assert_eq!(
        toks("0..<10"),
        vec![Tok::Int(0), Tok::RangeExcl, Tok::Int(10), Tok::Newline]
    );
    // inclusive range, used both as a value and as a type
    assert_eq!(
        toks("0...255"),
        vec![Tok::Int(0), Tok::RangeIncl, Tok::Int(255), Tok::Newline]
    );
}

#[test]
fn multichar_operators() {
    assert_eq!(
        toks("+= -= -> => == != <= >= ?."),
        vec![
            Tok::PlusEq,
            Tok::MinusEq,
            Tok::Arrow,
            Tok::FatArrow,
            Tok::Eq,
            Tok::Ne,
            Tok::Le,
            Tok::Ge,
            Tok::QuestionDot,
            Tok::Newline,
        ]
    );
}

#[test]
fn keywords_vs_identifiers() {
    assert_eq!(
        toks("mut x = 0"),
        vec![Tok::Mut, Tok::Ident("x".into()), Tok::Assign, Tok::Int(0), Tok::Newline]
    );
}

#[test]
fn comments_and_blank_lines_collapse() {
    // A comment line and blank lines produce no stray tokens, and runs of
    // newlines collapse to one.
    assert_eq!(
        toks("# just a comment\n\n\nfn f"),
        vec![Tok::Fn, Tok::Ident("f".into()), Tok::Newline]
    );
}

#[test]
fn strings() {
    assert_eq!(
        toks("\"hello\""),
        vec![Tok::Str("hello".into()), Tok::Newline]
    );
}
