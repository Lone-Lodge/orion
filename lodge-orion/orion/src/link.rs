//! Standalone-executable builder. Sits on top of `aot::compile_object`: takes
//! the `.o` Cranelift emits, generates a tiny wrapper `main` that calls the
//! chosen Orion function with `argv` arguments and prints the result, then
//! drives a system compiler/linker to merge them into a runnable binary.
//!
//! Preferred driver is `rustc` — it comes with the same toolchain Orion is
//! built with, bundles a linker (rust-lld), and knows how to link COFF/ELF/
//! Mach-O objects on every platform. Falls back to `cc`/`gcc`/`clang`/`cl`
//! if found on PATH.
//!
//! Only `int` (i64) and `f64` parameters/returns are supported — that's also
//! the JIT's surface today. More types come when the JIT learns them.

use std::path::{Path, PathBuf};
use std::process::Command;

use crate::ast::{Decl, FnDecl, Program, Type};
use crate::jit::{JTy, jty_of_type};

/// Build a standalone executable from `program` rooted at fn `root`. The
/// produced binary, when run, calls `root` with arguments parsed from `argv`
/// and prints the result on stdout.
pub fn build_executable(program: &Program, root: &str, out: &str) -> Result<(), String> {
    let f = find_fn(program, root)?;
    check_supported(f)?;

    let tmp = make_tmp_dir()?;
    let obj_path = tmp.join(if cfg!(windows) { "orion.obj" } else { "orion.o" });

    crate::aot::compile_object(program, root, obj_path.to_str().unwrap())?;

    let driver = find_driver()
        .ok_or_else(|| "no compiler driver found on PATH — install `rustc` (it ships with cargo) or a C compiler (cc/gcc/clang/cl)".to_string())?;

    match driver {
        Driver::Rustc => {
            let rs_path = tmp.join("main.rs");
            std::fs::write(&rs_path, generate_rust_main(f)?).map_err(|e| e.to_string())?;
            invoke_rustc(&rs_path, &obj_path, out)?;
        }
        Driver::Cc(kind) => {
            let c_path = tmp.join("main.c");
            std::fs::write(&c_path, generate_c_main(f)?).map_err(|e| e.to_string())?;
            invoke_cc(&kind, &c_path, &obj_path, out)?;
        }
    }

    let _ = std::fs::remove_dir_all(&tmp);
    Ok(())
}

fn find_fn<'a>(program: &'a Program, root: &str) -> Result<&'a FnDecl, String> {
    program.decls.iter().find_map(|d| match d {
        Decl::Fn(f) if f.name == root => Some(f),
        _ => None,
    }).ok_or_else(|| format!("no function `{root}` in program"))
}

/// Only int/f64 signatures map cleanly to the C ABI we emit; reject anything
/// else early with a useful message instead of producing a broken binary.
/// We check the type *name* explicitly because the JIT's `jty_of_type` falls
/// back to int for anything unknown — that'd silently smuggle a `Text` param
/// through as i64 and produce a binary that segfaults on first use.
fn check_supported(f: &FnDecl) -> Result<(), String> {
    let ret = f.ret.as_ref()
        .ok_or_else(|| format!("fn `{}` needs a return type annotation to be linkable", f.name))?;
    if !is_linkable_type(ret) {
        return Err(format!("fn `{}`: only int/f64 return types are linkable today, not `{}`", f.name, type_name(ret)));
    }
    for p in &f.params {
        let t = p.ty.as_ref()
            .ok_or_else(|| format!("fn `{}`: parameter `{}` needs a type annotation to be linkable", f.name, p.name))?;
        if !is_linkable_type(t) {
            return Err(format!("fn `{}`: parameter `{}` of type `{}` is not linkable today (only int/f64 are supported)", f.name, p.name, type_name(t)));
        }
    }
    Ok(())
}

fn is_linkable_type(t: &Type) -> bool {
    match t {
        Type::Named(n) => matches!(n.as_str(), "int" | "f32" | "f64" | "float"),
        _ => false,
    }
}

fn type_name(t: &Type) -> String {
    match t {
        Type::Named(n) => n.clone(),
        _ => format!("{t:?}"),
    }
}

fn make_tmp_dir() -> Result<PathBuf, String> {
    // Unique per call — two threads linking in parallel must not share scratch.
    use std::sync::atomic::{AtomicU64, Ordering};
    static N: AtomicU64 = AtomicU64::new(0);
    let p = std::env::temp_dir().join(format!(
        "orion_link_{}_{}", std::process::id(), N.fetch_add(1, Ordering::SeqCst)
    ));
    std::fs::create_dir_all(&p).map_err(|e| e.to_string())?;
    Ok(p)
}

