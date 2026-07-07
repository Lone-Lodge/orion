# Orion — VS Code support

Language support for `.or` files: TextMate syntax highlighting, a Language
Server (hover, go-to-definition, document symbols, diagnostics), snippets,
a structure-preserving formatter, and palette commands wired to the
`orbit` CLI for build/run/test/fmt.

## Features

| Feature | Powered by |
|---|---|
| Syntax highlighting | TextMate grammar (`syntaxes/orion.tmLanguage.json`) |
| **Outline view** (Cmd-Shift-O / Cmd-T) | LSP `documentSymbol` |
| **Go to Definition (F12)** | LSP `definition` |
| **Hover tooltips** | LSP `hover` |
| **Error squiggles** | LSP `publishDiagnostics` — lex / parse errors live as you type |
| **Format Document** (Shift-Alt-F) | Indentation-stack reflow at a canonical 4-space step |
| **Snippets** | `fn`, `pfn`, `efn`, `data`, `enum`, `trait`, `impl`, `for`, `if`, `loop`, `mut`, `match`, `spawn`, … |
| **Orbit palette commands** | `orbit build`, `run`, `test`, `fmt`, `new`, `add` shelled to an integrated terminal |
| **Keybindings** | Cmd-Shift-T runs tests, Cmd-Shift-R runs the current file |

## Install (local dev)

```sh
# 1. Build the LSP server (release).
cd ~/lone-lodge/lodge-orion
cargo build --release --bin orion-lsp --manifest-path orion/Cargo.toml

# 2. Drop the binary into the extension's bin/ folder (Windows shown):
cp orion/target/release/orion-lsp.exe orion/editors/vscode/bin/orion-lsp.exe
# On Linux/macOS:
# cp orion/target/release/orion-lsp orion/editors/vscode/bin/orion-lsp

# 3. Install the client dep.
cd orion/editors/vscode && npm install

# 4. Symlink (or copy) the extension into your VS Code extensions dir.
#    Path differs per OS — example for Windows:
ln -sfn "$PWD" "$APPDATA/Code/User/extensions/lonelodge.orion-0.0.1"
# macOS:
# ln -sfn "$PWD" ~/.vscode/extensions/lonelodge.orion-0.0.1
# Linux:
# ln -sfn "$PWD" ~/.vscode/extensions/lonelodge.orion-0.0.1

# 5. Reload VS Code (Cmd-Shift-P → "Developer: Reload Window").
```

Open any `.or` file — the status bar shows "Orion" and the language server starts.

## Configuration

The extension auto-discovers the LSP server in this order:

1. `orion.server.path` in VS Code settings — if set, use it.
2. The binary bundled with this extension (`<ext>/bin/orion-lsp[.exe]`).
3. `<workspace>/target/release/orion-lsp[.exe]`.
4. `<workspace>/target/debug/orion-lsp[.exe]`.
5. `orion-lsp` on `$PATH`.

`orion.orbit.path` (default `orbit`) lets you point the palette commands at a
specific `orbit` binary if it's not on PATH.

## Develop

- Edit `syntaxes/orion.tmLanguage.json` for highlighting; reload window to see
  changes. The scope inspector (Cmd-Shift-P → "Developer: Inspect Editor Tokens
  and Scopes") shows which rule coloured any given token.
- Edit `orion/src/lsp/` to change LSP behaviour. Rebuild with
  `cargo build --release --bin orion-lsp` and run "Orion: restart language
  server" from the palette.
- Logs: View → Output → "Orion Language Server" shows what the server is doing.
- The formatter is a single ~40-line JS file (`format.js`) — easy to extend.

## Status

`0.0.1` — first cut. Hover, go-to-def, document symbols, and diagnostics ride
on what `orion-lsp` already exposes. Completion, references, rename, and code
lenses are planned but not wired yet; the server scaffold makes adding them a
small change.
