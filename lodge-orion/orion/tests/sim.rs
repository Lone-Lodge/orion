//! Tests for the simulation driver model (init + tick over a persistent world).

use orion::interp::Interp;
use orion::value::Value;
use orion::{lex, parse};

const SRC: &str = "\
data Position: x: f32, y: f32\n\
data Velocity: dx: f32, dy: f32\n\
system move(dt: f32):\n\
\x20   for e with Position, Velocity:\n\
\x20       e.Position.x += e.Velocity.dx * dt\n\
fn report() -> f64:\n\
\x20   mut s = 0.0\n\
\x20   for e with Position:\n\
\x20       s += e.Position.x\n\
\x20   s\n\
fn init():\n\
\x20   spawn Position{x: 0.0, y: 0.0}, Velocity{dx: 1.0, dy: 0.0}\n\
\x20   spawn Position{x: 0.0, y: 0.0}, Velocity{dx: 3.0, dy: 0.0}\n\
fn tick():\n\
\x20   move(1.0)\n";

#[test]
fn ticks_advance_the_persistent_world() {
    let program = parse(&lex(SRC).unwrap()).unwrap();
    let interp = Interp::new(&program);
    interp.call("init", vec![]).unwrap();
    interp.call("tick", vec![]).unwrap();
    interp.call("tick", vec![]).unwrap();
    // two ticks: each entity's x += dx twice -> 2 and 6 -> sum 8
    assert_eq!(interp.call("report", vec![]).unwrap(), Value::Float(8.0));
}
