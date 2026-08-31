# math

Vector arithmetic on the ORI `V3`.

```orion
add(a, b)   sub(a, b)   scale(a, by)
dot(a, b)   cross(a, b) norm(a)
rot_y(p, angle)   rot_x(p, angle)
```

These lived inside `raster` as private helpers, and `add` and `scale` were
written out by hand at every call site. A second renderer would have copied all
eight - which is the duplicate the one-of-each rule exists to prevent, so they
came out.

`V3` comes from `ori`, the seam vocabulary, rather than living here. That was
an awkward dependency while `ori` was three orbs and this one had to name the
3D seam just to borrow a vector; with one `ori` it is simply the shared
vocabulary.
