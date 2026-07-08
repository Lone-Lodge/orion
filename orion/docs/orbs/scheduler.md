# orb `scheduler`

scheduler — cooperative task abstraction on top of the async orb.

This is the user-space layer. A `Task` is a deadline + a fn_id the
dispatcher knows how to invoke. The run loop sleeps until the
earliest deadline, fires all due tasks, repeats until empty.

Real preemptive scheduling with non-blocking I/O needs:
  - libco (or Windows fibers) for stack switching
  - IOCP (Windows) / epoll (Linux) for fd readiness
  - a worker pool for parallel execution
All future work. What this orb gives you today is a clean
event-loop pattern that composes with the existing setjmp/longjmp
continuations + the async timer queue.

## Public functions

### `pub fn task_new(fire_in_ms: int, fn_id: int, payload: int) -> Task`


### `pub fn task_deadline(t: Task) -> int`


### `pub fn task_fn_id(t: Task) -> int`


### `pub fn task_payload(t: Task) -> int`


### `pub fn task_due(t: Task) -> int`

Is this task ready to run (deadline ≤ now)?

### `pub fn await_task(t: Task)`

Sleep until task fires. Returns immediately if already due.

### `pub fn await_next(tasks: [Task])`

Sleep until the earliest deadline in a list. Caller dispatches the
fired task(s) by inspecting `task_due` on each entry.

