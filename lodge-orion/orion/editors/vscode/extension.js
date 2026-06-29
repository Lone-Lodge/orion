// Orion VS Code extension — launches the orion-lsp Language Server on
// activation, registers Orbit CLI commands (build/run/test/fmt/new/add),
// and wires a structure-preserving formatter for `.or` files.
//
// Server is the `orion-lsp` binary from the orion crate. Build it with:
//   cargo build --release --bin orion-lsp
// and either bundle the binary under bin/, drop it in the workspace's
// target/{release,debug}/, put it on PATH, or set orion.server.path.

const path = require("path");
const fs = require("fs");
const vscode = require("vscode");
const { LanguageClient, TransportKind } = require("vscode-languageclient/node");
const { formatOrion } = require("./format");

let client;

function findServer(context) {
  // 1. Explicit override via settings.
  const configured = vscode.workspace
    .getConfiguration("orion")
    .get("server.path");
  if (configured && fs.existsSync(configured)) {
    return configured;
  }
  // 2. Bundled binary inside the extension.
  const platformBin = process.platform === "win32" ? "orion-lsp.exe" : "orion-lsp";
  const bundled = path.join(context.extensionPath, "bin", platformBin);
  if (fs.existsSync(bundled)) {
    return bundled;
  }
  // 3. Workspace builds (handy when iterating on the server itself).
  for (const folder of vscode.workspace.workspaceFolders || []) {
    for (const profile of ["release", "debug"]) {
      const candidate = path.join(folder.uri.fsPath, "target", profile, platformBin);
      if (fs.existsSync(candidate)) {
        return candidate;
      }
    }
  }
  // 4. Last resort — assume on PATH.
  return platformBin;
}

function activate(context) {
  const command = findServer(context);

  const serverOptions = {
    run: { command, transport: TransportKind.stdio },
    debug: { command, transport: TransportKind.stdio },
  };

  const clientOptions = {
    documentSelector: [
      { scheme: "file", language: "orion" },
    ],
    synchronize: {
      fileEvents: vscode.workspace.createFileSystemWatcher("**/*.or"),
    },
  };

  client = new LanguageClient(
    "orion-lsp",
    "Orion Language Server",
    serverOptions,
    clientOptions
  );

  client.start();
  context.subscriptions.push({
    dispose: () => client && client.stop(),
  });

  // ---- formatter ----
  context.subscriptions.push(
    vscode.languages.registerDocumentFormattingEditProvider(
      [{ scheme: "file", language: "orion" }],
      {
        provideDocumentFormattingEdits(document) {
          const formatted = formatOrion(document.getText());
          if (formatted === document.getText()) return [];
          const fullRange = new vscode.Range(
            document.positionAt(0),
            document.positionAt(document.getText().length)
          );
          return [vscode.TextEdit.replace(fullRange, formatted)];
        },
      }
    )
  );

  // ---- orbit CLI commands ----
  const runOrbit = (name, subcmd, extraArgs = "") => {
    const orbitBin = vscode.workspace.getConfiguration("orion").get("orbit.path") || "orbit";
    let term = vscode.window.terminals.find((t) => t.name === name);
    if (!term) term = vscode.window.createTerminal({ name });
    term.show();
    term.sendText(`${orbitBin} ${subcmd}${extraArgs ? " " + extraArgs : ""}`);
  };

  context.subscriptions.push(
    vscode.commands.registerCommand("orion.build", () => runOrbit("Orbit", "build")),
    vscode.commands.registerCommand("orion.run", () => runOrbit("Orbit", "run")),
    vscode.commands.registerCommand("orion.test", () => runOrbit("Orbit tests", "test")),
    vscode.commands.registerCommand("orion.fmt", () => runOrbit("Orbit", "fmt")),
    vscode.commands.registerCommand("orion.runCurrentFile", () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor) {
        vscode.window.showInformationMessage("Orion: no active file to run.");
        return;
      }
      const fsPath = editor.document.uri.fsPath;
      runOrbit("Orbit", "run", `"${fsPath}"`);
    }),
    vscode.commands.registerCommand("orion.new", async () => {
      const name = await vscode.window.showInputBox({
        prompt: "Name of the new Orion project",
        placeHolder: "my_project",
      });
      if (!name) return;
      runOrbit("Orbit", "new", name);
    }),
    vscode.commands.registerCommand("orion.addOrb", async () => {
      const orb = await vscode.window.showInputBox({
        prompt: "Name of the orb to add",
        placeHolder: "bytes",
      });
      if (!orb) return;
      runOrbit("Orbit", "add", orb);
    }),
    vscode.commands.registerCommand("orion.restartServer", async () => {
      if (!client) return;
      await client.stop();
      client.start();
      vscode.window.showInformationMessage("Orion language server restarted.");
    })
  );
}

function deactivate() {
  if (!client) return undefined;
  return client.stop();
}

module.exports = { activate, deactivate };
