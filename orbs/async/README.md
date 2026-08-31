# async

Tasks: real suspension, one stack each.

Every task gets its own stack - Windows fibers, ucontext elsewhere - so
`yield_now()` suspends and the scheduler resumes exactly where it stopped.
Cooperative and single-threaded on purpose: `loop parallel:` is the parallel
primitive, this is the concurrency one.

```orion
t1 = spawn(worker, 10)        # a closure and one int argument
t2 = spawn(worker, 20)
a = await(t1)                 # drives the scheduler until t1 finishes
b = await(t2)

define worker(n: number) -> number:
    edit total = 0
    loop i in 0 until n:
        total += i
        yield_now()           # another task gets a turn here
    total
```

## Watch out for

A task is awaited ONCE. Awaiting it again answers 0, because its stack is gone.

Where the platform has no stack switching, `spawn` runs the closure right away
and `yield_now()` does nothing. A non-yielding task still gives the same
answer, so a program written against this orb is portable even where the
suspension is not.

## Status

No consumer in the workspace. It works and it is tested, but nothing has needed
it yet - so it is unproven against a real caller's shape.
