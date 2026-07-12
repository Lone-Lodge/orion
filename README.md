# orion

A next-gen 2026 programming language: AI-friendly, data-oriented (not OOP), self-hosting.

## Layout

- **`orion/`** — THE Orion compiler, written in Orion. Self-hosting,
  fixpoint-verified, emits LLVM IR → native exe. `dist/orion.exe` (~290KB)
  is the canonical toolchain. Games built with it run native (cubsy: 279KB,
  full atlas/astra/veil stack, no Rust at runtime).

Orion is now **fully self-hosted** — there is no Rust implementation in the
tree. The compiler builds, self-hosts, and reaches its fixpoint using only
`dist/orion.exe` + clang (the retired Rust interpreter, lodge-orion, lives
in git history if ever needed).

## State

- `orion.exe` self-compiles. Fixed-point verified (gen2 == gen3, byte-identical).
- Cubsy runs fully native end-to-end: window, D3D12 render, astra scripts,
  ECS, input. Compile: lex 16 / parse 16 / ir 31 / emit 62 ms.
- Language features: sum types with payloads, `?` operator, pattern
  destructuring, method-call syntax, `return` keyword, data structs, enums,
  f64, multi-payload enums, extern fns, multi-orb driver.
- Stdlib orbs: bytes, text, fs, io, time, math, random, log, hash, json, csv,
  xml, regex, url, base64, hex, color, crypto, easing, noise, format,
  collections, env, sysinfo, image, gpu, wgsl, net, result, option, assert.

## Setup (Windows)

Put `orbit` / `orion` on your PATH once — this is what makes `orbit play dev`
work from any project dir:

```powershell
E:\lone-lodge\orion\bin\install.ps1
```

It prepends this repo's `bin\` (self-locating shims → `dist\orbit.exe`) to your
user PATH and warns if a stale `orbit` elsewhere is shadowing it. That stale
shim is the usual cause of `The system cannot find the path specified.` — an
old shortcut pointing at a dead dir. The shims are portable (relative to the
repo), so cloning to any path Just Works after one `install.ps1`.

## Building

```
cd orion
bash tools/self_bootstrap.sh    # orion.exe rebuilds itself, fixpoint-verified
```

This detects the host (Windows / Linux / Mac), retargets the emitted IR, and
links a native `dist/orion.exe`. To hand-run the self-compile loop instead:

```
cd orion
bash tools/bundle_orbs.sh                              # → dist/orion_self_bundled.or
./dist/orion.exe dist/orion_self_bundled.or out.ll     # self-compile
clang out.ll runtime/orion_rt.c -Os -o dist/orion.exe
```

Bootstrap from scratch on a fresh clone (no `orion.exe` yet): the committed
seed IR is the ONE checked-in artifact self-hosting needs —
`bash tools/bootstrap_from_ll.sh` links `tools/seed/orion.ll` with clang into
a working `dist/orion.exe`, then run `tools/self_bootstrap.sh`. No Rust,
no prior binary required.

Compile a game (native) — see cubsy/build.cmd for the full recipe:

```
build        game.exe       GDI software renderer — runs GPU-less, ~27MB RAM
build gpu    game_gpu.exe   D3D12 backend
build ship   game_ship.exe  GDI + ALL assets embedded (config + scripts as
                            byte arrays via runtime/tools/embed_assets.ps1) —
                            one standalone file, zero file I/O
```

Renderer backends share the og_* API; pick at link time (gdi_min.c OR
d3d12_min.c). Dev builds read assets from disk, so script hot reload
works ("dev": 1 in the project json swaps changed .astra bundles live,
parse-gated). Ship builds run from the embedded table.

Dev loop (interpreted, instant): `orbit run src/main.or` from the project dir.

## Sibling projects (separate repos)

`astra`, `atlas`, `skriva`, `veil` — products built ON Orion, each in its own repo at the `lone-lodge` level.
