//! Tests for M5 data-parallel execution. Run with `cargo test`.

use orion::parallel::{lower, run};
use orion::{lex, parse};

const SRC: &str = "\
data Position: x: f32, y: f32\n\
data Velocity: dx: f32, dy: f32\n\
system move(dt: f32):\n\
\x20   for e with Position, Velocity:\n\
\x20       e.Position.x += e.Velocity.dx * dt\n";

#[test]
fn parallel_matches_sequential_and_is_correct() {
    let program = parse(&lex(SRC).unwrap()).unwrap();
    let kernel = lower(&program, "move").unwrap();
    let n = 10_000;
    let dt = 2.0;

    let seq = run(&kernel, n, &[dt], 1);
    let par = run(&kernel, n, &[dt], 8);

    // Threaded result is identical to the sequential one.
    assert_eq!(seq, par);

    // Columns start at 1.0; Position.x += Velocity.dx * dt == 1 + 1*2 == 3.
    let px = kernel.col_names.iter().position(|c| c == "Position.x").unwrap();
    assert!(seq[px].iter().all(|&v| v == 3.0));
}

#[test]
fn rejects_bodies_outside_the_subset() {
    // A `where` filter is outside the parallel kernel subset.
    let src = "data Health: hp: 0...1000, max: 0...1000\n\
               system regen():\n\
               \x20   for e with Health where e.Health.hp < 5:\n\
               \x20       e.Health.hp += 1\n";
    let program = parse(&lex(src).unwrap()).unwrap();
    assert!(lower(&program, "regen").is_err());
}
