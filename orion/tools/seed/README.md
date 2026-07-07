# Bootstrap seed

The **one** binary self-hosting needs: a known-good `orion.exe` that a fresh
clone starts from. With it, `orion.exe` builds the next `orion.exe` — no Rust,
no lodge-orion, ever.

This is how OCaml (`boot/ocamlc`) and Zig (a committed wasm build) bootstrap.
Rust/Go instead download a previous release; we commit the seed because a fresh
web-container clones empty with no prior Orion installed.

## The file

    orion/tools/seed/orion.exe      # excepted from *.exe in .gitignore

~290 KB. Committed on purpose. The fixed-point check (gen2 == gen3
byte-identical) protects against a tampered seed, so a checked-in binary is not
a trust hole.

## Bootstrap a fresh clone

    bash orion/tools/bootstrap.sh    # seed -> dist/orion.exe -> self-compile -> test

## Refresh the seed (per release)

The seed only needs replacing when the language grows past what the old seed can
parse. Refresh it with Orion's OWN output — never with Rust:

    cp orion/dist/orion.exe orion/tools/seed/orion.exe
    git add -f orion/tools/seed/orion.exe && git commit -m "seed: refresh to <version>"

## Why not keep lodge-orion up to date?

That's two compilers in sync forever — the burden self-hosting exists to remove.
The seed is a *frozen* orion.exe, produced by orion itself. lodge-orion was only
the primordial seed; once a real seed lives here, it stays archived.
