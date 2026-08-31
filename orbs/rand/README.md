# rand

A small pseudo-random generator. NOT cryptographic.

```orion
rand()             # a non-negative int
rand_range(1, 7)   # 1..6, hi exclusive
rand_float()       # 0.0 .. 1.0
srand(seed)        # fix the sequence
```

Deterministic by default: with no `srand` the stream is fixed, so tests stay
reproducible without anyone having to remember to seed. For a run that varies,
seed once at startup - `srand(monotonic_ms())`. State lives in a global slot,
the same model as C's `srand`/`rand`, so there is nothing to thread through
your own code.

The generator is a 64-bit LCG using Knuth's MMIX constants; the multiply wraps
in i64.

## Watch out for

Good enough for games, sampling and shuffles. Do not use it for secrets.
