//! Compact (one-line) JSON encoder.

use super::Value;

pub(super) fn write(v: &Value, out: &mut String) {
    match v {
        Value::Null => out.push_str("null"),
        Value::Bool(true) => out.push_str("true"),
        Value::Bool(false) => out.push_str("false"),
        Value::Int(n) => out.push_str(&n.to_string()),
        Value::Float(x) => write_float(*x, out),
        Value::Str(s) => write_string(s, out),
        Value::Array(items) => write_array(items, out),
        Value::Object(pairs) => write_object(pairs, out),
    }
}

fn write_float(x: f64, out: &mut String) {
    // Always emit with a decimal point so `1` parses as Int, `1.0` as Float.
    let s = x.to_string();
    out.push_str(&s);
    if !s.contains('.') && !s.contains('e') && !s.contains('E') && x.is_finite() {
        out.push_str(".0");
    }
}

fn write_array(items: &[Value], out: &mut String) {
    out.push('[');
    for (i, it) in items.iter().enumerate() {
        if i > 0 {
            out.push(',');
        }
        write(it, out);
    }
    out.push(']');
}

fn write_object(pairs: &std::collections::BTreeMap<String, Value>, out: &mut String) {
    out.push('{');
    for (i, (k, v)) in pairs.iter().enumerate() {
        if i > 0 {
            out.push(',');
        }
        write_string(k, out);
        out.push(':');
        write(v, out);
    }
    out.push('}');
}

fn write_string(s: &str, out: &mut String) {
    out.push('"');
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
}
