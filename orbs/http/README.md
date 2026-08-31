# http

Fetch and post over HTTP(S).

```orion
r = fetch("https://example.com")
r.status    # 200
r.body      # text
```

The INTERFACE is the commitment: request in, `reply{status, body}` out. The
engine behind it is curl as a child process - present on Windows 10+, macOS and
virtually every Linux - which buys TLS, redirects and proxies for free. A
native client (the `net` orb plus a TLS layer) can replace the engine later
without a caller changing a line.

## Watch out for

It is `reply`, not `response`, and that is not a style choice: `app` has a
`response` of its own with a `mime` field, and a type name is ONE layout for
the whole build. A program that used both orbs did not compile, and the error
was about a field.

Each call blocks by design. Run it inside a task (see `async`) and the
scheduler keeps everything else moving while curl works.
