# blender_bridge

Claude driving Blender, with the link written in Orion.

```
du / Claude ──▶ blender_bridge_cli (Orion) ──▶ TCP 127.0.0.1:4777 ──▶ orion_bridge.py i Blender ──▶ bpy
Blender-panelen "Orion" ──▶ claude-CLI (headless) ──▶ samma brygga tillbaka in
```

Three pieces:

- `src/main.or` - the CLI. Takes Python on the command line (or stdin), sends
  it to Blender, prints what came back. Exit 0/1 mirrors ok/fail.
- `orion_bridge.py` - the Blender add-on. Socket server on 127.0.0.1:4777,
  runs received code on the main thread, and owns the "Orion" sidebar panel:
  Claude chat, quick actions, activity log.
- `.claude/settings.json` - permission allowlist for the headless claude
  sessions the panel starts, so they may run the bridge CLI without prompts.

## Setup on a new machine

1. **Blender 4.2+.** Edit > Preferences > Add-ons > Install, pick
   `orion_bridge.py`, enable "Orion Bridge". The server now starts with
   Blender (check: the panel header shows a linked icon).
2. **claude CLI** (only needed for the in-panel chat):
   `npm install -g @anthropic-ai/claude-code`, then run `claude` once in a
   terminal and log in. A subscription login means panel messages draw from
   that subscription; an `ANTHROPIC_API_KEY` in the environment means
   per-token billing instead.
3. **Point CHAT_DIR at this directory.** The constant at the top of
   `orion_bridge.py` is where the panel's claude sessions run: the
   conversation history, the permission allowlist, and the bridge CLI all
   live there. Edit it before installing (it is a personal path).
4. **Build the CLI** (only needed when an agent should drive Blender from a
   terminal): `orbit run src/main.or main "print('hej')"` in this directory
   compiles and runs `build/blender_bridge_cli.exe` in one go.

## Using it

```
build\blender_bridge_cli.exe "bpy.ops.mesh.primitive_cube_add(size=2)"
type snippet.py | build\blender_bridge_cli.exe
```

Everything the bridge runs lands in the panel log - timestamp, ok/fail, the
code line, first output lines. Chat replies show up to 12 lines; the copy
button takes the whole latest output.

## Protocol

One line-delimited JSON request per connection on 127.0.0.1:4777:
`{"code": "..."}` in, `{"ok": 0|1, "output": "...", "error": "..."}` out.
Anything that speaks that - an MCP server, a test harness, another editor -
can drive Blender the same way.

## Headless / tests

- `blender --background --python orion_bridge.py` - server without a GUI
  (code runs directly, no timers).
- `python orion_bridge.py` - no bpy at all; plain exec. Lets you test the
  protocol without Blender.
