//! Language-server analysis layer. Protocol-free: takes source + position,
//! returns plain Rust values (diagnostics, a hover string, a definition span).
//! An LSP transport shim wraps these for the wire.

mod describe;
mod scan;
pub mod server;

use std::path::{Path, PathBuf};

use crate::ast::{Decl, Span};

pub use describe::{Symbol, SymbolKind};
use describe::describe;
use scan::{decl_span, find_decl_line};

/// One editor-facing diagnostic. 1-based line, 0-based column.
#[derive(Debug, PartialEq)]
pub struct Diag {
    pub message: String,
    pub line: u32,
    pub col: u32,
}

/// Run every analysis pass and return all errors that fire on `src`. Pipeline
/// matches `orion check`: lex → parse → check → typeck → ownership. The first
/// failing pass wins; later passes don't run.
///
/// When `uri` is given, the nearest `Orbit.toml` above the file is consulted
/// and any built-in orbs it declares get prepended to the source so externs
/// like `bytes_from_text` resolve. Diagnostic line numbers are adjusted back
/// into the user's coordinate space; errors inside the prelude are silently
/// dropped (those orbs are validated by the stdlib test suite, not by the
/// user's editor session).
pub fn diagnostics(src: &str, uri: Option<&str>) -> Vec<Diag> {
    let (prelude, prelude_lines) = build_prelude(uri);
    let full = format!("{prelude}{src}");

    let tokens = match crate::lex(&full) {
        Ok(t) => t,
        Err(e) => {
            return adjust(
                vec![Diag { message: e.message, line: e.line, col: e.col }],
                prelude_lines,
            );
        }
    };
    let program = match crate::parse(&tokens) {
        Ok(p) => p,
        Err(e) => {
            return adjust(
                vec![Diag { message: e.message, line: e.line, col: e.col }],
                prelude_lines,
            );
        }
    };
    if let Err(e) = crate::check::check(&program) {
        return adjust(vec![diag_from_span(e.message, e.span)], prelude_lines);
    }
    if let Err(e) = crate::typeck::check_types(&program) {
        return adjust(vec![diag_from_span(e.message, e.span)], prelude_lines);
    }
    if let Err(e) = crate::ownership::check(&program) {
        return adjust(vec![diag_from_span(e.message, e.span)], prelude_lines);
    }
    Vec::new()
}

fn diag_from_span(message: String, span: Option<Span>) -> Diag {
    Diag {
        message,
        line: span.map(|s| s.line).unwrap_or(0),
        col: span.map(|s| s.col).unwrap_or(0),
    }
}

/// Subtract `prelude_lines` from each diagnostic's line and drop any that
/// land inside the prelude (those would mislead the user — the prelude isn't
/// in their editor buffer).
fn adjust(diags: Vec<Diag>, prelude_lines: u32) -> Vec<Diag> {
    if prelude_lines == 0 {
        return diags;
    }
    diags
        .into_iter()
        .filter_map(|d| {
            if d.line > prelude_lines {
                Some(Diag { message: d.message, line: d.line - prelude_lines, col: d.col })
            } else {
                None
            }
        })
        .collect()
}

/// Resolve the file's `Orbit.toml` if there is one and build a prelude of every
/// declared built-in orb's source. Returns the prelude text plus how many lines
/// it spans (so diagnostic line numbers can be adjusted back).
fn build_prelude(uri: Option<&str>) -> (String, u32) {
    let Some(uri) = uri else { return (String::new(), 0) };
    let Some(file_path) = uri_to_path(uri) else { return (String::new(), 0) };
    let Some(toml_path) = find_orbit_toml(&file_path) else { return (String::new(), 0) };
    let toml_str = match toml_path.to_str() {
        Some(s) => s,
        None => return (String::new(), 0),
    };
    let Ok(toml) = crate::orbit_toml::OrbitToml::read(toml_str) else {
        return (String::new(), 0);
    };

    let self_name = orb_name_of(&file_path);
    let project_dir = toml_path.parent().map(|p| p.to_path_buf());
    let mut prelude = String::new();
    for (name, spec) in &toml.orbs {
        // Skip the orb that owns this file — its definitions are already in
        // the user's buffer, prepending them would cause duplicate-name errors.
        if Some(name.as_str()) == self_name.as_deref() {
            continue;
        }
        // Local-path orb (`name = "path:DIR"`): read DIR/lib.or from disk.
        if let Some(local) = spec.strip_prefix("path:") {
            if let Some(base) = &project_dir {
                let lib_path = base.join(local).join("lib.or");
                if let Ok(source) = std::fs::read_to_string(&lib_path) {
                    prelude.push_str(&source);
                    prelude.push('\n');
                    continue;
                }
            }
        }
        if let Some(orb) = crate::stdlib::find(name) {
            prelude.push_str(orb.source);
            prelude.push('\n');
        }
    }
    let lines = prelude.matches('\n').count() as u32;
    (prelude, lines)
}

/// Walk up from `file_path` looking for the closest `Orbit.toml`.
fn find_orbit_toml(file_path: &Path) -> Option<PathBuf> {
    let mut dir = file_path.parent()?;
    loop {
        let candidate = dir.join("Orbit.toml");
        if candidate.exists() {
            return Some(candidate);
        }
        dir = dir.parent()?;
    }
}

/// If `file_path` looks like `…/orbs/<name>/lib.or`, return `<name>` so we can
/// skip prepending our own source to ourselves.
fn orb_name_of(file_path: &Path) -> Option<String> {
    let parent = file_path.parent()?;
    let name = parent.file_name()?.to_str()?;
    let grandparent = parent.parent()?.file_name()?.to_str()?;
    if grandparent == "orbs" {
        Some(name.to_string())
    } else {
        None
    }
}

