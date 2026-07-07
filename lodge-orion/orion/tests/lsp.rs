//! Tests for the LSP analysis layer (hover, goto-def, diagnostics, outline).

use orion::lsp;

#[test]
fn diagnostics_are_empty_for_a_good_program() {
    let src = "fn f(x: int) -> int = x + 1\n";
    assert!(lsp::diagnostics(src, None).is_empty());
}

#[test]
fn diagnostics_report_a_parse_error_with_line_and_col() {
    // `=` after `f()` without a body.
    let src = "fn f() -> int =\n";
    let diags = lsp::diagnostics(src, None);
    assert_eq!(diags.len(), 1);
}

#[test]
fn diagnostics_report_an_unknown_name() {
    let src = "fn f() -> int = missing\n";
    let diags = lsp::diagnostics(src, None);
    assert_eq!(diags.len(), 1);
    assert!(diags[0].message.contains("missing"));
}

#[test]
fn hover_on_a_function_shows_its_signature() {
    let src = "fn double(x: int) -> int = x + x\n";
    // `double` starts at line 1, col 3 (after `fn `).
    let sig = lsp::hover(src, 1, 4, None).expect("hover");
    assert!(sig.contains("fn double"), "got: {sig}");
    assert!(sig.contains("x: int"), "got: {sig}");
    assert!(sig.contains("-> int"), "got: {sig}");
}

#[test]
fn hover_on_a_data_shows_its_fields() {
    let src = "data Health: hp: int, max: int\n";
    let sig = lsp::hover(src, 1, 5, None).expect("hover");
    assert!(sig.contains("data Health"), "got: {sig}");
    assert!(sig.contains("hp: int"), "got: {sig}");
}

#[test]
fn hover_on_an_unrelated_position_is_none() {
    let src = "fn f() -> int = 0\n";
    // Position deep into whitespace at a non-existent column.
    assert!(lsp::hover(src, 1, 200, None).is_none());
}

#[test]
fn symbols_lists_top_level_decls_with_their_line() {
    let src = "data Health: hp: int\nfn heal(target: Entity) -> int = 0\nenum Shape:\n    Circle\n    Square\n";
    let syms = lsp::symbols(src);
    assert_eq!(syms.len(), 3);
    assert_eq!(syms[0].name, "Health");
    assert_eq!(syms[0].kind, lsp::SymbolKind::Data);
    assert_eq!(syms[0].line, 1);
    assert_eq!(syms[1].name, "heal");
    assert_eq!(syms[1].kind, lsp::SymbolKind::Fn);
    assert_eq!(syms[1].line, 2);
    assert_eq!(syms[2].name, "Shape");
    assert_eq!(syms[2].kind, lsp::SymbolKind::Enum);
    assert_eq!(syms[2].line, 3);
}

#[test]
fn goto_def_finds_a_function_declaration() {
    let src = "fn helper() -> int = 1\nfn demo() -> int = helper()\n";
    // Cursor on `helper` in the call on line 2.
    let (line, _col) = lsp::goto_def(src, 2, 20).expect("goto");
    assert_eq!(line, 1);
}

#[test]
fn goto_def_on_a_data_type_jumps_to_its_line() {
    let src = "data Health: hp: int\nfn make() -> Entity = spawn Health{hp: 10}\n";
    // Cursor on `Health` in the spawn on line 2.
    let (line, _col) = lsp::goto_def(src, 2, 29).expect("goto");
    assert_eq!(line, 1);
}

#[test]
fn name_at_extracts_the_word_under_cursor() {
    let src = "fn doubled(n: int) -> int = n + n\n";
    assert_eq!(lsp::name_at(src, 1, 5).as_deref(), Some("doubled"));
    assert_eq!(lsp::name_at(src, 1, 11).as_deref(), Some("n"));
}

// ---- orb dep prelude (the bug fix that motivated this) ----

