# net

Blocking TCP, client and server. The capability contracts are the point:
`uses net` in a signature means you can READ what a function may reach without
opening its body.

```orion
c = connect("127.0.0.1", 8080)
send(c, "GET / HTTP/1.0\r\n\r\n")
reply = recv(c, 4096)
close(c)

s = listen(8080)          # listening socket
client = accept(s)        # blocks until someone connects
msg = recv(client, 4096)  # "" at end of stream
```

Handles are plain numbers: a socket is >= 0 and every failure is -1. Backed by
the `tcp_*` primitives in `runtime/orion_rt.c` - Winsock on Windows, BSD
sockets elsewhere. `WSAStartup` is lazy, so a program that opens no socket
never touches Winsock.

Blocking only. `loop parallel` and `spawn` give you concurrency where you need
it.

## Watch out for

Today a socket is closed by `close`. Pair it with `defer close(c)` so an early
return cannot leak it. The planned model makes the resource scope-owned - a
handler owns the socket, closing happens on scope exit - see "Resurser och
samtidighet" in `docs/SYNTAX-INVENTORY.md`.
