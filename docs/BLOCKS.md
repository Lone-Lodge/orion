# Blocks - how Orion software composes

Five primitives, no framework. The same model for an app, the game engine,
a tool. (The frontier calls this direction "component model"; we get it from
things the language already has.)

1. **The unit is the orb.** Local (`path:`) or remote (`git:` + Orbit.lock).
   Foundational orbs live in the orion repo; an app's own blocks live with
   the app, or in their own repos when shared.
2. **A plugin is a record of functions.** Traits are dictionaries here - a
   block hands its behavior over as a struct value, wiring visible at the
   call site. No registry, no resolution, no build(&mut App).
3. **A seam is a data type both sides speak.** `Effect` in / `DisplayList`
   out (engine), `request`/`response` (app), `DisplayList -> pixels`
   (render). A seam is just a type in an orb. Two blocks that can only
   cooperate through a shared mutable registry are wrongly designed.
4. **Capabilities say what a block may touch.** The `uses` clause is the
   contract: a block declaring `uses files` cannot quietly grow a network
   habit.
5. **orbit composes.** Orbit.toml names the blocks (and vendored C through
   the `link =` seam); the lock pins them.

Rules that keep layers thin:

- **The extraction rule**: shell code is written in the app first, and moves
  into a shared orb only when it is provably not app-specific.
- **The two-consumer rule**: nothing enters a shared orb without two real
  users. One user = it is app code.
- **The gate rule**: a shared orb gets a proof that is not its first
  consumer, so reuse is demonstrated, never claimed.

First proof outside the engine: the `app` orb (serve + routes + window +
run-until-interrupted) with Folio on top. The engine's endpoint is the same
model: atlas = baseplate orb + block orbs + a thin `game` shell orb, and
existing blocks migrate seam by seam as they are touched - never big-bang.
