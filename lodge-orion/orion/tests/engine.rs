//! Tests for the JIT-backed tick engine.

use orion::engine::Engine;
use orion::{lex, parse};

fn program(src: &str) -> orion::ast::Program {
    parse(&lex(src).unwrap()).unwrap()
}

#[test]
fn plan_reports_native_vs_interpreted_systems() {
    // `move` is in the parallel/SIMD subset; `tally` is not (no body that lowers).
    let src = "\
data Position: x: f64, y: f64
data Velocity: vx: f64, vy: f64

system move(dt: f64):
    for e with Position, Velocity:
        e.Position.x = e.Position.x + e.Velocity.vx * dt

system tally():
    mut k = 0
    k = k + 1
";
    let p = program(src);
    let plan = Engine::plan(&p);
    assert_eq!(plan.native, vec!["move".to_string()]);
    assert_eq!(plan.interpreted.len(), 1);
    assert_eq!(plan.interpreted[0].0, "tally");
}

#[test]
fn tick_advances_native_column_buffers() {
    // One JIT'd system: x += vx*dt. After N ticks the x column should be
    // 1.0 + N*vx*dt for every entity (all columns start at 1.0 in the engine).
    let src = "\
data Position: x: f64
data Velocity: vx: f64

system move(dt: f64):
    for e with Position, Velocity:
        e.Position.x = e.Position.x + e.Velocity.vx * dt
";
    let p = program(src);
    let n = 8usize;
    let mut eng = Engine::new(&p, n).unwrap();
    let dt = 0.5;
    let ticks = 4;
    for _ in 0..ticks {
        eng.tick(&[dt]).unwrap();
    }
    let xs = eng.column("Position.x").expect("Position.x column");
    let expected = 1.0 + (ticks as f64) * 1.0 * dt; // vx = 1.0 (default), dt = 0.5
    for &x in xs {
        assert!((x - expected).abs() < 1e-9, "got {x}, expected {expected}");
    }
}

#[test]
fn attach_and_sync_round_trip_real_entities_through_native_kernels() {
    // init() spawns two entities; move() advances them via the JIT'd kernel;
    // after sync_to_store the interpreter sees the updated x values.
    let src = "\
data Position: x: f64
data Velocity: vx: f64

system move(dt: f64):
    for e with Position, Velocity:
        e.Position.x = e.Position.x + e.Velocity.vx * dt

fn init():
    spawn Position{x: 0.0}, Velocity{vx: 2.0}
    spawn Position{x: 10.0}, Velocity{vx: 3.0}

fn report() -> f64:
    mut sum = 0.0
    for e with Position:
        sum += e.Position.x
    sum
";
    let p = program(src);
    let interp = orion::interp::Interp::new(&p);
    interp.call("init", vec![]).unwrap();

    // Before any tick: sum of x is 0.0 + 10.0 = 10.0.
    let before = interp.call("report", vec![]).unwrap();
    assert_eq!(before, orion::value::Value::Float(10.0));

    let mut eng = Engine::new(&p, 0).unwrap();
    eng.attach(&interp.store());
    let dt = 1.0;
    let ticks = 4;
    for _ in 0..ticks {
        eng.tick(&[dt]).unwrap();
    }
    eng.sync_to_store(&mut interp.store_mut());

    // After 4 ticks at dt=1: x_0 = 0+4*2=8, x_1 = 10+4*3=22, sum=30.
    let after = interp.call("report", vec![]).unwrap();
    assert_eq!(after, orion::value::Value::Float(30.0));
}

#[test]
fn engine_falls_back_for_unsupported_systems() {
    // A system the parallel/SIMD lowering can't accept must still be runnable.
    let src = "\
data Counter: n: int

system bump():
    mut k = 0
    k = k + 1
";
    let p = program(src);
    let mut eng = Engine::new(&p, 4).unwrap();
    // Each tick interprets `bump`; it should succeed without error.
    for _ in 0..3 {
        eng.tick(&[]).unwrap();
    }
}