#[test]
fn diagnostics_resolve_orb_deps_via_orbit_toml() {
    // Create a tiny project that declares the `bytes` orb as a built-in dep,
    // then check a file that calls `bytes_zeros` from it. Without the prelude
    // fix this would error with "unknown function `bytes_zeros`"; with the fix
    // it should be clean.
    let tmp = std::env::temp_dir().join(format!("orion_lsp_dep_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&tmp);
    let lib = tmp.join("orbs").join("mini");
    std::fs::create_dir_all(&lib).unwrap();
    std::fs::write(
        lib.join("Orbit.toml"),
        "name = \"mini\"\n[orbs]\nbytes = { built-in = true }\n",
    )
    .unwrap();
    let user_src = "pub fn make_empty() -> [int] = bytes_zeros(0)\n";
    let user_path = lib.join("lib.or");
    std::fs::write(&user_path, user_src).unwrap();

    let uri = format!("file:///{}", user_path.to_string_lossy().replace('\\', "/"));
    let diags = lsp::diagnostics(user_src, Some(&uri));
    assert!(
        diags.is_empty(),
        "expected no diagnostics, got {diags:?}",
    );

    let _ = std::fs::remove_dir_all(&tmp);
}

#[test]
fn diagnostics_report_user_typo_at_correct_line() {
    // Reproduces the original misleading-error symptom: with `bytes` loaded via
    // Orbit.toml, an undefined `input_bytes` identifier should be reported as
    // `unknown name input_bytes` pointing at the user's line — NOT as a spurious
    // "unknown function bytes_zeros" at line 1.
    let tmp = std::env::temp_dir().join(format!("orion_lsp_typo_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&tmp);
    let lib = tmp.join("orbs").join("typotest");
    std::fs::create_dir_all(&lib).unwrap();
    std::fs::write(
        lib.join("Orbit.toml"),
        "name = \"typotest\"\n[orbs]\nbytes = { built-in = true }\n",
    )
    .unwrap();
    let user_src =
        "pub fn f(bytes: [int]) -> int:\n    n = bytes_length(input_bytes)\n    n\n";
    let user_path = lib.join("lib.or");
    std::fs::write(&user_path, user_src).unwrap();

    let uri = format!("file:///{}", user_path.to_string_lossy().replace('\\', "/"));
    let diags = lsp::diagnostics(user_src, Some(&uri));
    assert_eq!(diags.len(), 1, "got {diags:?}");
    assert!(
        diags[0].message.contains("input_bytes"),
        "expected message to name the actual typo, got {:?}",
        diags[0].message,
    );
    // The error should land on the user's line 2 (the line WITH input_bytes),
    // not line 1 or somewhere inside the prelude.
    assert_eq!(diags[0].line, 2, "got {diags:?}");

    let _ = std::fs::remove_dir_all(&tmp);
}

#[test]
fn diagnostics_skip_self_when_editing_an_orbs_lib_or() {
    // If the Orbit.toml lists the SAME orb the user is editing, prepending its
    // source would cause "duplicate definition" errors. The prelude builder
    // detects this and skips the self-include.
    let tmp = std::env::temp_dir().join(format!("orion_lsp_self_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&tmp);
    let lib = tmp.join("orbs").join("base64");
    std::fs::create_dir_all(&lib).unwrap();
    std::fs::write(
        lib.join("Orbit.toml"),
        "name = \"base64\"\n[orbs]\nbase64 = { built-in = true }\nbytes = { built-in = true }\n",
    )
    .unwrap();
    // A trivial, valid function — should be clean regardless of self-inclusion.
    let user_src = "pub fn hi() -> int = 1\n";
    let user_path = lib.join("lib.or");
    std::fs::write(&user_path, user_src).unwrap();

    let uri = format!("file:///{}", user_path.to_string_lossy().replace('\\', "/"));
    let diags = lsp::diagnostics(user_src, Some(&uri));
    assert!(
        diags.is_empty(),
        "expected no diagnostics (self-include should be skipped), got {diags:?}",
    );

    let _ = std::fs::remove_dir_all(&tmp);
}

#[test]
fn diagnostics_resolve_orb_deps_via_percent_encoded_uri() {
    // VS Code on Windows often percent-encodes the drive-letter colon, sending
    // file:///e%3A/path/lib.or rather than file:///e:/path/lib.or. Both must
    // resolve to the same filesystem path so Orbit.toml is found either way.
    let tmp = std::env::temp_dir().join(format!("orion_lsp_uri_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&tmp);
    let lib = tmp.join("orbs").join("uritest");
    std::fs::create_dir_all(&lib).unwrap();
    std::fs::write(
        lib.join("Orbit.toml"),
        "name = \"uritest\"\n[orbs]\nbytes = { built-in = true }\n",
    )
    .unwrap();
    let user_src = "pub fn f() -> [int] = bytes_zeros(0)\n";
    let user_path = lib.join("lib.or");
    std::fs::write(&user_path, user_src).unwrap();

    let path_str = user_path.to_string_lossy().replace('\\', "/");
    let encoded = path_str.replacen(':', "%3A", 1);
    let uri = format!("file:///{encoded}");
    let diags = lsp::diagnostics(user_src, Some(&uri));
    assert!(
        diags.is_empty(),
        "percent-encoded URI should still resolve deps, got {diags:?}",
    );

    let _ = std::fs::remove_dir_all(&tmp);
}

#[test]
fn hover_on_a_parameter_shows_its_type() {
    let src = "fn double(x: int) -> int = x + x\n";
    // Cursor on `x` inside the body — should resolve to the param.
    let sig = lsp::hover(src, 1, 27, None).expect("hover");
    assert!(sig.contains("x: int"), "got: {sig}");
    assert!(sig.contains("parameter"), "got: {sig}");
}

#[test]
fn hover_on_a_mut_binding_shows_the_local_form() {
    let src = "fn run() -> int:\n    mut count = 0\n    count\n";
    // Cursor on `count` in the tail position.
    let sig = lsp::hover(src, 3, 5, None).expect("hover");
    assert!(sig.contains("mut count"), "got: {sig}");
    assert!(sig.contains("local"), "got: {sig}");
}

#[test]
fn hover_on_a_for_loop_var_shows_loop_form() {
    let src = "fn count() -> int:\n    mut total = 0\n    for i in 0..<10:\n        total += i\n    total\n";
    // Cursor on `i` inside the loop body.
    let sig = lsp::hover(src, 4, 17, None).expect("hover");
    assert!(sig.contains("for i"), "got: {sig}");
    assert!(sig.contains("loop variable"), "got: {sig}");
}

#[test]
fn hover_on_orb_dep_extern_uses_orbit_toml() {
    // Same setup as the diagnostics test — hex-like project depending on bytes.
    let tmp = std::env::temp_dir().join(format!("orion_lsp_hover_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&tmp);
    let lib = tmp.join("orbs").join("mini");
    std::fs::create_dir_all(&lib).unwrap();
    std::fs::write(
        lib.join("Orbit.toml"),
        "name = \"mini\"\n[orbs]\nbytes = { built-in = true }\n",
    )
    .unwrap();
    let user_src = "pub fn f() -> [int] = bytes_zeros(0)\n";
    let user_path = lib.join("lib.or");
    std::fs::write(&user_path, user_src).unwrap();

    let uri = format!("file:///{}", user_path.to_string_lossy().replace('\\', "/"));
    // Cursor on `bytes_zeros` in the call.
    let sig = lsp::hover(user_src, 1, 25, Some(&uri)).expect("hover");
    assert!(sig.contains("bytes_zeros"), "got: {sig}");
    assert!(sig.contains("int"), "got: {sig}");

    let _ = std::fs::remove_dir_all(&tmp);
}

#[test]
fn hover_on_mut_binding_infers_type_from_range() {
    let src = "fn run() -> int:\n    mut count = 0\n    count\n";
    let sig = lsp::hover(src, 2, 11, None).expect("hover");
    // mut count = 0 → int
    assert!(sig.contains("mut count: int"), "got: {sig}");
}

#[test]
fn hover_on_immutable_binding_infers_type_from_literal() {
    let src = "fn run() -> Text:\n    greeting = \"hi\"\n    greeting\n";
    let sig = lsp::hover(src, 2, 8, None).expect("hover");
    // greeting = "hi" → Text
    assert!(sig.contains("greeting: Text"), "got: {sig}");
}

#[test]
fn hover_on_for_loop_var_infers_int_from_range() {
    let src = "fn count() -> int:\n    mut total = 0\n    for i in 0..<10:\n        total += i\n    total\n";
    let sig = lsp::hover(src, 4, 17, None).expect("hover");
    // for i in 0..<10 → i: int
    assert!(sig.contains("for i: int"), "got: {sig}");
}

#[test]
fn hover_on_local_infers_return_type_of_called_orb_fn() {
    // Simulate hex-style file: declares bytes orb dep and binds to byte_at result.
    let tmp = std::env::temp_dir().join(format!("orion_lsp_infer_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&tmp);
    let lib = tmp.join("orbs").join("infertest");
    std::fs::create_dir_all(&lib).unwrap();
    std::fs::write(
        lib.join("Orbit.toml"),
        "name = \"infertest\"\n[orbs]\nbytes = { built-in = true }\n",
    )
    .unwrap();
    let user_src = "pub fn first(b: [int]) -> int:\n    value = byte_at(b, 0)\n    value\n";
    let user_path = lib.join("lib.or");
    std::fs::write(&user_path, user_src).unwrap();

    let uri = format!("file:///{}", user_path.to_string_lossy().replace('\\', "/"));
    let sig = lsp::hover(user_src, 2, 8, Some(&uri)).expect("hover");
    // byte_at returns int (declared in bytes orb), so value should be int.
    assert!(sig.contains("value: int"), "expected `value: int`, got: {sig}");

    let _ = std::fs::remove_dir_all(&tmp);
}
