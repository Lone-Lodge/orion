//! Tests for fs, format, sysinfo orbs.

use orion::interp::Interp;
use orion::stdlib;
use orion::value::Value;

fn run_with_orb(orb: &str, user: &str, fname: &str) -> Value {
    // Pull in the orb's declared deps too so pure-Orion orbs that delegate
    // to bytes/string keep working when loaded by these isolation tests.
    let mut chain: Vec<&str> = Vec::new();
    let target = stdlib::find(orb).expect(orb);
    for d in target.deps {
        chain.push(*d);
    }
    chain.push(orb);
    run_with_orbs(&chain, user, fname)
}

fn run_with_orbs(orbs: &[&str], user: &str, fname: &str) -> Value {
    let resolved: Vec<&stdlib::Orb> = orbs.iter().map(|n| stdlib::find(n).expect(n)).collect();
    let mut src = String::new();
    for o in &resolved {
        src.push_str(o.source);
        src.push('\n');
    }
    src.push_str(user);
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    orion::check::check(&p).unwrap();
    orion::typeck::check_types(&p).unwrap();
    let interp = Interp::new(&p);
    for o in &resolved {
        (o.register)(&interp);
    }
    interp.call(fname, vec![]).unwrap()
}

// ---- fs ----

#[test]
fn fs_mkdir_and_rmdir() {
    let tmp = std::env::temp_dir().join(format!("orion_fs_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&tmp);
    let path = tmp.to_str().unwrap().replace('\\', "\\\\");
    let orb = stdlib::find("fs").unwrap();
    let src = format!(
        "{}\nfn run() -> bool:\n    mk = mkdir(\"{path}\")\n    exists = is_dir(\"{path}\")\n    rm = rmdir(\"{path}\")\n    mk and exists and rm\n",
        orb.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (orb.register)(&interp);
    assert_eq!(interp.call("run", vec![]).unwrap(), Value::Bool(true));
    let _ = std::fs::remove_dir_all(&tmp);
}

#[test]
fn fs_list_dir_returns_entries() {
    let tmp = std::env::temp_dir().join(format!("orion_listdir_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&tmp);
    std::fs::create_dir_all(&tmp).unwrap();
    std::fs::write(tmp.join("a.txt"), "x").unwrap();
    std::fs::write(tmp.join("b.txt"), "y").unwrap();

    let path = tmp.to_str().unwrap().replace('\\', "\\\\");
    let orb = stdlib::find("fs").unwrap();
    let src = format!("{}\nfn f() -> int = len(list_dir(\"{path}\"))\n", orb.source);
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (orb.register)(&interp);
    assert_eq!(interp.call("f", vec![]).unwrap(), Value::Int(2));
    let _ = std::fs::remove_dir_all(&tmp);
}

#[test]
fn fs_file_size_of_known_content() {
    let tmp = std::env::temp_dir().join(format!("orion_size_{}.txt", std::process::id()));
    std::fs::write(&tmp, "hello").unwrap();
    let path = tmp.to_str().unwrap().replace('\\', "\\\\");
    let orb = stdlib::find("fs").unwrap();
    let src = format!("{}\nfn f() -> int = file_size(\"{path}\")\n", orb.source);
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (orb.register)(&interp);
    assert_eq!(interp.call("f", vec![]).unwrap(), Value::Int(5));
    let _ = std::fs::remove_file(&tmp);
}

#[test]
fn fs_is_file_vs_is_dir() {
    let tmp = std::env::temp_dir().join(format!("orion_kind_{}", std::process::id()));
    std::fs::create_dir_all(&tmp).unwrap();
    let file = tmp.join("a.txt");
    std::fs::write(&file, "x").unwrap();
    let file_str = file.to_str().unwrap().replace('\\', "\\\\");
    let dir_str = tmp.to_str().unwrap().replace('\\', "\\\\");

    let orb = stdlib::find("fs").unwrap();
    let src = format!(
        "{}\nfn fk() -> bool = is_file(\"{file_str}\")\nfn dk() -> bool = is_dir(\"{dir_str}\")\nfn fmd() -> bool = is_dir(\"{file_str}\")\n",
        orb.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (orb.register)(&interp);
    assert_eq!(interp.call("fk", vec![]).unwrap(), Value::Bool(true));
    assert_eq!(interp.call("dk", vec![]).unwrap(), Value::Bool(true));
    assert_eq!(interp.call("fmd", vec![]).unwrap(), Value::Bool(false));
    let _ = std::fs::remove_dir_all(&tmp);
}

#[test]
fn fs_copy_then_remove() {
    let src_path = std::env::temp_dir().join(format!("orion_cp_src_{}.txt", std::process::id()));
    let dst_path = std::env::temp_dir().join(format!("orion_cp_dst_{}.txt", std::process::id()));
    std::fs::write(&src_path, "data").unwrap();

    let sp = src_path.to_str().unwrap().replace('\\', "\\\\");
    let dp = dst_path.to_str().unwrap().replace('\\', "\\\\");

    let orb = stdlib::find("fs").unwrap();
    let src = format!(
        "{}\nfn run() -> bool:\n    c = copy_file(\"{sp}\", \"{dp}\")\n    e = is_file(\"{dp}\")\n    r = remove_file(\"{dp}\")\n    c and e and r\n",
        orb.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (orb.register)(&interp);
    assert_eq!(interp.call("run", vec![]).unwrap(), Value::Bool(true));
    let _ = std::fs::remove_file(&src_path);
}

// ---- format ----

#[test]
fn fmt_int_right_aligned() {
    let src = "fn f() -> Text = fmt_int(42, 5)";
    assert_eq!(run_with_orb("format", src, "f"), Value::Text("   42".into()));
}

#[test]
fn fmt_int_pad_with_zeros() {
    let src = "fn f() -> Text = fmt_int_pad(42, 5, \"0\")";
    assert_eq!(run_with_orb("format", src, "f"), Value::Text("00042".into()));
}

#[test]
fn fmt_hex_lowercase() {
    let src = "fn f() -> Text = fmt_hex(255)";
    assert_eq!(run_with_orb("format", src, "f"), Value::Text("ff".into()));
}

#[test]
fn fmt_hex_pad_to_width() {
    let src = "fn f() -> Text = fmt_hex_pad(255, 4)";
    assert_eq!(run_with_orb("format", src, "f"), Value::Text("00ff".into()));
}

#[test]
fn fmt_bin() {
    let src = "fn f() -> Text = fmt_bin(10)";
    assert_eq!(run_with_orb("format", src, "f"), Value::Text("1010".into()));
}

#[test]
fn fmt_float_precision() {
    let src = "fn f() -> Text = fmt_float(3.14159265, 2)";
    assert_eq!(run_with_orb("format", src, "f"), Value::Text("3.14".into()));
}

#[test]
fn pad_left_and_right() {
    let src = "\
fn l() -> Text = pad_left(\"hi\", 5, \".\")
fn r() -> Text = pad_right(\"hi\", 5, \".\")
";
    assert_eq!(run_with_orb("format", src, "l"), Value::Text("...hi".into()));
    assert_eq!(run_with_orb("format", src, "r"), Value::Text("hi...".into()));
}

#[test]
fn fmt_does_not_truncate_too_wide() {
    let src = "fn f() -> Text = fmt_int(123456, 3)";
    // width is min, not max
    assert_eq!(run_with_orb("format", src, "f"), Value::Text("123456".into()));
}

// ---- sysinfo ----

#[test]
fn cpu_count_is_positive() {
    let src = "fn f() -> bool = cpu_count() >= 1";
    assert_eq!(run_with_orb("sysinfo", src, "f"), Value::Bool(true));
}

#[test]
fn os_name_is_known_value() {
    let src = "fn f() -> Text = os_name()";
    let v = run_with_orb("sysinfo", src, "f");
    if let Value::Text(s) = v {
        // It's at least one of the common names.
        assert!(["windows", "linux", "macos", "ios", "android", "freebsd"].contains(&s.as_str()),
            "unexpected os_name: {s}");
    } else { panic!() }
}

#[test]
fn arch_is_nonempty() {
    let src = "fn f() -> int = len(arch())";
    if let Value::Int(n) = run_with_orb("sysinfo", src, "f") {
        assert!(n > 0);
    } else { panic!() }
}

// ---- registry ----

#[test]
fn fs_format_sysinfo_are_registered() {
    let names: Vec<&str> = stdlib::ORBS.iter().map(|o| o.name).collect();
    for needed in ["fs", "format", "sysinfo"] {
        assert!(names.contains(&needed), "missing: {needed}");
    }
}
