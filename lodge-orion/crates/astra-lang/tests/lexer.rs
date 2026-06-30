//! The scanner falsified through its public face: source text in, the exact
//! token stream out. Drives the same `place_mark` shapes the rest of the
//! pipeline will parse, so a lexer regression shows here first.

use astra::{Tok, lex};

fn kinds(src: &str) -> Vec<Tok> {
    lex(src).unwrap().into_iter().map(|t| t.tok).collect()
}

#[test]
fn lexes_a_rule_header_and_a_guard() {
    let k = kinds("rule place_mark(cell)\n    require cell.mark == empty\n");
    assert_eq!(
        k,
        vec![
            Tok::Rule,
            Tok::Ident("place_mark".into()),
            Tok::LParen,
            Tok::Ident("cell".into()),
            Tok::RParen,
            Tok::Newline,
            Tok::Require,
            Tok::Ident("cell".into()),
            Tok::Dot,
            Tok::Ident("mark".into()),
            Tok::Eq,
            Tok::Empty,
            Tok::Newline,
        ]
    );
}

#[test]
fn comments_and_blank_lines_never_reach_the_parser() {
    let k = kinds("# heading\nrule r()\n\n\n  set x.y = 1\n");
    assert_eq!(k.first(), Some(&Tok::Rule));
    assert!(
        !k.windows(2)
            .any(|w| w[0] == Tok::Newline && w[1] == Tok::Newline)
    );
}

#[test]
fn two_char_operators_beat_one_char() {
    assert_eq!(
        kinds("a != b"),
        vec![
            Tok::Ident("a".into()),
            Tok::Ne,
            Tok::Ident("b".into()),
            Tok::Newline
        ],
    );
}

#[test]
fn an_unterminated_string_is_a_located_error() {
    let e = lex("set x.y = \"oops\n").unwrap_err();
    assert_eq!(e.line, 1);
    assert!(e.message.contains("string"));
}
