//! Tests for the `image` orb (PNG decode/encode).

use orion::interp::Interp;
use orion::stdlib;
use orion::value::Value;

fn run_with_orb(orb: &str, user: &str, fname: &str, args: Vec<Value>) -> Value {
    let mut order: Vec<&'static str> = Vec::new();
    walk_orb_deps(orb, &mut order);
    let resolved: Vec<&stdlib::Orb> = order.iter().map(|n| stdlib::find(n).expect(n)).collect();
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
    interp.call(fname, args).unwrap()
}

fn walk_orb_deps(name: &str, order: &mut Vec<&'static str>) {
    if order.iter().any(|n| *n == name) {
        return;
    }
    let orb = stdlib::find(name).expect(name);
    for dep in orb.deps {
        walk_orb_deps(dep, order);
    }
    order.push(orb.name);
}

#[test]
fn image_blank_dimensions_match() {
    let src = "fn w() -> int = get(image_blank(64, 32), \"width\")\nfn h() -> int = get(image_blank(64, 32), \"height\")\nfn c() -> int = get(image_blank(64, 32), \"channels\")";
    assert_eq!(run_with_orb("image", src, "w", vec![]), Value::Int(64));
    assert_eq!(run_with_orb("image", src, "h", vec![]), Value::Int(32));
    assert_eq!(run_with_orb("image", src, "c", vec![]), Value::Int(4));
}

#[test]
fn image_blank_pixel_count_is_w_x_h_x_4() {
    let src = "fn f() -> int = len(get(image_blank(4, 3), \"pixels\"))";
    assert_eq!(run_with_orb("image", src, "f", vec![]), Value::Int(48));
}

#[test]
fn image_save_then_load_round_trip() {
    let tmp = std::env::temp_dir().join(format!("orion_img_{}.png", std::process::id()));
    let path = tmp.to_str().unwrap().replace('\\', "\\\\");

    // Encode a 2x2 RGBA pattern: red, green, blue, white.
    let src = format!(
        "fn save() -> bool:\n    px = [255, 0, 0, 255,  0, 255, 0, 255,  0, 0, 255, 255,  255, 255, 255, 255]\n    image_save_png(\"{path}\", 2, 2, px)\n\nfn loaded_w() -> int = get(image_load_png(\"{path}\"), \"width\")\nfn loaded_h() -> int = get(image_load_png(\"{path}\"), \"height\")\nfn loaded_red_x0_y0() -> int = at(get(image_load_png(\"{path}\"), \"pixels\"), 0)\n"
    );
    assert_eq!(run_with_orb("image", &src, "save", vec![]), Value::Bool(true));
    assert_eq!(run_with_orb("image", &src, "loaded_w", vec![]), Value::Int(2));
    assert_eq!(run_with_orb("image", &src, "loaded_h", vec![]), Value::Int(2));
    assert_eq!(run_with_orb("image", &src, "loaded_red_x0_y0", vec![]), Value::Int(255));

    let _ = std::fs::remove_file(&tmp);
}

#[test]
fn image_load_missing_file_returns_none() {
    let src = "fn f() = image_load_png(\"this_file_does_not_exist_abc123.png\")";
    assert_eq!(run_with_orb("image", src, "f", vec![]), Value::None);
}

#[test]
fn image_load_malformed_returns_none() {
    // Write a non-PNG file at a path the orb will try to decode.
    let tmp = std::env::temp_dir().join(format!("orion_bad_png_{}.png", std::process::id()));
    std::fs::write(&tmp, b"not a png").unwrap();
    let path = tmp.to_str().unwrap().replace('\\', "\\\\");
    let src = format!("fn f() = image_load_png(\"{path}\")");
    assert_eq!(run_with_orb("image", &src, "f", vec![]), Value::None);
    let _ = std::fs::remove_file(&tmp);
}

#[test]
fn image_orb_is_registered() {
    let names: Vec<&str> = stdlib::ORBS.iter().map(|o| o.name).collect();
    assert!(names.contains(&"image"));
}
