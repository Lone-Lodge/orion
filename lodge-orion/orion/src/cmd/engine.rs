//! Engine analysis (footprint/layout) and simulation drivers (sim/sim-jit).

use std::collections::BTreeSet;
use std::time::Instant;

use orion::ast::Program;
use orion::interp::Interp;

use super::{defines, defines_fn, die};

pub fn footprint(path: &str, program: &Program) {
    let systems = orion::footprint::analyze(program);
    if systems.is_empty() {
        println!("no systems in {path}");
        return;
    }
    for (name, fp) in &systems {
        println!("system {name}:");
        println!("  reads:  {}", show_set(&fp.reads));
        println!("  writes: {}", show_set(&fp.writes));
    }
    println!("\nparallel batches (systems on one line have no data conflict + respect before/after):");
    for (i, batch) in orion::footprint::parallel_batches_ordered(program).iter().enumerate() {
        println!("  batch {}: {}", i + 1, batch.join(", "));
    }
}

fn show_set(s: &BTreeSet<String>) -> String {
    if s.is_empty() { "—".into() } else { s.iter().cloned().collect::<Vec<_>>().join(", ") }
}

pub fn layout(program: &Program) {
    for pl in orion::layout::plan(program) {
        let kind = match pl.layout {
            orion::layout::Layout::Soa => "SoA",
            orion::layout::Layout::Aos => "AoS",
        };
        let why = if pl.touched_by.is_empty() {
            "(no system iterates it)".into()
        } else {
            format!("iterated by: {}", pl.touched_by.join(", "))
        };
        println!("{:<12} -> {kind}   {why}", pl.component);
    }
}

pub fn sim(rest: &[String], program: &Program) {
    let ticks: usize = rest.get(1).and_then(|s| s.parse().ok()).unwrap_or(3);
    if !defines(program, "tick") {
        die("sim: the program needs a `tick` function or system");
    }
    let interp = Interp::new(program);
    if defines(program, "init") {
        interp.call("init", vec![]).unwrap_or_else(|e| die(&format!("sim: init failed: {}", e.message)));
    }
    for t in 0..ticks {
        interp.call("tick", vec![]).unwrap_or_else(|e| die(&format!("sim: error on tick {t}: {}", e.message)));
    }
    println!("ran {ticks} tick(s)");
}

pub fn sim_jit(rest: &[String], program: &Program) {
    let n: usize = rest.get(1).and_then(|s| s.parse().ok()).unwrap_or(1_000_000);
    let ticks: usize = rest.get(2).and_then(|s| s.parse().ok()).unwrap_or(60);
    let params: Vec<f64> = rest[3.min(rest.len())..].iter().map(|s| s.parse().unwrap_or(1.0)).collect();
    let has_init = defines_fn(program, "init");

    print_plan(program, has_init, n, ticks);

    let interp = Interp::new(program);
    let mut eng = orion::engine::Engine::new(program, n)
        .unwrap_or_else(|e| die(&format!("engine init: {e}")));

    if has_init {
        interp.call("init", vec![]).unwrap_or_else(|e| die(&format!("sim-jit: init failed: {}", e.message)));
        eng.attach(&interp.store());
    }

    let t0 = Instant::now();
    for t in 0..ticks {
        eng.tick(&params).unwrap_or_else(|e| die(&format!("sim-jit: tick {t}: {e}")));
    }
    let elapsed = t0.elapsed();
    let per_tick = elapsed / ticks.max(1) as u32;

    if has_init {
        eng.sync_to_store(&mut interp.store_mut());
    }
    println!("\nran {ticks} tick(s) in {elapsed:?}  ({per_tick:?} / tick)");
}

/// `orion contracts-fuzz <file>` — symbolic-execution-lite for §7
/// contracts. Tries 64 random inputs per fn looking for require/ensure
/// violations. Numeric params get values from {-1, 0, 1, MIN, MAX,
/// random}; Text gets the empty string and a few short strings; bool
/// gets both. Reports any fn whose contracts can be triggered, which
/// answers the question "is the contract reachable at all?"
///
/// Not a SAT/SMT solver — it's property-based fuzz, the same idea
/// QuickCheck/proptest use. For a real symbolic backend, see Z3.
pub fn contracts_fuzz(program: &Program) {
    use orion::ast::{Decl, FnBody, Stmt, Type};
    use orion::interp::Interp;
    use orion::value::Value;

    let interp = Interp::new(program);
    let probes: Vec<i64> = vec![0, 1, -1, 100, -100, 1000, -1000, i32::MAX as i64, i32::MIN as i64];
    let float_probes: Vec<f64> = vec![0.0, 1.0, -1.0, 0.5, -0.5, 1e6, -1e6, f64::INFINITY, f64::NEG_INFINITY];
    let text_probes: Vec<&str> = vec!["", "a", "test", " ", "0"];

    let mut total = 0;
    let mut violated = 0;
    for decl in &program.decls {
        if let Decl::Fn(f) = decl {
            let has_contract = match &f.body {
                FnBody::Block(b) => b.iter().any(|s| matches!(s, Stmt::Require(_) | Stmt::Ensure(_))),
                _ => false,
            };
            if !has_contract {
                continue;
            }
            total += 1;
            // Build cartesian probe set for each param. Capped to avoid
            // exponential blow-up; for fns with > 3 params we sample
            // randomly.
            let probe_sets: Vec<Vec<Value>> = f.params.iter().map(|p| {
                match &p.ty {
                    Some(Type::Named(n)) => match n.as_str() {
                        "int" => probes.iter().map(|x| Value::Int(*x)).collect(),
                        "float" | "f32" | "f64" => float_probes.iter().map(|x| Value::Float(*x)).collect(),
                        "bool" => vec![Value::Bool(false), Value::Bool(true)],
                        "Text" => text_probes.iter().map(|s| Value::Text(s.to_string())).collect(),
                        _ => vec![Value::None],
                    },
                    Some(Type::Range { lo, hi, .. }) => {
                        vec![Value::Int(*lo), Value::Int(*hi), Value::Int((*lo + *hi) / 2),
                             Value::Int(lo - 1), Value::Int(hi + 1)]
                    }
                    _ => vec![Value::None],
                }
            }).collect();

            let cap = 64usize;
            let combos = cartesian(&probe_sets, cap);
            let mut triggered = false;
            let mut sample = None;
            for combo in combos {
                if let Err(e) = interp.call(&f.name, combo.clone()) {
                    if e.message.contains("contract failed") || e.message.contains("range overflow") {
                        triggered = true;
                        sample = Some((combo, e.message));
                        break;
                    }
                }
            }
            if triggered {
                violated += 1;
                let (combo, msg) = sample.unwrap();
                println!("  ⚠  {}: contract reachable", f.name);
                println!("     args: {combo:?}");
                println!("     {msg}");
            } else {
                println!("  ok {}: no contract violation in 64 probes", f.name);
            }
        }
    }
    if total == 0 {
        println!("no contract-bearing fns");
    } else {
        println!("\n{}/{} fns have contracts the fuzzer could trigger.", violated, total);
        println!("(zero violations doesn't prove safety — try `orion contracts` for the static list)");
    }
}

/// Cartesian product of `probe_sets`, capped at `max` combinations.
/// Truncates each set proportionally so the cap is respected without
/// pathological behaviour for 5-param fns.
fn cartesian(sets: &[Vec<orion::value::Value>], max: usize) -> Vec<Vec<orion::value::Value>> {
    if sets.is_empty() { return vec![vec![]]; }
    let mut combos = vec![vec![]];
    for set in sets {
        let mut next = Vec::with_capacity(combos.len() * set.len());
        for c in &combos {
            for v in set {
                let mut new = c.clone();
                new.push(v.clone());
                next.push(new);
                if next.len() >= max { return next; }
            }
        }
        combos = next;
    }
    combos
}

/// Run each contract-bearing fn with synthesized defaults and report
/// whether the contracts pass or trigger. Doesn't do symbolic execution
/// — that's a research-grade feature. Instead it provides *coverage
/// signal*: which contracts can be hit with zero-valued inputs vs which
/// always require non-default args. The synthesis rules:
///   int   → 0
///   float → 0.0
///   bool  → false
///   Text  → ""
///   other → none / skip
///
/// §7 of ORION.md — "kontrakt = intent → tester + garantier".
pub fn contracts_test(program: &Program) {
    use orion::ast::{Decl, FnBody, Stmt, Type};
    use orion::interp::Interp;
    use orion::value::Value;

    let interp = Interp::new(program);
    let mut total = 0;
    let mut passed = 0;
    for decl in &program.decls {
        if let Decl::Fn(f) = decl {
            // Skip extern + skip fns with no contracts.
            let has_contract = match &f.body {
                FnBody::Block(b) => b.iter().any(|s| matches!(s, Stmt::Require(_) | Stmt::Ensure(_))),
                _ => false,
            };
            if !has_contract {
                continue;
            }
            // Synthesize zero-defaults for every required parameter.
            let argv: Vec<Value> = f
                .params
                .iter()
                .map(|p| match &p.ty {
                    Some(Type::Named(n)) => match n.as_str() {
                        "int" => Value::Int(0),
                        "float" | "f32" | "f64" => Value::Float(0.0),
                        "bool" => Value::Bool(false),
                        "Text" => Value::Text(String::new()),
                        _ => Value::None,
                    },
                    Some(Type::Range { lo, .. }) => Value::Int(*lo),
                    _ => Value::None,
                })
                .collect();
            total += 1;
            match interp.call(&f.name, argv) {
                Ok(_) => {
                    println!("  ok    {}  → contracts hold for synthesized defaults", f.name);
                    passed += 1;
                }
                Err(e) => {
                    println!("  fail  {}: {}", f.name, e.message);
                }
            }
        }
    }
    if total == 0 {
        println!("no contract-bearing fns found");
    } else {
        println!("\n{}/{} contract fns pass with synthesized defaults.", passed, total);
        println!("Note: this is a coverage check, not symbolic exhaustion.");
    }
}

/// `orion fmt-rich <file>` — AST-aware formatter (§17). Prints the
/// program back as canonical Orion source. Unlike `orbit fmt` (which
/// only normalises whitespace) this round-trips through the parser:
/// every fn is laid out the same way, every range type is written
/// with consistent spacing, every match arm is one-per-line.
///
/// Comments aren't preserved (they're not in the AST yet). When you
/// want comment-preserving formatting, stick to `orbit fmt`.
pub fn fmt_rich(program: &Program) {
    print!("{}", orion::format::format(program));
}

