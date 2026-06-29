//! `net` — HTTP + TCP networking. Public API is pure Orion
//! (`orbs/net/lib.or`); the OS bridges live here.
//!
//! Minimal API for games: HTTP GET/POST + raw TCP. Blocking calls for
//! now; integrate with `spawn job` for async behavior.

use std::io::{Read, Write};
use std::net::TcpStream;
use std::sync::Mutex;
use std::time::Duration;

use crate::interp::Interp;
use crate::value::Value;

pub const SOURCE: &str = include_str!("../../../orbs/net/lib.or");

fn as_text(v: &Value) -> String {
    match v {
        Value::Text(s) => s.clone(),
        other => format!("{other}"),
    }
}

fn as_int(v: &Value) -> i64 {
    match v {
        Value::Int(n) => *n,
        _ => 0,
    }
}

// Thread-local table of open TCP handles. Indexed by i64 id.
thread_local! {
    static STREAMS: Mutex<Vec<Option<TcpStream>>> = Mutex::new(Vec::new());
}

pub fn register(interp: &Interp) {
    interp.register_extern("__os_http_get", |args| {
        let url = as_text(&args[0]);
        let body = ureq::get(&url)
            .call()
            .ok()
            .and_then(|r| r.into_string().ok())
            .unwrap_or_default();
        Ok(Value::Text(body))
    });

    interp.register_extern("__os_http_post", |args| {
        let url = as_text(&args[0]);
        let body = as_text(&args[1]);
        let resp = ureq::post(&url)
            .send_string(&body)
            .ok()
            .and_then(|r| r.into_string().ok())
            .unwrap_or_default();
        Ok(Value::Text(resp))
    });

    interp.register_extern("__os_tcp_connect", |args| {
        let host = as_text(&args[0]);
        let port = as_int(&args[1]) as u16;
        let addr = format!("{host}:{port}");
        let stream = TcpStream::connect_timeout(
            &addr.parse().map_err(|_| crate::interp::run_err(format!("bad addr {addr}")))?,
            Duration::from_secs(10),
        );
        let handle = match stream {
            Ok(s) => STREAMS.with(|cell| {
                let mut v = cell.lock().unwrap();
                v.push(Some(s));
                v.len() as i64 - 1
            }),
            Err(_) => -1,
        };
        Ok(Value::Int(handle))
    });

    interp.register_extern("__os_tcp_send", |args| {
        let handle = as_int(&args[0]) as usize;
        let data = as_text(&args[1]);
        let sent = STREAMS.with(|cell| {
            let mut v = cell.lock().unwrap();
            v.get_mut(handle)
                .and_then(|s| s.as_mut())
                .and_then(|s| s.write(data.as_bytes()).ok())
                .map(|n| n as i64)
                .unwrap_or(-1)
        });
        Ok(Value::Int(sent))
    });

    interp.register_extern("__os_tcp_recv", |args| {
        let handle = as_int(&args[0]) as usize;
        let max = as_int(&args[1]) as usize;
        let text = STREAMS.with(|cell| {
            let mut v = cell.lock().unwrap();
            v.get_mut(handle)
                .and_then(|s| s.as_mut())
                .map(|s| {
                    let mut buf = vec![0u8; max];
                    let n = s.read(&mut buf).unwrap_or(0);
                    buf.truncate(n);
                    String::from_utf8_lossy(&buf).into_owned()
                })
                .unwrap_or_default()
        });
        Ok(Value::Text(text))
    });

    interp.register_extern("__os_tcp_close", |args| {
        let handle = as_int(&args[0]) as usize;
        STREAMS.with(|cell| {
            let mut v = cell.lock().unwrap();
            if let Some(slot) = v.get_mut(handle) {
                *slot = None;
            }
        });
        Ok(Value::Unit)
    });
}
