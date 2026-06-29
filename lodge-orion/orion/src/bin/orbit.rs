//! `orbit` — Orion's project tool. Now a *launcher* for `orbit_main.or`:
//! the CLI dispatch, `new` and `add` commands live in pure Orion. The
//! `build`/`run`/`test` commands still need access to Rust's parser,
//! type-checker, and interpreter, so they reach back into Rust via a
//! handful of `__os_orbit_*` primitives.
//!
//! This is the first step of self-hosting (see [[orion-pure-orion-goal]]):
//! orbit's user-facing surface is Orion code. The kernel underneath is
//! still Rust — for now.

use std::path::PathBuf;
use std::{fs, process};

use orion::interp::Interp;
use orion::orbit_toml::OrbitToml;
use orion::stdlib;
use orion::value::Value;

const ORBIT_TOML: &str = "Orbit.toml";
const MODULES_DIR: &str = "target/orbit_modules";

/// The Orion-implemented CLI. Inlined at compile time so the binary is
/// self-contained.
const ORBIT_MAIN_SOURCE: &str = include_str!("../../orbit_main.or");

/// Orbs whose externs we need available in the orbit-CLI Orion program.
/// (Everything the `*.or` calls — fs, io, env, string, etc.)
const ORBIT_DEPS: &[&str] = &[
    "bytes", "string", "format", "io", "fs", "env", "path", "process", "time",
];

fn main() {
    // Concatenate dep-orb sources + orbit_main.or, then parse/check/run.
    // `program` and `interp` must live in `main` because `Interp` borrows
    // from `Program`.
    let mut src = String::new();
    for name in ORBIT_DEPS {
        let orb = stdlib::find(name)
            .unwrap_or_else(|| die(&format!("orbit: missing dep orb `{name}`")));
        src.push_str(orb.source);
        src.push('\n');
    }
    src.push_str(ORBIT_MAIN_SOURCE);

    let tokens = orion::lex(&src).unwrap_or_else(|e| die(&format!("orbit: lex: {e:?}")));
    let program = orion::parse(&tokens).unwrap_or_else(|e| die(&format!("orbit: parse: {e:?}")));
    orion::check::check(&program).unwrap_or_else(|e| die(&format!("orbit: check: {}", e.message)));
    orion::typeck::check_types(&program)
        .unwrap_or_else(|e| die(&format!("orbit: typeck: {}", e.message)));

    let interp = Interp::new(&program);
    for name in ORBIT_DEPS {
        if let Some(orb) = stdlib::find(name) {
            (orb.register)(&interp);
        }
    }
    register_orbit_primitives(&interp);

    match interp.call("main", vec![]) {
        Ok(_) => {}
        Err(e) => {
            eprintln!("orbit: {}", e.message);
            process::exit(1);
        }
    }
}

