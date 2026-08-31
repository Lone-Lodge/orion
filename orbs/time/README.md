# time

Clock time for humans: unix seconds, and dates a person can read. The runtime
already has `monotonic_ms` / `sleep_ms` for MEASURING - this orb is for TELLING
the time, which is a different job with different failure modes.

```orion
now_unix()                          # seconds since the epoch
timestamp()                         # "2026-08-31 14:03:11", local
local_time(s, "%A")                 # the weekday
utc_time(s, "%Y-%m-%dT%H:%M:%SZ")
parse_utc("2026-08-31T14:03:11Z")   # back to seconds
```

Formatting rides the C library's `strftime`, so the usual codes work.

## Watch out for

Timezones are exactly what the host's `localtime` gives. Named zones and
offsets beyond "here" and "UTC" are a later, bigger job, and this orb does not
pretend otherwise.
