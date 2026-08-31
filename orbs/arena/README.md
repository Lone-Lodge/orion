# arena

The cycle region, and the way out of it.

Names first, because they overlap. A REGION is the runtime's bump-buffer
mechanism; there are three - arena, frame, pools - and they all size themselves
the same way. The ARENA is the innermost one, the one a cycle resets. This orb
is the arena and the escape hatch beside it, not regions in general.

Orion has no garbage collector. The default is plain malloc that never gives
anything back, and that is right for a tool that runs and exits: nobody is left
to care. A LOOP that grinds through a lot of data is the other case. It has to
say where a cycle ENDS, and then the runtime hands back everything that cycle
allocated.

```orion
arena_on()
loop:
    # everything the cycle allocates lands in the arena
    mine = persisted(must_live)      # out of the arena, into malloc
    arena_reset()                    # the rest is garbage by definition
```

Measured on a reader grinding 256 MB in blocks: 1615 MB peak without the reset,
13 MB with.

## Watch out for

`persisted` is the point of this orb. Without it there is no way across the
line: a value born in the arena POINTS into it, and after a reset the next
cycle writes over it with nothing to say so.

The externs live in `runtime/orion_rt.c`. `app`, `typeface` and `orion_ir` each
declare their own copy of them today; this orb is where they belong.
