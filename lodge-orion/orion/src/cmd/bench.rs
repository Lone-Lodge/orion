//! Benchmarks across the perf modes: JIT, parallel ECS, SIMD, AoSoA, layout
//! selection, and the SoA-vs-AoS gather microbenchmark.

use std::time::{Duration, Instant};

use orion::ast::Program;
use orion::jit::Jit;

use super::{die, parse_params};

pub fn gatherbench(rest: &[String]) {
    let n: usize = rest.first().and_then(|s| s.parse().ok()).unwrap_or(4_000_000);
    let reads: usize = rest.get(1).and_then(|s| s.parse().ok()).unwrap_or(20_000_000);
    let (soa, aos, _sum) = orion::select::gather_bench(n, reads);
    println!("random gather: {reads} reads over {n} entities (4 f64 fields each)");
    println!("  SoA (4 arrays): {soa:?}");
    println!("  AoS (interleaved): {aos:?}");
    let r = soa.as_secs_f64() / aos.as_secs_f64().max(1e-9);
    println!("  AoS vs SoA on gather: {r:.2}x");
}

pub fn parbench(rest: &[String], program: &Program) {
    let fname = rest.get(1).map(|s| s.as_str())
        .unwrap_or_else(|| die("usage: orion parbench <file.or> <fn> <n> [iters]"));
    let n: i64 = rest.get(2).and_then(|s| s.parse().ok()).unwrap_or(35);
    let iters: usize = rest.get(3).and_then(|s| s.parse().ok()).unwrap_or(16);

    let mut jit = Jit::new().unwrap_or_else(|e| die(&format!("jit init error: {e}")));
    let cf = jit.compile(program, fname).unwrap_or_else(|e| die(&format!("jit compile error: {e}")));
    if cf.params.len() != 1 {
        die("parbench needs a 1-argument int function");
    }
    let addr = jit.func_addr(cf.id);

    let (seq, seq_acc) = bench_sequential(addr, n, iters);
    let cores = std::thread::available_parallelism().map(|n| n.get()).unwrap_or(4);
    let (par, par_acc) = bench_parallel(addr, n, iters, cores);

    println!("{fname}({n}) x{iters}  (result check: {})", seq_acc == par_acc);
    println!("  sequential: {seq:?}");
    println!("  parallel ({cores} threads): {par:?}");
    print_speedup(seq, par);
}

fn bench_sequential(addr: usize, n: i64, iters: usize) -> (Duration, i64) {
    let f: extern "C" fn(i64) -> i64 = unsafe { std::mem::transmute(addr) };
    let t0 = Instant::now();
    let mut acc: i64 = 0;
    for _ in 0..iters {
        acc = acc.wrapping_add(f(n));
    }
    (t0.elapsed(), acc)
}

fn bench_parallel(addr: usize, n: i64, iters: usize, cores: usize) -> (Duration, i64) {
    let t0 = Instant::now();
    let acc: i64 = std::thread::scope(|s| {
        let mut handles = Vec::new();
        for t in 0..cores {
            let count = iters / cores + usize::from(t < iters % cores);
            handles.push(s.spawn(move || {
                let f: extern "C" fn(i64) -> i64 = unsafe { std::mem::transmute(addr) };
                let mut acc: i64 = 0;
                for _ in 0..count {
                    acc = acc.wrapping_add(f(n));
                }
                acc
            }));
        }
        handles.into_iter().map(|h| h.join().unwrap()).fold(0i64, i64::wrapping_add)
    });
    (t0.elapsed(), acc)
}

pub fn parrun(rest: &[String], program: &Program) {
    let sys = rest.get(1).map(|s| s.as_str())
        .unwrap_or_else(|| die("usage: orion parrun <file.or> <system> <n> [params...]"));
    let n: usize = rest.get(2).and_then(|s| s.parse().ok()).unwrap_or(2_000_000);
    let params = parse_params(rest, 3);

    let kernel = orion::parallel::lower(program, sys).unwrap_or_else(|e| die(&format!("parrun: {e}")));

    let t0 = Instant::now();
    let seq_cols = orion::parallel::run(&kernel, n, &params, 1);
    let seq = t0.elapsed();

    let cores = std::thread::available_parallelism().map(|n| n.get()).unwrap_or(4);
    let t1 = Instant::now();
    let par_cols = orion::parallel::run(&kernel, n, &params, cores);
    let par = t1.elapsed();

    println!("system {sys} over {n} entities  (columns: {})", kernel.col_names.join(", "));
    println!("  results match: {}", seq_cols == par_cols);
    println!("  sequential: {seq:?}");
    println!("  parallel ({cores} threads): {par:?}");
    print_speedup(seq, par);
}

