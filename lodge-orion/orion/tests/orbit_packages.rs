//! End-to-end tests for the orbit package system: TOML parse/write, the stdlib
//! registry, native registration on Interp, and the loader's extra search path.

use std::collections::BTreeMap;

use orion::interp::Interp;
use orion::orbit_toml::OrbitToml;
use orion::stdlib;
use orion::value::Value;

// ---- Orbit.toml ----

#[test]
fn parses_a_minimal_orbit_toml() {
    let src = r#"
        [package]
        name = "demo"
        version = "0.0.1"

        [orbs]
        time = "stdlib"
    "#;
    let toml = orion::orbit_toml::parse(src);
    assert_eq!(toml.package.get("name").map(String::as_str), Some("demo"));
    assert_eq!(toml.package.get("version").map(String::as_str), Some("0.0.1"));
    assert_eq!(toml.orbs.get("time").map(String::as_str), Some("stdlib"));
}

#[test]
fn round_trips_through_write_render() {
    let mut t = OrbitToml::default();
    t.package.insert("name".into(), "ringo".into());
    t.package.insert("version".into(), "0.1.0".into());
    t.orbs.insert("time".into(), "stdlib".into());

    let rendered = t.render();
    let reparsed = orion::orbit_toml::parse(&rendered);
    assert_eq!(reparsed.package, t.package);
    assert_eq!(reparsed.orbs, t.orbs);
}

#[test]
fn ignores_comments_and_blank_lines() {
    let src = "# top-level\n[package]\nname = \"x\" # inline comment\n\n[orbs]\n";
    let toml = orion::orbit_toml::parse(src);
    assert_eq!(toml.package.get("name").map(String::as_str), Some("x"));
}

// ---- stdlib registry ----

#[test]
fn stdlib_finds_time_package() {
    let p = stdlib::find("time").expect("time package");
    assert!(p.source.contains("pub fn now()"));
}

#[test]
fn stdlib_returns_none_for_unknown_packages() {
    assert!(stdlib::find("nonexistent").is_none());
}

// ---- native registration round-trip ----

#[test]
fn time_externs_register_and_run() {
    // Build a tiny program that uses time's `now()` extern.
    let src = format!("{}\nfn f() -> f64 = now()\n", stdlib::find("time").unwrap().source);
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    orion::check::check(&p).unwrap();
    orion::typeck::check_types(&p).unwrap();

    let interp = Interp::new(&p);
    (stdlib::find("time").unwrap().register)(&interp);

    let v = interp.call("f", vec![]).unwrap();
    match v {
        Value::Float(t) => assert!(t > 0.0, "now() should be > 0, got {t}"),
        other => panic!("expected float, got {other:?}"),
    }
}

#[test]
fn time_elapsed_measures_a_real_interval() {
    let src = format!(
        "{}\nfn f() -> f64:\n    start = now()\n    sleep(0.01)\n    elapsed(start)\n",
        stdlib::find("time").unwrap().source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    orion::check::check(&p).unwrap();
    let interp = Interp::new(&p);
    (stdlib::find("time").unwrap().register)(&interp);

    let v = interp.call("f", vec![]).unwrap();
    match v {
        Value::Float(d) => assert!(d >= 0.005, "elapsed should be ≥ 5ms, got {d}"),
        other => panic!("expected float, got {other:?}"),
    }
}

// ---- loader search path ----

#[test]
fn loader_resolves_use_via_extra_search_paths() {
    let tmp = std::env::temp_dir().join(format!("orion_search_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&tmp);
    std::fs::create_dir_all(&tmp).unwrap();

    let entry = tmp.join("main.or");
    let modules = tmp.join("modules");
    std::fs::create_dir_all(&modules).unwrap();
    std::fs::write(&entry, "use helper\nfn run() -> int = helper_value()\n").unwrap();
    std::fs::write(modules.join("helper.or"), "pub fn helper_value() -> int = 42\n").unwrap();

    let loaded = orion::loader::load_with_search_paths(entry.to_str().unwrap(), &[modules.clone()]).unwrap();
    orion::check::check(&loaded.program).unwrap();
    let v = Interp::new(&loaded.program).call("run", vec![]).unwrap();
    assert_eq!(v, Value::Int(42));

    let _ = std::fs::remove_dir_all(&tmp);
}

// ---- compile-time inventory of all stdlib packages ----

#[test]
fn every_stdlib_package_has_parseable_source() {
    let mut seen: BTreeMap<&str, ()> = BTreeMap::new();
    for p in stdlib::ORBS {
        // Topological walk so transitive deps (e.g. log → format → bytes)
        // all get prepended — mirrors what orbit does when loading orbs.
        let mut order: Vec<&'static str> = Vec::new();
        walk_orb_deps(p.name, &mut order);
        let mut src = String::new();
        for dep_name in &order {
            if *dep_name == p.name {
                continue;
            }
            let dep = stdlib::find(dep_name)
                .unwrap_or_else(|| panic!("{}: unknown dep `{dep_name}`", p.name));
            src.push_str(dep.source);
            src.push('\n');
        }
        src.push_str(p.source);
        let prog = orion::parse(&orion::lex(&src).expect(p.name)).expect(p.name);
        orion::check::check(&prog).expect(p.name);
        seen.insert(p.name, ());
    }
    assert!(seen.contains_key("time"));
}

fn walk_orb_deps(name: &'static str, order: &mut Vec<&'static str>) {
    if order.contains(&name) {
        return;
    }
    let Some(orb) = stdlib::find(name) else { return };
    for dep in orb.deps {
        walk_orb_deps(*dep, order);
    }
    order.push(orb.name);
}
