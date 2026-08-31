# text

Common text helpers, callable with method-call syntax. Once you `use text`:

```orion
msg.is_empty()
msg.starts_with("hello")
msg.ends_with("!")
msg.byte_count()
split("a,b,c", ",")   # ["a", "b", "c"]
join(parts, ", ")     # "a, b, c"
```

The dot form is not a method system: `msg.starts_with("x")` is MethodCall
desugar and lowers to `starts_with(msg, "x")`. Both spellings work and mean the
same thing, so nothing here needs a receiver or a vtable.

This is the most-used orb in the workspace by a wide margin, which is worth
knowing before changing a name in it.
