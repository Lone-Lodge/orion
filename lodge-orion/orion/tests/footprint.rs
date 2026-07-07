//! Tests for M5 footprint inference. Run with `cargo test`.

use orion::footprint::{analyze, conflicts, parallel_batches};
use orion::{lex, parse};

const SRC: &str = "\
data Position: x: f32, y: f32\n\
data Velocity: dx: f32, dy: f32\n\
data Health: hp: 0...1000, max: 0...1000\n\
system move(dt: f32):\n\
\x20   for e with Position, Velocity:\n\
\x20       e.Position.x += e.Velocity.dx * dt\n\
system regen(amount: int):\n\
\x20   for e with Health:\n\
\x20       e.Health.hp += amount\n\
system clear_dead():\n\
\x20   for e with Health where e.Health.hp <= 0:\n\
\x20       destroy e\n";

fn systems(src: &str) -> Vec<(String, orion::footprint::Footprint)> {
    analyze(&parse(&lex(src).unwrap()).unwrap())
}

#[test]
fn infers_reads_and_writes() {
    let s = systems(SRC);
    let mv = &s.iter().find(|(n, _)| n == "move").unwrap().1;
    assert!(mv.reads.contains("Position"));
    assert!(mv.reads.contains("Velocity"));
    assert!(mv.writes.contains("Position"));
    assert!(!mv.writes.contains("Velocity"));
}

#[test]
fn disjoint_systems_do_not_conflict() {
    let s = systems(SRC);
    let mv = &s.iter().find(|(n, _)| n == "move").unwrap().1;
    let regen = &s.iter().find(|(n, _)| n == "regen").unwrap().1;
    assert!(!conflicts(mv, regen)); // Position/Velocity vs Health
}

#[test]
fn read_after_write_conflicts() {
    let s = systems(SRC);
    let regen = &s.iter().find(|(n, _)| n == "regen").unwrap().1; // writes Health
    let clear = &s.iter().find(|(n, _)| n == "clear_dead").unwrap().1; // reads Health
    assert!(conflicts(regen, clear));
}

#[test]
fn parallel_batches_group_non_conflicting_systems() {
    let s = systems(SRC);
    let batches = parallel_batches(&s);
    // move + regen are disjoint -> first batch; clear_dead conflicts with regen.
    assert_eq!(batches.len(), 2);
    assert!(batches[0].contains(&"move".to_string()));
    assert!(batches[0].contains(&"regen".to_string()));
    assert_eq!(batches[1], vec!["clear_dead".to_string()]);
}
