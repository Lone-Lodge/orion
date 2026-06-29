//! String interpolation: split `"text {expr} more"` into a sequence of literal
//! strings and parsed sub-expressions. `\{` and `\}` are literal braces — the
//! lexer leaves them backslashed so we can tell them apart from interpolation.

use super::super::{ParseError, Parser};
use crate::ast::Expr;

impl Parser<'_> {
    /// A plain `Str` if `s` has no unescaped `{`; otherwise an `Interp` of
    /// alternating literal-string and re-parsed expression segments.
    pub(super) fn build_str(&self, s: String, line: u32) -> Result<Expr, ParseError> {
        if !has_unescaped_brace(&s) {
            return Ok(Expr::Str(unescape_braces(&s)));
        }
        let mut parts: Vec<Expr> = Vec::new();
        let mut lit = String::new();
        let mut chars = s.chars().peekable();
        while let Some(c) = chars.next() {
            match c {
                '\\' if matches!(chars.peek(), Some('{') | Some('}')) => {
                    // Literal `\{` or `\}` — emit the brace, skip the backslash.
                    lit.push(chars.next().unwrap());
                }
                '{' => {
                    if !lit.is_empty() {
                        parts.push(Expr::Str(std::mem::take(&mut lit)));
                    }
                    let code = take_until_brace(&mut chars).ok_or_else(|| ParseError {
                        message: "unterminated `{` in string interpolation".into(),
                        line,
                        col: 0,
                    })?;
                    parts.push(self.sub_expr(&code, line)?);
                }
                c => lit.push(c),
            }
        }
        if !lit.is_empty() {
            parts.push(Expr::Str(lit));
        }
        Ok(Expr::Interp(parts))
    }

    fn sub_expr(&self, code: &str, line: u32) -> Result<Expr, ParseError> {
        let toks = crate::lexer::lex(code).map_err(|e| ParseError {
            message: format!("in interpolation: {}", e.message),
            line,
            col: 0,
        })?;
        Parser { toks: &toks, i: 0, file: self.file }.expr()
    }
}

/// Does `s` contain a `{` that isn't escaped as `\{`?
fn has_unescaped_brace(s: &str) -> bool {
    let bytes = s.as_bytes();
    for (i, &b) in bytes.iter().enumerate() {
        if b == b'{' && (i == 0 || bytes[i - 1] != b'\\') {
            return true;
        }
    }
    false
}

/// `\{` -> `{`, `\}` -> `}` — for plain (non-interpolated) strings.
fn unescape_braces(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut chars = s.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '\\' && matches!(chars.peek(), Some('{') | Some('}')) {
            out.push(chars.next().unwrap());
        } else {
            out.push(c);
        }
    }
    out
}

/// Consume characters until a matching `}`, returning the segment (without it).
/// Inside an interpolation the `}` MUST close the expression — no need to
/// honour `\}` here because the expression parser doesn't see those.
fn take_until_brace<I: Iterator<Item = char>>(chars: &mut I) -> Option<String> {
    let mut code = String::new();
    for d in chars {
        if d == '}' {
            return Some(code);
        }
        code.push(d);
    }
    None
}
