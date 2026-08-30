# Platforms - the three seams

Orion targets new platforms through three fixed seams. Everything below each
seam is swappable; nothing above it ever changes. This file is the contract:
what a platform must provide, where it plugs in, and what proves it works.

Proof lives in CI (`.github/workflows/green.yml`): the full gate battery runs
on ubuntu, windows and macos on every push to main. A platform is "supported"
exactly when that matrix is green for it - not before.

## Seam 1 - the toolchain (compiler output -> native binary)

The compiler always emits ONE module shape: LLVM IR with a pinned Windows
triple (the setjmp/longjmp effect ABI is defined against it). A host does not
teach the compiler about itself; it retargets the emitted module header and
lets clang do the rest.

A platform provides exactly three facts:

| host    | datalayout mangling | triple                     | big stack via |
|---------|---------------------|----------------------------|---------------|
| Windows | `w` (as emitted)    | as emitted                 | `/STACK` link flag |
| Linux   | `e`                 | `x86_64-unknown-linux-gnu` | `ulimit -s`   |
| macOS   | `o`                 | `arm64-apple-macosx`       | `ulimit -s` (OS-capped) |

The rewrite is two anchored string replacements in the module header
(`datalayout = "e-m:w` and the triple line), done by whoever drives clang:
`orbit` (cli_build), the test runner, and the bootstrap scripts all carry it.
Adding a host = adding one row to this table in those call sites.

The retargeted text goes to a SCRATCH file. The emitted `.ll` is the
compiler's output, byte-identical on every machine; host-specific copies are
never committed.

## Seam 2 - the CLI runtime (what every Orion program links)

`runtime/orion_rt.c` + `runtime/orion_cli.c` + `runtime/net_min.c` are the
whole native runtime for command-line programs. Every function in them is
written as a two-branch `#ifdef _WIN32 / #else` where the platforms differ,
and the POSIX branch is the portable one (POSIX covers Linux and macOS both).

The contract is the extern surface the stdlib declares - if a platform fills
these, every orb works:

- process: `sys_run`, `sys_run_quiet`, `capture`, `proc_start`,
  `proc_start_to_file`, `proc_wait_ready`, `proc_result`, `proc_stop`
- filesystem: `mkdir_all`, `remove_file`, `fs_remove_tree`, `file_exists`,
  `is_dir`, `file_size`, `file_mtime`, `file_readonly`, `orion_dir_list`,
  `orion_dir_subdirs`
- host: `now`, `host_os`, `host_cpus`, `host_self_exe`, `exit_with`, `eprint`
- sockets: the `tcp_*` family + `sock_wait_ready` (select/poll per platform)
- tasks: fibers on Windows, ucontext elsewhere; where neither exists, `spawn`
  runs inline and `yield_now()` is a no-op - stated, not faked
- multi-shot (`ask`/`resume_with`): Windows fibers only, EXPERIMENTAL;
  `resumable_ok()` answers honestly per platform

New platform work happens ONLY inside the `#else` branches of these files.
No orb, no compiler code, no tool changes.

## Seam 3 - the engine blocks (window / pixels / audio / input)

Games link platform backends instead of orion_cli.c: `runtime/*_min.c`,
selected per host by `platform_c_files()` in `tools/orbit.or`. The contract
is a baseplate: a backend consumes a DisplayList and produces pixels; audio
and input are their own blocks.

Today's blocks are Windows (`win32_min.c`, `gdi_min.c`, `ogpu_min.c`,
`wasapi_min.c`). A platform lands as its own `<plat>_min.c` set; until it
exists, orbit refuses with a message naming exactly what to add - it never
half-links. The browser (the wasm backend) is the second working render platform and
needs no C at all.

## Adding a platform, in order

1. Toolchain row (seam 1) in orbit + test runner + bootstrap scripts.
2. `#else` branches that platform ifdefs differently from POSIX (seam 2).
3. Run the battery locally: `bash tools/bootstrap.sh` from a bare clone is
   the whole story - seed -> fixpoint -> orbit -> suite.
4. Add the runner to the green.yml matrix. Green there = supported, and it
   stays supported because every push re-proves it.
5. Engine blocks (seam 3) only when a game needs that platform's window.
