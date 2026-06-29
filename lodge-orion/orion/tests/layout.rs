//! Tests for M5 layout planning. Run with `cargo test`.

use orion::layout::{Layout, plan};
use orion::{lex, parse};

const SRC: &str = "\
data Position: x: f32, y: f32\n\
data Label: id: int\n\
system move(dt: f32):\n\
\x20   for e with Position:\n\
\x20       e.Position.x += dt\n";

fn layout_of(component: &str) -> Layout {
    let program = parse(&lex(SRC).unwrap()).unwrap();
    plan(&program)
        .into_iter()
        .find(|p| p.component == component)
        .unwrap()
        .layout
}

#[test]
fn iterated_component_is_soa() {
    assert_eq!(layout_of("Position"), Layout::Soa);
}

#[test]
fn unused_component_stays_aos() {
    assert_eq!(layout_of("Label"), Layout::Aos);
}
