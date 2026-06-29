//! JSON parser. Plain recursive-descent over a byte slice.

use std::collections::BTreeMap;

use super::Value;

/// Parse a JSON document — `Err(message)` on any malformed input.
pub fn parse(src: &str) -> Result<Value, String> {
    let mut p = Parser { src: src.as_bytes(), i: 0 };
    p.skip_ws();
    let v = p.value()?;
    p.skip_ws();
    if p.i != p.src.len() {
        return Err(format!("trailing input at byte {}", p.i));
    }
    Ok(v)
}

struct Parser<'a> {
    src: &'a [u8],
    i: usize,
}

impl Parser<'_> {
    fn skip_ws(&mut self) {
        while self.i < self.src.len() && self.src[self.i].is_ascii_whitespace() {
            self.i += 1;
        }
    }

    fn skip_digits(&mut self) {
        while matches!(self.peek(), Some(c) if c.is_ascii_digit()) {
            self.i += 1;
        }
    }

    fn peek(&self) -> Option<u8> {
        self.src.get(self.i).copied()
    }

    fn bump(&mut self) -> Option<u8> {
        let c = self.peek();
        if c.is_some() {
            self.i += 1;
        }
        c
    }

    fn eat(&mut self, b: u8) -> Result<(), String> {
        if self.peek() == Some(b) {
            self.i += 1;
            Ok(())
        } else {
            Err(format!("expected `{}` at byte {}", b as char, self.i))
        }
    }

    fn value(&mut self) -> Result<Value, String> {
        self.skip_ws();
        match self.peek() {
            Some(b'n') => self.literal("null", Value::Null),
            Some(b't') => self.literal("true", Value::Bool(true)),
            Some(b'f') => self.literal("false", Value::Bool(false)),
            Some(b'"') => self.string().map(Value::Str),
            Some(b'[') => self.array(),
            Some(b'{') => self.object(),
            Some(c) if c == b'-' || c.is_ascii_digit() => self.number(),
            Some(c) => Err(format!("unexpected `{}` at byte {}", c as char, self.i)),
            None => Err("unexpected end of input".into()),
        }
    }

    fn literal(&mut self, word: &str, v: Value) -> Result<Value, String> {
        if self.src[self.i..].starts_with(word.as_bytes()) {
            self.i += word.len();
            Ok(v)
        } else {
            Err(format!("expected `{word}` at byte {}", self.i))
        }
    }

    fn string(&mut self) -> Result<String, String> {
        self.eat(b'"')?;
        let mut out = String::new();
        while let Some(c) = self.bump() {
            match c {
                b'"' => return Ok(out),
                b'\\' => out.push(self.parse_escape()?),
                c => out.push(c as char),
            }
        }
        Err("unterminated string".into())
    }

    fn parse_escape(&mut self) -> Result<char, String> {
        Ok(match self.bump() {
            Some(b'"') => '"',
            Some(b'\\') => '\\',
            Some(b'/') => '/',
            Some(b'n') => '\n',
            Some(b'r') => '\r',
            Some(b't') => '\t',
            Some(b'b') => '\u{0008}',
            Some(b'f') => '\u{000c}',
            Some(b'u') => self.parse_unicode_escape()?,
            other => return Err(format!("bad escape `\\{other:?}`")),
        })
    }

    fn parse_unicode_escape(&mut self) -> Result<char, String> {
        let mut h = String::with_capacity(4);
        for _ in 0..4 {
            h.push(self.bump().ok_or("bad \\u escape")? as char);
        }
        let code = u32::from_str_radix(&h, 16).map_err(|e| e.to_string())?;
        Ok(char::from_u32(code).unwrap_or('\u{fffd}'))
    }

    fn number(&mut self) -> Result<Value, String> {
        let start = self.i;
        if self.peek() == Some(b'-') {
            self.i += 1;
        }
        self.skip_digits();
        let mut is_float = false;
        if self.peek() == Some(b'.') {
            is_float = true;
            self.i += 1;
            self.skip_digits();
        }
        if matches!(self.peek(), Some(b'e') | Some(b'E')) {
            is_float = true;
            self.i += 1;
            if matches!(self.peek(), Some(b'+') | Some(b'-')) {
                self.i += 1;
            }
            self.skip_digits();
        }
        let s = std::str::from_utf8(&self.src[start..self.i]).map_err(|e| e.to_string())?;
        if is_float {
            s.parse::<f64>().map(Value::Float).map_err(|e| e.to_string())
        } else {
            s.parse::<i64>().map(Value::Int).map_err(|e| e.to_string())
        }
    }

    fn array(&mut self) -> Result<Value, String> {
        self.eat(b'[')?;
        let mut out = Vec::new();
        self.skip_ws();
        if self.peek() == Some(b']') {
            self.i += 1;
            return Ok(Value::Array(out));
        }
        loop {
            out.push(self.value()?);
            self.skip_ws();
            match self.peek() {
                Some(b',') => {
                    self.i += 1;
                    self.skip_ws();
                }
                Some(b']') => {
                    self.i += 1;
                    return Ok(Value::Array(out));
                }
                _ => return Err(format!("expected `,` or `]` at byte {}", self.i)),
            }
        }
    }

    fn object(&mut self) -> Result<Value, String> {
        self.eat(b'{')?;
        let mut out = BTreeMap::new();
        self.skip_ws();
        if self.peek() == Some(b'}') {
            self.i += 1;
            return Ok(Value::Object(out));
        }
        loop {
            self.skip_ws();
            let k = self.string()?;
            self.skip_ws();
            self.eat(b':')?;
            self.skip_ws();
            let v = self.value()?;
            out.insert(k, v);
            self.skip_ws();
            match self.peek() {
                Some(b',') => self.i += 1,
                Some(b'}') => {
                    self.i += 1;
                    return Ok(Value::Object(out));
                }
                _ => return Err(format!("expected `,` or `}}` at byte {}", self.i)),
            }
        }
    }
}
