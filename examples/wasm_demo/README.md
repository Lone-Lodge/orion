# Orion → WebAssembly demo

`demo.or` is a small Orion program compiled to WebAssembly and run in the
browser. `render(t)` computes eight orbiting circles (f64 math, `host_sin`/
`host_cos`, void extern draw calls); `main.js` owns the canvas and the clock.

## Run

Recompile the wasm (after changing `demo.or`):

```bash
orion examples/wasm_demo/demo.or examples/wasm_demo/demo.wasm orbs
```

Serve and open it:

```bash
node examples/wasm_demo/server.js
```

Then open <http://localhost:8099>. The static server serves `.wasm` with the
`application/wasm` MIME type so `WebAssembly.instantiateStreaming` works.

This is the pattern for atlas web games: Orion source compiled ahead of time to
wasm, the browser instantiating it, JavaScript providing graphics and input.
