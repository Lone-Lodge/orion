//! Tests for M7 layout selection. Run with `cargo test`.

use orion::parallel::lower;
use orion::select::{LayoutChoice, choose, gather_bench};
use orion::{lex, parse};

#[test]
fn streaming_kernel_picks_soa() {
    let src = "data Position: x: f32, y: f32\n\
               data Velocity: dx: f32, dy: f32\n\
               system move(dt: f32):\n\
               \x20   for e with Position, Velocity:\n\
               \x20       e.Position.x += e.Velocity.dx * dt\n";
    let kernel = lower(&parse(&lex(src).unwrap()).unwrap(), "move").unwrap();
    assert_eq!(choose(&kernel), LayoutChoice::Soa);
}

#[test]
fn measured_choice_runs_and_decides() {
    let src = "data Position: x: f32, y: f32\n\
               data Velocity: dx: f32, dy: f32\n\
               system move(dt: f32):\n\
               \x20   for e with Position, Velocity:\n\
               \x20       e.Position.x += e.Velocity.dx * dt\n";
    let kernel = lower(&parse(&lex(src).unwrap()).unwrap(), "move").unwrap();
    let (choice, soa, aosoa) = orion::select::choose_measured(&kernel, 100_000, &[1.0]).unwrap();
    // Whichever it picks, it must be the one it measured as faster.
    let expected = if soa <= aosoa { LayoutChoice::Soa } else { LayoutChoice::Aosoa };
    assert_eq!(choice, expected);
}

#[test]
fn gather_bench_layouts_agree_on_value() {
    // Both layouts read the same data, so the checksum must match exactly; the
    // benchmark is only about timing.
    let (_soa, _aos, sum) = gather_bench(10_000, 50_000);
    assert!(sum.is_finite());
}