/// Build the C `extern` declaration and `main` body. The C ABI for our
/// emitted object is: `int` → `long long`, `f64` → `double`.
fn generate_c_main(f: &FnDecl) -> Result<String, String> {
    let ret_c = c_ty(f.ret.as_ref().unwrap());
    let params_c: Vec<String> = f.params.iter().enumerate().map(|(i, p)| {
        let cty = p.ty.as_ref().map(c_ty_of_type).unwrap_or("long long");
        format!("{cty} a{i}")
    }).collect();
    let proto = format!("extern {ret_c} {}({});", f.name, params_c.join(", "));

    let parse_args = f.params.iter().enumerate().map(|(i, p)| {
        let cty = p.ty.as_ref().map(c_ty_of_type).unwrap_or("long long");
        match cty {
            "double" => format!("    double a{i} = (argc > {}) ? atof(argv[{}]) : 0.0;", i + 1, i + 1),
            _ => format!("    long long a{i} = (argc > {}) ? atoll(argv[{}]) : 0;", i + 1, i + 1),
        }
    }).collect::<Vec<_>>().join("\n");

    let arg_names = (0..f.params.len()).map(|i| format!("a{i}")).collect::<Vec<_>>().join(", ");
    let printf_fmt = match ret_c {
        "double" => r#"printf("%.17g\n", r);"#,
        _ => r#"printf("%lld\n", r);"#,
    };

    Ok(format!(r#"#include <stdio.h>
#include <stdlib.h>

{proto}

int main(int argc, char** argv) {{
{parse_args}
    {ret_c} r = {fname}({arg_names});
    {printf_fmt}
    return 0;
}}
"#, fname = f.name))
}

fn c_ty(t: &Type) -> &'static str { c_ty_of_type(t) }
fn c_ty_of_type(t: &Type) -> &'static str {
    match jty_of_type(t) {
        JTy::Float => "double",
        JTy::Int => "long long",
    }
}

enum Driver {
    Rustc,
    Cc(CompilerKind),
}

enum CompilerKind {
    /// gcc/clang/cc style: `<cc> -o out main.c orion.o`
    Unix(String),
    /// MSVC `cl /Fe:out main.c orion.obj`
    Msvc,
}

/// Prefer rustc — it's reliably present and brings its own linker. Fall back
/// to platform C compilers if available.
fn find_driver() -> Option<Driver> {
    if which("rustc").is_some() {
        return Some(Driver::Rustc);
    }
    for name in ["cc", "gcc", "clang"] {
        if which(name).is_some() {
            return Some(Driver::Cc(CompilerKind::Unix(name.to_string())));
        }
    }
    if cfg!(windows) && which("cl").is_some() {
        return Some(Driver::Cc(CompilerKind::Msvc));
    }
    None
}

/// Generate a tiny Rust `main.rs` with the FFI declaration and an argv parser.
fn generate_rust_main(f: &FnDecl) -> Result<String, String> {
    let ret_rs = rust_ty(f.ret.as_ref().unwrap());
    let params_rs: Vec<String> = f.params.iter().enumerate().map(|(i, p)| {
        let rt = p.ty.as_ref().map(rust_ty_of_type).unwrap_or("i64");
        format!("a{i}: {rt}")
    }).collect();

    let parse_args = f.params.iter().enumerate().map(|(i, p)| {
        let rt = p.ty.as_ref().map(rust_ty_of_type).unwrap_or("i64");
        format!("    let a{i}: {rt} = args.get({}).and_then(|s| s.parse().ok()).unwrap_or_default();", i + 1)
    }).collect::<Vec<_>>().join("\n");

    let arg_names = (0..f.params.len()).map(|i| format!("a{i}")).collect::<Vec<_>>().join(", ");
    let fname = &f.name;

    Ok(format!(r#"// Auto-generated by `orion link` — calls into the Cranelift-compiled object.
extern "C" {{
    fn {fname}({params}) -> {ret_rs};
}}

fn main() {{
    let args: Vec<String> = std::env::args().collect();
{parse_args}
    let r = unsafe {{ {fname}({arg_names}) }};
    println!("{{r}}");
}}
"#, params = params_rs.join(", ")))
}

fn rust_ty(t: &Type) -> &'static str { rust_ty_of_type(t) }
fn rust_ty_of_type(t: &Type) -> &'static str {
    match jty_of_type(t) {
        JTy::Float => "f64",
        JTy::Int => "i64",
    }
}

fn invoke_rustc(rs_src: &Path, obj: &Path, out: &str) -> Result<(), String> {
    // `-C link-arg=<obj>` hands the .o straight to the linker.
    let status = Command::new("rustc")
        .arg("--edition").arg("2021")
        .arg("-O")
        .arg(rs_src)
        .arg("-o").arg(out)
        .arg(format!("-Clink-arg={}", obj.display()))
        .status()
        .map_err(|e| format!("failed to launch rustc: {e}"))?;
    if !status.success() {
        return Err(format!("rustc exited with status {}", status.code().unwrap_or(-1)));
    }
    Ok(())
}

fn invoke_cc(cc: &CompilerKind, c_src: &Path, obj: &Path, out: &str) -> Result<(), String> {
    let status = match cc {
        CompilerKind::Unix(name) => Command::new(name)
            .arg("-o").arg(out)
            .arg(c_src)
            .arg(obj)
            .status(),
        CompilerKind::Msvc => Command::new("cl")
            .arg(format!("/Fe:{out}"))
            .arg(c_src)
            .arg(obj)
            .arg("/link")
            .arg("/SUBSYSTEM:CONSOLE")
            .status(),
    }.map_err(|e| format!("failed to launch C compiler: {e}"))?;

    if !status.success() {
        return Err(format!("C compiler exited with status {}", status.code().unwrap_or(-1)));
    }
    Ok(())
}

/// Tiny PATH walk so we don't pull in a crate just for `which`.
fn which(name: &str) -> Option<PathBuf> {
    let exts: &[&str] = if cfg!(windows) { &["", ".exe", ".bat", ".cmd"] } else { &[""] };
    let path = std::env::var_os("PATH")?;
    for dir in std::env::split_paths(&path) {
        for ext in exts {
            let cand = dir.join(format!("{name}{ext}"));
            if cand.is_file() {
                return Some(cand);
            }
        }
    }
    None
}
