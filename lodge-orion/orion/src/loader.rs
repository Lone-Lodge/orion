//! Module loader — resolves `use` imports into one merged program.
//!
//! `use foo` -> `foo.or`; `use foo.bar` -> `foo/bar.or` (dotted = path segments).
//! The loader searches the entry's directory first; orbit hands it extra search
//! roots for resolved package deps.

use std::collections::HashSet;
use std::path::PathBuf;

use crate::ast::Program;

pub struct Loaded {
    pub program: Program,
    /// `(display name, source)` per file; the index is the file id used in spans.
    pub files: Vec<(String, String)>,
}

pub fn load(entry: &str) -> Result<Loaded, String> {
    load_with_search_paths(entry, &[])
}

/// Like `load`, but resolves a `use` against `entry`'s directory first, then
/// each path in `extra_dirs` in order. Used by orbit so `use time` finds
/// `target/orbit_modules/time.or`.
pub fn load_with_search_paths(entry: &str, extra_dirs: &[PathBuf]) -> Result<Loaded, String> {
    let entry_path = PathBuf::from(entry);
    let entry_dir = entry_path.parent().map(|p| p.to_path_buf()).unwrap_or_default();

    let mut files: Vec<(String, String)> = Vec::new();
    let mut seen: HashSet<PathBuf> = HashSet::new();
    let mut decls = Vec::new();
    let mut stack = vec![entry_path.clone()];

    while let Some(path) = stack.pop() {
        if !seen.insert(path.clone()) {
            continue;
        }
        let src = std::fs::read_to_string(&path)
            .map_err(|e| format!("cannot read {}: {e}", path.display()))?;
        let name = path.display().to_string();
        let file_id = files.len() as u32;
        files.push((name.clone(), src.clone()));

        let prog = parse_file_or_diag(&src, &name, file_id)?;

        let parent_dir = path.parent().map(|p| p.to_path_buf()).unwrap_or_else(|| entry_dir.clone());
        for u in &prog.uses {
            let next = resolve_use(u, &parent_dir, extra_dirs)?;
            stack.push(next);
        }
        decls.extend(prog.decls);
    }

    let mut program = Program { uses: Vec::new(), decls };
    // §10 — pre-evaluate every `comptime EXPR` to a literal. Programs
    // that don't use comptime pay near-nothing; programs that do see
    // the work happen here, not at runtime.
    crate::comptime::fold_program(&mut program);
    Ok(Loaded { program, files })
}

fn parse_file_or_diag(src: &str, name: &str, file_id: u32) -> Result<Program, String> {
    let tokens = crate::lex(src)
        .map_err(|e| crate::diag::render_file(name, src, e.line, e.col, &e.message))?;
    crate::parse_file(&tokens, file_id)
        .map_err(|e| crate::diag::render_file(name, src, e.line, e.col, &e.message))
}

/// Find the first existing `<dir>/<u-as-path>.or` over `parent_dir` then each
/// of `extras`. Returns the would-be-parent-dir entry as a fallback so the read
/// error in the caller points at a sensible path.
fn resolve_use(u: &str, parent_dir: &PathBuf, extras: &[PathBuf]) -> Result<PathBuf, String> {
    let rel: PathBuf = u.split('.').collect();
    let mut candidate = parent_dir.join(&rel);
    candidate.set_extension("or");
    if candidate.exists() {
        return Ok(candidate);
    }
    for d in extras {
        let mut p = d.join(&rel);
        p.set_extension("or");
        if p.exists() {
            return Ok(p);
        }
    }
    // Caller will hit a clean "cannot read" diagnostic against parent_dir.
    Ok(candidate)
}
