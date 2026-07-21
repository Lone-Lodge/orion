# orb `async`

async — cooperative async helpers built on the new timing primitives.

This orb is the user-space layer above the runtime builtins:
  - time_now_ms()     — wall clock (non-deterministic)
  - monotonic_ms()    — monotonic since process start
  - sleep_ms(n)       — blocking yield to OS

A real preemptive scheduler with non-blocking I/O is future work
(libco + IOCP/epoll bindings). What this orb gives you today is the
cooperative subset: deadline tracking, periodic ticks, and a
`sleep_until` helper that's deadline-stable across loop iterations.

## Public functions

### `pub fn sleep_until(deadline_ms: int)`

A real preemptive scheduler with non-blocking I/O is future work
(libco + IOCP/epoll bindings). What this orb gives you today is the
cooperative subset: deadline tracking, periodic ticks, and a
`sleep_until` helper that's deadline-stable across loop iterations.
Sleep until the monotonic clock reaches `deadline_ms`. If we're already
past it, returns immediately. Otherwise sleeps the remaining time.

### `pub fn delay(duration_ms: int)`

Sleep for at least `duration_ms`. Wrapper that documents intent —
`sleep_ms` directly works too, but `delay` reads better in async code.

### `pub fn deadline_from_now(offset_ms: int) -> int`

Return the monotonic clock value `offset_ms` from now. Useful for
building deadlines: `deadline = deadline_from_now(100)` then later
`sleep_until(deadline)`.

### `pub fn past_deadline(deadline_ms: int) -> int`

Did `deadline_ms` already pass? Plain comparison helper for readability
in event loops.

### `pub fn time_left(deadline_ms: int) -> int`

Number of ms remaining until `deadline_ms`, clamped to 0 if past.

### `pub fn timers_new() -> [int]`

Returns a list of timer-deadlines. Use add_timer / pop_due / next_due.
Build an empty timer queue.

### `pub fn add_timer(timers: [int], offset_ms: int) -> [int]`

Push a timer that fires `offset_ms` from now. Returns the new queue.

### `pub fn next_due(timers: [int]) -> int`

Earliest deadline in the queue, or -1 if empty.

### `pub fn count_due(timers: [int]) -> int`

How many timers have already fired (deadline <= now)?

### `pub fn wait_next(timers: [int])`

Sleep until the next deadline fires. Returns immediately if past or
the queue is empty. Caller is expected to dispatch after this returns.

