# glyphs

THE 5x7 bitmap font, in one place. `overlay` draws it into pixel frames and
`raster` turns it into field-space triangles; both read the same rows, which is
the one-of-each law doing its job - two copies of a font drift, and the drift
shows up as text that looks subtly different depending on which renderer drew
it.

```orion
glyph_rows(code)    # seven numbers, top row first
```

One glyph is seven 5-bit rows, top down, bit 16 being the leftmost column.
Uppercase letters, digits, and the few marks a HUD line uses. Lowercase maps
onto uppercase.

## Watch out for

An unknown character comes back as a solid block, not as nothing. A missing
glyph is meant to be SEEN - a silently skipped one turns into a spacing bug
somebody chases for an hour.