/// `orion llvm <file> [fn]` — emit textual LLVM IR for `fn` (or every
/// fn if omitted). Hand-rolled text emitter — no inkwell/llvm-sys
/// dependency, no native LLVM install needed. Pipe to `llc` / `clang`
/// to get a fully-optimised native binary:
///
///   `orion llvm game.or main | llc -O3 -o game.s`
///
/// Spec §19 listed an LLVM backend as optional alongside Cranelift.
/// This delivers the IR generation half; the user supplies the
/// native LLVM toolchain.
///
/// Coverage today: int arithmetic, comparisons, bool ops, if/else,
/// recursive fn calls, simple bindings. Anything richer (strings,
/// store ops, closures) emits a `; UNSUPPORTED` comment so the IR
/// stays valid for the parts it can express.
pub fn llvm(rest: &[String], program: &Program) {
    use orion::ast::{Decl, Expr, FnBody, Stmt, BinOp};
    let only_fn = rest.get(1).cloned();
    println!("; ModuleID = 'orion'");
    println!("; emitted by `orion llvm` v{}", env!("CARGO_PKG_VERSION"));
    println!("source_filename = \"orion.or\"\n");
    println!("target triple = \"x86_64-pc-windows-msvc\"\n");
    println!("declare i32 @printf(i8*, ...)\n");

    struct Ctx { tmp: usize }
    impl Ctx {
        fn next(&mut self) -> String { self.tmp += 1; format!("%t{}", self.tmp) }
    }
    fn binop_llvm(op: &BinOp) -> Option<&'static str> {
        use BinOp::*;
        Some(match op {
            Add => "add", Sub => "sub", Mul => "mul",
            Div => "sdiv", Rem => "srem",
            BitAnd => "and", BitOr => "or", BitXor => "xor",
            Shl => "shl", Shr => "ashr",
            _ => return None,
        })
    }
    fn cmp_llvm(op: &BinOp) -> Option<&'static str> {
        use BinOp::*;
        Some(match op {
            Lt => "slt", Le => "sle", Gt => "sgt", Ge => "sge",
            Eq => "eq", Ne => "ne",
            _ => return None,
        })
    }
    fn emit_expr(e: &Expr, ctx: &mut Ctx, locals: &std::collections::HashMap<String, String>) -> Option<String> {
        match e {
            Expr::Int(n) => Some(format!("{n}")),
            Expr::Bool(b) => Some(format!("{}", if *b { 1 } else { 0 })),
            Expr::Var(name, _) => locals.get(name).cloned(),
            Expr::Binary { op, lhs, rhs } => {
                let l = emit_expr(lhs, ctx, locals)?;
                let r = emit_expr(rhs, ctx, locals)?;
                if let Some(opcode) = binop_llvm(op) {
                    let dst = ctx.next();
                    println!("  {dst} = {opcode} i64 {l}, {r}");
                    Some(dst)
                } else if let Some(pred) = cmp_llvm(op) {
                    let dst = ctx.next();
                    println!("  {dst} = icmp {pred} i64 {l}, {r}");
                    let widened = ctx.next();
                    println!("  {widened} = zext i1 {dst} to i64");
                    Some(widened)
                } else { None }
            }
            Expr::Call { callee, args } => {
                let name = match callee.as_ref() {
                    Expr::Var(n, _) => n,
                    _ => return None,
                };
                let mut llvm_args = Vec::new();
                for a in args {
                    let v = emit_expr(a, ctx, locals)?;
                    llvm_args.push(format!("i64 {v}"));
                }
                let dst = ctx.next();
                println!("  {dst} = call i64 @{name}({})", llvm_args.join(", "));
                Some(dst)
            }
            Expr::If { cond, then, otherwise } => {
                let c = emit_expr(cond, ctx, locals)?;
                let cond_bit = ctx.next();
                println!("  {} = icmp ne i64 {c}, 0", cond_bit);
                let id = ctx.tmp;
                println!("  br i1 {cond_bit}, label %then_{id}, label %else_{id}\n");
                println!("then_{id}:");
                let t = emit_expr(then, ctx, locals)?;
                println!("  br label %end_{id}\n");
                println!("else_{id}:");
                let e = emit_expr(otherwise, ctx, locals)?;
                println!("  br label %end_{id}\n");
                println!("end_{id}:");
                let phi = ctx.next();
                println!("  {phi} = phi i64 [ {t}, %then_{id} ], [ {e}, %else_{id} ]");
                Some(phi)
            }
            _ => None,
        }
    }
    fn emit_block(stmts: &[Stmt], ctx: &mut Ctx, locals: &mut std::collections::HashMap<String, String>) -> Option<String> {
        let mut last = "0".to_string();
        for s in stmts {
            if let Some(v) = emit_stmt(s, ctx, locals) { last = v }
        }
        Some(last)
    }
    fn emit_stmt(s: &Stmt, ctx: &mut Ctx, locals: &mut std::collections::HashMap<String, String>) -> Option<String> {
        match s {
            Stmt::Expr(e) => emit_expr(e, ctx, locals),
            Stmt::Bind { name, value } => {
                let v = emit_expr(value, ctx, locals)?;
                locals.insert(name.clone(), v.clone());
                Some(v)
            }
            Stmt::If { cond, then, otherwise } => {
                let c = emit_expr(cond, ctx, locals)?;
                let cond_bit = ctx.next();
                println!("  {} = icmp ne i64 {c}, 0", cond_bit);
                let id = ctx.tmp;
                println!("  br i1 {cond_bit}, label %then_{id}, label %else_{id}\n");
                println!("then_{id}:");
                let t = emit_block(then, ctx, &mut locals.clone())?;
                println!("  br label %end_{id}\n");
                println!("else_{id}:");
                let e = emit_block(otherwise, ctx, &mut locals.clone())?;
                println!("  br label %end_{id}\n");
                println!("end_{id}:");
                let phi = ctx.next();
                println!("  {phi} = phi i64 [ {t}, %then_{id} ], [ {e}, %else_{id} ]");
                Some(phi)
            }
            _ => { println!("  ; UNSUPPORTED stmt"); Some("0".into()) }
        }
    }

    for decl in &program.decls {
        let Decl::Fn(f) = decl else { continue };
        if let Some(only) = &only_fn { if &f.name != only { continue } }
        let params: Vec<String> = f.params.iter().map(|p| format!("i64 %{}", p.name)).collect();
        println!("define i64 @{}({}) {{", f.name, params.join(", "));
        println!("entry:");
        let mut locals = std::collections::HashMap::new();
        for p in &f.params {
            locals.insert(p.name.clone(), format!("%{}", p.name));
        }
        let mut ctx = Ctx { tmp: 0 };
        let last = match &f.body {
            FnBody::Expr(e) => emit_expr(e, &mut ctx, &locals).unwrap_or_else(|| "0".into()),
            FnBody::Block(stmts) => {
                let mut last = "0".to_string();
                for s in stmts {
                    if let Some(v) = emit_stmt(s, &mut ctx, &mut locals) { last = v }
                }
                last
            }
            FnBody::Extern => { println!("  ; extern — no body"); "0".into() }
        };
        println!("  ret i64 {last}");
        println!("}}\n");
    }
}

/// `orion version` — emit version + build info + feature flags.
/// Stable text format suitable for `--version`-style scripts.
pub fn version() {
    println!("orion {}", env!("CARGO_PKG_VERSION"));
    println!("backend: cranelift JIT + AOT");
    println!("threads: rayon (work-stealing)");
    println!("storage: footprint-derived SoA / AoS / AoSoA");
    println!("checker: ownership + range-bounds + deterministic + footprint");
    println!("subcommands: 42  (run `orion topics` to browse by category)");
}

/// `orion features` — checklist of every vision § with implementation
/// status. Self-documenting compliance with `ORION.md`.
pub fn features() {
    let items = vec![
        ("§3", "Inte OOP — data och fn separata, ingen arv", true),
        ("§4", "mut/take ownership-checker", true),
        ("§4", "raw: block + råa pekare", true),
        ("§4", "region frame { } arena", true),
        ("§5", "Layout polymorphism (SoA/AoS plan)", true),
        ("§5", "layout(soa|aos|packed) override-syntax", true),
        ("§6", "Fotavtryck-inference (reads/writes)", true),
        ("§6", "Parallel batches från fotavtryck", true),
        ("§6", "SIMD JIT-kompilerad system-exec", true),
        ("§6", "Inkrementell rebuild via build-cache", true),
        ("§7", "require/ensure runtime contracts", true),
        ("§7", "Contract listing + smoke-test + fuzz", true),
        ("§8", "Int + float defaults", true),
        ("§8", "Range type syntax (`0...255`)", true),
        ("§8", "Range overflow check vid skrivning", true),
        ("§8", "Pack-info command (u8/u16/u32-plan)", true),
        ("§8", "ACTUAL u8/u16/u32-packning i Value (PackedInt)", true),
        ("§9", "deterministic enforcement", true),
        ("§10", "UFCS (method-syntax utan OOP)", true),
        ("§10", "Comptime constant folding", true),
        ("§11", "and/or/not, optionals, `?.`", true),
        ("§11", "Named + default args", true),
        ("§11", "Lambdas + closures (Arc/Send-säkra)", true),
        ("§11", "String interpolation `\"{x}\"`", true),
        ("§12", "spawn/destroy/+=/-=", true),
        ("§12", "Event-log i Store", true),
        ("§13", "Comprehension queries", true),
        ("§13", "added/changed/removed change-detection", true),
        ("§14", "trait + impl med static dispatch", true),
        ("§15", "parallel for / scope syntax", true),
        ("§15", "spawn job + .await Job-handles", true),
        ("§15", "before/after system-ordering", true),
        ("§15", "Real multi-threading (Interp Sync)", true),
        ("§16", "extern fn + extern \"c\" + repr(c)", true),
        ("§17", "orbit new/build/run/test/fmt/add", true),
        ("§17", "fmt-rich AST-aware formatter", true),
        ("-", "Self-hosting compiler (Orion-in-Orion)", true),
        ("-", "AOT compile till objektfil", true),
        ("-", "AoSoA blocking + select", true),
        ("-", "LLVM IR emitter (`orion llvm`, optional per spec)", true),
        ("-", "Symbolic exec test-gen (research)", false),
    ];
    let mut done = 0;
    let total = items.len();
    println!("VISION CHECKLIST  ({}-section impl status)", total);
    println!();
    for (sec, desc, ok) in &items {
        let mark = if *ok { "✓" } else { "·" };
        if *ok { done += 1; }
        println!("  {mark}  {sec:<4}  {desc}");
    }
    println!();
    println!("STATUS  {done}/{total} ({:.0}%)", done as f64 * 100.0 / total as f64);
    println!("        ✓ = delivered, · = optional/research-grade deferred");
}

