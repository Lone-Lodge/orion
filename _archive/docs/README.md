# Retired docs

## sprak-svenska.md

A Swedish language reference that duplicated `docs/syntax.md`. Nothing linked to
it, and a second description of the same language drifts by construction — the
same failure as the editor grammar that lived only in the installed extension,
the lexer's unused keyword table, and the stale copies under `dist/`.

In one audit (2026-07-26) it was wrong about six things: a `|x|` lambda form, a
`|>` pipe operator, colon-style match arms (`Empty: 0` instead of
`Empty -> 0`), `resume_int`/`resume_text` as callable names, "run a file
interpreted" (there is no interpreter; lodge-orion is gone), and a link to a
`NEW_FEATURES.md` that does not exist.

Kept rather than deleted because this tree has no git history to recover from.
`docs/syntax.md` is the one reference.
