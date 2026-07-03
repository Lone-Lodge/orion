//! `net` — TCP client/server. Pure OS primitives.
//! HTTP protocol lives in the `net` Orion orb (pure Orion on top of tcp_*).
//! WebSocket protocol lives in the `atlas_ws` Orion orb on top of these.

use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::Mutex;
use std::time::Duration;

use crate::interp::Interp;
use crate::value::Value;

pub const SOURCE: &str = include_str!("../../../orbs/net/lib.or");

fn as_text(v: &Value) -> String {
    match v { Value::Text(s) => s.clone(), other => format!("{other}") }
}
fn as_int(v: &Value) -> i64 {
    match v { Value::Int(n) => *n, _ => 0 }
}

thread_local! {
    static STREAMS:   Mutex<Vec<Option<TcpStream>>>   = Mutex::new(Vec::new());
    static LISTENERS: Mutex<Vec<Option<TcpListener>>> = Mutex::new(Vec::new());
}

pub fn register(interp: &Interp) {

    interp.register_extern("__os_tcp_connect", |args| {
        let host = as_text(&args[0]);
        let port = as_int(&args[1]) as u16;
        let addr = format!("{host}:{port}");
        let handle = match TcpStream::connect_timeout(
            &addr.parse().map_err(|_| crate::interp::run_err(format!("bad addr {addr}")))?,
            Duration::from_secs(10),
        ) {
            Ok(s) => STREAMS.with(|c| { let mut v = c.lock().unwrap(); v.push(Some(s)); v.len() as i64 - 1 }),
            Err(_) => -1,
        };
        Ok(Value::Int(handle))
    });

    interp.register_extern("__os_tcp_send", |args| {
        let handle = as_int(&args[0]) as usize;
        let data = as_text(&args[1]);
        let sent = STREAMS.with(|c| {
            let mut v = c.lock().unwrap();
            v.get_mut(handle).and_then(|s| s.as_mut())
                .and_then(|s| s.write(data.as_bytes()).ok())
                .map(|n| n as i64).unwrap_or(-1)
        });
        Ok(Value::Int(sent))
    });

    interp.register_extern("__os_tcp_recv", |args| {
        let handle = as_int(&args[0]) as usize;
        let max = as_int(&args[1]) as usize;
        let text = STREAMS.with(|c| {
            let mut v = c.lock().unwrap();
            v.get_mut(handle).and_then(|s| s.as_mut()).map(|s| {
                let mut buf = vec![0u8; max];
                let n = s.read(&mut buf).unwrap_or(0);
                buf.truncate(n);
                String::from_utf8_lossy(&buf).into_owned()
            }).unwrap_or_default()
        });
        Ok(Value::Text(text))
    });

    interp.register_extern("__os_tcp_close", |args| {
        let handle = as_int(&args[0]) as usize;
        STREAMS.with(|c| { let mut v = c.lock().unwrap(); if let Some(s) = v.get_mut(handle) { *s = None; } });
        Ok(Value::Unit)
    });

    // --- TCP server ---

    interp.register_extern("__os_tcp_listen", |args| {
        let port = as_int(&args[0]) as u16;
        let handle = match TcpListener::bind(format!("0.0.0.0:{port}")) {
            Ok(l) => { l.set_nonblocking(true).ok(); LISTENERS.with(|c| { let mut v = c.lock().unwrap(); v.push(Some(l)); v.len() as i64 - 1 }) }
            Err(_) => -1,
        };
        Ok(Value::Int(handle))
    });

    // Non-blocking accept. Returns a new STREAMS handle or -1 if no pending connection.
    interp.register_extern("__os_tcp_accept", |args| {
        let lh = as_int(&args[0]) as usize;
        let stream = LISTENERS.with(|c| {
            let v = c.lock().unwrap();
            v.get(lh).and_then(|l| l.as_ref()).and_then(|l| l.accept().ok()).map(|(s, _)| s)
        });
        let handle = match stream {
            Some(s) => {
                // Short write timeout so a slow client never stalls the game loop.
                s.set_write_timeout(Some(Duration::from_millis(5))).ok();
                // Short read timeout for non-blocking recv from Orion side.
                s.set_read_timeout(Some(Duration::from_millis(1))).ok();
                STREAMS.with(|c| { let mut v = c.lock().unwrap(); v.push(Some(s)); v.len() as i64 - 1 })
            }
            None => -1,
        };
        Ok(Value::Int(handle))
    });

    interp.register_extern("__os_tcp_close_server", |args| {
        let h = as_int(&args[0]) as usize;
        LISTENERS.with(|c| { let mut v = c.lock().unwrap(); if let Some(s) = v.get_mut(h) { *s = None; } });
        Ok(Value::Unit)
    });
}