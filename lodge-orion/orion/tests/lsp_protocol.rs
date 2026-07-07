//! End-to-end tests for the `orion-lsp` binary: framed JSON-RPC in, framed
//! JSON-RPC out. Spawns the compiled binary and pipes messages through stdio,
//! the way a real editor does.

use std::io::{Read, Write};
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

use orion::json::{Value, parse};

fn lsp_binary() -> PathBuf {
    // `tests/` runs with CARGO_BIN_EXE_<name> set when the binary is in the
    // current package; fall back to a manual debug path if it isn't.
    if let Some(p) = option_env!("CARGO_BIN_EXE_orion-lsp") {
        return PathBuf::from(p);
    }
    let mut p = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    p.push("target");
    p.push("debug");
    p.push(if cfg!(windows) { "orion-lsp.exe" } else { "orion-lsp" });
    p
}

/// Frame `body` as a single LSP message.
fn framed(body: &str) -> Vec<u8> {
    format!("Content-Length: {}\r\n\r\n{body}", body.len()).into_bytes()
}

/// Read framed messages from `out` until EOF. Returns the parsed JSON objects.
fn read_all(out: &mut std::process::ChildStdout) -> Vec<Value> {
    let mut buf = Vec::new();
    out.read_to_end(&mut buf).unwrap_or(0);
    split_frames(&buf)
}

fn split_frames(buf: &[u8]) -> Vec<Value> {
    let mut out = Vec::new();
    let mut i = 0;
    while i < buf.len() {
        let Some(rel) = buf[i..].windows(4).position(|w| w == b"\r\n\r\n") else {
            break;
        };
        let header = std::str::from_utf8(&buf[i..i + rel]).unwrap_or("");
        let Some(line) = header.lines().find(|l| l.starts_with("Content-Length:")) else {
            break;
        };
        let Ok(n) = line.trim_start_matches("Content-Length:").trim().parse::<usize>() else {
            break;
        };
        let body_start = i + rel + 4;
        let body_end = body_start + n;
        if buf.len() < body_end {
            break;
        }
        if let Ok(body) = std::str::from_utf8(&buf[body_start..body_end]) {
            if let Ok(v) = parse(body) {
                out.push(v);
            }
        }
        i = body_end;
    }
    out
}

/// Send a list of messages, then exit, then read every response to EOF.
fn dialog(messages: &[String]) -> Vec<Value> {
    let bin = lsp_binary();
    let mut child = Command::new(&bin)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .expect("spawn orion-lsp");
    // Send everything and drop stdin so the server reads EOF.
    {
        let mut stdin = child.stdin.take().expect("stdin");
        for m in messages {
            stdin.write_all(&framed(m)).unwrap();
        }
        let exit = r#"{"jsonrpc":"2.0","method":"exit"}"#;
        stdin.write_all(&framed(exit)).unwrap();
        stdin.flush().unwrap();
        // Dropping `stdin` closes the pipe.
    }
    let mut stdout = child.stdout.take().expect("stdout");
    let frames = read_all(&mut stdout);
    let _ = child.wait_timeout(Duration::from_secs(5));
    frames
}

// Tiny replacement for std::process::Child::wait_timeout (not in std).
trait WaitTimeout {
    fn wait_timeout(&mut self, dur: Duration) -> std::io::Result<Option<std::process::ExitStatus>>;
}
impl WaitTimeout for std::process::Child {
    fn wait_timeout(&mut self, dur: Duration) -> std::io::Result<Option<std::process::ExitStatus>> {
        let deadline = Instant::now() + dur;
        loop {
            if let Some(s) = self.try_wait()? {
                return Ok(Some(s));
            }
            if Instant::now() >= deadline {
                let _ = self.kill();
                return Ok(None);
            }
            std::thread::sleep(Duration::from_millis(10));
        }
    }
}