/// The narrow Rust→Orion bridge the orbit CLI needs for commands that
/// still call into the parser/interpreter.
fn register_orbit_primitives(interp: &Interp) {
    interp.register_extern("__os_orbit_stdlib_orbs", |_args| {
        let names: Vec<Value> = stdlib::ORBS
            .iter()
            .map(|orb| Value::Text(orb.name.to_string()))
            .collect();
        Ok(Value::List(std::sync::Arc::new(names)))
    });

    interp.register_extern("__os_orbit_build", |args| {
        let path = as_text(&args[0]);
        let toml = read_toml();
        let Some(program) = build_program(&path, &toml) else {
            return Ok(Value::Bool(false));
        };
        // §6 — incremental rebuild driver: hash each decl, compare to
        // the cached manifest, and report what would actually need
        // recompilation. Today we still rebuild everything (the JIT is
        // fast); the cache is the trail of breadcrumbs the build
        // system reads to skip work in a future pipeline.
        let mut summary = std::collections::BTreeMap::new();
        use orion::ast::Decl;
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};
        for decl in &program.decls {
            let (kind, name) = match decl {
                Decl::Fn(f) => ("fn", f.name.clone()),
                Decl::System(s) => ("system", s.name.clone()),
                Decl::Data(d) => ("data", d.name.clone()),
                Decl::Enum(e) => ("enum", e.name.clone()),
                _ => continue,
            };
            let mut h = DefaultHasher::new();
            format!("{decl:?}").hash(&mut h);
            summary.insert(format!("{kind} {name}"), h.finish());
        }
        // Persist the manifest so the next build can diff.
        if let Ok(dir) = std::env::current_dir() {
            let cache = dir.join("target").join("orion-cache");
            std::fs::create_dir_all(&cache).ok();
            let manifest = cache.join("build.manifest");
            let body: String = summary.iter().map(|(k, v)| format!("{k}\t{v}")).collect::<Vec<_>>().join("\n");
            std::fs::write(manifest, body).ok();
        }
        Ok(Value::Bool(true))
    });

    interp.register_extern("__os_orbit_run", |args| {
        let path = as_text(&args[0]);
        let fname = as_text(&args[1]);
        let raw_args = match &args[2] {
            Value::List(items) => items.iter().map(as_text).collect::<Vec<_>>(),
            _ => Vec::new(),
        };
        let toml = read_toml();
        let Some(program) = build_program(&path, &toml) else {
            return Ok(Value::Bool(false));
        };
        let runtime = Interp::new(&program);
        register_natives(&runtime, &toml);
        let call_args: Vec<Value> = raw_args.iter().map(|s| to_value(s)).collect();
        match runtime.call(&fname, call_args) {
            Ok(v) => {
                println!("{v}");
                Ok(Value::Bool(true))
            }
            Err(e) => {
                eprintln!("run error: {}", e.message);
                Ok(Value::Bool(false))
            }
        }
    });

    interp.register_extern("__os_orbit_test", |args| {
        let path = as_text(&args[0]);
        let toml = read_toml();
        let Some(program) = build_program(&path, &toml) else {
            return Ok(Value::Int(1));
        };
        let runtime = Interp::new(&program);
        register_natives(&runtime, &toml);

        let tests: Vec<String> = program
            .decls
            .iter()
            .filter_map(|d| match d {
                orion::ast::Decl::Fn(f) if f.name.starts_with("test_") && f.params.is_empty() => {
                    Some(f.name.clone())
                }
                _ => None,
            })
            .collect();

        if tests.is_empty() {
            println!("{path}: no `test_*` functions found");
            return Ok(Value::Int(0));
        }

        let (mut passed, mut failed) = (0i64, 0i64);
        for name in &tests {
            match runtime.call(name, vec![]) {
                Ok(_) => {
                    println!("  ok   {name}");
                    passed += 1;
                }
                Err(e) => {
                    println!("  FAIL {name}: {}", e.message);
                    failed += 1;
                }
            }
        }
        println!("\n{passed} passed, {failed} failed");
        Ok(Value::Int(failed))
    });
}

// ---- toml / deps (shared between build/run/test primitives) ----

fn read_toml() -> OrbitToml {
    if !PathBuf::from(ORBIT_TOML).exists() {
        return OrbitToml::default();
    }
    OrbitToml::read(ORBIT_TOML).unwrap_or_else(|e| die(&format!("orbit: {e}")))
}

fn materialize_orbs(toml: &OrbitToml) -> PathBuf {
    let dir = PathBuf::from(MODULES_DIR);
    if !toml.orbs.is_empty() {
        fs::create_dir_all(&dir)
            .unwrap_or_else(|e| die(&format!("orbit: cannot create {}: {e}", dir.display())));
    }
    for (name, spec) in &toml.orbs {
        // Spec shapes today:
        //   "*"            — bundled stdlib orb
        //   "0.1.0"        — bundled stdlib orb (version ignored at v0)
        //   "path:DIR"     — local orb at DIR (relative to project root).
        //                    Reads DIR/lib.or, transitively walks DIR/Orbit.toml
        //                    to materialise nested local deps.
        if let Some(local) = spec.strip_prefix("path:") {
            materialize_local_orb(name, local, &dir);
            continue;
        }
        match stdlib::find(name) {
            Some(orb) => {
                let path = dir.join(format!("{name}.or"));
                fs::write(&path, orb.source)
                    .unwrap_or_else(|e| die(&format!("orbit: cannot write {}: {e}", path.display())));
            }
            None => die(&format!("orbit: unknown orb `{name}` (not in bundled stdlib)")),
        }
    }
    dir
}

