# orion

A next-gen 2026 programming language: AI-friendly, data-oriented (not OOP), self-hosting.

## Layout

- **`orion-self/`** — THE Orion compiler, written in Orion. Self-hosting,
  fixpoint-verified, emits LLVM IR → native exe. `dist/orion.exe` (~290KB)
  is the canonical toolchain. Games built with it run native (cubsy: 279KB,
  full atlas/astra/veil stack, no Rust at runtime).
- **`lodge-orion/`** — Rust implementation, now the *dev loop only*:
  `orbit run` gives instant interpreted feedback while editing. Not a
  runtime dependency of anything shipped. See `lodge-orion/STATUS.md`.

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

## Building

```
cd orion-self
bash tools/bundle_orbs.sh                      # → dist/orion_self_bundled.or
./dist/orion.exe dist/orion_self_bundled.or out.ll   # self-compile
clang out.ll runtime/orion_rt.c -Os -o dist/orion.exe
```

Bootstrap from scratch (no orion.exe yet): build `orbit.exe` in
`lodge-orion/orion` (`cargo build --release`) and run the bundle through
`examples/compile_or` once, then switch to the self-compile loop above.

Compile a game (native):

```
orion.exe src/main.or game.ll <orb roots: atlas/orbs_native atlas/orbs astra/orbs veil/orbs>
clang game.ll runtime/orion_rt.c runtime/win32_min.c runtime/d3d12_min.c \
  -Os -o game.exe -luser32 -lgdi32 -ld3d12 -ldxgi -ld3dcompiler
```

Dev loop (interpreted, instant): `orbit run src/main.or` from the project dir.

## Sibling projects (separate repos)

`astra`, `atlas`, `skriva`, `veil` — products built ON Orion, each in its own repo at the `lone-lodge` level.