#[test]
fn initialize_advertises_our_capabilities() {
    let init = r#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"#;
    let frames = dialog(&[init.into()]);
    let init_response = frames
        .iter()
        .find(|f| f.get("id").and_then(|i| i.as_int()) == Some(1))
        .expect("initialize response");
    let caps = init_response.get("result").and_then(|r| r.get("capabilities")).expect("caps");
    assert_eq!(caps.get("hoverProvider").and_then(|v| match v {
        orion::json::Value::Bool(b) => Some(*b),
        _ => None,
    }), Some(true));
    assert_eq!(caps.get("definitionProvider").and_then(|v| match v {
        orion::json::Value::Bool(b) => Some(*b),
        _ => None,
    }), Some(true));
}

#[test]
fn opening_a_good_file_emits_zero_diagnostics() {
    let init = r#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"#;
    let open = r#"{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///tmp/ok.or","languageId":"orion","version":1,"text":"fn f() -> int = 1"}}}"#;
    let frames = dialog(&[init.into(), open.into()]);
    let diag_msg = frames
        .iter()
        .find(|f| f.get("method").and_then(|m| m.as_str()) == Some("textDocument/publishDiagnostics"))
        .expect("publishDiagnostics notification");
    let items = diag_msg.get("params").and_then(|p| p.get("diagnostics")).unwrap();
    if let Value::Array(items) = items {
        assert!(items.is_empty(), "expected no diagnostics, got {items:?}");
    } else {
        panic!("diagnostics is not an array");
    }
}

#[test]
fn opening_a_broken_file_reports_a_diagnostic() {
    let init = r#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"#;
    let open = r#"{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///tmp/bad.or","languageId":"orion","version":1,"text":"fn f() -> int = missing"}}}"#;
    let frames = dialog(&[init.into(), open.into()]);
    let diag_msg = frames
        .iter()
        .find(|f| f.get("method").and_then(|m| m.as_str()) == Some("textDocument/publishDiagnostics"))
        .expect("publishDiagnostics notification");
    let items = diag_msg.get("params").and_then(|p| p.get("diagnostics")).unwrap();
    let Value::Array(items) = items else {
        panic!("diagnostics is not an array");
    };
    assert_eq!(items.len(), 1);
    let msg = items[0].get("message").and_then(|m| m.as_str()).unwrap_or("");
    assert!(msg.contains("missing"), "expected `missing` in: {msg}");
}

#[test]
fn hover_returns_a_signature_for_a_known_function() {
    let init = r#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"#;
    // `fn double(x: int) -> int = x + x` — cursor on `double`, col 4 (0-based).
    let open = r#"{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///tmp/h.or","languageId":"orion","version":1,"text":"fn double(x: int) -> int = x + x"}}}"#;
    let hover = r#"{"jsonrpc":"2.0","id":2,"method":"textDocument/hover","params":{"textDocument":{"uri":"file:///tmp/h.or"},"position":{"line":0,"character":4}}}"#;
    let frames = dialog(&[init.into(), open.into(), hover.into()]);
    let hover_resp = frames
        .iter()
        .find(|f| f.get("id").and_then(|i| i.as_int()) == Some(2))
        .expect("hover response");
    let value = hover_resp
        .get("result")
        .and_then(|r| r.get("contents"))
        .and_then(|c| c.get("value"))
        .and_then(|v| v.as_str())
        .unwrap_or("");
    assert!(value.contains("fn double"), "got: {value}");
    assert!(value.contains("-> int"), "got: {value}");
}

#[test]
fn document_symbol_lists_top_level_decls() {
    let init = r#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"#;
    let open = r#"{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///tmp/s.or","languageId":"orion","version":1,"text":"data Health: hp: int\nfn heal() -> int = 1"}}}"#;
    let req = r#"{"jsonrpc":"2.0","id":3,"method":"textDocument/documentSymbol","params":{"textDocument":{"uri":"file:///tmp/s.or"}}}"#;
    let frames = dialog(&[init.into(), open.into(), req.into()]);
    let resp = frames
        .iter()
        .find(|f| f.get("id").and_then(|i| i.as_int()) == Some(3))
        .expect("documentSymbol response");
    let Value::Array(items) = resp.get("result").unwrap() else {
        panic!("expected array");
    };
    let names: Vec<&str> = items
        .iter()
        .filter_map(|i| i.get("name").and_then(|n| n.as_str()))
        .collect();
    assert_eq!(names, vec!["Health", "heal"]);
}
