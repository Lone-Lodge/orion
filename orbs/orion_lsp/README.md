# orion_lsp

A Language Server for Orion, written in Orion.

Its diagnostics come from THE COMPILER, never from a second model of the
grammar. A server with its own idea of the language drifts, and an editor
confidently underlining correct code is worse than no editor support at all.

## What it serves

Diagnostics (on open, change and save), document symbols for the outline,
go-to-definition, hover, and declaration-based completion: every `fn`, `type`,
`effect` and `const` in the document and in the orbs it can see, plus the
keywords.

Completion does not filter by what would type-check at the cursor, because the
compiler does not expose scope-aware types. That limit is stated in the
completion section rather than implied by a confident-looking list.

## Watch out for

Protocol framing is `Content-Length: N\r\n\r\n<json>` over stdin/stdout, so
stdout is RESERVED for protocol traffic. Logging goes to stderr. One stray
`print_line` and the editor sees a malformed message.
