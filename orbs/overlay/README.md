# overlay

The 2D compositor: an `ori_display` DisplayList drawn OVER a rendered pixel
frame. This is how a UI block's output - veil's, or anyone's - lands on a game
frame without either knowing the other. The DisplayList is the whole contract.

The list arrives in the producer's own units and `scale` maps them to this
frame's pixels: a field-space UI passes its px-per-unit, a pixel-space HUD
passes 1.0.

Text goes through typeface's blitter, so overlay text is the same crisp AA
glyphs as the rest of the frame. Rounded rects round for real.

Icon, path, sprite and image commands arrive when something needs them, not
before.
