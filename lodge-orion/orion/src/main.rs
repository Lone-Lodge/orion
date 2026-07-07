//! The `orion` CLI. Parses argv, dispatches to `cmd::*`. Every subcommand lives
//! in `src/cmd.rs` so this file stays a one-screen routing table.

mod cmd;

use std::{env, process};

use orion::ast::Span;

const COMMANDS: &[&str] = &[
    "lex", "parse", "check", "run", "jit", "footprint", "layout", "parbench",
    "parrun", "aot", "link", "simd", "aosoa", "select", "gatherbench", "sim", "sim-jit",
    "hover", "goto", "symbols", "contracts", "contracts-test", "contracts-fuzz",
    "pack-info", "build-cache", "fmt-rich", "analyze", "stats", "docs",
    "lint", "bench", "ai-context", "graph", "explain", "repl", "check-all",
    "init", "call", "watch", "search", "outline", "size", "completion", "sample",
    "version", "features", "topics", "llvm",
];

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();

    if let Some(flag) = args.first().map(|s| s.as_str()) {
        match flag {
            "-h" | "--help" | "help" => return print_help(),
            "-V" | "--version" => return println!("orion {}", env!("CARGO_PKG_VERSION")),
            _ => {}
        }
    }

    let (cmd, rest): (&str, &[String]) = match args.first() {
        Some(a) if COMMANDS.contains(&a.as_str()) => (a.as_str(), &args[1..]),
        Some(_) => ("lex", &args[..]),
        None => usage(),
    };

    // `gatherbench` doesn't take a source file.
    if cmd == "gatherbench" {
        cmd::gatherbench(rest);
        return;
    }
    // `repl` is the interactive shell — no source file needed.
    if cmd == "repl" {
        cmd::repl();
        return;
    }
    // `init` scaffolds a new project — no source file needed.
    if cmd == "init" {
        cmd::init(rest);
        return;
    }
    // `completion` / `sample` produce text output without a source file.
    if cmd == "completion" {
        cmd::completion(rest);
        return;
    }
    if cmd == "sample" {
        cmd::sample(rest);
        return;
    }
    if cmd == "version" { cmd::version(); return; }
    if cmd == "features" { cmd::features(); return; }
    if cmd == "topics" { cmd::topics(); return; }

    let path = rest.first().map(|s| s.as_str()).unwrap_or_else(|| usage());

    // Raw-source commands don't need module resolution or full check.
    match cmd {
        "lex" => return cmd::lex(path),
        "parse" => return cmd::parse(path),
        "symbols" => return cmd::symbols(path),
        "watch" => return cmd::watch(path),
        "hover" => return cmd::hover(path, rest),
        "goto" => return cmd::goto(path, rest),
        _ => {}
    }

    // Everything else: load + resolve modules, then run every static check.
    let loaded = orion::loader::load(path).unwrap_or_else(|e| cmd::die(&e));
    let program = loaded.program;
    let files = loaded.files;
    let report = |span: Option<Span>, msg: &str| match span {
        Some(s) => orion::diag::render_file(&files[s.file as usize].0, &files[s.file as usize].1, s.line, s.col, msg),
        None => orion::diag::plain(msg),
    };
    run_checks(&program, &report);

    match cmd {
        "check" => cmd::check_ok(path),
        "run" => cmd::run(rest, &program),
        "jit" => cmd::jit(rest, &program),
        "aot" => cmd::aot(rest, &program),
        "link" => cmd::link(rest, &program),
        "footprint" => cmd::footprint(path, &program),
        "layout" => cmd::layout(&program),
        "contracts" => cmd::contracts(&program),
        "contracts-test" => cmd::contracts_test(&program),
        "contracts-fuzz" => cmd::contracts_fuzz(&program),
        "pack-info" => cmd::pack_info(&program),
        "build-cache" => cmd::build_cache(path, &program),
        "fmt-rich" => cmd::fmt_rich(&program),
        "analyze" => cmd::analyze(path, &program),
        "stats" => cmd::stats(&program),
        "docs" => cmd::docs(&program),
        "lint" => cmd::lint(&program),
        "bench" => cmd::bench(&program),
        "ai-context" => cmd::ai_context(path, &program),
        "check-all" => cmd::check_all(path, &program),
        "graph" => cmd::graph(&program),
        "call" => cmd::call(rest, &program),
        "search" => cmd::search(rest, &program),
        "outline" => cmd::outline(&program),
        "size" => cmd::size(&program),
        "llvm" => cmd::llvm(rest, &program),
        "explain" => {
            let sym = rest.get(1).map(|s| s.as_str()).unwrap_or_else(|| cmd::die("explain: need a symbol name"));
            cmd::explain(&program, sym);
        }
        "sim" => cmd::sim(rest, &program),
        "sim-jit" => cmd::sim_jit(rest, &program),
        "parbench" => cmd::parbench(rest, &program),
        "parrun" => cmd::parrun(rest, &program),
        "simd" => cmd::simd(rest, &program),
        "aosoa" => cmd::aosoa(rest, &program),
        "select" => cmd::select(rest, &program),
        _ => unreachable!("dispatch covered every COMMANDS entry"),
    }
}

fn run_checks(program: &orion::ast::Program, report: &dyn Fn(Option<Span>, &str) -> String) {
    if let Err(e) = orion::check::check(program) {
        cmd::die(&report(e.span, &e.message));
    }
    if let Err(e) = orion::typeck::check_types(program) {
        cmd::die(&report(e.span, &e.message));
    }
    if let Err(e) = orion::ownership::check(program) {
        cmd::die(&report(e.span, &e.message));
    }
}

fn usage() -> ! {
    eprintln!("usage: orion <command> <file.or> [args...]");
    eprintln!("try `orion --help`");
    process::exit(2);
}

fn print_help() {
    println!("orion {} — the Orion language CLI\n", env!("CARGO_PKG_VERSION"));
    println!("usage: orion <command> <file.or> [args...]\n");
    println!("inspect");
    println!("  lex   <file>              text → tokens");
    println!("  parse <file>              tokens → AST");
    println!("  check <file>              scope / mutability / arity errors");
    println!("\nrun");
    println!("  run  <file> <fn> [args]    interpret a function");
    println!("  jit  <file> <fn> [ints]    JIT to native code and run");
    println!("  aot  <file> <fn> [out.o]   compile to a native object file");
    println!("  link <file> <fn> [out]     compile + link a standalone executable");
    println!("\nengine analysis");
    println!("  footprint <file>               per-system reads/writes + parallel batches");
    println!("  layout    <file>               SoA/AoS per component");
    println!("  select    <file> <system>      measure both layouts, pick the faster");
    println!("\nbenchmarks");
    println!("  parbench <file> <fn> <n>       JIT'd fn across threads");
    println!("  parrun   <file> <system> <n>   data-parallel ECS, scalar vs threaded");
    println!("  simd     <file> <system> <n>   scalar vs SIMD (F64X2)");
    println!("  aosoa    <file> <system> <n>   SoA vs AoSoA layout");
    println!("  gatherbench [n] [reads]        SoA vs AoS on random access");
    println!("\nengine");
    println!("  sim     <file> [ticks]               run the world via the interpreter");
    println!("  sim-jit <file> [n] [ticks] [params]  same, but JIT systems that fit");
    println!("\neditor / LSP");
    println!("  symbols <file>                outline (top-level decls)");
    println!("  hover   <file> <line> <col>   signature at a cursor position");
    println!("  goto    <file> <line> <col>   jump to a name's declaration");
    println!("\nflags: --help, --version");
    println!("see also: `orbit` (the project tool: new / build / run / test)");
}
