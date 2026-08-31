# ori

The Orion Rendering Interface.

One orb, three seams: the 2D primitives every box is measured in, the display
list every 2D backend consumes, and the scene frame a 3D renderer turns into
pixels.

A seam is a data type both sides speak. Nothing here draws anything. Every type
in this file is a contract, and contracts are not swapped - what sits behind
them is.

## Why one orb and not three

They were three, which cost three manifests and a dependency between them for a
vocabulary of 211 lines - and made `math` depend on the 3D SEAM just to name a
`V3`.

On the NATIVE path the split bought nothing: the emitter prunes to what is
reached, so an orb costs what you use of it, not what it contains.

On the WASM path it is not free, and the number is measured. Veil's gallery
went from 8924 to 9078 bundled lines and from 245 to 276 kB, because
`bundle_app.sh` follows `use` lines rather than reachability. Veil now carries
the 3D seam it never touches, about 12% of that module.

That cost is the bundler's, not the seam's, and it is worth paying for one
vocabulary in one place. Teaching the bundler to prune the way the native
emitter already does would take it back for everyone.
