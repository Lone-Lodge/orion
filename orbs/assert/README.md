# assert

One assertion for Orion, and only one. `assert(a is b, ...)` replaced the old
`assert_eq` / `assert_true` / `assert_text_eq` trio: comparisons already read
as words, so a separate word per comparison bought nothing.

```orion
assert(x is 42)                       # the condition IS the message
assert(is_some(opt), "opt was None")  # a label when the condition is not enough
```

It does not abort the process. Orion has no panic - failure is data - so a
failed assertion prints its label and answers 0 where a pass answers 1. A test
function counts the results and returns 0 if any failed.
