# store

Program state shaped like a database (manifesto P1): flat records with STABLE
ids, not object graphs. Games call it ECS, business software calls it
relations - the same idea. Value semantics makes pointer graphs impossible, and
this orb makes tables of entities natural instead.

```orion
w0 = store_new()
w1, id = insert(w0, {"hp": 10})     # id is stable for the entity's life
w2 = remove(w1, id)
e  = entity(w, id)                  # {} when absent
hurt = loop e in items(w) where get_int(e, "hp") < 10: collect e
```

`loop ... in items(w) where ...` IS the query. The storage layout - SoA,
archetype, whatever - is the compiler's business, never the code's.

The store itself is a RECORD with typed fields, not a bag-of-anything table: a
heterogeneous table read through typed getters is a poor man's record, and the
language has real ones. Cells stay a `table<table>` - id-text to entity record,
homogeneous - so plain typed reads work.
