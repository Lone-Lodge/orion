//! Tests for M7 SIMD codegen. Run with `cargo test`.
//!
//! The vectorised kernel must produce exactly the same columns as the scalar
//! interpreter, including the odd-length remainder element.

use orion::parallel::{lower, run as scalar_run};
use orion::simd::run as simd_run;
use orion::{lex, parse};

const SRC: &str = "\
data Position: x: f32, y: f32\n\
data Velocity: dx: f32, dy: f32\n\
system integrate(dt: f32):\n\
\x20   for e with Position, Velocity:\n\
\x20       e.Position.x += e.Velocity.dx * dt * dt + e.Velocity.dx * dt\n";

fn kernel() -> orion::parallel::Kernel {
    lower(&parse(&lex(SRC).unwrap()).unwrap(), "integrate").unwrap()
}

#[test]
fn simd_matches_scalar_even_length() {
    let k = kernel();
    let scalar = scalar_run(&k, 1000, &[0.5], 1);
    let vector = simd_run(&k, 1000, &[0.5]).unwrap();
    assert_eq!(scalar, vector);
}

#[test]
fn simd_matches_scalar_odd_length() {
    // 1001 exercises the scalar remainder element after the F64X2 loop.
    let k = kernel();
    let scalar = scalar_run(&k, 1001, &[0.5], 1);
    let vector = simd_run(&k, 1001, &[0.5]).unwrap();
    assert_eq!(scalar, vector);
}

#[test]
fn computed_value_is_correct() {
    // columns start at 1.0; Position.x += dx*dt*dt + dx*dt, dx=1, dt=2 -> 1 + 4 + 2 = 7
    let k = kernel();
    let vector = simd_run(&k, 8, &[2.0]).unwrap();
    let px = k.col_names.iter().position(|c| c == "Position.x").unwrap();
    assert!(vector[px].iter().all(|&v| v == 7.0));
}
