# file

Streaming file IO. Whole-file `read_file` / `write_file` are builtins and are
fine until the data is bigger than memory, or until you want to write a line at
a time. These are the missing primitives: open a handle, move bytes a chunk at
a time, close it.

```orion
h = open_read("big.log")
loop:
    chunk = read_chunk(h, 4096)
    if is_end(chunk):
        break
    process(chunk)
close(h)
```

A read at end-of-stream returns `""` - the same convention `net.recv` uses, so
files and sockets are read the same way.

## Watch out for

Prefer `with_read` / `with_write`. They own the handle and close it on every
exit path, including an early return from your body. A hand-written
`open` / `close` pair leaks the handle the first time somebody adds a `return`
in the middle.
