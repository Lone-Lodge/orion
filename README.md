# orion

A next-gen 2026 programming language: AI-friendly, data-oriented (not OOP), self-hosting.

## Layout

- **`lodge-orion/`** — Rust reference implementation. Provides `orbit` CLI and the bootstrap interpreter. See `lodge-orion/STATUS.md`.
- **`orion-self/`** — Self-hosted Orion compiler written in Orion. Compiles to a native `orion.exe` (~289KB) via LLVM IR.

## State

- `orion.exe` self-compiles. Fixed-point verified.
- Language features: sum types with payloads, `?` operator, pattern destructuring, method-call syntax, `return` keyword, algebraic-effects parser (continuations: future), data structs, enums, contracts, ECS-style queries.
- Stdlib orbs: bytes, text, fs, io, time, math, random, log, hash, json, csv, xml, regex, url, base64, hex, color, crypto, easing, noise, format, collections, env, sysinfo, image, audio, gpu, wgsl, net, result, option, assert.

## Building

```
cd lodge-orion/orion
cargo build --release   # produces orbit.exe
cd ../../orion-self
bash tools/bundle_minified.sh   # produces dist/orion_self_bundled_min.or
# then compile bundle → orion.exe via examples/compile_or driver
```

## Sibling projects (separate repos)

`astra`, `atlas`, `skriva`, `veil` — products built ON Orion, each in its own repo at the `lone-lodge` level.
