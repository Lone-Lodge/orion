//! Diagnostics — rustc-style error rendering.
//!
//! Turns a `(source, line, col, message)` into a friendly, pointed message:
//!
//! ```text
//! error: expected `:`, found Newline
//!  --> 3:14
//!   |
//! 3 | data Position  x: f32
//!   |              ^
//! ```
//!
//! Lexer and parser errors carry a line + column, so they render with the caret.
//! Semantic (checker) errors don't carry spans yet — they render as a plain
//! `error: …` line until the AST grows spans (see ORION.md §19).

/// Render a positioned diagnostic with a caret under the offending column.
pub fn render(src: &str, line: u32, col: u32, message: &str) -> String {
    render_at(None, src, line, col, message)
}

/// Like `render`, but name the file in the location line (for multi-module builds).
pub fn render_file(file: &str, src: &str, line: u32, col: u32, message: &str) -> String {
    render_at(Some(file), src, line, col, message)
}

fn render_at(file: Option<&str>, src: &str, line: u32, col: u32, message: &str) -> String {
    let mut out = format!("error: {message}\n");
    match file {
        Some(f) => out.push_str(&format!(" --> {f}:{line}:{col}\n")),
        None => out.push_str(&format!(" --> {line}:{col}\n")),
    }
    if let Some(text) = src.lines().nth(line.saturating_sub(1) as usize) {
        let gutter = line.to_string();
        let pad = " ".repeat(gutter.len());
        out.push_str(&format!("{pad} |\n"));
        out.push_str(&format!("{gutter} | {text}\n"));
        out.push_str(&format!("{pad} | {}^", " ".repeat(col as usize)));
    }
    out
}

/// Render a message with no source position (e.g. a semantic error).
pub fn plain(message: &str) -> String {
    format!("error: {message}")
}