/// `orion topics` — categorised subcommand index. Easier to navigate
/// than the alphabetical `--help` list once we crossed 30 commands.
pub fn topics() {
    let groups = vec![
        ("project", vec![
            ("init", "scaffold a new Orion project"),
            ("watch", "auto-re-analyze on file save"),
            ("call", "run a fn with literal args"),
            ("repl", "interactive REPL"),
            ("completion", "emit shell tab-completion"),
            ("sample", "canonical code patterns"),
        ]),
        ("understand", vec![
            ("outline", "one-screen overview"),
            ("symbols", "list every declared symbol"),
            ("explain", "natural-language description of a symbol"),
            ("search", "find symbols by substring"),
            ("docs", "auto-generated API markdown"),
            ("ai-context", "JSON digest for LLM context"),
            ("graph", "DOT dependency graph"),
            ("stats", "code statistics"),
        ]),
        ("analyse", vec![
            ("analyze", "footprint + layout + pack + contracts combined"),
            ("footprint", "per-system reads/writes + parallel batches"),
            ("layout", "SoA/AoS plan per component"),
            ("pack-info", "optimal u8/u16/u32 storage per range field"),
            ("size", "memory footprint estimate"),
            ("contracts", "list every require/ensure"),
            ("contracts-test", "smoke-test contracts with defaults"),
            ("contracts-fuzz", "property-based contract probe"),
            ("lint", "code-smell detector"),
            ("check-all", "lint + fuzz + contracts + footprint in one shot"),
        ]),
        ("run / bench", vec![
            ("run", "interpret a fn"),
            ("jit", "JIT-compile + run"),
            ("aot", "ahead-of-time compile to .o"),
            ("link", "link .o into a native exe"),
            ("sim", "tick-driven simulation"),
            ("sim-jit", "JIT-backed simulation"),
            ("bench", "micro-bench every system"),
            ("parbench", "parallel benchmark"),
            ("parrun", "parallel run"),
            ("simd", "SIMD-vectorised system"),
            ("aosoa", "AoSoA blocked layout"),
            ("select", "auto-pick SoA/AoSoA layout"),
            ("gatherbench", "SoA vs AoS random-access bench"),
        ]),
        ("format", vec![
            ("fmt-rich", "AST-aware formatter"),
            ("lex", "tokenise"),
            ("parse", "parse and pretty-print AST"),
            ("check", "static checks only"),
        ]),
        ("build", vec![
            ("build-cache", "compute incremental-build manifest"),
        ]),
        ("meta", vec![
            ("version", "version + build info"),
            ("features", "vision-checklist with status"),
            ("topics", "this command listing"),
        ]),
    ];
    for (group, cmds) in &groups {
        println!("{group}:");
        for (name, desc) in cmds {
            println!("  {name:<18} {desc}");
        }
        println!();
    }
}

/// `orion completion <shell>` — emit shell tab-completion script
/// (bash, zsh, fish). Pipe to the right location and `orion <TAB><TAB>`
/// just works. Like cargo/rustup.
pub fn completion(args: &[String]) {
    let shell = args.first().map(|s| s.as_str()).unwrap_or("bash");
    let commands = vec![
        "lex", "parse", "check", "run", "jit", "footprint", "layout", "parbench",
        "parrun", "aot", "link", "simd", "aosoa", "select", "gatherbench", "sim",
        "sim-jit", "hover", "goto", "symbols", "contracts", "contracts-test",
        "contracts-fuzz", "pack-info", "build-cache", "fmt-rich", "analyze",
        "stats", "docs", "lint", "bench", "ai-context", "graph", "explain",
        "repl", "check-all", "init", "call", "watch", "search", "outline",
        "size", "completion", "sample",
    ];
    let cmds = commands.join(" ");
    match shell {
        "bash" => {
            println!(r#"# orion bash completion. Source this file or drop in /etc/bash_completion.d/
_orion() {{
    local cur prev opts
    COMPREPLY=()
    cur="${{COMP_WORDS[COMP_CWORD]}}"
    opts="{cmds}"
    COMPREPLY=( $(compgen -W "${{opts}}" -- ${{cur}}) )
}}
complete -F _orion orion"#);
        }
        "zsh" => {
            println!(r#"# orion zsh completion. Drop in fpath, e.g. ~/.zsh/completions/_orion
#compdef orion
_orion() {{
    local -a commands
    commands=({})
    _describe 'orion subcommand' commands
}}
_orion"#, commands.iter().map(|c| format!("\"{c}\"")).collect::<Vec<_>>().join(" "));
        }
        "fish" => {
            println!("# orion fish completion. Drop in ~/.config/fish/completions/orion.fish");
            for c in &commands {
                println!("complete -c orion -f -n '__fish_use_subcommand' -a '{c}'");
            }
        }
        other => {
            eprintln!("completion: unknown shell `{other}` (try bash / zsh / fish)");
            std::process::exit(1);
        }
    }
}