/// Copy a path-based orb's `lib.or` into the modules dir and recurse
/// into its own `Orbit.toml` so nested local deps materialise too.
fn materialize_local_orb(name: &str, local_path: &str, modules_dir: &PathBuf) {
    let lib_src_path = PathBuf::from(local_path).join("lib.or");
    let source = fs::read_to_string(&lib_src_path).unwrap_or_else(|e| {
        die(&format!(
            "orbit: local orb `{name}` — cannot read {}: {e}",
            lib_src_path.display()
        ))
    });
    let dest = modules_dir.join(format!("{name}.or"));
    fs::write(&dest, &source).unwrap_or_else(|e| {
        die(&format!(
            "orbit: cannot write {}: {e}",
            dest.display()
        ))
    });

    // Recurse into nested Orbit.toml so transitive path-deps work.
    let nested_toml = PathBuf::from(local_path).join("Orbit.toml");
    if nested_toml.exists() {
        if let Ok(nested) = OrbitToml::read(nested_toml.to_str().unwrap_or("")) {
            // Resolve nested path-deps relative to THIS orb's directory.
            for (nested_name, nested_spec) in &nested.orbs {
                if let Some(rel) = nested_spec.strip_prefix("path:") {
                    let joined = PathBuf::from(local_path).join(rel);
                    let joined_str = joined.to_str().unwrap_or("").to_string();
                    materialize_local_orb(nested_name, &joined_str, modules_dir);
                } else if let Some(orb) = stdlib::find(nested_name) {
                    let path = modules_dir.join(format!("{nested_name}.or"));
                    fs::write(&path, orb.source).unwrap_or_else(|e| {
                        die(&format!("orbit: cannot write {}: {e}", path.display()))
                    });
                }
            }
        }
    }
}

fn register_natives(interp: &Interp, toml: &OrbitToml) {
    for name in toml.orbs.keys() {
        if let Some(orb) = stdlib::find(name) {
            (orb.register)(interp);
        }
    }
}

fn build_program(path: &str, toml: &OrbitToml) -> Option<orion::ast::Program> {
    let modules_dir = materialize_orbs(toml);
    let loaded = match orion::loader::load_with_search_paths(path, &[modules_dir]) {
        Ok(l) => l,
        Err(e) => {
            eprintln!("{e}");
            return None;
        }
    };
    let program = loaded.program;
    let files = loaded.files;
    let report = |span: Option<orion::ast::Span>, msg: &str| match span {
        Some(s) => orion::diag::render_file(
            &files[s.file as usize].0,
            &files[s.file as usize].1,
            s.line,
            s.col,
            msg,
        ),
        None => orion::diag::plain(msg),
    };
    if let Err(e) = orion::check::check(&program) {
        eprintln!("{}", report(e.span, &e.message));
        return None;
    }
    if let Err(e) = orion::typeck::check_types(&program) {
        eprintln!("{}", report(e.span, &e.message));
        return None;
    }
    if let Err(e) = orion::ownership::check(&program) {
        eprintln!("{}", report(e.span, &e.message));
        return None;
    }
    Some(program)
}

fn to_value(s: &str) -> Value {
    if let Ok(i) = s.parse::<i64>() {
        Value::Int(i)
    } else if let Ok(f) = s.parse::<f64>() {
        Value::Float(f)
    } else {
        Value::Text(s.to_string())
    }
}

fn as_text(v: &Value) -> String {
    match v {
        Value::Text(s) => s.clone(),
        other => other.to_string(),
    }
}

#[track_caller]
fn die(msg: &str) -> ! {
    eprintln!("{msg}");
    process::exit(1);
}

