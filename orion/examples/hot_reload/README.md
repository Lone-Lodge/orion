# Hot reload in Orion

Recompile gameplay code and swap it into a **running** program — no restart,
state preserved. This is the "less editor, more live" loop: an edit becomes
visible in the running world immediately, the way a player's change would.

```
bash examples/hot_reload/run.sh
```

Output:

```
v1  state = 1
v1  state = 2
v1  state = 3
v2  state = 13   (behavior changed, state kept)
v2  state = 23
v2  state = 33
```

`state` climbs by 1 (v1: `tick = state + 1`), then — after a hot swap to v2
(`tick = state + 10`) — keeps climbing from where it was. The **code** changed
under the program's feet; the **state** carried straight through.

## How it works

- **Code as shared libraries.** Each `tick` is compiled to a `.so`
  (`orion.exe plugin.or → .ll → clang -shared`). An Orion function is an
  ordinary external symbol, so it exports cleanly.
- **Load + call at runtime.** The host (`reload.or`, itself Orion) declares
  `extern fn dlopen` / `dlsym`, loads the library, and calls the returned
  function pointer with `call_ptr(fnptr, arg)` — the primitive for calling a
  raw pointer (a normal `f(x)` assumes `f` is a closure).
- **State lives outside the code.** `state` is a plain value in the host, so
  swapping the `.so` never touches it. In the real engine the game world (the
  atlas reactive net / ECS) is that persistent state, and only the systems'
  code reloads.

## Why this fits Orion

Orion is **self-hosting** and **data-oriented** — code and state are already
separate, and the whole compile path is fast. That is exactly what hot reload
wants. The only language piece it needed was `call_ptr`; the rest is the
ordinary compile-to-native path pointed at a `.so`.

Files: `reload.or` (the host loop), `plugin_v1.or` / `plugin_v2.or` (the
gameplay code, "edited" between builds), `run.sh` (compiles both + runs).

## Auto watch-and-reload

`run.sh` does one scripted swap. `run_watch.sh` does the real live loop:

```
bash examples/hot_reload/run_watch.sh
```

It launches `watch.or` (a ~25-line Orion program) and edits `plugin.or` while
it runs. The watcher notices the source changed, **invokes the compiler at
runtime** to rebuild the `.so`, and hot-swaps it — state carries straight
through:

```
tick -> state = 5
  * source changed -> recompiled + hot-swapped (gen 1)
tick -> state = 15
tick -> state = 55
```

`watch.or` uses `run_command` (from the `os` orb) to call the compiler,
`read_file` to detect the edit by content, `sleep_ms` to pace the loop, and
`dlopen`/`dlsym` + `call_ptr` to load and call the fresh code. The whole
live-coding loop is Orion driving Orion.
