# typeface

Real font rendering from TrueType (.ttf) files, for the declared-game engine.

The parser - sfnt tables, cmap, glyf outlines, scanline fill - is the proven
atlas_text code. What this orb adds is the LABEL SPRITE: a whole line of text
rasterized into one keyed `Texture`, wrapped in a field-space `Sprite`. The
renderer's bilinear minification then scales it smoothly to any window size,
along the same path every other sprite takes.

A .ttf is big-endian binary. Fonts arrive as EMBEDDED blobs - the engine's
`assets/fonts`, mirrored into a project's `build/fonts` by `game_astra.sh` - so
a game binary carries its letters the way it carries its art.
