//! Tests for the module loader (`use`). Run with `cargo test`.

use orion::interp::Interp;
use orion::loader::load;
use orion::value::Value;

/// Make a fresh sandbox under temp/ — cleaned by Drop.
struct Sandbox(std::path::PathBuf);
impl Sandbox {
    fn new(label: &str) -> Self {
        let p = std::env::temp_dir().join(format!("orion_{label}_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&p);
        std::fs::create_dir_all(&p).unwrap();
        Self(p)
    }
    fn write(&self, rel: &str, body: &str) -> std::path::PathBuf {
        let p = self.0.join(rel);
        if let Some(parent) = p.parent() {
            std::fs::create_dir_all(parent).unwrap();
        }
        std::fs::write(&p, body).unwrap();
        p
    }
}
impl Drop for Sandbox {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

#[test]
fn use_imports_a_function_from_another_file() {
    let dir = std::env::temp_dir();
    let lib = dir.join("orion_mod_geom.or");
    let app = dir.join("orion_mod_app.or");
    std::fs::write(&lib, "fn square(n: int) -> int = n * n\n").unwrap();
    std::fs::write(&app, "use orion_mod_geom\nfn demo() -> int = square(6)\n").unwrap();

    let loaded = load(app.to_str().unwrap()).unwrap();
    let v = Interp::new(&loaded.program).call("demo", vec![]).unwrap();
    assert_eq!(v, Value::Int(36));

    let _ = std::fs::remove_file(&lib);
    let _ = std::fs::remove_file(&app);
}

#[test]
fn dotted_use_imports_a_nested_module() {
    // `use math.geom` should resolve to `math/geom.or` relative to the entry.
    let sb = Sandbox::new("dotted");
    sb.write("math/geom.or", "pub fn cube(n: int) -> int = n * n * n\n");
    let app = sb.write("app.or", "use math.geom\nfn demo() -> int = cube(3)\n");

    let loaded = load(app.to_str().unwrap()).unwrap();
    let v = Interp::new(&loaded.program).call("demo", vec![]).unwrap();
    assert_eq!(v, Value::Int(27));
}

#[test]
fn private_fn_cannot_be_called_from_another_module() {
    let sb = Sandbox::new("priv");
    sb.write("util.or", "fn secret() -> int = 7\n"); // no `pub` -> private
    let app = sb.write("main.or", "use util\nfn demo() -> int = secret()\n");

    let loaded = load(app.to_str().unwrap()).unwrap();
    let err = orion::check::check(&loaded.program).unwrap_err();
    assert!(
        err.message.contains("private"),
        "expected privacy error, got: {}",
        err.message
    );
}

#[test]
fn pub_fn_is_visible_across_modules() {
    let sb = Sandbox::new("pubok");
    sb.write("util.or", "pub fn shared() -> int = 42\n");
    let app = sb.write("main.or", "use util\nfn demo() -> int = shared()\n");

    let loaded = load(app.to_str().unwrap()).unwrap();
    orion::check::check(&loaded.program).unwrap();
    let v = Interp::new(&loaded.program).call("demo", vec![]).unwrap();
    assert_eq!(v, Value::Int(42));
}

#[test]
fn private_use_within_same_module_is_fine() {
    // A non-`pub` fn is fully usable inside its own file.
    let src = "fn helper() -> int = 9\nfn demo() -> int = helper()\n";
    let p = orion::parse(&orion::lex(src).unwrap()).unwrap();
    orion::check::check(&p).unwrap();
}

#[test]
fn spans_carry_the_right_file_id() {
    // The imported module is file 1; an error in it must reference file 1.
    let dir = std::env::temp_dir();
    let lib = dir.join("orion_mod_bad.or");
    let app = dir.join("orion_mod_main.or");
    // `pub` so visibility passes — we're testing the span's file id, not privacy.
    std::fs::write(&lib, "pub fn helper() -> int = missing\n").unwrap(); // unknown name
    std::fs::write(&app, "use orion_mod_bad\nfn demo() -> int = helper()\n").unwrap();

    let loaded = load(app.to_str().unwrap()).unwrap();
    let e = orion::check::check(&loaded.program).unwrap_err();
    let span = e.span.expect("span");
    assert_eq!(span.file, 1); // the error is in the imported module, not the entry

    let _ = std::fs::remove_file(&lib);
    let _ = std::fs::remove_file(&app);
}
