//! Orion's Language Server — speaks LSP over stdio. Transport, encoders, and
//! extractors live in `orion::lsp::server`; this binary is the dispatch loop.

use std::collections::BTreeMap;

use orion::json::{Value, parse};
use orion::lsp::{self, server};

fn main() {
    let mut docs: BTreeMap<String, String> = BTreeMap::new();

    while let Some(msg) = server::read_message() {
        let Ok(req) = parse(&msg) else { continue };
        let method = req.get("method").and_then(|m| m.as_str()).unwrap_or("");
        let id = req.get("id").cloned();
        if !handle(method, id, &req, &mut docs) {
            break; // `exit` returned false
        }
    }
}

/// Dispatch one request. Returns `false` only on `exit` (the loop should stop).
fn handle(
    method: &str,
    id: Option<Value>,
    req: &Value,
    docs: &mut BTreeMap<String, String>,
) -> bool {
    match method {
        "initialize" => server::respond(id, Some(server::initialize_result())),
        "exit" => return false,
        "shutdown" | "initialized" => {
            if id.is_some() {
                server::respond(id, Some(Value::Null));
            }
        }
        "textDocument/didOpen" => on_open(req, docs),
        "textDocument/didChange" => on_change(req, docs),
        "textDocument/didClose" => on_close(req, docs),
        "textDocument/hover" => on_hover(req, docs, id),
        "textDocument/definition" => on_definition(req, docs, id),
        "textDocument/documentSymbol" => on_symbols(req, docs, id),
        _ => {
            if id.is_some() {
                server::respond(id, Some(Value::Null));
            }
        }
    }
    true
}

fn on_open(req: &Value, docs: &mut BTreeMap<String, String>) {
    if let Some((uri, text)) = server::extract_open(req) {
        docs.insert(uri.clone(), text.clone());
        server::publish_diagnostics(&uri, &text);
    }
}

fn on_change(req: &Value, docs: &mut BTreeMap<String, String>) {
    if let Some((uri, text)) = server::extract_change(req) {
        docs.insert(uri.clone(), text.clone());
        server::publish_diagnostics(&uri, &text);
    }
}

fn on_close(req: &Value, docs: &mut BTreeMap<String, String>) {
    if let Some(uri) = server::uri_of(req) {
        docs.remove(&uri);
    }
}

fn on_hover(req: &Value, docs: &BTreeMap<String, String>, id: Option<Value>) {
    let src = server::doc_for(docs, req).unwrap_or("");
    let (line, col) = server::pos_from(req);
    let uri = server::uri_of(req);
    let result = match lsp::hover(src, line + 1, col, uri.as_deref()) {
        Some(sig) => server::hover_result(&sig),
        None => Value::Null,
    };
    server::respond(id, Some(result));
}

fn on_definition(req: &Value, docs: &BTreeMap<String, String>, id: Option<Value>) {
    let src = server::doc_for(docs, req).unwrap_or("");
    let (line, col) = server::pos_from(req);
    let uri = server::uri_of(req).unwrap_or_default();
    let result = match lsp::goto_def(src, line + 1, col) {
        Some((l, c)) => server::location(&uri, l.saturating_sub(1), c),
        None => Value::Null,
    };
    server::respond(id, Some(result));
}

fn on_symbols(req: &Value, docs: &BTreeMap<String, String>, id: Option<Value>) {
    let src = server::doc_for(docs, req).unwrap_or("");
    server::respond(id, Some(server::document_symbols(src)));
}
