# orion_emit_wasm

Emit a WebAssembly module - the `.wasm` binary itself.

Pure Orion produces bytes on disk whose exports a JS shell calls. No external
linker, no wasm-bindgen, no wasm-pack: Orion writes the bytes, and JS imports
them with `WebAssembly.instantiateStreaming`.

Spec: <https://webassembly.github.io/spec/core/binary/index.html>

## Layout

```
"\0asm" + version 1     8 bytes of magic
Type    section  id=1   function signatures
Func    section  id=3   fn indices into Types
Memory  section  id=5   linear memory, 1 page = 64 KiB
Export  section  id=7   what JS can call
Code    section  id=10  fn bodies as bytecode
```

## Scope today

int-to-int functions with arithmetic, locals, calls and return. Strings, memory
ops and import tables land next, as the JS shell expands.
