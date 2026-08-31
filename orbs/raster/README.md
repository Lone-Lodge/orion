# raster

The first render block behind the ORI 3D seam (`ori_scene`). Pure software:
world-space triangles in, flat-shaded pixels out, plus BMP and PNG encoders so
a frame can become a file anywhere. That is the whole `orbit shot` story.

No window, no GPU. A block that draws is a block that can be replaced by one
that draws faster.

## The pipeline

View transform (translate, yaw, pitch) -> cheap near-plane cull -> perspective
projection -> z-buffered edge-function fill with one fixed light. Every step is
the simplest version that makes a correct, legible picture.

## Watch out for

`bmp_of(pixels, w, h)` builds a whole image in ONE call, and that is
deliberate. The header and the body used to be two public lists that a caller
joined, and the picture died at that boundary: the bytes were written whole
inside and read real at the caller's `text_of`, so every byte came back a
denormal and the image was black at exactly the right file size.

The same bug is still open one level down. `test_sprites_sample_and_respect_
depth` fails because a texel read out of `Texture.pixels` arrives as an
integer's bit pattern read as a double - 111 becomes 5.5e-322 - and nothing in
this orb can repair it, because the value is wrong before raster sees it. See
F12 in `arkitektur/ISSUES.md`; the fix is in the compiler. The failure is
declared in `tools/orb_test.sh` under `KNOWN_RED`.
