# ORI — the Orion Render Interface

Status: **design spec** (next-gen north-star). No code migrates until the
shape below is agreed. Sibling to `NEXTGEN.md`, `HULL.md`, `PRINCIPLES.md`.

## Why ORI exists

Today the render path is real but **nameless and scattered** across four
places: `veil_display` owns the DrawCmd list, `atlas_render` bridges it to a
backend, an `atlas` `gpu` orb wraps device init, a `window` orb owns the
platform surface, and `orion/runtime/{d3d12,gdi,ogpu,win32}_min.c` are the
metal. It renders — but no single surface answers "draw this frame on this
machine", there is **no 3D**, it is **Windows-only**, and settings (vsync,
fullscreen, backend) are sprinkled through tomls and window calls.

ORI is **one named interface** — the same language-level status as the `log`
and `audio` orbs — that a game or app renders *against*, on any platform, in
2D or 3D. It is not a consolidation of the old shapes; it is designed from the
stack's own laws.

## The one idea: **render is a pure function of state, over data, on a seam**

```
        state ──(pure)──▶  FRAME (data)  ──(ORI backend)──▶  pixels
                            DisplayList (2D)                  d3d12 / gdi /
                            Scene       (3D)                  gl / vk / metal / e-ink
```

A frame is **declared data**, never a sequence of imperative draw calls. That
single choice is the moat and follows every existing law:

- **Deterministic** (`tick-model-doctrine`) — same state ⇒ same frame ⇒
  screenshot-diff is a valid test, tick-log replay re-renders exactly.
- **Provenance** (`veil-ui-vision`) — every cmd carries its source
  (`file:line`/rule); click a pixel → the line that drew it.
- **Small** (`potato-principle`) — the renderer stays dumb (~4 core cmds), the
  *resolver* is smart. A backend is ~100 LOC.
- **No idle spin** — ORI presents on a real event/tick, sleeps otherwise.

## Two seams (the load-bearing law)

Games and UI touch **only the content seam**. They never see a backend.

| Seam | Owns | Who writes it |
| --- | --- | --- |
| **Content** | *what* to draw — `DisplayList` (2D) + `Scene` (3D), both provenance-tagged, both pure data | veil / atlas / any app |
| **Backend** | *how* — rasterize/render the data + present it on a platform surface | ORI backends only |

`atlas_render` becomes a *consumer* of ORI (it hands ORI a DisplayList). veil
stays the 2D content author. Neither knows whether d3d12, GL, or an e-ink
framebuffer is underneath.

## Layer 1 — 2D content (formalize what exists)

The 2D content model is `veil_display`'s `DrawCmd`, promoted to ORI's content
contract. Keep it tiny — **the renderer never grows; the resolver does**:

```
enum DrawCmd:                       # every cmd ends with a `src` provenance int
    DrawRect(Rect, color, src)
    DrawRoundRect(Rect, color, radius, src)
    DrawText(Point, text, color, size, src)
    DrawImage(Point, asset, w, h, tint, blend)   # 9-slice = 9 of these (resolver)
    Clip(Rect)                                    # the only state cmd
```

`Icon`/`Sprite`/`Path` today collapse into `DrawImage` + resolver expansion
(border = 4 rects, glow = an image, 9-slice = 9 images). Four real cmds; a
backend rasterizes four things. This is already true — ORI just names it the
contract and makes `src` mandatory (provenance is not optional).

## Layer 2 — 3D content (new, same shape)

3D is **data too** — no imperative `glDraw`. A `Scene` is declared each frame
(immediate-mode declaration + retained-within-frame, exactly like the 2D tree):

```
data Scene:  camera: Camera, lights: [Light], nodes: [Draw3D]
enum Draw3D:
    DrawMesh(mesh_id, transform, material_id, src)
    DrawInstances(mesh_id, [transform], material_id, src)   # one call, N copies
data Camera:   view: Mat4, proj: Mat4                        # perspective|ortho
data Material: shader_id, params: Map, blend, cull, depth
```

Meshes/materials/shaders are **registered once** (device-side, id-keyed —
same pattern as the AA-glyph texture cache already in the runtime) and
*referenced* by id in the per-frame Scene. So the frame stays small and
diffable even at MMO scale; the heavy GPU resources live behind the seam.

