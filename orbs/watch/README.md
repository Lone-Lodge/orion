# watch

The mechanics of a file watcher: scan a tree, fingerprint it, name what
changed.

```orion
before = snapshot("src")
# ... time passes ...
changed = first_change(before, snapshot("src"))   # "" when nothing moved
```

Pure bookkeeping, and that is the point of the split: everything here is a
function of its arguments, so it is testable. The loop that ACTS on a change -
rerun a command, stop a stale run - lives in `tools/orbwatch.or`, where it can
be messy about time and processes without dragging that into a test.
