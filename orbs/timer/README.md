# timer

Deterministic tick-based timers - the systems-level counterpart to astra's
`every`.

You feed `dt_ms` per frame and the timer advances. No wall clock, no sleep, no
RNG, so the same inputs replay to the same outputs. That is what makes it safe
inside the deterministic engine core, unlike the `scheduler` orb, which is
real-time and blocking.

Two shapes:

- **countdown** - `timer_start` then `timer_tick`, completes once (`timer_done`)
- **cadence** - `timer_every` fires N times per period, forever

State lives in global slots under `"timer:{id}:..."`, so a timer is just a
name. Nothing is threaded through your own types.
