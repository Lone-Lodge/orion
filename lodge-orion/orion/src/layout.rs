//! M5 — layout planning (the layout-polymorphism half).
//!
//! ORION.md §5: you declare `data` once; the compiler picks the *physical* layout
//! per component from how it's accessed. The hot ECS case — many entities, a few
//! components iterated field-wise in systems — wants SoA (columnar, cache- and
//! SIMD-friendly). A component never iterated by a system (only spawned, or used
//! whole) is fine as AoS.
//!
//! This pass turns the inferred footprints into a per-component layout plan. The
//! code generator that *uses* the plan (real SoA storage, AoSoA blocking for
//! SIMD) is M7; this is the decision the design promised the compiler would make.

use std::collections::BTreeMap;

use crate::ast::{Decl, Program};
use crate::footprint::analyze;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Layout {
    /// Struct-of-arrays — columnar, cache-friendly for field-wise iteration.
    Soa,
    /// Array-of-structs — fine when the component isn't hot-iterated.
    Aos,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Plan {
    pub component: String,
    pub layout: Layout,
    /// The systems whose footprint touches this component (the evidence for SoA).
    pub touched_by: Vec<String>,
}

/// Decide a layout for every `data` component in the program.
pub fn plan(program: &Program) -> Vec<Plan> {
    let systems = analyze(program);

    // component -> systems that read or write it
    let mut touch: BTreeMap<String, Vec<String>> = BTreeMap::new();
    for (sys, fp) in &systems {
        for c in fp.reads.iter().chain(fp.writes.iter()) {
            let e = touch.entry(c.clone()).or_default();
            if !e.contains(sys) {
                e.push(sys.clone());
            }
        }
    }

    program
        .decls
        .iter()
        .filter_map(|d| match d {
            Decl::Data(dd) => {
                let touched = touch.get(&dd.name).cloned().unwrap_or_default();
                let layout = if touched.is_empty() { Layout::Aos } else { Layout::Soa };
                Some(Plan {
                    component: dd.name.clone(),
                    layout,
                    touched_by: touched,
                })
            }
            _ => None,
        })
        .collect()
}
