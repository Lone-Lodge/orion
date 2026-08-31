# encoding

Hex and base64, both directions.

```orion
hex_encode([255, 16])     # "ff10"
hex_decode("ff10")        # [255, 16]
base64_encode(bytes)      # "..."
base64_decode("...")      # bytes
```

A "bytes" value in Orion is just a `[int]` of byte values 0..255 - that is what
`bytes_from_text` returns and what `bytes_to_text` consumes - so these
functions take and return plain int lists. There is no separate byte type to
learn, and nothing to convert at the boundary.
