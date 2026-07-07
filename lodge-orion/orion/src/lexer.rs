//! Scanner — turns source text into a `Token` stream. Records each token's
//! column so the parser can apply the offside rule (indentation-based nesting).
//! `#` is a line comment.

use crate::token::{LexError, Tok, Token};

pub fn lex(src: &str) -> Result<Vec<Token>, LexError> {
    let mut out = Vec::new();
    let bytes = src.as_bytes();
    let mut i = 0usize;
    let mut line = 1u32;
    let mut line_start = 0usize;

    while i < bytes.len() {
        let col = (i - line_start) as u32;
        let c = bytes[i];
        match c {
            b'\n' => {
                push_newline(&mut out, line);
                line += 1;
                i += 1;
                line_start = i;
            }
            b' ' | b'\t' | b'\r' => i += 1,
            b'#' => i = skip_line_comment(bytes, i),
            b'"' => {
                let (t, next) = scan_string(bytes, i, line, col)?;
                out.push(tok(t, line, col));
                i = next;
            }
            d if d.is_ascii_digit() => {
                let (t, next) = scan_number(bytes, i, line, col)?;
                out.push(tok(t, line, col));
                i = next;
            }
            d if d == b'_' || d.is_ascii_alphabetic() => {
                let (t, next) = scan_word(bytes, i);
                out.push(tok(t, line, col));
                i = next;
            }
            _ => {
                let (t, advance) = symbol(&bytes[i..], line, col)?;
                out.push(tok(t, line, col));
                i += advance;
            }
        }
    }

    push_newline(&mut out, line);
    Ok(out)
}

fn tok(t: Tok, line: u32, col: u32) -> Token {
    Token { tok: t, line, col }
}

fn err(message: &str, line: u32, col: u32) -> LexError {
    LexError { message: message.to_string(), line, col }
}

/// Bytes reach here past `is_ascii_*` guards or balanced quotes — valid UTF-8.
fn text(b: &[u8]) -> String {
    String::from_utf8_lossy(b).into_owned()
}

/// Never two newlines in a row, never first — blank lines and leading whitespace
/// don't surface as empty statements.
fn push_newline(out: &mut Vec<Token>, line: u32) {
    if !matches!(out.last(), Some(Token { tok: Tok::Newline, .. }) | None) {
        out.push(tok(Tok::Newline, line, 0));
    }
}

fn skip_line_comment(bytes: &[u8], mut i: usize) -> usize {
    while i < bytes.len() && bytes[i] != b'\n' {
        i += 1;
    }
    i
}

fn scan_string(bytes: &[u8], i: usize, line: u32, col: u32) -> Result<(Tok, usize), LexError> {
    let mut j = i + 1;
    let mut out = String::new();
    while j < bytes.len() {
        match bytes[j] {
            b'"' => return Ok((Tok::Str(out), j + 1)),
            b'\n' => return Err(err("unterminated string", line, col)),
            b'\\' if j + 1 < bytes.len() => {
                match bytes[j + 1] {
                    b'"' => out.push('"'),
                    b'\\' => out.push('\\'),
                    b'n' => out.push('\n'),
                    b'r' => out.push('\r'),
                    b't' => out.push('\t'),
                    b'0' => out.push('\0'),
                    // `\e` is the ESC character (0x1b) — practical for ANSI
                    // colour codes since users reach for it more often than the
                    // hex form. Mirrors what Bash, Ruby and Zig accept.
                    b'e' => out.push('\u{1b}'),
                    // Keep `\{`/`\}` raw so `build_str` knows they're literal
                    // braces and skips interpolation for them.
                    b'{' => { out.push('\\'); out.push('{'); }
                    b'}' => { out.push('\\'); out.push('}'); }
                    other => return Err(err(&format!("bad escape `\\{}`", other as char), line, col)),
                }
                j += 2;
            }
            c => {
                out.push(c as char);
                j += 1;
            }
        }
    }
    Err(err("unterminated string", line, col))
}

fn scan_word(bytes: &[u8], start: usize) -> (Tok, usize) {
    let mut i = start;
    while i < bytes.len() && (bytes[i] == b'_' || bytes[i].is_ascii_alphanumeric()) {
        i += 1;
    }
    (keyword(&text(&bytes[start..i])), i)
}

/// `0..<10` is the integer `0` followed by `..<`, NOT a float — only consume `.`
/// as a decimal point if the next byte is a digit. Scientific notation
/// (`1e9`, `2.5e-3`) is also a float. Prefixes: `0x` hex, `0o` octal, `0b`
/// binary — all int-only.
fn scan_number(bytes: &[u8], start: usize, line: u32, col: u32) -> Result<(Tok, usize), LexError> {
    if let Some((tok, end)) = scan_prefixed_int(bytes, start, line, col)? {
        return Ok((tok, end));
    }
    let mut i = skip_digits(bytes, start);
    let mut is_float = false;
    if i + 1 < bytes.len() && bytes[i] == b'.' && bytes[i + 1].is_ascii_digit() {
        is_float = true;
        i = skip_digits(bytes, i + 1);
    }
    if i < bytes.len() && (bytes[i] == b'e' || bytes[i] == b'E') {
        let exp_after_sign = if i + 1 < bytes.len() && (bytes[i + 1] == b'+' || bytes[i + 1] == b'-') {
            i + 2
        } else {
            i + 1
        };
        if exp_after_sign < bytes.len() && bytes[exp_after_sign].is_ascii_digit() {
            is_float = true;
            i = skip_digits(bytes, exp_after_sign);
        }
    }
    let s = text(&bytes[start..i]);
    if is_float {
        let f = s.parse::<f64>().map_err(|_| err(&format!("bad float `{s}`"), line, col))?;
        Ok((Tok::Float(f), i))
    } else {
        let n = s.parse::<i64>().map_err(|_| err(&format!("bad integer `{s}`"), line, col))?;
        Ok((Tok::Int(n), i))
    }
}

