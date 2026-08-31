# log

Leveled, categorized logging. One system, one way in.

```orion
use log
const ecs = channel("ecs")            # a report: leveled, can be hushed
const out = always("out")             # an answer: ORION_LOG never reaches it

error(ecs, "no tray slot {i}")        # always visible, red
warn(ecs,  "kept old bundle")         # yellow
info(ecs,  "scripts reloaded")        # cyan, the default ceiling
debug(ecs, () -> text: "packed {n}")  # hidden until raised
```

## A channel is a declared value, not a string

`debug(esc, ...)` against a channel spelled `ecs` is an unknown identifier at
compile time. A free string was a line that silently never appeared again.

And the channel carries its own POLICY. The only thing that really separates a
program's answer from a subsystem's report is one question - may it be
hushed? - so that question lives on the channel and everything else is one
system. `ORION_LOG=error` cannot accidentally kill a tool's output or an
editor's type stream, because those channels are declared `always`.

## Levels

error 0, warn 1, info 2, debug 3. A line shows when its level is at most the
channel's ceiling; the default is info.

`ORION_LOG` sets ceilings without a code change, read once on the first line:
`debug` raises everything, `ecs=3` raises one channel, and the two mix
(`debug,net=1`). An explicit `log_set_level` always wins - it writes
unconditionally, and the environment only fills what nobody set.

## Why debug takes a maker

Orion evaluates arguments before the call, so an eager `debug` builds its text
even when the line is dropped. Measured: 300 000 suppressed calls cost 74 ms
eagerly and 12 ms lazily. The closure is not free, but it is six times less -
and a second spelling where one is always worse is what the one-spelling rule
forbids, so there is no eager form.

The other three levels stay eager. They show nearly always, and a closure for a
line that will be written is pure cost.

## Logging may not cost the disk

The level calls declare `uses console` and nothing else, so a system that
declares its capabilities - simulation code, where it matters most - can log
without asking for the filesystem. Lines accumulate in memory, and the PROGRAM
layer, which already holds `uses files`, writes them out with `log_drain_to`.

## Every line carries its place

Nobody writes it. The `at` parameter defaults to `caller()`, which the compiler
replaces with the file and line of THE CALL - not of the signature, which is
what `here()` would have given and why it is a different word. It lowers to a
string constant, so the place is free at run time.

A channel says which subsystem; the place says which of its forty lines. On the
console it is dimmed so it does not fight the message; in the kept line it is
plain, because that one is read afterwards and searched.

## Watch out for

The buffer holds 128 lines. Drain more often than that. If you do not, the
drain says how many it lost rather than quietly writing a hole.

A library orb may not call `print_line` at all - `tools/orb_console_test.sh`
enforces it. That is what makes this orb the only way a library can speak,
rather than the one it ought to choose.