pub fn simd(rest: &[String], program: &Program) {
    let sys = rest.get(1).map(|s| s.as_str())
        .unwrap_or_else(|| die("usage: orion simd <file.or> <system> <n> [params...]"));
    let n: usize = rest.get(2).and_then(|s| s.parse().ok()).unwrap_or(5_000_000);
    let params = parse_params(rest, 3);

    let kernel = orion::parallel::lower(program, sys).unwrap_or_else(|e| die(&format!("simd: {e}")));

    let t0 = Instant::now();
    let scalar = orion::parallel::run(&kernel, n, &params, 1);
    let scal = t0.elapsed();

    let compiled = orion::simd::Compiled::compile(&kernel).unwrap_or_else(|e| die(&format!("simd compile: {e}")));
    let t1 = Instant::now();
    let vec = compiled.run(n, &params);
    let sim = t1.elapsed();

    println!("system {sys} over {n} entities  (columns: {})", kernel.col_names.join(", "));
    println!("  results match: {}", scalar == vec);
    println!("  scalar (1 thread):    {scal:?}");
    println!("  SIMD F64X2 (1 thread): {sim:?}");
    print_speedup(scal, sim);
}

pub fn aosoa(rest: &[String], program: &Program) {
    let sys = rest.get(1).map(|s| s.as_str())
        .unwrap_or_else(|| die("usage: orion aosoa <file.or> <system> <n> [params...]"));
    let n: usize = rest.get(2).and_then(|s| s.parse().ok()).unwrap_or(20_000_000);
    let params = parse_params(rest, 3);
    let kernel = orion::parallel::lower(program, sys).unwrap_or_else(|e| die(&format!("aosoa: {e}")));

    let soa = orion::simd::Compiled::compile(&kernel).unwrap();
    let aos = orion::aosoa::Compiled::compile(&kernel).unwrap();

    let t0 = Instant::now();
    let a = soa.run(n, &params);
    let soa_t = t0.elapsed();
    let t1 = Instant::now();
    let b = aos.run(n, &params);
    let aos_t = t1.elapsed();

    println!("system {sys} over {n} entities");
    println!("  results match: {}", a == b);
    println!("  SoA  SIMD: {soa_t:?}");
    println!("  AoSoA SIMD: {aos_t:?}");
    let r = soa_t.as_secs_f64() / aos_t.as_secs_f64().max(1e-9);
    println!("  AoSoA vs SoA: {r:.2}x");
}

pub fn select(rest: &[String], program: &Program) {
    let sys = rest.get(1).map(|s| s.as_str())
        .unwrap_or_else(|| die("usage: orion select <file.or> <system>"));
    let kernel = orion::parallel::lower(program, sys).unwrap_or_else(|e| die(&format!("select: {e}")));
    let sample: usize = rest.get(2).and_then(|s| s.parse().ok()).unwrap_or(2_000_000);
    let params = parse_params(rest, 3);
    let (choice, soa_t, aosoa_t) = orion::select::choose_measured(&kernel, sample, &params)
        .unwrap_or_else(|e| die(&format!("select: {e}")));
    println!("system {sys}: measured both layouts on {sample} entities");
    println!("  SoA:   {soa_t:?}");
    println!("  AoSoA: {aosoa_t:?}");
    println!("  → choose {choice:?} (the measured winner — no guessing)");
}

fn print_speedup(slower: Duration, faster: Duration) {
    let r = slower.as_secs_f64() / faster.as_secs_f64().max(1e-9);
    println!("  speedup: {r:.1}x");
}
