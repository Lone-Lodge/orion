# compress

LZ77 over a 64 KB window. Not zlib, and not compatible with it - a store that
writes and reads its own bytes needs no interchange format, and the whole of
DEFLATE (Huffman tables, dynamic blocks, the lot) is most of the code for the
last third of the ratio.

## The format, whole

```
token < 128     a run of (token + 1) literal bytes follows
token >= 128    a match: length = (token - 128) + 4, then two bytes of
                distance, high byte first
```

So a match costs three bytes and reaches 4..131 bytes back, up to 65535 away. A
literal run costs one byte per 128.

## The one trade

The matcher keeps ONE position per three-byte hash - the most recent - and no
chain. A chain finds longer matches and costs a search per byte. Greedy and
shallow is what a store wants, because it compresses once and reads many times.
