//! LSP server helpers — framing, JSON-RPC envelope, and the shape builders /
//! extractors for the methods the analysis layer answers. The transport (stdin
//! framing) and dispatch loop live in the `orion-lsp` binary; this module gives
//! it the wire-format vocabulary.

use std::collections::BTreeMap;
use std::io::{Read, Write, stdin, stdout};

use crate::json::Value;
use crate::lsp::{self, SymbolKind};

// ---- transport ----

/// Read one `Content-Length:`-framed message from stdin. `None` on EOF.
pub fn read_message() -> Option<String> {
    let mut header = String::new();
    let mut byte = [0u8; 1];
    let stdin = stdin();
    let mut h = stdin.lock();
    loop {
        if h.read(&mut byte).ok()? == 0 {
            return None;
        }
        header.push(byte[0] as char);
        if header.ends_with("\r\n\r\n") {
            break;
        }
    }
    let n = parse_content_length(&header)?;
    let mut buf = vec![0u8; n];
    h.read_exact(&mut buf).ok()?;
    String::from_utf8(buf).ok()
}

fn parse_content_length(header: &str) -> Option<usize> {
    header
        .split("\r\n")
        .find_map(|line| line.strip_prefix("Content-Length:"))
        .and_then(|rest| rest.trim().parse().ok())
}

fn write_message(body: &str) {
    let out = stdout();
    let mut h = out.lock();
    let _ = write!(h, "Content-Length: {}\r\n\r\n{body}", body.len());
    let _ = h.flush();
}

/// Send a JSON-RPC response for the given request id.
pub fn respond(id: Option<Value>, result: Option<Value>) {
    let mut o = Value::obj();
    o.insert("jsonrpc".into(), Value::Str("2.0".into()));
    if let Some(id) = id {
        o.insert("id".into(), id);
    }
    if let Some(r) = result {
        o.insert("result".into(), r);
    }
    write_message(&Value::Object(o).to_string());
}

fn notify(method: &str, params: Value) {
    let mut o = Value::obj();
    o.insert("jsonrpc".into(), Value::Str("2.0".into()));
    o.insert("method".into(), Value::Str(method.into()));
    o.insert("params".into(), params);
    write_message(&Value::Object(o).to_string());
}

// ---- diagnostics ----

pub fn publish_diagnostics(uri: &str, src: &str) {
    let items: Vec<Value> = lsp::diagnostics(src, Some(uri)).into_iter().map(diag_to_value).collect();
    let mut params = Value::obj();
    params.insert("uri".into(), Value::Str(uri.into()));
    params.insert("diagnostics".into(), Value::Array(items));
    notify("textDocument/publishDiagnostics", Value::Object(params));
}

fn diag_to_value(d: lsp::Diag) -> Value {
    let mut o = Value::obj();
    o.insert("range".into(), zero_width_range(d.line.saturating_sub(1), d.col));
    o.insert("severity".into(), Value::Int(1)); // Error
    o.insert("source".into(), Value::Str("orion".into()));
    o.insert("message".into(), Value::Str(d.message));
    Value::Object(o)
}

// ---- shape builders ----

pub fn initialize_result() -> Value {
    let mut caps = Value::obj();
    caps.insert("textDocumentSync".into(), Value::Int(1)); // full-document sync
    caps.insert("hoverProvider".into(), Value::Bool(true));
    caps.insert("definitionProvider".into(), Value::Bool(true));
    caps.insert("documentSymbolProvider".into(), Value::Bool(true));
    let mut info = Value::obj();
    info.insert("name".into(), Value::Str("orion-lsp".into()));
    info.insert("version".into(), Value::Str(env!("CARGO_PKG_VERSION").into()));
    let mut result = Value::obj();
    result.insert("capabilities".into(), Value::Object(caps));
    result.insert("serverInfo".into(), Value::Object(info));
    Value::Object(result)
}

pub fn hover_result(sig: &str) -> Value {
    let mut contents = Value::obj();
    contents.insert("kind".into(), Value::Str("markdown".into()));
    contents.insert("value".into(), Value::Str(format!("```orion\n{sig}\n```")));
    let mut o = Value::obj();
    o.insert("contents".into(), Value::Object(contents));
    Value::Object(o)
}

pub fn location(uri: &str, line: u32, col: u32) -> Value {
    let mut o = Value::obj();
    o.insert("uri".into(), Value::Str(uri.into()));
    o.insert("range".into(), zero_width_range(line, col));
    Value::Object(o)
}

pub fn document_symbols(src: &str) -> Value {
    let items: Vec<Value> = lsp::symbols(src).into_iter().map(symbol_to_value).collect();
    Value::Array(items)
}

fn symbol_to_value(s: lsp::Symbol) -> Value {
    let mut o = Value::obj();
    o.insert("name".into(), Value::Str(s.name));
    o.insert("kind".into(), Value::Int(symbol_kind_code(&s.kind)));
    let range = full_line_range(s.line.saturating_sub(1));
    o.insert("range".into(), range.clone());
    o.insert("selectionRange".into(), range);
    Value::Object(o)
}

fn position(line: u32, col: u32) -> Value {
    let mut p = Value::obj();
    p.insert("line".into(), Value::Int(line as i64));
    p.insert("character".into(), Value::Int(col as i64));
    Value::Object(p)
}

fn zero_width_range(line: u32, col: u32) -> Value {
    let pos = position(line, col);
    let mut r = Value::obj();
    r.insert("start".into(), pos.clone());
    r.insert("end".into(), pos);
    Value::Object(r)
}

fn full_line_range(line: u32) -> Value {
    let mut r = Value::obj();
    r.insert("start".into(), position(line, 0));
    r.insert("end".into(), position(line, 1024)); // wide enough
    Value::Object(r)
}

fn symbol_kind_code(k: &SymbolKind) -> i64 {
    // Standard LSP SymbolKind values.
    match k {
        SymbolKind::Fn => 12,     // Function
        SymbolKind::Data => 23,   // Struct
        SymbolKind::Enum => 10,   // Enum
        SymbolKind::System => 6,  // Method
        SymbolKind::Query => 13,  // Variable
        SymbolKind::Trait => 11,  // Interface
        SymbolKind::Impl => 19,   // Object
    }
}

// ---- request extractors ----

pub fn doc_for<'d>(docs: &'d BTreeMap<String, String>, req: &Value) -> Option<&'d str> {
    let uri = req.get("params")?.get("textDocument")?.get("uri")?.as_str()?;
    docs.get(uri).map(|s| s.as_str())
}

pub fn uri_of(req: &Value) -> Option<String> {
    Some(req.get("params")?.get("textDocument")?.get("uri")?.as_str()?.to_string())
}

pub fn pos_from(req: &Value) -> (u32, u32) {
    let pos = req.get("params").and_then(|p| p.get("position"));
    let line = pos.and_then(|p| p.get("line")).and_then(|n| n.as_int()).unwrap_or(0) as u32;
    let col = pos.and_then(|p| p.get("character")).and_then(|n| n.as_int()).unwrap_or(0) as u32;
    (line, col)
}

pub fn extract_open(req: &Value) -> Option<(String, String)> {
    let td = req.get("params")?.get("textDocument")?;
    let uri = td.get("uri")?.as_str()?.to_string();
    let text = td.get("text")?.as_str()?.to_string();
    Some((uri, text))
}

pub fn extract_change(req: &Value) -> Option<(String, String)> {
    let uri = uri_of(req)?;
    let changes = req.get("params")?.get("contentChanges")?;
    let Value::Array(items) = changes else { return None; };
    let text = items.first()?.get("text")?.as_str()?.to_string();
    Some((uri, text))
}
