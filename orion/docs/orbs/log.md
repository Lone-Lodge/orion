# orb `log`

log — leveled, categorized console logging. Pure Orion, language-
level orb: usable by astra, atlas, games and tools alike. The only
runtime hooks are orion_console_color (tty probe, fallback arm in
the interp) and orion_persist_text (identity in the interp).

  error("cubsy", "no tray slot {i}")     always visible, red
  warn("reload", "kept old bundle")      yellow
  info("project", "scripts reloaded")    default ceiling
  debug("ecs", "packed {n} entities")    hidden until raised

Levels: error 0, warn 1, info 2, debug 3. A category shows a line
when line-level <= category ceiling; default ceiling is info(2).
Ceilings live in slots and can be flipped at RUNTIME — per category
or globally — by the game, the dev console, or an agent:

  log_set_default(3)            # everything, everywhere
  log_set_level("ecs", 3)       # just one subsystem

Styling rides the same tty-gated ANSI as the rest of the engine —
redirected output stays plain. Message interpolation happens at the
call site and lands in the frame region: a suppressed line costs
one transient text + a slot probe, never permanent heap.

FLIGHT RECORDER: log_ring_on() keeps the last 128 lines (plain
text) so log_dump() can replay the recent past — wire it to a dev
key and the exit path next to the mem ledger. Ring copies persist
(~100B a line, dev-only, visible in the session ledger like every
other byte).

## Public functions

### `pub fn log_set_default(level: int)`

---- Ceilings ----

### `pub fn log_set_level(cat: Text, level: int)`


### `pub fn error(cat: Text, msg: Text)`

---- Emit ----

### `pub fn warn(cat: Text, msg: Text)`


### `pub fn info(cat: Text, msg: Text)`


### `pub fn debug(cat: Text, msg: Text)`


### `pub fn log_ring_on()`

---- Flight recorder ----

### `pub fn log_dump()`


