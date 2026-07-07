//! The JIT-backed engine — runs the game-loop systems through compiled native
//! kernels instead of the tree-walking interpreter.
//!
//! `parallel::lower` already reduces a system to a column-assignment kernel and
//! `simd::Compiled` JIT-compiles that kernel to native (SoA + F64X2 vectors). What
//! was missing was the *driver*: a thing that holds the compiled kernels and the
//! column buffers across many ticks and runs them in order each frame.
//!
//! That is what `Engine` is. For every system in the program, it tries the SIMD
//! lowering once at construction; the ones that fit run natively, the rest fall
//! back to the interpreter. The same column buffers survive between ticks, so the
//! state of the world (positions, velocities, …) actually evolves.
//!
//! With `Engine::attach`, the column buffers are seeded from a live `Store`
//! (after `init` runs) so the native ticks evolve the actual entities; the
//! companion `sync_to_store` writes the columns back so subsequent interpreter
//! code (or another tick of a non-native system) sees the updated values.

use crate::ast::{Decl, Program};
use crate::interp::Interp;
use crate::parallel::Kernel;
use crate::simd::Compiled;
use crate::store::Store;

/// One system, in either the native form (compiled kernel + its column buffers)
/// or the fallback form (a name to interpret).
struct Native {
    kernel: Kernel,
    compiled: Compiled,
    /// Per-field column buffers; same order as `kernel.col_names`.
    cols: Vec<Vec<f64>>,
    /// Entity ids per row — populated only when the engine is `attach`ed to a
    /// Store, so `sync_to_store` knows which entity to write each row back to.
    row_ids: Vec<u64>,
}

enum SystemSlot {
    Native(Native),
    Interp(String),
}

/// A live engine: a set of systems and the column state they evolve. Each
/// `tick()` runs every system once in declaration order.
pub struct Engine<'p> {
    program: &'p Program,
    /// Number of rows in synthetic mode (used when no Store is attached). When
    /// attached, each Native slot has its own row count from the snapshot.
    synthetic_n: usize,
    slots: Vec<SystemSlot>,
}

/// Why a system fell back to interpretation rather than running natively, plus
/// how many fit. Useful as a one-line "engine plan" report.
#[derive(Debug, PartialEq)]
pub struct Plan {
    pub native: Vec<String>,
    pub interpreted: Vec<(String, String)>,
}

impl<'p> Engine<'p> {
    /// Build an engine for `program` with `n` synthetic entities per SoA column.
    /// Use this for standalone perf runs; for a real simulation, call `attach`
    /// to seed columns from a populated Store.
    pub fn new(program: &'p Program, n: usize) -> Result<Self, String> {
        let mut slots = Vec::new();
        for d in &program.decls {
            if let Decl::System(s) = d {
                match crate::parallel::lower(program, &s.name) {
                    Ok(kernel) => match Compiled::compile(&kernel) {
                        Ok(compiled) => {
                            let cols: Vec<Vec<f64>> = vec![vec![1.0; n]; kernel.col_names.len()];
                            slots.push(SystemSlot::Native(Native {
                                kernel,
                                compiled,
                                cols,
                                row_ids: Vec::new(),
                            }));
                        }
                        Err(_) => slots.push(SystemSlot::Interp(s.name.clone())),
                    },
                    Err(_) => slots.push(SystemSlot::Interp(s.name.clone())),
                }
            }
        }
        Ok(Self { program, synthetic_n: n, slots })
    }

    /// Seed every Native slot's columns from the entities in `store`. After
    /// this call, `tick` advances the actual world state and `sync_to_store`
    /// writes the columns back.
    pub fn attach(&mut self, store: &Store) {
        for slot in &mut self.slots {
            if let SystemSlot::Native(n) = slot {
                let keys = parse_keys(&n.kernel.col_names);
                let (ids, cols) = store.snapshot_columns(&n.kernel.components, &keys);
                n.row_ids = ids;
                // Replace whatever was there with the live data.
                n.cols = cols;
            }
        }
    }

    /// Write every Native slot's columns back into `store`. Idempotent with
    /// `attach`: attach → tick* → sync round-trips state through the columns.
    pub fn sync_to_store(&self, store: &mut Store) {
        for slot in &self.slots {
            if let SystemSlot::Native(n) = slot {
                let keys = parse_keys(&n.kernel.col_names);
                store.writeback_columns(&n.row_ids, &keys, &n.cols);
            }
        }
    }

    /// One frame: every system runs once, in declaration order. Interpreted
    /// slots evaluate against `interp`'s store; native slots advance their own
    /// columns.
    pub fn tick(&mut self, params: &[f64]) -> Result<(), String> {
        for slot in &mut self.slots {
            match slot {
                SystemSlot::Native(n) => {
                    let n_rows = if n.row_ids.is_empty() {
                        self.synthetic_n
                    } else {
                        n.row_ids.len()
                    };
                    let col_ptrs: Vec<i64> =
                        n.cols.iter_mut().map(|c| c.as_mut_ptr() as i64).collect();
                    let f: extern "C" fn(i64, *const f64, *const i64) =
                        unsafe { std::mem::transmute(n.compiled.addr_for_engine()) };
                    f(n_rows as i64, params.as_ptr(), col_ptrs.as_ptr());
                }
                SystemSlot::Interp(name) => {
                    let interp = Interp::new(self.program);
                    interp.call(name, vec![]).map_err(|e| e.message)?;
                }
            }
        }
        Ok(())
    }

    /// Read a column's current values by name (for tests and inspection).
    pub fn column(&self, name: &str) -> Option<&[f64]> {
        for slot in &self.slots {
            if let SystemSlot::Native(n) = slot {
                if let Some(i) = n.kernel.col_names.iter().position(|c| c == name) {
                    return Some(&n.cols[i]);
                }
            }
        }
        None
    }

    /// A one-shot report of which systems are running native and which fell back.
    pub fn plan(program: &Program) -> Plan {
        let mut native = Vec::new();
        let mut interpreted = Vec::new();
        for d in &program.decls {
            if let Decl::System(s) = d {
                match crate::parallel::lower(program, &s.name) {
                    Ok(k) => match Compiled::compile(&k) {
                        Ok(_) => native.push(s.name.clone()),
                        Err(e) => interpreted.push((s.name.clone(), e)),
                    },
                    Err(e) => interpreted.push((s.name.clone(), e)),
                }
            }
        }
        Plan { native, interpreted }
    }
}

/// Split `["Position.x", "Velocity.vx", …]` into `[(Position, x), (Velocity, vx), …]`.
fn parse_keys(col_names: &[String]) -> Vec<(String, String)> {
    col_names
        .iter()
        .map(|c| match c.split_once('.') {
            Some((comp, field)) => (comp.to_string(), field.to_string()),
            None => (String::new(), c.clone()),
        })
        .collect()
}
