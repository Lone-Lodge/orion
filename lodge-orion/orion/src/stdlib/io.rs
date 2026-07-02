//! `io` — file I/O and line-based stdio. Public API is pure Orion
//! (`orbs/io/lib.or`); only the OS bridges stay native.

use std::fs;
use std::io::{BufRead, Write};

use crate::interp::Interp;
use crate::value::Value;

pub const SOURCE: &str = include_str!("../../../orbs/io/lib.or");

pub fn register(interp: &Interp) {
    interp.register_extern("__os_read_file", |args| {
        let path = as_text(&args[0]);
        Ok(Value::Text(fs::read_to_string(&path).unwrap_or_default()))
    });
    interp.register_extern("__os_write_file", |args| {
        let path = as_text(&args[0]);
        let contents = as_text(&args[1]);
        Ok(Value::Bool(fs::write(&path, contents).is_ok()))
    });
    interp.register_extern("__os_write_bytes", |args| {
        // Write a `[int]` to disk as raw bytes — preserves values ≥ 0x80
        // that `__os_write_file` (which goes through `bytes_to_text` →
        // `from_utf8_lossy`) would corrupt. Required for emitting PE/ELF
        // binaries, image files, audio, anything non-text.
        let path = as_text(&args[0]);
        let bytes: Vec<u8> = match &args[1] {
            Value::List(items) => items
                .iter()
                .map(|v| match v {
                    Value::Int(n) => (*n).max(0).min(255) as u8,
                    Value::Float(f) => (*f as i64).max(0).min(255) as u8,
                    _ => 0,
                })
                .collect(),
            _ => Vec::new(),
        };
        Ok(Value::Bool(fs::write(&path, bytes).is_ok()))
    });
    interp.register_extern("__os_print_line", |args| {
        let line = as_text(&args[0]);
        let stdout = std::io::stdout();
        let mut h = stdout.lock();
        let _ = writeln!(h, "{line}");
        let _ = h.flush();   // flush per line so bg-task tails see live output
        Ok(Value::Unit)
    });
    interp.register_extern("__os_read_line", |_args| {
        let stdin = std::io::stdin();
        let mut buf = String::new();
        let _ = stdin.lock().read_line(&mut buf);
        if buf.ends_with('\n') {
            buf.pop();
        }
        if buf.ends_with('\r') {
            buf.pop();
        }
        Ok(Value::Text(buf))
    });

    interp.register_extern("__os_read_bytes", |args| {
        let path = as_text(&args[0]);
        match std::fs::read(&path) {
            Ok(bytes) => {
                let list: Vec<Value> = bytes.into_iter().map(|b| Value::Int(b as i64)).collect();
                Ok(Value::List(std::sync::Arc::new(list)))
            }
            Err(_) => Ok(Value::List(std::sync::Arc::new(Vec::new()))),
        }
    });

    interp.register_extern("__os_file_exists", |args| {
        let path = as_text(&args[0]);
        Ok(Value::Bool(std::path::Path::new(&path).exists()))
    });

    // Compile-error counter mirroring @orion_err_count in orion-self's
    // native runtime. orion_ir declares these as `extern fn` so the
    // same compiler source runs interpreted (here) and native (there).
    interp.register_extern("orion_err_bump", |_args| {
        ERR_COUNT.with(|c| {
            let n = c.get() + 1;
            c.set(n);
            Ok(Value::Int(n))
        })
    });
    interp.register_extern("orion_err_get", |_args| {
        Ok(Value::Int(ERR_COUNT.with(|c| c.get())))
    });

    // String-builder join — one allocation for the whole result.
    // Mirrors @orion_text_join in orion-self's emitted runtime.
    interp.register_extern("orion_text_join", |args| {
        let Some(Value::List(items)) = args.first() else {
            return Ok(Value::Text(String::new()));
        };
        let total: usize = items.iter().map(|v| match v {
            Value::Text(s) => s.len(),
            _ => 0,
        }).sum();
        let mut out = String::with_capacity(total);
        for v in items.iter() {
            if let Value::Text(s) = v {
                out.push_str(s);
            }
        }
        Ok(Value::Text(out))
    });
}

thread_local! {
    static ERR_COUNT: std::cell::Cell<i64> = const { std::cell::Cell::new(0) };
}

fn as_text(v: &Value) -> String {
    match v {
        Value::Text(s) => s.clone(),
        other => other.to_string(),
    }
}