/// Decode a `file://` URI into a filesystem path. Handles the Windows-style
/// `file:///C:/…` shape (with the drive letter colon either literal or
/// percent-encoded as `%3A`) plus generic percent-encoding (`%20`, etc.).
fn uri_to_path(uri: &str) -> Option<PathBuf> {
    let body = uri.strip_prefix("file://")?;
    // Decode FIRST — VS Code on Windows often sends the drive-letter colon as
    // `%3A`, and we need the literal `:` visible before we can detect-and-strip
    // the leading slash that turns `/c:/foo` into `c:/foo`.
    let decoded = percent_decode(body);
    let bytes = decoded.as_bytes();
    let stripped = if decoded.starts_with('/') && bytes.get(2).copied() == Some(b':') {
        decoded[1..].to_string()
    } else {
        decoded
    };
    Some(PathBuf::from(stripped))
}

fn percent_decode(s: &str) -> String {
    let bytes = s.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 2 < bytes.len() {
            if let (Some(h), Some(l)) = (hex_nibble(bytes[i + 1]), hex_nibble(bytes[i + 2])) {
                out.push(h * 16 + l);
                i += 3;
                continue;
            }
        }
        out.push(bytes[i]);
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}

fn hex_nibble(b: u8) -> Option<u8> {
    match b {
        b'0'..=b'9' => Some(b - b'0'),
        b'a'..=b'f' => Some(b - b'a' + 10),
        b'A'..=b'F' => Some(b - b'A' + 10),
        _ => None,
    }
}

/// The word under `(line, col)` — the lookup key for hover and goto-def.
pub fn name_at(src: &str, line: u32, col: u32) -> Option<String> {
    let line_str = src.lines().nth((line.saturating_sub(1)) as usize)?;
    let bytes = line_str.as_bytes();
    let col = col as usize;
    if col > bytes.len() {
        return None;
    }
    let is_word = |b: u8| b.is_ascii_alphanumeric() || b == b'_';
    let mut start = col;
    while start > 0 && is_word(bytes[start - 1]) {
        start -= 1;
    }
    let mut end = col;
    while end < bytes.len() && is_word(bytes[end]) {
        end += 1;
    }
    if start == end {
        return None;
    }
    Some(line_str[start..end].to_string())
}

/// Signature + one-line description for the identifier at `(line, col)`.
///
/// Resolution order, first hit wins:
///   1. Parameter or local binding inside the enclosing fn (so hovering on
///      a fn-param name or a `mut x` shows its type / binding form).
///   2. A top-level decl in the user's own file.
///   3. A top-level decl from any orb-dep declared in `Orbit.toml`. This is
///      what makes `bytes_zeros` show its signature when you're editing a
///      file that depends on the `bytes` orb.
pub fn hover(src: &str, line: u32, col: u32, uri: Option<&str>) -> Option<String> {
    let name = name_at(src, line, col)?;
    let user_program = crate::parse(&crate::lex(src).ok()?).ok()?;

    // Combine user source with the orb-prelude so type inference inside
    // `local_hover` can resolve calls like `byte_at(...)` against the bytes
    // orb's declared signatures. `enclosing_fn` still uses the user's `src`
    // for line lookup, so prelude line numbers don't confuse it.
    let (prelude, _) = build_prelude(uri);
    let combined_program = if prelude.is_empty() {
        user_program.clone()
    } else {
        crate::lex(&format!("{prelude}{src}"))
            .ok()
            .and_then(|t| crate::parse(&t).ok())
            .unwrap_or_else(|| user_program.clone())
    };

    // 1. Local (parameter or in-body binding) inside the enclosing fn.
    if let Some(desc) = scan::local_hover(src, &user_program, &combined_program, &name, line) {
        return Some(desc);
    }
    // 2. Top-level decl in the user's own file.
    if let Some(desc) = user_program.decls.iter().find_map(|d| describe(d, &name)) {
        return Some(desc);
    }
    // 3. Top-level decl in any orb-dep brought in via Orbit.toml.
    if prelude.is_empty() {
        return None;
    }
    let dep_program = crate::parse(&crate::lex(&prelude).ok()?).ok()?;
    dep_program.decls.iter().find_map(|d| describe(d, &name))
}

/// Where the declaration of the name at `(line, col)` lives.
pub fn goto_def(src: &str, line: u32, col: u32) -> Option<(u32, u32)> {
    let name = name_at(src, line, col)?;
    let program = crate::parse(&crate::lex(src).ok()?).ok()?;
    decl_span(src, &program, &name)
}

/// Every top-level declaration's name, kind, and source line — the outline.
pub fn symbols(src: &str) -> Vec<Symbol> {
    let Ok(tokens) = crate::lex(src) else { return Vec::new(); };
    let Ok(program) = crate::parse(&tokens) else { return Vec::new(); };
    program.decls.iter().map(|d| symbol_of(d, src)).collect()
}

fn symbol_of(decl: &Decl, src: &str) -> Symbol {
    let (name, kind) = match decl {
        Decl::Fn(f) => (f.name.clone(), SymbolKind::Fn),
        Decl::Data(d) => (d.name.clone(), SymbolKind::Data),
        Decl::Enum(e) => (e.name.clone(), SymbolKind::Enum),
        Decl::System(s) => (s.name.clone(), SymbolKind::System),
        Decl::Query(q) => (q.name.clone(), SymbolKind::Query),
        Decl::Trait(t) => (t.name.clone(), SymbolKind::Trait),
        Decl::Impl(i) => (format!("{} for {}", i.trait_name, i.for_type), SymbolKind::Impl),
    };
    let line = find_decl_line(src, &name).unwrap_or(0);
    Symbol { name, kind, line }
}