fn skip_digits(bytes: &[u8], mut i: usize) -> usize {
    while i < bytes.len() && bytes[i].is_ascii_digit() {
        i += 1;
    }
    i
}

/// Lex `0x…`, `0o…`, `0b…` literals into a single `Int`. Underscores between
/// digits are allowed for readability (`0xDEAD_BEEF`).
fn scan_prefixed_int(bytes: &[u8], start: usize, line: u32, col: u32) -> Result<Option<(Tok, usize)>, LexError> {
    if bytes[start] != b'0' || start + 1 >= bytes.len() {
        return Ok(None);
    }
    let (radix, name): (u32, &str) = match bytes[start + 1] {
        b'x' | b'X' => (16, "hex"),
        b'o' | b'O' => (8, "octal"),
        b'b' | b'B' => (2, "binary"),
        _ => return Ok(None),
    };
    let mut i = start + 2;
    let body_start = i;
    while i < bytes.len() && (bytes[i] == b'_' || is_radix_digit(bytes[i], radix)) {
        i += 1;
    }
    if i == body_start {
        return Err(err(&format!("{name} literal needs at least one digit"), line, col));
    }
    let raw = std::str::from_utf8(&bytes[body_start..i]).map_err(|_| err("invalid utf-8 in literal", line, col))?;
    let cleaned: String = raw.chars().filter(|c| *c != '_').collect();
    // i64 first; if that overflows (very common for full 64-bit constants like
    // SHA-256 hashing primes) fall back to u64 and reinterpret the bits as i64.
    let n = match i64::from_str_radix(&cleaned, radix) {
        Ok(n) => n,
        Err(_) => u64::from_str_radix(&cleaned, radix)
            .map(|u| u as i64)
            .map_err(|_| err(&format!("bad {name} literal `{raw}`"), line, col))?,
    };
    Ok(Some((Tok::Int(n), i)))
}

fn is_radix_digit(b: u8, radix: u32) -> bool {
    (b as char).to_digit(radix).is_some()
}

fn keyword(w: &str) -> Tok {
    match w {
        "data" => Tok::Data,
        "enum" => Tok::Enum,
        "fn" => Tok::Fn,
        "system" => Tok::System,
        "query" => Tok::Query,
        "trait" => Tok::Trait,
        "impl" => Tok::Impl,
        "dyn" => Tok::Dyn,
        "region" => Tok::Region,
        "raw" => Tok::Raw,
        "extern" => Tok::Extern,
        "pub" => Tok::Pub,
        "use" => Tok::Use,
        "mut" => Tok::Mut,
        "take" => Tok::Take,
        "require" => Tok::Require,
        "ensure" => Tok::Ensure,
        "spawn" => Tok::Spawn,
        "destroy" => Tok::Destroy,
        "if" => Tok::If,
        "then" => Tok::Then,
        "else" => Tok::Else,
        "match" => Tok::Match,
        "for" => Tok::For,
        "loop" => Tok::Loop,
        "break" => Tok::Break,
        "continue" => Tok::Continue,
        "return" => Tok::Return,
        "in" => Tok::In,
        "and" => Tok::And,
        "or" => Tok::Or,
        "not" => Tok::Not,
        "true" => Tok::True,
        "false" => Tok::False,
        "none" => Tok::None,
        _ => Tok::Ident(w.to_string()),
    }
}

/// Try longest operator first so `..<` never lexes as `.` `.` `<`.
fn symbol(rest: &[u8], line: u32, col: u32) -> Result<(Tok, usize), LexError> {
    if let Some(t) = three_char(rest) {
        return Ok((t, 3));
    }
    if let Some(t) = two_char(rest) {
        return Ok((t, 2));
    }
    one_char(rest[0], line, col).map(|t| (t, 1))
}

fn three_char(rest: &[u8]) -> Option<Tok> {
    if rest.len() < 3 {
        return None;
    }
    Some(match (rest[0], rest[1], rest[2]) {
        (b'.', b'.', b'<') => Tok::RangeExcl,
        (b'.', b'.', b'.') => Tok::RangeIncl,
        _ => return None,
    })
}

fn two_char(rest: &[u8]) -> Option<Tok> {
    if rest.len() < 2 {
        return None;
    }
    Some(match (rest[0], rest[1]) {
        (b'=', b'=') => Tok::Eq,
        (b'!', b'=') => Tok::Ne,
        (b'>', b'=') => Tok::Ge,
        (b'<', b'=') => Tok::Le,
        (b'+', b'=') => Tok::PlusEq,
        (b'-', b'=') => Tok::MinusEq,
        (b'-', b'>') => Tok::Arrow,
        (b'=', b'>') => Tok::FatArrow,
        (b'?', b'.') => Tok::QuestionDot,
        (b'<', b'<') => Tok::Shl,
        (b'>', b'>') => Tok::Shr,
        _ => return None,
    })
}

fn one_char(b: u8, line: u32, col: u32) -> Result<Tok, LexError> {
    Ok(match b {
        b'(' => Tok::LParen,
        b')' => Tok::RParen,
        b'{' => Tok::LBrace,
        b'}' => Tok::RBrace,
        b'[' => Tok::LBracket,
        b']' => Tok::RBracket,
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
        b'?' => Tok::Question,
        b'&' => Tok::BitAnd,
        b'|' => Tok::BitOr,
        b'^' => Tok::BitXor,
        b'~' => Tok::Tilde,
        other => return Err(err(&format!("unexpected character `{}`", other as char), line, col)),
    })
}