3D UI overlays are just a `DisplayList` composited over the `Scene`'s color
target (a game's character screen = 3D model under a 2D Veil overlay —
`veil-ui-vision`'s AAA benchmark, unchanged).

## Layer 3 — the backend interface (unify the scattered surface)

One orb surface. This is what `render_backend`/`render_caps`/`gpu_init`/
`window_*` become — a single vocabulary, caps-negotiated:

```
# lifecycle
ori_open(settings: OriSettings) -> Surface     # window + device + swapchain
ori_caps(Surface) -> Caps                       # what this backend can do
ori_resize(Surface, w, h)
ori_close(Surface)

# per frame (present on a real event/tick, never in an idle loop)
ori_begin(Surface) -> Frame
ori_raster(Frame, DisplayList)                  # 2D content
ori_render(Frame, Scene)                        # 3D content
ori_present(Frame)                              # flip / tear per settings

# resources (id-keyed, registered once)
ori_mesh(Surface, verts, indices) -> int
ori_material(Surface, shader, params) -> int
ori_texture(Surface, image) -> int
```

`Caps` makes degradation **data, not branches in the app**: a backend that
can't do 3D reports `dim: 2`, an e-ink target reports `colors: 1` (1-bit) and
`present: on_change`, d3d12 reports the full set. The app renders the same
content; ORI resolves it to what the panel can show.

## Layer 4 — platforms (the seam already exists)

`ogpu_min.c` is already a dispatcher over `sw_og_*` (gdi) and `dx_og_*`
(d3d12), selected by `renderer = auto|gdi|gpu`. ORI formalizes that seam so a
new backend is a *table of function pointers*, nothing in content changes:

| Backend | Target | State |
| --- | --- | --- |
| `d3d12` | Windows GPU | exists (`d3d12_min.c`) |
| `gdi` | Windows software / headless `shot` | exists (`gdi_min.c`) |
| `gl` | Linux/macOS GPU | **new** — de-risks the OrionOS/e-reader track |
| `vulkan` | Linux/Android/Steam Deck | **new** |
| `metal` | macOS/iOS | **new** |
| `eink` | 1-bit e-paper (PineNote) | **new** — `Caps{colors:1, present:on_change}` |

Platform = **host-chosen data** (`build-system` doctrine): the same content
bundle renders on whatever backend the host picks. `shot` (headless one-frame
→ BMP, no window) stays the agent's eyes on every backend.

## Settings — one surface, all data

`OriSettings` replaces scattered toml keys + window calls:

```
data OriSettings:
    backend: auto|gdi|gpu|gl|vk|metal|eink
    present: vsync|tear|on_change        # on_change = e-ink / event-driven idle
    fullscreen: bool,  frameless: bool,  dpi_aware: bool
    hdr: bool,  srgb: bool,  msaa: int
    width: int, height: int, title: text
```

Read from the project toml as one `[render]` table; nothing imperative.

## The moat — why this beats mainstream engines

Because the frame is replayable data with provenance, ORI gets for free what
Unity/Unreal can't:

1. **Screenshot-diff CI** — render state N, assert pixels. Deterministic.
2. **Click-to-source** — pixel → `DrawCmd.src` → the exact line/rule.
3. **Tick-log render replay** — "this pixel changed because rule X fired at
   tick N" re-renders the frame from the log.
4. **Same content, any backend** — author once, ships to GPU / software /
   e-ink / (later) web canvas, caps-negotiated.

No mainstream engine has render-as-replayable-provenanced-data. That is ORI.

## Potato budgets (hard limits, `PRINCIPLES.md`)

- Core `DrawCmd` ≤ 5 variants; a 2D backend rasterizer ≤ ~150 LOC.
- 3D core ≤ `{DrawMesh, DrawInstances}` + camera/material; built-in shaders
  (unlit, lit, glyph) ship, custom shaders are one `ori_material` away.
- Per-frame data is **references** (ids), never resources — the frame stays
  small enough to diff and log at MMO scale.
- Idle = present nothing, sleep. `on_change` present mode is the e-ink default.

## Migration path (no big bang)

1. **Name the seam** — introduce the `ori` orb wrapping today's
   `render_backend`/`render_caps`/`gpu`/`window`. Content unchanged. (pure rename)
2. **2D contract** — make `src` provenance mandatory on every `DrawCmd`;
   `atlas_render` calls `ori_raster` instead of its ad-hoc bridge.
3. **Settings** — collapse toml render keys + window calls into `OriSettings`.
4. **GL backend** — second backend behind the seam; proves platform-neutrality
   and unblocks the Linux/e-reader track (`orion-os-vision`).
5. **3D content** — add `Scene`/`ori_render`; first slice = one lit mesh under
   a Veil overlay (the AAA-benchmark screen).
6. **eink / vulkan / metal** — as targets demand; each is a backend table.

## Non-goals / next-gen stances

- **No retained scene graph** the app mutates (kills diff + hot reload). The
  frame is re-declared; retained GPU resources live *behind* the seam by id.
- **No imperative draw API** exposed to games — content is always data.
- **No per-backend `#if` in app code** — differences are `Caps`, resolved once.
- ORI never owns game logic, audio, or input — it takes a frame and a surface,
  returns pixels. Purity is what lets it embed anywhere.

Related: `NEXTGEN.md`, `HULL.md`, `PRINCIPLES.md`, and the memories
`veil-ui-vision`, `tick-model-doctrine`, `potato-principle`, `orion-os-vision`.
