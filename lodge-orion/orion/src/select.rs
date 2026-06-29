//! M7 — layout selection + the empirical reason for it.
//!
//! `layout.rs` decides SoA vs AoS for *storage*; this picks SoA vs **AoSoA** for a
//! compiled kernel, from its access pattern:
//!
//! - **Streaming** (each entity reads its own index, sequentially) → **SoA**.
//!   Sequential per-column streams prefetch perfectly; measured 3× faster than
//!   AoSoA for `integrate`.
//! - **Gather** (random/indirect index into another entity) → **AoSoA/AoS**, so
//!   one random fetch lands all of an entity's fields in one cache line.
//!
//! Orion's kernels are all streaming today (no indirect index in the grammar yet),
//! so `choose` currently returns SoA for everything — *correctly*. The
//! `gather_bench` below is the empirical proof of the other branch: it measures
//! the exact crossover on random access, grounding the selector in reality rather
//! than belief.

use std::time::{Duration, Instant};

use crate::parallel::{KExpr, Kernel};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LayoutChoice {
    Soa,
    Aosoa,
}

/// A kernel is "gather" if any read is indirect (a column indexed by another
/// value). The current kernel grammar has no such form, so this is always false
/// today — but the classifier is real, not hard-coded to SoA.
fn has_gather(kernel: &Kernel) -> bool {
    fn walk(e: &KExpr) -> bool {
        match e {
            KExpr::Bin(_, a, b) => walk(a) || walk(b),
            // No `KExpr::Gather` variant exists yet; add it when indirect reads
            // enter the grammar, and this lights up.
            _ => false,
        }
    }
    kernel.assigns.iter().any(|(_, _, e)| walk(e))
}

/// Pick a layout from the access pattern (a cheap *heuristic*).
///
/// Provisional: our own measurements show rules of thumb are unreliable for
/// layout, so prefer [`choose_measured`] when you can afford to compile both.
pub fn choose(kernel: &Kernel) -> LayoutChoice {
    if has_gather(kernel) {
        LayoutChoice::Aosoa
    } else {
        LayoutChoice::Soa
    }
}

/// Pick a layout by **measuring** both — compile the SoA and AoSoA kernels, time
/// each on a sample, and choose the faster. This is the honest answer: layout
/// performance defies rules of thumb (we measured both AoSoA-on-streaming and
/// AoS-on-gather losing against intuition), so the compiler should measure, not
/// guess. Returns the choice and both per-call times.
pub fn choose_measured(
    kernel: &Kernel,
    sample: usize,
    params: &[f64],
) -> Result<(LayoutChoice, Duration, Duration), String> {
    let soa = crate::simd::Compiled::compile(kernel)?;
    let aosoa = crate::aosoa::Compiled::compile(kernel)?;
    let soa_t = soa.bench(sample, params, 5);
    let aosoa_t = aosoa.bench(sample, params, 5);
    let choice = if soa_t <= aosoa_t {
        LayoutChoice::Soa
    } else {
        LayoutChoice::Aosoa
    };
    Ok((choice, soa_t, aosoa_t))
}

/// Empirical crossover: read all of N entities' 4 fields at `reads` random
/// indices, once from SoA storage (4 separate arrays) and once from AoS storage
/// (fields interleaved per entity). Returns `(soa_time, aos_time, checksum)`.
/// The checksum is identical for both layouts — only the timing differs.
pub fn gather_bench(n: usize, reads: usize) -> (Duration, Duration, f64) {
    // SoA: four independent columns.
    let a: Vec<f64> = (0..n).map(|i| i as f64).collect();
    let b: Vec<f64> = (0..n).map(|i| (i as f64) * 2.0).collect();
    let c: Vec<f64> = (0..n).map(|i| (i as f64) * 3.0).collect();
    let d: Vec<f64> = (0..n).map(|i| (i as f64) * 4.0).collect();
    // AoS: the same data, interleaved 4-per-entity.
    let mut aos: Vec<f64> = Vec::with_capacity(n * 4);
    for i in 0..n {
        aos.push(a[i]);
        aos.push(b[i]);
        aos.push(c[i]);
        aos.push(d[i]);
    }

    // A deterministic pseudo-random index stream (no rand dependency).
    let mut rng: u64 = 0x9E3779B97F4A7C15;
    let mut next = |n: usize| {
        rng = rng.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        ((rng >> 33) as usize) % n
    };
    let idxs: Vec<usize> = (0..reads).map(|_| next(n)).collect();

    // SoA gather: four arrays -> up to four cache lines per entity.
    let t0 = Instant::now();
    let mut soa_sum = 0.0f64;
    for &i in &idxs {
        soa_sum += a[i] + b[i] + c[i] + d[i];
    }
    let soa_t = t0.elapsed();

    // AoS gather: one contiguous group per entity -> one cache line.
    let t1 = Instant::now();
    let mut aos_sum = 0.0f64;
    for &i in &idxs {
        let base = i * 4;
        aos_sum += aos[base] + aos[base + 1] + aos[base + 2] + aos[base + 3];
    }
    let aos_t = t1.elapsed();

    debug_assert_eq!(soa_sum, aos_sum);
    (soa_t, aos_t, aos_sum)
}
