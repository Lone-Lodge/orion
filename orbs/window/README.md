# window

The app-first window block: a Win32 window plus the runtime's software
framebuffer. Open, show a pixel frame, read input, pace, resize, close.

The project's `Orbit.toml` links the two C halves:

```
link = "../orion/runtime/win32_min.c ../orion/runtime/gdi_min.c -luser32 -lgdi32"
```

This is the GAME window path - it owns its framebuffer. Orion's `app` orb owns
the other one: OS webview windows for web-UI apps (folio).

## Status

It lives here under the extraction rule: it moves toward a shared orb when a
second consumer exists.
