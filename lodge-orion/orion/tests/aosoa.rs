//! Tests for M7 AoSoA codegen. Run with `cargo test`.
//!
//! The AoSoA-laid-out, vectorised kernel must produce the same per-column results
//! as the scalar interpreter and the SoA SIMD kernel — including padded blocks
//! when `n` isn't a multiple of the block width.

use orion::parallel::{lower, run as scalar_run};
use orion::{aosoa, lex, parse};

const SRC: &str = "\
data Position: x: f32, y: f32\n\
data Velocity: dx: f32, dy: f32\n\
system integrate(dt: f32):\n\
\x20   for e with Position, Velocity:\n\
\x20       e.Position.x += e.Velocity.dx * dt * dt + e.Velocity.dx * dt\n\
\x20       e.Position.y += e.Velocity.dy * dt\n";

fn kernel() -> orion::parallel::Kernel {
    lower(&parse(&lex(SRC).unwrap()).unwrap(), "integrate").unwrap()
}

#[test]
fn aosoa_matches_scalar_even() {
    let k = kernel();
    assert_eq!(scalar_run(&k, 1000, &[0.5], 1), aosoa::run(&k, 1000, &[0.5]).unwrap());
}

#[test]
fn aosoa_matches_scalar_odd_padding() {
    // 1001 forces a padded final block; padding lanes must not corrupt results.
    let k = kernel();
    assert_eq!(scalar_run(&k, 1001, &[0.5], 1), aosoa::run(&k, 1001, &[0.5]).unwrap());
}

#[test]
fn aosoa_value_is_correct() {
    // columns start at 1.0; Position.x += dx*dt*dt + dx*dt with dx=1, dt=2 -> 7.
    let k = kernel();
    let cols = aosoa::run(&k, 8, &[2.0]).unwrap();
    let px = k.col_names.iter().position(|c| c == "Position.x").unwrap();
    assert!(cols[px].iter().all(|&v| v == 7.0));
}