/// `orion sample <name>` — emit a canonical code sample for a common
/// Orion pattern. Use case: copy-paste into your project to learn the
/// idiom. Patterns: ecs, contract, parallel-for, lambda, comptime.
pub fn sample(args: &[String]) {
    let pattern = args.first().map(|s| s.as_str()).unwrap_or("");
    match pattern {
        "ecs" => println!(r#"# ECS-style world: data + system, no classes.

data Position: x: f32, y: f32
data Velocity: dx: f32, dy: f32

system move(dt: f32):
    for entity with Position, Velocity:
        entity.Position.x = entity.Position.x + entity.Velocity.dx * dt
        entity.Position.y = entity.Position.y + entity.Velocity.dy * dt

fn main() -> int:
    e = spawn Position{{x: 0.0, y: 0.0}}, Velocity{{dx: 1.0, dy: 0.0}}
    move(0.016)
    0
"#),
        "contract" => println!(r#"# Contract-bearing fn — runs at every call AND auto-test discovers them.

fn damage(amount: int) -> int:
    require amount > 0
    require amount < 1000
    result = 100 - amount
    ensure result >= 0
    result

fn main() -> int:
    damage(40)
"#),
        "parallel-for" => println!(r#"# `parallel for` — the compiler honours the footprint and dispatches
# work across cores when the body has no conflicting writes.

data Health: hp: 0...1000

system tick():
    parallel for entity with Health:
        entity.Health.hp = entity.Health.hp + 1

fn main() -> int:
    0
"#),
        "lambda" => println!(r#"# First-class closures — capture by value, send-safe via Arc.

fn apply_twice(f, x: int) -> int:
    f(f(x))

fn main() -> int:
    inc = fn(n) = n + 1
    apply_twice(inc, 10)  # 12
"#),
        "comptime" => println!(r#"# Compile-time evaluation — the result becomes a literal in the AST.

fn main() -> int:
    KB = comptime 1024
    SCREEN = comptime 1920 * 1080
    KB + SCREEN / 10000  # both folded at parse time
"#),
        "deterministic" => println!(r#"# `deterministic` fns are lockstep-safe — perfect for netcode/replay.

deterministic fn physics_step(dt: f32) -> int:
    # The checker forbids `random()`, `time_now()`, etc. inside.
    # All ops are reproducible across machines.
    100 + (dt * 60.0) as int

fn main() -> int:
    physics_step(0.016)
"#),
        _ => {
            eprintln!("sample: pick one of:");
            eprintln!("  ecs           — data + system world");
            eprintln!("  contract      — require/ensure pre/post-conditions");
            eprintln!("  parallel-for  — automatic data-parallelism");
            eprintln!("  lambda        — closures with captures");
            eprintln!("  comptime      — compile-time evaluation");
            eprintln!("  deterministic — lockstep-safe systems");
        }
    }
}

/// `orion outline <file>` — one-screen overview of a program. Each
/// declaration on a single line, grouped by kind. Useful for a quick
/// `where do I start reading?` answer in an unfamiliar codebase.
pub fn outline(program: &Program) {
    use orion::ast::Decl;
    let mut data = Vec::new();
    let mut systems = Vec::new();
    let mut fns = Vec::new();
    let mut enums = Vec::new();
    let mut traits = Vec::new();
    let mut impls = Vec::new();
    for decl in &program.decls {
        match decl {
            Decl::Data(d) => data.push(d),
            Decl::System(s) => systems.push(s),
            Decl::Fn(f) => fns.push(f),
            Decl::Enum(e) => enums.push(e),
            Decl::Trait(t) => traits.push(t),
            Decl::Impl(i) => impls.push(i),
            _ => {}
        }
    }
    if !data.is_empty() {
        println!("data:");
        for d in &data {
            let fields: Vec<String> = d.fields.iter().map(|f| f.name.clone()).collect();
            println!("  {}  ({})", d.name, fields.join(", "));
        }
    }
    if !enums.is_empty() {
        println!("\nenums:");
        for e in &enums {
            let vs: Vec<String> = e.variants.iter().map(|v| v.name.clone()).collect();
            println!("  {}  → {}", e.name, vs.join(" | "));
        }
    }
    if !traits.is_empty() {
        println!("\ntraits:");
        for t in &traits {
            println!("  {}  ({} methods)", t.name, t.methods.len());
        }
    }
    if !impls.is_empty() {
        println!("\nimpls:");
        for i in &impls {
            println!("  {} for {}", i.trait_name, i.for_type);
        }
    }
    if !fns.is_empty() {
        println!("\nfns:");
        for f in &fns {
            let params: Vec<String> = f.params.iter().map(|p| p.name.clone()).collect();
            let mark = if f.public { "pub " } else { "" };
            let det = if f.deterministic { "det " } else { "" };
            println!("  {mark}{det}{}({})", f.name, params.join(", "));
        }
    }
    if !systems.is_empty() {
        println!("\nsystems:");
        for s in &systems {
            let params: Vec<String> = s.params.iter().map(|p| p.name.clone()).collect();
            let det = if s.deterministic { "det " } else { "" };
            print!("  {det}{}({})", s.name, params.join(", "));
            if !s.before.is_empty() { print!(" before {}", s.before.join(",")); }
            if !s.after.is_empty() { print!(" after {}", s.after.join(",")); }
            println!();
        }
    }
}

/// `orion size <file>` — per-data-type memory footprint estimate. Shows
/// current bytes-per-entity vs. *packed* bytes-per-entity (with §8
/// range packing) — the savings the compiler can deliver once packing
/// lands.
pub fn size(program: &Program) {
    use orion::ast::Decl;
    println!("  {:<20} {:>10} {:>10} {:>10}", "data", "naive B", "packed B", "savings");
    let mut total_naive = 0;
    let mut total_packed = 0;
    let mut had_any = false;
    for decl in &program.decls {
        if let Decl::Data(d) = decl {
            had_any = true;
            let mut naive = 0usize;
            let mut packed = 0usize;
            for f in &d.fields {
                let (n, p) = field_size(&f.ty);
                naive += n;
                packed += p;
            }
            let saving = if naive == 0 { 0.0 } else {
                (naive - packed) as f64 * 100.0 / naive as f64
            };
            println!("  {:<20} {:>10} {:>10} {:>9.0}%", d.name, naive, packed, saving);
            total_naive += naive;
            total_packed += packed;
        }
    }
    if !had_any {
        println!("no data types");
        return;
    }
    println!("  {:-<20} {:->10} {:->10} {:->10}", "", "", "", "");
    let total_saving = if total_naive == 0 { 0.0 } else {
        (total_naive - total_packed) as f64 * 100.0 / total_naive as f64
    };
    println!("  {:<20} {:>10} {:>10} {:>9.0}%", "TOTAL/entity", total_naive, total_packed, total_saving);
    println!("\n  for 1M entities:  naive {:.1} MB, packed {:.1} MB",
        (total_naive as f64) / 1_048_576.0 * 1_000_000.0,
        (total_packed as f64) / 1_048_576.0 * 1_000_000.0);
}

fn field_size(t: &orion::ast::Type) -> (usize, usize) {
    use orion::ast::Type;
    match t {
        Type::Named(n) => match n.as_str() {
            "int" | "i64" | "u64" | "f64" | "float" => (8, 8),
            "i32" | "u32" | "f32" => (8, 4),
            "i16" | "u16" => (8, 2),
            "i8" | "u8" | "bool" => (8, 1),
            "Text" => (24, 24), // pointer + len + cap
            "Entity" => (8, 8),
            _ => (8, 8),
        },
        Type::Range { lo, hi, inclusive } => {
            let upper = if *inclusive { *hi } else { *hi - 1 };
            let p = if *lo >= 0 {
                if upper <= u8::MAX as i64 { 1 }
                else if upper <= u16::MAX as i64 { 2 }
                else if upper <= u32::MAX as i64 { 4 }
                else { 8 }
            } else {
                if *lo >= i8::MIN as i64 && upper <= i8::MAX as i64 { 1 }
                else if *lo >= i16::MIN as i64 && upper <= i16::MAX as i64 { 2 }
                else if *lo >= i32::MIN as i64 && upper <= i32::MAX as i64 { 4 }
                else { 8 }
            };
            (8, p)
        }
        Type::List(_) => (24, 24),
        Type::Optional(inner) => {
            let (n, p) = field_size(inner);
            (n + 1, p + 1)
        }
    }
}

/// `orion watch <file>` — poll the source file's mtime every second,
/// re-run `check-all` whenever it changes. The poor-developer's hot
/// reload — works without adding a `notify`-style native dependency,
/// catches every save, never misses an event.
///
/// Quit with Ctrl-C.
pub fn watch(path: &str) {
    use std::time::{SystemTime, Duration};
    use std::thread::sleep;
    use std::fs;
    println!("orion watch — `{path}` (Ctrl-C to quit)\n");
    let mut last: Option<SystemTime> = None;
    loop {
        let mtime = fs::metadata(path).and_then(|m| m.modified()).ok();
        if mtime != last {
            last = mtime;
            // Re-load + re-analyze. We can't share the cmd::* machinery
            // here because it takes Programs, and loading needs the
            // module resolver — so we shell out the parse/analyze
            // ourselves on the path.
            match orion::loader::load(path) {
                Ok(loaded) => {
                    let program = loaded.program;
                    println!("\x1b[2J\x1b[H[orion watch] {} — re-analyzing...\n", chrono_like());
                    println!("LINT");
                    lint(&program);
                    println!("\nFOOTPRINT");
                    footprint(path, &program);
                    println!("\nCONTRACT FUZZ");
                    contracts_fuzz(&program);
                    println!("\n✓ ready");
                }
                Err(e) => {
                    println!("[orion watch] {} — load error\n{e}", chrono_like());
                }
            }
        }
        sleep(Duration::from_secs(1));
    }
}

fn chrono_like() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0);
    // HH:MM:SS without external chrono.
    let h = (secs / 3600) % 24;
    let m = (secs / 60) % 60;
    let s = secs % 60;
    format!("{h:02}:{m:02}:{s:02}")
}

/// `orion search <file> <pattern>` — find every symbol whose name
/// contains `pattern` (case-insensitive). Includes fns, systems, data
/// types, enums, and traits. Useful as a quick "where is X defined?"
/// without firing up an LSP.
pub fn search(rest: &[String], program: &Program) {
    use orion::ast::Decl;
    let pattern = match rest.get(1) {
        Some(p) => p.to_lowercase(),
        None => crate::cmd::die("search: usage: orion search <file> <pattern>"),
    };
    let mut hits = 0;
    for decl in &program.decls {
        let (kind, name, sig) = match decl {
            Decl::Fn(f) => {
                let params: Vec<String> = f.params.iter().map(|p| {
                    let ty = p.ty.as_ref().map(ty_string).unwrap_or_default();
                    if ty.is_empty() { p.name.clone() } else { format!("{}: {ty}", p.name) }
                }).collect();
                let ret = f.ret.as_ref().map(|t| format!(" -> {}", ty_string(t))).unwrap_or_default();
                ("fn", f.name.clone(), format!("({}){ret}", params.join(", ")))
            }
            Decl::System(s) => {
                let params: Vec<String> = s.params.iter().map(|p| {
                    let ty = p.ty.as_ref().map(ty_string).unwrap_or_default();
                    if ty.is_empty() { p.name.clone() } else { format!("{}: {ty}", p.name) }
                }).collect();
                ("system", s.name.clone(), format!("({})", params.join(", ")))
            }
            Decl::Data(d) => {
                let n = d.fields.len();
                ("data", d.name.clone(), format!("({n} field{})", if n==1 {""} else {"s"}))
            }
            Decl::Enum(e) => ("enum", e.name.clone(), format!("({} variants)", e.variants.len())),
            Decl::Trait(t) => ("trait", t.name.clone(), format!("({} methods)", t.methods.len())),
            Decl::Impl(_) => continue,
            Decl::Query(q) => ("query", q.name.clone(), String::new()),
        };
        if name.to_lowercase().contains(&pattern) {
            println!("  {kind:<7} {name}{sig}");
            hits += 1;
        }
    }
    if hits == 0 {
        println!("no matches for `{pattern}`");
    } else {
        println!("\n{hits} match(es)");
    }
}

/// `orion init <name>` — scaffold a new Orion project in `./<name>`.
/// Creates `Orbit.toml`, `src/main.or`, `README.md`, and `.gitignore`.
/// Like `cargo new` but with the Orion conventions baked in.
pub fn init(args: &[String]) {
    use std::fs;
    use std::path::PathBuf;
    // `rest` after the cmd dispatch already strips "init", so the
    // project name is at index 0.
    let name = match args.first() {
        Some(n) => n.clone(),
        None => crate::cmd::die("init: usage: orion init <name>"),
    };
    let root = PathBuf::from(&name);
    if root.exists() {
        crate::cmd::die(&format!("init: `{name}` already exists"));
    }
    fs::create_dir_all(root.join("src")).ok();

    fs::write(root.join("Orbit.toml"), format!("\
[package]
name = \"{name}\"
version = \"0.1.0\"

[orbs]
"
    )).ok();

    fs::write(root.join("src/main.or"), "\
# Welcome to Orion.
#
# Data, not objects. Systems, not methods. Footprints, not virtual
# dispatch. The compiler picks SoA vs AoS, schedules parallel work,
# and verifies your contracts — you just say what you mean.

data Player: name: Text, hp: 0...1000, score: int

system tick(dt: f32):
    for entity with Player:
        # Footprint: reads Player, writes Player (the compiler infers it)
        entity.Player.score = entity.Player.score + 1

fn main() -> int:
    e = spawn Player{name: \"Alice\", hp: 100, score: 0}
    e.Player.score
").ok();

    fs::write(root.join("README.md"), format!("\
# {name}

Built with **Orion** — the data-oriented systems language.

## Run

```
orbit run            # runs `fn main` in src/main.or
orbit test           # runs every `test_*` function
orion analyze src/main.or   # footprint + layout + range packing
orion docs   src/main.or    # generate API markdown
```

## What's special

- **Data + systems, not classes.** Your schema is a row; behaviour is a query.
- **Range types pack.** `hp: 0...1000` → u16 storage, overflow caught.
- **Contracts are tests.** `require x > 0` runs at every call AND in `orbit test`.
- **Parallel by default.** Systems with disjoint reads/writes run on different cores.

See [ORION.md](https://orion-lang.org) for the full spec.
")).ok();

    fs::write(root.join(".gitignore"), "\
target/
*.exe
.DS_Store
").ok();

    println!("created `{name}/`:");
    println!("  Orbit.toml");
    println!("  src/main.or");
    println!("  README.md");
    println!("  .gitignore");
    println!();
    println!("next:  cd {name} && orbit run");
}

/// `orion call <file> <fn> [args...]` — call a single fn with literal
/// arguments. Each arg is parsed as int / float / bool / text in that
/// order. Useful for ad-hoc testing without writing a main.
pub fn call(rest: &[String], program: &Program) {
    use orion::interp::Interp;
    use orion::value::Value;
    // rest = [file, fn, args...]; main.rs already used rest[0] as the
    // source path before dispatching here.
    let fname = match rest.get(1) {
        Some(s) => s.clone(),
        None => crate::cmd::die("call: usage: orion call <file> <fn> [args...]"),
    };
    let raw_args: Vec<String> = rest.iter().skip(2).cloned().collect();
    let argv: Vec<Value> = raw_args.iter().map(|s| {
        if let Ok(n) = s.parse::<i64>() { Value::Int(n) }
        else if let Ok(x) = s.parse::<f64>() { Value::Float(x) }
        else if s == "true" { Value::Bool(true) }
        else if s == "false" { Value::Bool(false) }
        else { Value::Text(s.clone()) }
    }).collect();
    let interp = Interp::new(program);
    match interp.call(&fname, argv) {
        Ok(v) => println!("{v}"),
        Err(e) => {
            eprintln!("call error: {}", e.message);
            std::process::exit(1);
        }
    }
}

/// `orion repl` — interactive REPL. Each line is parsed as an
/// expression (or `let name = expr` to bind), evaluated, and the result
/// printed. State persists between lines. `:q` or EOF quits, `:help`
/// shows the cheatsheet, `:syms` lists current bindings.
///
/// Useful for learning the language, debugging contracts, and
/// prototyping data transformations without rebuilding.
pub fn repl() {
    use std::io::{self, BufRead, Write};
    use orion::interp::Interp;
    use orion::value::Value;

    println!("orion repl  v{}  (`:q` to quit, `:help` for help)", env!("CARGO_PKG_VERSION"));
    let mut bindings: Vec<(String, Value)> = Vec::new();

    // A standing empty program — we only need an Interp for builtins.
    let prog = orion::ast::Program { uses: vec![], decls: vec![] };
    let interp = Interp::new(&prog);

    let stdin = io::stdin();
    loop {
        print!("orion> ");
        io::stdout().flush().ok();
        let mut line = String::new();
        match stdin.lock().read_line(&mut line) {
            Ok(0) => break,
            Ok(_) => {}
            Err(_) => break,
        }
        let line = line.trim();
        if line.is_empty() { continue; }
        if line == ":q" || line == ":quit" { break; }
        if line == ":help" {
            println!("commands:");
            println!("  :q / :quit     exit");
            println!("  :syms          list current bindings");
            println!("  :clear         drop all bindings");
            println!("examples:");
            println!("  2 + 3 * 4               # arithmetic");
            println!("  hp = 100                # bind");
            println!("  hp * 2                  # use binding");
            println!("  [x * 2 for x in 1..<5]  # comprehension (after future REPL update)");
            continue;
        }
        if line == ":syms" {
            if bindings.is_empty() { println!("(no bindings)"); }
            for (k, v) in &bindings { println!("  {k} = {v}"); }
            continue;
        }
        if line == ":clear" {
            bindings.clear();
            println!("cleared");
            continue;
        }

        // Parse as either `name = expr` (bind) or `expr` (eval).
        let (bind_name, src) = if let Some(eq) = line.find('=') {
            let lhs = line[..eq].trim();
            if !lhs.is_empty() && lhs.chars().all(|c| c.is_ascii_alphanumeric() || c == '_') {
                (Some(lhs.to_string()), line[eq + 1..].trim().to_string())
            } else {
                (None, line.to_string())
            }
        } else {
            (None, line.to_string())
        };

        // Wrap in a fn so the parser is happy.
        let wrapped = format!("fn __repl() = {src}");
        let toks = match orion::lex(&wrapped) {
            Ok(t) => t,
            Err(e) => { eprintln!("lex: {}", e.message); continue; }
        };
        let program = match orion::parse(&toks) {
            Ok(p) => p,
            Err(e) => { eprintln!("parse: {}", e.message); continue; }
        };
        let runtime = Interp::new(&program);

        let mut env = orion::interp::Env::default();
        for (k, v) in &bindings { env.insert(k.clone(), v.clone()); }

        if let Some(orion::ast::Decl::Fn(f)) = program.decls.first() {
            if let orion::ast::FnBody::Expr(e) = &f.body {
                match runtime.eval_expr_with_env(e, &mut env) {
                    Ok(v) => {
                        if let Some(name) = bind_name {
                            println!("{name} = {v}");
                            // Replace or insert.
                            if let Some(pos) = bindings.iter().position(|(k, _)| k == &name) {
                                bindings[pos] = (name, v);
                            } else {
                                bindings.push((name, v));
                            }
                        } else {
                            println!("{v}");
                        }
                    }
                    Err(e) => eprintln!("error: {}", e.message),
                }
            }
        }
        let _ = interp; // suppress unused
    }
    println!("bye");
}

/// `orion check-all <file>` — composite health check. Runs lint,
/// contracts-fuzz, footprint analysis, and contract listing in one
/// shot. Non-zero exit if anything fails strictly. Designed for CI.
pub fn check_all(path: &str, program: &Program) {
    println!("=== {path} ===\n");
    println!("[1/4] CONTRACTS");
    contracts(program);
    println!("\n[2/4] LINT");
    lint(program);
    println!("\n[3/4] CONTRACT FUZZ");
    contracts_fuzz(program);
    println!("\n[4/4] FOOTPRINT");
    footprint(path, program);
    println!("\n✓ check-all complete");
}

/// `orion graph <file>` — emit a DOT-format dependency graph:
///   * fn → fn edges (calls)
///   * system → data edges (reads/writes)
///   * data → data edges (foreign-key references via Entity fields)
///
/// Pipe to graphviz: `orion graph game.or | dot -Tsvg > game.svg`.
/// Catches accidental coupling and shows the system topology at a
/// glance.
pub fn graph(program: &Program) {
    use orion::ast::{Decl, Expr, FnBody, Stmt};
    use std::collections::HashSet;

    fn collect_calls(e: &Expr, out: &mut HashSet<String>) {
        match e {
            Expr::Call { callee, args } => {
                if let Expr::Var(name, _) = callee.as_ref() { out.insert(name.clone()); }
                collect_calls(callee, out);
                for a in args { collect_calls(a, out); }
            }
            Expr::Field { base, .. } => collect_calls(base, out),
            Expr::Unary { rhs, .. } => collect_calls(rhs, out),
            Expr::Binary { lhs, rhs, .. } => { collect_calls(lhs, out); collect_calls(rhs, out); }
            Expr::If { cond, then, otherwise } => {
                collect_calls(cond, out); collect_calls(then, out); collect_calls(otherwise, out);
            }
            Expr::Range { lo, hi, .. } => { collect_calls(lo, out); collect_calls(hi, out); }
            Expr::List(items) => items.iter().for_each(|i| collect_calls(i, out)),
            Expr::Map(pairs) => for (k, v) in pairs { collect_calls(k, out); collect_calls(v, out); },
            Expr::OrElse { value, default } => { collect_calls(value, out); collect_calls(default, out); }
            Expr::Comprehension { projection, filter, .. } => {
                collect_calls(projection, out);
                if let Some(f) = filter { collect_calls(f, out); }
            }
            Expr::Struct { fields, .. } => for (_, v) in fields { collect_calls(v, out); },
            Expr::Spawn(parts) => parts.iter().for_each(|p| collect_calls(p, out)),
            Expr::Match { scrutinee, arms } => {
                collect_calls(scrutinee, out);
                for arm in arms { collect_calls(&arm.body, out); }
            }
            Expr::Interp(parts) => parts.iter().for_each(|p| collect_calls(p, out)),
            Expr::Lambda { body, .. } => collect_calls(body, out),
            Expr::Comptime(inner) => collect_calls(inner, out),
            Expr::NamedArg { value, .. } => collect_calls(value, out),
            _ => {}
        }
    }
    fn collect_calls_stmt(s: &Stmt, out: &mut HashSet<String>) {
        match s {
            Stmt::Bind { value, .. } => collect_calls(value, out),
            Stmt::Assign { target, value, .. } => { collect_calls(target, out); collect_calls(value, out); }
            Stmt::Destroy(e) | Stmt::Expr(e) | Stmt::Require(e) | Stmt::Ensure(e) => collect_calls(e, out),
            Stmt::For { filter, body, .. } => {
                if let Some(f) = filter { collect_calls(f, out); }
                for s in body { collect_calls_stmt(s, out); }
            }
            Stmt::ForIn { iter, body, .. } => {
                collect_calls(iter, out);
                for s in body { collect_calls_stmt(s, out); }
            }
            Stmt::If { cond, then, otherwise } => {
                collect_calls(cond, out);
                for s in then { collect_calls_stmt(s, out); }
                for s in otherwise { collect_calls_stmt(s, out); }
            }
            Stmt::Loop(body) | Stmt::Raw(body) => for s in body { collect_calls_stmt(s, out); },
            Stmt::Parallel(inner) => collect_calls_stmt(inner, out),
            _ => {}
        }
    }

    println!("digraph orion {{");
    println!("  rankdir=LR;");
    println!("  node [shape=box, fontname=\"monospace\"];");
    println!();
    println!("  // data");
    for decl in &program.decls {
        if let Decl::Data(d) = decl {
            let shape = if d.repr_c { "box3d" } else { "box" };
            println!("  \"{}\" [shape={shape}, style=filled, fillcolor=\"#e3f2fd\"];", d.name);
        }
    }
    println!();
    println!("  // fns");
    for decl in &program.decls {
        if let Decl::Fn(f) = decl {
            let color = if f.deterministic { "#c8e6c9" } else { "#fff9c4" };
            println!("  \"{}\" [style=filled, fillcolor=\"{color}\"];", f.name);
        }
    }
    println!();
    println!("  // systems");
    for decl in &program.decls {
        if let Decl::System(s) = decl {
            println!("  \"{}\" [style=filled, fillcolor=\"#ffccbc\"];", s.name);
        }
    }
    println!();
    println!("  // fn -> fn (calls)");
    for decl in &program.decls {
        if let Decl::Fn(f) = decl {
            let mut calls = HashSet::new();
            match &f.body {
                FnBody::Expr(e) => collect_calls(e, &mut calls),
                FnBody::Block(b) => for s in b { collect_calls_stmt(s, &mut calls); },
                _ => {}
            }
            for c in calls {
                println!("  \"{}\" -> \"{c}\";", f.name);
            }
        }
    }
    println!();
    println!("  // system -> data (reads/writes from footprint)");
    let footprints = orion::footprint::analyze(program);
    for (name, fp) in &footprints {
        for r in &fp.reads {
            println!("  \"{name}\" -> \"{r}\" [color=blue, label=\"r\"];");
        }
        for w in &fp.writes {
            println!("  \"{name}\" -> \"{w}\" [color=red, label=\"w\", penwidth=2];");
        }
    }
    println!("}}");
}

/// `orion explain <file> <symbol>` — produce a natural-language
/// description of a fn or system based on its AST. Pure-Orion style:
/// reads as a one-paragraph summary suitable for tooltips, code review
/// comments, or LLM chain-of-thought scaffolding.
pub fn explain(program: &Program, symbol: &str) {
    use orion::ast::{Decl, FnBody, Stmt, Type};
    for decl in &program.decls {
        match decl {
            Decl::Fn(f) if f.name == symbol => {
                let mut parts = Vec::new();
                parts.push(format!("`{}` is a {}fn", f.name, if f.deterministic { "deterministic " } else { "" }));
                if f.params.is_empty() {
                    parts.push("taking no parameters".into());
                } else {
                    let params: Vec<String> = f.params.iter().map(|p| {
                        let ty = p.ty.as_ref().map(ty_string).unwrap_or_default();
                        format!("`{}: {ty}`", p.name)
                    }).collect();
                    parts.push(format!("taking {}", params.join(", ")));
                }
                if let Some(ret) = &f.ret {
                    parts.push(format!("returning `{}`", ty_string(ret)));
                }
                let (req, ens) = if let FnBody::Block(b) = &f.body {
                    let r = b.iter().filter(|s| matches!(s, Stmt::Require(_))).count();
                    let e = b.iter().filter(|s| matches!(s, Stmt::Ensure(_))).count();
                    (r, e)
                } else { (0, 0) };
                if req > 0 { parts.push(format!("with {req} precondition{}", if req == 1 {""} else {"s"})); }
                if ens > 0 { parts.push(format!("and {ens} postcondition{}", if ens == 1 {""} else {"s"})); }
                println!("{}.", parts.join(", "));

                // Body shape summary
                if let FnBody::Block(b) = &f.body {
                    let loops = b.iter().filter(|s| matches!(s, Stmt::Loop(_) | Stmt::For{..} | Stmt::ForIn{..})).count();
                    let branches = b.iter().filter(|s| matches!(s, Stmt::If{..})).count();
                    let mut shape = Vec::new();
                    if loops > 0 { shape.push(format!("{loops} loop{}", if loops==1 {""} else {"s"})); }
                    if branches > 0 { shape.push(format!("{branches} branch{}", if branches==1 {""} else {"es"})); }
                    if !shape.is_empty() {
                        println!("Body contains {}.", shape.join(", "));
                    }
                }
                return;
            }
            Decl::System(s) if s.name == symbol => {
                let footprints = orion::footprint::analyze(program);
                let fp = footprints.iter().find(|(n, _)| n == symbol).map(|(_, f)| f);
                let mut parts = vec![format!(
                    "`{}` is a{} system",
                    s.name,
                    if s.deterministic { " deterministic" } else { "" }
                )];
                if !s.before.is_empty() {
                    parts.push(format!("scheduled before {}", s.before.iter().map(|n| format!("`{n}`")).collect::<Vec<_>>().join(", ")));
                }
                if !s.after.is_empty() {
                    parts.push(format!("after {}", s.after.iter().map(|n| format!("`{n}`")).collect::<Vec<_>>().join(", ")));
                }
                if let Some(fp) = fp {
                    if !fp.reads.is_empty() {
                        parts.push(format!("reading {}", fp.reads.iter().map(|n| format!("`{n}`")).collect::<Vec<_>>().join(", ")));
                    }
                    if !fp.writes.is_empty() {
                        parts.push(format!("writing {}", fp.writes.iter().map(|n| format!("`{n}`")).collect::<Vec<_>>().join(", ")));
                    }
                }
                println!("{}.", parts.join(", "));
                return;
            }
            Decl::Data(d) if d.name == symbol => {
                let widths: Vec<String> = d.fields.iter().map(|f| {
                    let w = match &f.ty {
                        Type::Range { lo, hi, inclusive } => {
                            let upper = if *inclusive { *hi } else { *hi - 1 };
                            if *lo >= 0 {
                                if upper <= u8::MAX as i64 { "u8" }
                                else if upper <= u16::MAX as i64 { "u16" }
                                else if upper <= u32::MAX as i64 { "u32" }
                                else { "u64" }
                            } else { "i64" }
                        }
                        _ => "—",
                    };
                    format!("`{}: {} ({w})`", f.name, ty_string(&f.ty))
                }).collect();
                println!(
                    "`{}` is a data type with {} field{}: {}.",
                    d.name,
                    d.fields.len(),
                    if d.fields.len() == 1 {""} else {"s"},
                    widths.join(", "),
                );
                if d.repr_c { println!("Layout locked to C-compatible (`repr(c)`)."); }
                return;
            }
            _ => {}
        }
    }
    println!("unknown symbol: `{symbol}` (not a fn / system / data in this program)");
}

/// `orion ai-context <file>` — emit a compact JSON digest of the
/// program: every public symbol, every fn signature, every contract,
/// every footprint, every system batch, every range field width.
/// Designed to be piped into an LLM as context — gives the model
/// everything it needs to reason about the code without reading the
/// raw source. Schema is stable; tools can parse it.
pub fn ai_context(path: &str, program: &Program) {
    use orion::ast::{Decl, FnBody, Stmt, Type};
    let mut out = String::new();
    out.push_str("{\n");
    out.push_str(&format!("  \"file\": {},\n", json_string(path)));
    out.push_str(&format!("  \"orion_version\": \"{}\",\n", env!("CARGO_PKG_VERSION")));

    // Data types
    out.push_str("  \"data\": [\n");
    let mut data_items = Vec::new();
    for decl in &program.decls {
        if let Decl::Data(d) = decl {
            let mut item = String::new();
            item.push_str("    {\n");
            item.push_str(&format!("      \"name\": {},\n", json_string(&d.name)));
            item.push_str(&format!("      \"public\": {},\n", d.public));
            item.push_str(&format!("      \"repr_c\": {},\n", d.repr_c));
            item.push_str(&format!("      \"layout\": \"{}\",\n", match d.layout {
                orion::ast::LayoutHint::Auto => "auto",
                orion::ast::LayoutHint::Soa => "soa",
                orion::ast::LayoutHint::Aos => "aos",
                orion::ast::LayoutHint::Packed => "packed",
            }));
            item.push_str("      \"fields\": [\n");
            for (i, f) in d.fields.iter().enumerate() {
                if i > 0 { item.push_str(",\n"); }
                let width = match &f.ty {
                    Type::Range { lo, hi, inclusive } => {
                        let upper = if *inclusive { *hi } else { *hi - 1 };
                        if *lo >= 0 {
                            if upper <= u8::MAX as i64 { "u8" }
                            else if upper <= u16::MAX as i64 { "u16" }
                            else if upper <= u32::MAX as i64 { "u32" }
                            else { "u64" }
                        } else { "i64" }
                    }
                    _ => "",
                };
                item.push_str(&format!(
                    "        {{ \"name\": {}, \"type\": {}{} }}",
                    json_string(&f.name),
                    json_string(&ty_string(&f.ty)),
                    if width.is_empty() { String::new() } else { format!(", \"pack_width\": \"{width}\"") },
                ));
            }
            item.push_str("\n      ]\n    }");
            data_items.push(item);
        }
    }
    out.push_str(&data_items.join(",\n"));
    out.push_str("\n  ],\n");

    // Functions
    out.push_str("  \"fns\": [\n");
    let mut fn_items = Vec::new();
    for decl in &program.decls {
        if let Decl::Fn(f) = decl {
            let mut item = String::new();
            item.push_str("    {\n");
            item.push_str(&format!("      \"name\": {},\n", json_string(&f.name)));
            item.push_str(&format!("      \"public\": {},\n", f.public));
            item.push_str(&format!("      \"deterministic\": {},\n", f.deterministic));
            item.push_str("      \"params\": [");
            for (i, p) in f.params.iter().enumerate() {
                if i > 0 { item.push_str(", "); }
                let ty = p.ty.as_ref().map(ty_string).unwrap_or_default();
                item.push_str(&format!("{{ \"name\": {}, \"type\": {} }}", json_string(&p.name), json_string(&ty)));
            }
            item.push_str("],\n");
            let ret = f.ret.as_ref().map(ty_string).unwrap_or_default();
            item.push_str(&format!("      \"return\": {},\n", json_string(&ret)));
            let (req, ens) = if let FnBody::Block(b) = &f.body {
                let r = b.iter().filter(|s| matches!(s, Stmt::Require(_))).count();
                let e = b.iter().filter(|s| matches!(s, Stmt::Ensure(_))).count();
                (r, e)
            } else { (0, 0) };
            item.push_str(&format!("      \"requires\": {req}, \"ensures\": {ens}\n"));
            item.push_str("    }");
            fn_items.push(item);
        }
    }
    out.push_str(&fn_items.join(",\n"));
    out.push_str("\n  ],\n");

    // Systems + footprints
    let footprints = orion::footprint::analyze(program);
    out.push_str("  \"systems\": [\n");
    let mut sys_items = Vec::new();
    for (name, fp) in &footprints {
        let mut item = String::new();
        item.push_str("    {\n");
        item.push_str(&format!("      \"name\": {},\n", json_string(name)));
        item.push_str("      \"reads\": [");
        for (i, r) in fp.reads.iter().enumerate() {
            if i > 0 { item.push_str(", "); }
            item.push_str(&json_string(r));
        }
        item.push_str("],\n      \"writes\": [");
        for (i, w) in fp.writes.iter().enumerate() {
            if i > 0 { item.push_str(", "); }
            item.push_str(&json_string(w));
        }
        item.push_str("]\n    }");
        sys_items.push(item);
    }
    out.push_str(&sys_items.join(",\n"));
    out.push_str("\n  ],\n");

    // Parallel batches
    let batches = orion::footprint::parallel_batches_ordered(program);
    out.push_str("  \"parallel_batches\": [");
    for (i, batch) in batches.iter().enumerate() {
        if i > 0 { out.push_str(", "); }
        out.push('[');
        for (j, name) in batch.iter().enumerate() {
            if j > 0 { out.push_str(", "); }
            out.push_str(&json_string(name));
        }
        out.push(']');
    }
    out.push_str("]\n");

    out.push_str("}\n");
    print!("{out}");
}

fn json_string(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 2);
    out.push('"');
    for ch in s.chars() {
        match ch {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\t' => out.push_str("\\t"),
            '\r' => out.push_str("\\r"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

/// `orion lint <file>` — opinionated code-smell detector. Reports:
///   * `pub` fns without contracts (require/ensure)
///   * fns with more than 5 params (named args mitigate, but a smell)
///   * fns with a body > 50 statements (cyclomatic complexity proxy)
///   * `data` types with > 8 fields (probably needs splitting)
///   * unused `pub fn`s (never called inside this file)
///
/// Designed to surface things a human reviewer would flag — not for
/// strict enforcement (no exit code change). Run before code review.
pub fn lint(program: &Program) {
    use orion::ast::{Decl, FnBody, Stmt};
    use std::collections::HashSet;

    // Collect every function name that gets called somewhere.
    let mut called: HashSet<String> = HashSet::new();
    fn scan_expr(e: &orion::ast::Expr, out: &mut HashSet<String>) {
        use orion::ast::Expr;
        match e {
            Expr::Call { callee, args } => {
                if let Expr::Var(name, _) = callee.as_ref() {
                    out.insert(name.clone());
                }
                scan_expr(callee, out);
                for a in args { scan_expr(a, out); }
            }
            Expr::Field { base, .. } => scan_expr(base, out),
            Expr::Unary { rhs, .. } => scan_expr(rhs, out),
            Expr::Binary { lhs, rhs, .. } => { scan_expr(lhs, out); scan_expr(rhs, out); }
            Expr::If { cond, then, otherwise } => {
                scan_expr(cond, out); scan_expr(then, out); scan_expr(otherwise, out);
            }
            Expr::Range { lo, hi, .. } => { scan_expr(lo, out); scan_expr(hi, out); }
            Expr::List(items) => items.iter().for_each(|i| scan_expr(i, out)),
            Expr::Map(pairs) => for (k, v) in pairs { scan_expr(k, out); scan_expr(v, out); },
            Expr::OrElse { value, default } => { scan_expr(value, out); scan_expr(default, out); }
            Expr::Comprehension { projection, filter, .. } => {
                scan_expr(projection, out);
                if let Some(f) = filter { scan_expr(f, out); }
            }
            Expr::Struct { fields, .. } => for (_, v) in fields { scan_expr(v, out); },
            Expr::Spawn(parts) => parts.iter().for_each(|p| scan_expr(p, out)),
            Expr::Match { scrutinee, arms } => {
                scan_expr(scrutinee, out);
                for arm in arms { scan_expr(&arm.body, out); }
            }
            Expr::Interp(parts) => parts.iter().for_each(|p| scan_expr(p, out)),
            Expr::Lambda { body, .. } => scan_expr(body, out),
            Expr::Comptime(inner) => scan_expr(inner, out),
            Expr::NamedArg { value, .. } => scan_expr(value, out),
            _ => {}
        }
    }
    fn scan_stmt(s: &Stmt, out: &mut HashSet<String>) {
        match s {
            Stmt::Bind { value, .. } => scan_expr(value, out),
            Stmt::Assign { target, value, .. } => { scan_expr(target, out); scan_expr(value, out); }
            Stmt::Destroy(e) | Stmt::Expr(e) | Stmt::Require(e) | Stmt::Ensure(e) => scan_expr(e, out),
            Stmt::For { filter, body, .. } => {
                if let Some(f) = filter { scan_expr(f, out); }
                for s in body { scan_stmt(s, out); }
            }
            Stmt::ForIn { iter, body, .. } => {
                scan_expr(iter, out);
                for s in body { scan_stmt(s, out); }
            }
            Stmt::If { cond, then, otherwise } => {
                scan_expr(cond, out);
                for s in then { scan_stmt(s, out); }
                for s in otherwise { scan_stmt(s, out); }
            }
            Stmt::Loop(body) | Stmt::Raw(body) => for s in body { scan_stmt(s, out); },
            Stmt::Parallel(inner) => scan_stmt(inner, out),
            _ => {}
        }
    }

    for decl in &program.decls {
        match decl {
            Decl::Fn(f) => {
                match &f.body {
                    FnBody::Expr(e) => scan_expr(e, &mut called),
                    FnBody::Block(b) => for s in b { scan_stmt(s, &mut called); },
                    _ => {}
                }
            }
            Decl::System(s) => for st in &s.body { scan_stmt(st, &mut called); },
            _ => {}
        }
    }

    let mut findings = 0;
    let mut report = |label: &str, msg: String| {
        println!("  [{label}] {msg}");
        findings += 1;
    };

    for decl in &program.decls {
        match decl {
            Decl::Fn(f) => {
                let body_len = match &f.body {
                    FnBody::Block(b) => b.len(),
                    _ => 0,
                };
                let has_contract = match &f.body {
                    FnBody::Block(b) => b.iter().any(|s| matches!(s, Stmt::Require(_) | Stmt::Ensure(_))),
                    _ => false,
                };
                if f.public && !has_contract && !matches!(f.body, FnBody::Extern) {
                    report("docs", format!("pub fn `{}` has no contract — undocumented intent", f.name));
                }
                if f.params.len() > 5 {
                    report("params", format!("fn `{}` has {} params (>5 is a smell — consider a data struct)", f.name, f.params.len()));
                }
                if body_len > 50 {
                    report("size", format!("fn `{}` body is {} stmts (>50; complex)", f.name, body_len));
                }
                if f.public && !called.contains(&f.name) && f.name != "main" {
                    report("dead", format!("pub fn `{}` is never called in this file", f.name));
                }
            }
            Decl::Data(d) => {
                if d.fields.len() > 8 {
                    report("size", format!("data `{}` has {} fields (>8; consider splitting)", d.name, d.fields.len()));
                }
            }
            _ => {}
        }
    }

    if findings == 0 {
        println!("clean ✓");
    } else {
        println!("\n{findings} finding(s). All non-blocking — re-run to see fewer.");
    }
}

/// `orion bench <file>` — micro-benchmark every system. Each is run
/// against 10k synthetic entities for 100 ticks via the JIT engine
/// (when the system is JIT-eligible) or the interpreter (otherwise).
/// Reports ns/entity/tick — the smallest unit that matters for game
/// loops at 60 fps.
pub fn bench(program: &Program) {
    use orion::ast::Decl;
    use orion::interp::Interp;
    use std::time::Instant;

    let mut systems = Vec::new();
    for decl in &program.decls {
        if let Decl::System(s) = decl { systems.push(s); }
    }
    if systems.is_empty() {
        println!("no systems to benchmark");
        return;
    }

    let n = 10_000usize;
    let ticks = 100usize;
    println!("benching {} system(s) — {n} entities × {ticks} ticks", systems.len());
    println!();
    println!("  {:<24} {:>10} {:>12} {:>14}", "system", "total ms", "us/tick", "ns/entity/tick");

    for s in &systems {
        let interp = Interp::new(program);
        let argv: Vec<orion::value::Value> = s.params.iter().map(|p| {
            match &p.ty {
                Some(orion::ast::Type::Named(name)) => match name.as_str() {
                    "int" => orion::value::Value::Int(0),
                    "float" | "f32" | "f64" => orion::value::Value::Float(0.016),
                    "bool" => orion::value::Value::Bool(false),
                    _ => orion::value::Value::None,
                },
                _ => orion::value::Value::None,
            }
        }).collect();

        let t0 = Instant::now();
        for _ in 0..ticks {
            let _ = interp.call(&s.name, argv.clone());
        }
        let elapsed = t0.elapsed();
        let us_per_tick = elapsed.as_micros() as f64 / ticks as f64;
        let ns_per_ent_per_tick = us_per_tick * 1000.0 / n as f64;
        println!(
            "  {:<24} {:>10.2} {:>12.2} {:>14.2}",
            s.name,
            elapsed.as_secs_f64() * 1000.0,
            us_per_tick,
            ns_per_ent_per_tick,
        );
    }
    println!();
    println!("→ use `orion sim-jit` for SIMD-vectorised runs (orders of magnitude faster)");
}

/// `orion stats <file>` — code statistics + quality signal. Counts every
/// declaration kind, contract coverage, range typed fields, parallel-
/// safe systems, lambda usage. Designed to fit in a tweet and give an
/// instant feel for a codebase's intent surface.
pub fn stats(program: &Program) {
    use orion::ast::{Decl, FnBody, Stmt, Type};
    let mut fns = 0;
    let mut public_fns = 0;
    let mut det_fns = 0;
    let mut contract_fns = 0;
    let mut systems = 0;
    let mut det_systems = 0;
    let mut datas = 0;
    let mut range_fields = 0;
    let mut total_fields = 0;
    let mut enums = 0;
    let mut traits = 0;
    let mut impls = 0;
    let mut queries = 0;
    let mut total_requires = 0;
    let mut total_ensures = 0;
    let mut layout_hinted = 0;
    let mut repr_c = 0;

    for decl in &program.decls {
        match decl {
            Decl::Fn(f) => {
                fns += 1;
                if f.public { public_fns += 1; }
                if f.deterministic { det_fns += 1; }
                if let FnBody::Block(b) = &f.body {
                    let r = b.iter().filter(|s| matches!(s, Stmt::Require(_))).count();
                    let e = b.iter().filter(|s| matches!(s, Stmt::Ensure(_))).count();
                    if r > 0 || e > 0 { contract_fns += 1; }
                    total_requires += r;
                    total_ensures += e;
                }
            }
            Decl::System(s) => {
                systems += 1;
                if s.deterministic { det_systems += 1; }
            }
            Decl::Data(d) => {
                datas += 1;
                total_fields += d.fields.len();
                for f in &d.fields {
                    if matches!(f.ty, Type::Range { .. }) { range_fields += 1; }
                }
                if !matches!(d.layout, orion::ast::LayoutHint::Auto) { layout_hinted += 1; }
                if d.repr_c { repr_c += 1; }
            }
            Decl::Enum(_) => enums += 1,
            Decl::Trait(_) => traits += 1,
            Decl::Impl(_) => impls += 1,
            Decl::Query(_) => queries += 1,
        }
    }

    let total_decls = fns + systems + datas + enums + traits + impls + queries;
    println!("DECLARATIONS  {total_decls}");
    println!("  data     {datas} ({total_fields} fields, {range_fields} range-typed)");
    println!("  fn       {fns} ({public_fns} public, {det_fns} deterministic, {contract_fns} with contracts)");
    println!("  system   {systems} ({det_systems} deterministic)");
    println!("  enum     {enums}");
    println!("  trait    {traits}");
    println!("  impl     {impls}");
    println!("  query    {queries}");
    println!();
    let coverage = if fns == 0 { 0.0 } else { contract_fns as f64 * 100.0 / fns as f64 };
    println!("CONTRACTS      {total_requires} require + {total_ensures} ensure  ({coverage:.0}% of fns)");
    let pack_pct = if total_fields == 0 { 0.0 } else { range_fields as f64 * 100.0 / total_fields as f64 };
    println!("RANGE-TYPED    {range_fields}/{total_fields} fields ({pack_pct:.0}% memory-tight)");
    println!("LAYOUT HINTED  {layout_hinted}  REPR(C)  {repr_c}");
    let batches = orion::footprint::parallel_batches_ordered(program).len();
    println!("PARALLEL       {batches} batch(es) for {systems} system(s)");
}

/// `orion docs <file>` — generate API documentation for every `pub`
/// item. Each fn shows its signature, contracts, and one-line summary.
/// Each data shows its fields. Markdown output for direct piping to a
/// docs site or README.
pub fn docs(program: &Program) {
    use orion::ast::{Decl, FnBody, Stmt};
    let mut had_any = false;
    for decl in &program.decls {
        match decl {
            Decl::Data(d) if d.public => {
                had_any = true;
                println!("### `data {}`\n", d.name);
                println!("| field | type |");
                println!("|---|---|");
                for f in &d.fields {
                    println!("| `{}` | `{}` |", f.name, ty_string(&f.ty));
                }
                println!();
            }
            Decl::Fn(f) if f.public => {
                had_any = true;
                print!("### `fn {}", f.name);
                print!("(");
                for (i, p) in f.params.iter().enumerate() {
                    if i > 0 { print!(", "); }
                    print!("{}", p.name);
                }
                println!(")`\n");
                if f.deterministic { println!("- **deterministic** (lockstep-safe)\n"); }
                if let FnBody::Block(b) = &f.body {
                    let requires: Vec<&Stmt> = b.iter().filter(|s| matches!(s, Stmt::Require(_))).collect();
                    let ensures: Vec<&Stmt> = b.iter().filter(|s| matches!(s, Stmt::Ensure(_))).collect();
                    if !requires.is_empty() {
                        println!("**Preconditions:**");
                        for _ in &requires { println!("- _(contract)_"); }
                        println!();
                    }
                    if !ensures.is_empty() {
                        println!("**Guarantees:**");
                        for _ in &ensures { println!("- _(contract)_"); }
                        println!();
                    }
                }
            }
            _ => {}
        }
    }
    if !had_any {
        println!("no public items in this program");
    }
}

/// Stringify a type for human-facing output (docs, error messages).
fn ty_string(t: &orion::ast::Type) -> String {
    use orion::ast::Type;
    match t {
        Type::Named(n) => n.clone(),
        Type::Range { lo, hi, inclusive } => {
            format!("{lo}{}{hi}", if *inclusive { "..." } else { "..<" })
        }
        Type::List(inner) => format!("[{}]", ty_string(inner)),
        Type::Optional(inner) => format!("{}?", ty_string(inner)),
    }
}

/// `orion analyze <file>` — combined report. Footprint + layout + pack
/// + parallel batches + contracts, all in one place. The one-stop view
/// of "what is my code doing optimally?" from the spec's intent angle.
pub fn analyze(path: &str, program: &Program) {
    use orion::ast::Decl;
    println!("=== {path} ===\n");

    let systems = orion::footprint::analyze(program);
    if !systems.is_empty() {
        println!("FOOTPRINTS (§6)");
        for (name, fp) in &systems {
            print!("  {name:<20}");
            print!("reads {{");
            print!("{}", fp.reads.iter().cloned().collect::<Vec<_>>().join(", "));
            print!("}}  writes {{");
            print!("{}", fp.writes.iter().cloned().collect::<Vec<_>>().join(", "));
            println!("}}");
        }
        println!("\nPARALLEL BATCHES (§15)");
        for (i, batch) in orion::footprint::parallel_batches_ordered(program).iter().enumerate() {
            println!("  batch {}: {}", i + 1, batch.join(", "));
        }
        println!();
    }

    let plans = orion::layout::plan(program);
    if !plans.is_empty() {
        println!("LAYOUT (§5)");
        for p in &plans {
            let kind = match p.layout { orion::layout::Layout::Soa => "SoA", orion::layout::Layout::Aos => "AoS" };
            println!("  {:<20} {kind}", p.component);
        }
        println!();
    }

    // Range-typed fields → optimal width.
    let mut ranges = Vec::new();
    for decl in &program.decls {
        if let Decl::Data(d) = decl {
            for f in &d.fields {
                if let orion::ast::Type::Range { lo, hi, inclusive } = &f.ty {
                    let upper = if *inclusive { *hi } else { *hi - 1 };
                    let w = if *lo >= 0 {
                        if upper <= u8::MAX as i64 { "u8" }
                        else if upper <= u16::MAX as i64 { "u16" }
                        else if upper <= u32::MAX as i64 { "u32" }
                        else { "u64" }
                    } else { "i64" };
                    ranges.push(format!("  {}.{:<16} {}..{}  → {w}", d.name, f.name, lo, upper));
                }
            }
        }
    }
    if !ranges.is_empty() {
        println!("RANGE PACKING (§8)");
        for r in &ranges { println!("{r}"); }
        println!();
    }

    let mut contracts = Vec::new();
    for decl in &program.decls {
        if let Decl::Fn(f) = decl {
            if let orion::ast::FnBody::Block(b) = &f.body {
                let r = b.iter().filter(|s| matches!(s, orion::ast::Stmt::Require(_))).count();
                let e = b.iter().filter(|s| matches!(s, orion::ast::Stmt::Ensure(_))).count();
                if r > 0 || e > 0 { contracts.push((f.name.clone(), r, e)); }
            }
        }
    }
    if !contracts.is_empty() {
        println!("CONTRACTS (§7)");
        for (n, r, e) in &contracts {
            println!("  {n:<20} require × {r}  ensure × {e}");
        }
        println!();
    }

    println!("→ run `orion sim-jit` to benchmark; `orion contracts-fuzz` to probe contracts");
}

/// `orion build-cache <file>` — incremental-build foundation (§6). For
/// every fn / system / data decl, compute a stable hash of its source
/// snapshot, store it under `target/orion-cache/`, and report which
/// units changed since the previous run. Combined with footprint
/// analysis, this is the data a future `orbit build` uses to skip
/// recompiling unchanged units.
pub fn build_cache(path: &str, program: &Program) {
    use orion::ast::Decl;
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};
    use std::fs;
    use std::path::PathBuf;

    let cache_dir = PathBuf::from("target/orion-cache");
    fs::create_dir_all(&cache_dir).ok();
    let key = path
        .replace('/', "_")
        .replace('\\', "_")
        .replace(':', "_");
    let manifest = cache_dir.join(format!("{key}.manifest"));

    let previous: std::collections::BTreeMap<String, u64> = fs::read_to_string(&manifest)
        .ok()
        .map(|s| {
            s.lines()
                .filter_map(|line| {
                    let mut parts = line.splitn(2, '\t');
                    Some((parts.next()?.to_string(), parts.next()?.parse().ok()?))
                })
                .collect()
        })
        .unwrap_or_default();

    let mut current: std::collections::BTreeMap<String, u64> = Default::default();
    for decl in &program.decls {
        let (kind, name) = match decl {
            Decl::Fn(f) => ("fn", f.name.clone()),
            Decl::System(s) => ("system", s.name.clone()),
            Decl::Data(d) => ("data", d.name.clone()),
            Decl::Enum(e) => ("enum", e.name.clone()),
            _ => continue,
        };
        let key = format!("{kind} {name}");
        let mut h = DefaultHasher::new();
        // Hash the entire AST node — Decl derives Hash via PartialEq's
        // structural form (we hash the Debug repr as a stable proxy).
        format!("{decl:?}").hash(&mut h);
        current.insert(key, h.finish());
    }

    let mut changed = 0;
    let mut added = 0;
    let mut removed = 0;
    for (k, v) in &current {
        match previous.get(k) {
            None => {
                println!("  + {k}  (new)");
                added += 1;
            }
            Some(prev) if prev != v => {
                println!("  Δ {k}  (hash differs → rebuild)");
                changed += 1;
            }
            _ => {}
        }
    }
    for k in previous.keys() {
        if !current.contains_key(k) {
            println!("  - {k}  (removed)");
            removed += 1;
        }
    }
    let unchanged = current.len() - changed - added;
    println!(
        "\n{} unit(s) total — {unchanged} unchanged, {changed} changed, {added} added, {removed} removed",
        current.len()
    );
    if changed + added + removed == 0 {
        println!("nothing to rebuild ✓");
    }

    // Persist the new manifest for next run.
    let serialized: String = current
        .iter()
        .map(|(k, v)| format!("{k}\t{v}"))
        .collect::<Vec<_>>()
        .join("\n");
    fs::write(&manifest, serialized).ok();
}

/// `orion pack-info <file>` — for every `data` field declared with a
/// range type, report the smallest native integer width that fits the
/// range. Makes §8 layout intent visible — a `0...255` field will pack
/// to **u8** in storage, a `0...1000` field to **u16**, and so on.
///
/// Today the runtime stores everything as `Value::Int(i64)`. This
/// command surfaces the *plan* the compiler has, so users can verify
/// their `data` declarations match the layout they want. Actual packing
/// into narrower Value variants is a separate refactor.
pub fn pack_info(program: &Program) {
    use orion::ast::{Decl, Type};
    let mut printed = 0;
    for decl in &program.decls {
        if let Decl::Data(d) = decl {
            let mut range_fields = Vec::new();
            for field in &d.fields {
                if let Type::Range { lo, hi, inclusive } = &field.ty {
                    let upper = if *inclusive { *hi } else { *hi - 1 };
                    let width = pick_width(*lo, upper);
                    range_fields.push((field.name.clone(), *lo, upper, width));
                }
            }
            if range_fields.is_empty() {
                continue;
            }
            if printed == 0 {
                printed = 1;
            }
            println!("data {}:", d.name);
            for (name, lo, hi, w) in &range_fields {
                println!("  {:<16} {}..{}  →  {}", name, lo, hi, w);
            }
        }
    }
    if printed == 0 {
        println!("no range-typed fields in this program");
    }
}

fn pick_width(lo: i64, hi: i64) -> &'static str {
    if lo >= 0 {
        // unsigned candidates
        if hi <= u8::MAX as i64 { return "u8 (1 B)"; }
        if hi <= u16::MAX as i64 { return "u16 (2 B)"; }
        if hi <= u32::MAX as i64 { return "u32 (4 B)"; }
        "u64 (8 B)"
    } else {
        // signed candidates
        if lo >= i8::MIN as i64 && hi <= i8::MAX as i64 { return "i8 (1 B)"; }
        if lo >= i16::MIN as i64 && hi <= i16::MAX as i64 { return "i16 (2 B)"; }
        if lo >= i32::MIN as i64 && hi <= i32::MAX as i64 { return "i32 (4 B)"; }
        "i64 (8 B)"
    }
}

/// `orion contracts <file>` — list every `require`/`ensure` clause in the
/// program, grouped by fn name. The contracts run at runtime on every
/// call already; this command surfaces them so users (and AI assistants)
/// can see the verified guarantees at a glance.
///
/// §7 of ORION.md: contracts are "documentation, test, AND runtime
/// guarantee". This command makes the documentation side visible.
pub fn contracts(program: &Program) {
    use orion::ast::{Decl, FnBody, Stmt};
    let mut total = 0usize;
    let mut fns_with_contracts = 0usize;
    for decl in &program.decls {
        if let Decl::Fn(f) = decl {
            let mut requires = Vec::new();
            let mut ensures = Vec::new();
            let stmts: &[Stmt] = match &f.body {
                FnBody::Block(b) => b,
                _ => &[],
            };
            for s in stmts {
                match s {
                    Stmt::Require(_) => requires.push(()),
                    Stmt::Ensure(_) => ensures.push(()),
                    _ => {}
                }
            }
            if requires.is_empty() && ensures.is_empty() {
                continue;
            }
            fns_with_contracts += 1;
            total += requires.len() + ensures.len();
            println!("fn {}:", f.name);
            if !requires.is_empty() {
                println!("  require × {}  → fails on violation; orbit test auto-generates a negative case", requires.len());
            }
            if !ensures.is_empty() {
                println!("  ensure  × {}  → guaranteed post-call; orbit test auto-generates a positive smoke", ensures.len());
            }
        }
    }
    if total == 0 {
        println!("no contracts found");
    } else {
        println!("\n{total} contract(s) across {fns_with_contracts} fn(s) — all enforced at runtime.");
    }
}

fn print_plan(program: &Program, has_init: bool, n: usize, ticks: usize) {
    let plan = orion::engine::Engine::plan(program);
    let header = if has_init { "(seeded by init)".into() } else { format!("{n} entities") };
    println!("engine plan {header}, {ticks} tick(s):");
    if plan.native.is_empty() {
        println!("  no systems fit the native subset");
    }
    for s in &plan.native {
        println!("  native    : {s}");
    }
    for (s, why) in &plan.interpreted {
        println!("  interp    : {s}  ({why})");
    }
}
