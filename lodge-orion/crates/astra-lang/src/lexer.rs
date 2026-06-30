//! The scanner — source text to a `Token` stream. Indentation is cosmetic in
//! Astra's grammar: `Newline` separates statements, top-level keywords (`rule`,
//! `view`) delimit declarations, and `()`/`{}` bracket the rest, so the scanner
//! needs no INDENT/DEDENT machinery. A `#` runs a comment to end of line. The
//! stream is public on purpose — a syntax highlighter or LSP reads exactly this.

use crate::token::{LexError, Tok, Token};

fn tok(t: Tok, line: u32) -> Token {
    Token { tok: t, line }
}

/// Tokenise a whole source string. Whitespace and comments are dropped; runs of
/// blank lines collapse to a single `Newline`, and a terminating `Newline` is
/// appended so every statement — including the last — ends the same way.
pub fn lex(src: &str) -> Result<Vec<Token>, LexError> {
    let mut out = Vec::new();
    let bytes = src.as_bytes();
    let mut i = 0usize;
    let mut line = 1u32;
    while i < bytes.len() {
        let c = bytes[i] as char;
        match c {
            '\n' => {
                push_newline(&mut out, line);
                line += 1;
                i += 1;
            }
            ' ' | '\t' | '\r' => i += 1,
            '#' => {
                while i < bytes.len() && bytes[i] != b'\n' {
                    i += 1;
                }
            }
            '"' => {
                let start = i + 1;
                i += 1;
                while i < bytes.len() && bytes[i] != b'"' {
                    if bytes[i] == b'\n' {
                        return Err(err("unterminated string", line));
                    }
                    i += 1;
                }
                if i >= bytes.len() {
                    return Err(err("unterminated string", line));
                }
                out.push(tok(Tok::Str(ascii(&bytes[start..i])), line));
                i += 1; // consume the closing quote
            }
            c if c.is_ascii_digit() => {
                let start = i;
                while i < bytes.len() && (bytes[i] as char).is_ascii_digit() {
                    i += 1;
                }
                let text = ascii(&bytes[start..i]);
                let n = text
                    .parse()
                    .map_err(|_| err(&format!("bad integer `{text}`"), line))?;
                out.push(tok(Tok::Int(n), line));
            }
            c if c == '_' || c.is_ascii_alphabetic() => {
                let start = i;
                while i < bytes.len() && {
                    let b = bytes[i] as char;
                    b == '_' || b.is_ascii_alphanumeric()
                } {
                    i += 1;
                }
                out.push(tok(keyword(&ascii(&bytes[start..i])), line));
            }
            _ => {
                let (t, advance) = symbol(&bytes[i..], line)?;
                out.push(tok(t, line));
                i += advance;
            }
        }
    }
    push_newline(&mut out, line);
    Ok(out)
}

fn err(message: &str, line: u32) -> LexError {
    LexError {
        message: message.to_string(),
        line,
    }
}

/// The bytes reach here only past `is_ascii_*` guards or balanced quotes, so
/// they are valid UTF-8; an invalid sequence would already have errored.
fn ascii(b: &[u8]) -> String {
    String::from_utf8_lossy(b).into_owned()
}

/// Append a `Newline`, but never two in a row and never first, so blank lines
/// and leading whitespace cannot reach the parser as empty statements.
fn push_newline(out: &mut Vec<Token>, line: u32) {
    if !matches!(
        out.last(),
        Some(Token {
            tok: Tok::Newline,
            ..
        }) | None
    ) {
        out.push(tok(Tok::Newline, line));
    }
}

/// Reserved words to tags; anything else is an identifier.
fn keyword(w: &str) -> Tok {
    match w {
        "rule" => Tok::Rule,
        "record" => Tok::Record,
        "require" => Tok::Require,
        "let" => Tok::Let,
        "set" => Tok::Set,
        "spawn" => Tok::Spawn,
        "destroy" => Tok::Destroy,
        "emit" => Tok::Emit,
        "on" => Tok::On,
        "view" => Tok::View,
        "entity" => Tok::Entity,
        "test" => Tok::Test,
        "apply" => Tok::Apply,
        "expect" => Tok::Expect,
        "tick" => Tok::Tick,
        "if" => Tok::If,
        "then" => Tok::Then,
        "else" => Tok::Else,
        "match" => Tok::Match,
        "for" => Tok::For,
        "count" => Tok::Count,
        "all" => Tok::All,
        "in" => Tok::In,
        "where" => Tok::Where,
        "empty" => Tok::Empty,
        "true" => Tok::True,
        "false" => Tok::False,
        "not" => Tok::Not,
        "and" => Tok::And,
        "or" => Tok::Or,
        _ => Tok::Ident(w.to_string()),
    }
}

/// One- and two-character operators. Two-character forms are tried first so `==`
/// never lexes as two `=`.
fn symbol(rest: &[u8], line: u32) -> Result<(Tok, usize), LexError> {
    let two = |a: u8, b: u8| rest.len() >= 2 && rest[0] == a && rest[1] == b;
    if two(b'=', b'=') {
        return Ok((Tok::Eq, 2));
    }
    if two(b'!', b'=') {
        return Ok((Tok::Ne, 2));
    }
    if two(b'>', b'=') {
        return Ok((Tok::Ge, 2));
    }
    if two(b'<', b'=') {
        return Ok((Tok::Le, 2));
    }
    let one = match rest[0] {
        b'(' => Tok::LParen,
        b')' => Tok::RParen,
        b'{' => Tok::LBrace,
        b'}' => Tok::RBrace,
        b',' => Tok::Comma,
        b'.' => Tok::Dot,
        b':' => Tok::Colon,
        b'=' => Tok::Assign,
        b'<' => Tok::Lt,
        b'>' => Tok::Gt,
        b'+' => Tok::Plus,
        b'-' => Tok::Minus,
        b'*' => Tok::Star,
        b'/' => Tok::Slash,
        b'%' => Tok::Percent,
        other => {
            return Err(err(
                &format!("unexpected character `{}`", other as char),
                line,
            ));
        }
    };
    Ok((one, 1))
}
