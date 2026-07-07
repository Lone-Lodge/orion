//! Source-level inspection: lex, parse, check-ok, and LSP queries.

use super::{die, read};

pub fn lex(path: &str) {
    let src = read(path);
    let tokens = orion::lex(&src)
        .unwrap_or_else(|e| die(&orion::diag::render(&src, e.line, e.col, &e.message)));
    println!("{} tokens from {path}:\n", tokens.len());
    for t in &tokens {
        println!("{:>3}:{:<3} {:?}", t.line, t.col, t.tok);
    }
}

pub fn parse(path: &str) {
    let src = read(path);
    let tokens = orion::lex(&src)
        .unwrap_or_else(|e| die(&orion::diag::render(&src, e.line, e.col, &e.message)));
    let program = orion::parse(&tokens)
        .unwrap_or_else(|e| die(&orion::diag::render(&src, e.line, e.col, &e.message)));
    println!("AST from {path}:\n\n{program:#?}");
}

pub fn check_ok(path: &str) {
    println!("{path}: ok — no errors found");
}

pub fn symbols(path: &str) {
    let src = read(path);
    for s in orion::lsp::symbols(&src) {
        println!("{:>4}  {:?}  {}", s.line, s.kind, s.name);
    }
}

pub fn hover(path: &str, rest: &[String]) {
    let src = read(path);
    let (line, col) = lsp_position(rest);
    let uri = path_to_uri(path);
    match orion::lsp::hover(&src, line, col, Some(&uri)) {
        Some(sig) => println!("{sig}"),
        None => println!("(no info at {line}:{col})"),
    }
}

fn path_to_uri(path: &str) -> String {
    // Best-effort: turn a CLI path into a file:// URI so orb-dep resolution
    // can find the project's Orbit.toml from inside the LSP analysis layer.
    let abs = std::fs::canonicalize(path)
        .map(|p| p.to_string_lossy().into_owned())
        .unwrap_or_else(|_| path.to_string());
    let normalised = abs.replace('\\', "/");
    let trimmed = normalised.strip_prefix("//?/").unwrap_or(&normalised);
    format!("file:///{}", trimmed.trim_start_matches('/'))
}

pub fn goto(path: &str, rest: &[String]) {
    let src = read(path);
    let (line, col) = lsp_position(rest);
    match orion::lsp::goto_def(&src, line, col) {
        Some((l, c)) => println!("{path}:{l}:{c}"),
        None => println!("(no definition for the name at {line}:{col})"),
    }
}

fn lsp_position(rest: &[String]) -> (u32, u32) {
    let line: u32 = rest.get(1).and_then(|s| s.parse().ok()).unwrap_or(1);
    let col: u32 = rest.get(2).and_then(|s| s.parse().ok()).unwrap_or(0);
    (line, col)
}
