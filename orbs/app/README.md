# app

The thin shell a local desktop-web app stands on: serve a folder and some
routes on loopback, open the OS's app window at it, live until Ctrl+C.

```orion
routes = [route{method: "GET", path: "/api/list", handler: list_files}]
srv = serve("ui", routes, 0)
w = open_window("http://127.0.0.1:{local_port(srv)}/")
run_until_interrupted(srv, routes, "ui")
```

A route is a record with a function in it - the BLOCKS.md model. The app hands
its behavior over as data, with the wiring visible at the call site.

One task per connection, the httpd pattern. Static files stream in binary
through `send_raw`, so images and fonts survive.

HTTP/1.0, close per request: boring, debuggable, and plenty for loopback.

## Watch out for

`app` has a `response` type with a `mime` field, and a type name is ONE layout
for the whole build. That is why `http` calls its own type `reply` - a program
that used both did not compile, and the error was about a field.
