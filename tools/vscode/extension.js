// Orion VS Code extension - launches the orion-lsp Language Server on
// activation, registers Orbit CLI commands (build/run/test/fmt/new/add),
// and wires a structure-preserving formatter for `.or` files.
//
// Server is `orion-lsp`, written in ORION and living in this repo
// (orion/tools/orion_lsp.or + orion/orbs/orion_lsp). Build it with:
//   bash orion/tools/build_lsp.sh      ->  orion/dist/orion-lsp.exe
// and either bundle it under bin/, leave it in the workspace's dist/, put it on
// PATH, or set orion.server.path.
//
// It used to be a Rust binary from a crate that no longer exists in the tree,
// so nobody could rebuild it: an editor confidently underlining correct code
// with a year-old idea of the grammar. Diagnostics now come from the compiler
// itself, which is why the server needs to know where orion.exe and the orbs
// root are - that is what initializationOptions carries below.

const path = require("path");
const fs = require("fs");
const { execFile } = require("child_process");
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
  // 3. Workspace builds (handy when iterating on the server itself). `dist/` is
  //    where build_lsp.sh puts it; the orion tree may be the workspace root or
  //    a folder inside it.
  for (const folder of vscode.workspace.workspaceFolders || []) {
    const roots = [folder.uri.fsPath, path.join(folder.uri.fsPath, "orion")];
    for (const root of roots) {
      const candidate = path.join(root, "dist", platformBin);
      if (fs.existsSync(candidate)) {
        return candidate;
      }
    }
  }
  // 4. Last resort - assume on PATH.
  return platformBin;
}

// Every orb root the workspace can see: each folder's own orbs/ plus the
// parent directory of every `path:` dependency in its Orbit.toml. Without
// these the server only sees the stdlib and paints the project's own types
// (Binding, Intent, Scene) as unknown over a green build.
function workspaceOrbRoots() {
  const roots = [];
  for (const folder of vscode.workspace.workspaceFolders || []) {
    const base = folder.uri.fsPath;
    const own = path.join(base, "orbs");
    if (fs.existsSync(own) && !roots.includes(own)) roots.push(own);
    const toml = path.join(base, "Orbit.toml");
    if (!fs.existsSync(toml)) continue;
    const text = fs.readFileSync(toml, "utf8");
    for (const match of text.matchAll(/=\s*"path:([^"]+)"/g)) {
      const parent = path.dirname(path.resolve(base, match[1]));
      if (fs.existsSync(parent) && !roots.includes(parent)) roots.push(parent);
    }
  }
  return roots;
}

// Where the compiler and the stdlib orbs live, next to the server binary. The
// server shells out to the compiler for diagnostics, so a wrong guess here is
// the difference between real errors and none at all.
function toolchainOptions(serverPath) {
  const exe = process.platform === "win32" ? "orion.exe" : "orion";
  const near = path.dirname(serverPath);                    // …/dist
  const treeRoot = path.dirname(near);                      // …/orion
  const candidates = [
    { compiler: path.join(near, exe), orbs: path.join(treeRoot, "orbs") },
  ];
  for (const folder of vscode.workspace.workspaceFolders || []) {
    for (const root of [folder.uri.fsPath, path.join(folder.uri.fsPath, "orion")]) {
      candidates.push({
        compiler: path.join(root, "dist", exe),
        orbs: path.join(root, "orbs"),
      });
    }
  }
  for (const c of candidates) {
    if (fs.existsSync(c.compiler)) {
      const stdlib = fs.existsSync(c.orbs) ? [c.orbs] : [];
      const roots = stdlib.concat(workspaceOrbRoots().filter((r) => !stdlib.includes(r)));
      return { compiler: c.compiler, orbs: roots.join(";") };
    }
  }
  return { compiler: exe, orbs: workspaceOrbRoots().join(";") };
}

// ---- the Orion panel ----
// One activity-bar webview: what this project is (from Orbit.toml) and every
// orbit action as a click. The panel is a remote control for the CLI, not a
// second implementation of it - each row runs the command a terminal user
// would type, in a terminal, and shows that command dimmed on the right so
// the muscle memory transfers. Styled entirely with VS Code's own theme
// variables: native in every theme, light or dark.
const PANEL_SECTIONS = [
  { title: "Develop", rows: [
    { label: "Play", cli: "native / web", icon: "play", command: "orion.play", tip: "Run the project on the chosen target (Orion: choose play target switches)" },
    { label: "Run", cli: "orbit run", icon: "play", command: "orion.run", tip: "Compile and run the project" },
    { label: "Test", cli: "orbit test", icon: "beaker", command: "orion.test", tip: "Every test_* in the entry file, fail-fast" },
    { label: "Debug", cli: "orbit debug", icon: "bug", command: "orion.debug", tip: "Run with the call trail: crashes and require traps say how you got there" },
    { label: "Format", cli: "orbit fmt", icon: "braces", command: "orion.fmt", tip: "Format the sources in place" },
  ]},
  { title: "Verify", rows: [
    { label: "Gates", cli: "gates.sh", icon: "shield", command: "orion.gates", tip: "The one command: green or red" },
    { label: "Shot", cli: "orbit shot", icon: "camera", command: "orion.shot", tip: "Headless one-frame render to BMP" },
  ]},
  { title: "Ship", rows: [
    { label: "Dev build + launch", cli: "orbit dev", icon: "rocket", command: "orion.dev", tip: "Fresh native build, reference check, launch" },
    { label: "Package installer", cli: "orbit package", icon: "box", command: "orion.package", tip: "dist folder, zip and setup exe" },
  ]},
  { title: "Project", rows: [
    { label: "New project", cli: "orbit new", icon: "plus", command: "orion.new", tip: "Scaffold a project" },
    { label: "Add orb", cli: "orbit add", icon: "puzzle", command: "orion.addOrb", tip: "Add a library to Orbit.toml" },
    { label: "Restart language server", cli: "orion-lsp", icon: "refresh", command: "orion.restartServer", tip: "Restart orion-lsp" },
  ]},
];

// A declared game is a different job from a program: you probe it, you live
// with it in a window, and you may read its sketch in your own tongue. These
// rows appear only when the workspace actually holds a sketch, so an orion
// project never grows buttons for a language it does not use.
const ASTRA_SECTIONS = [
  { title: "Sketch", rows: [
    { label: "Probe", cli: "probe.sh", icon: "beaker", command: "astra.probe", tip: "Drive the game headless through its scenarios - the claims say green or red" },
    { label: "Kin window", cli: "game_kin.sh", icon: "rocket", command: "astra.kin", tip: "Build and run the sketch as its own frameless companion window" },
    { label: "Read in...", cli: "dialect.sh", icon: "globe", command: "astra.tongue", tip: "Turn this sketch's WORDS between English and Swedish - the same game either way" },
    { label: "Canonicalize all", cli: "dialect.sh en", icon: "shield", command: "astra.canonicalize", tip: "Put every sketch back in canonical English - run before you commit" },
  ]},
];

// 14px stroke icons, currentColor so they follow the theme.
const PANEL_ICONS = {
  play: '<path d="M4 2.5l9 4.5-9 4.5z"/>',
  beaker: '<path d="M5.5 1.5h3M6 1.5v4L2.8 11a1.2 1.2 0 0 0 1.1 1.7h6.2a1.2 1.2 0 0 0 1.1-1.7L8 5.5v-4M4.2 9h5.6"/>',
  bug: '<circle cx="7" cy="8" r="3.2"/><path d="M7 4.8V3.2M3.9 6l-1.7-1M10.1 6l1.7-1M3.8 9.5H2M10.2 9.5H12M4.5 11.5l-1.3 1.2M9.5 11.5l1.3 1.2"/>',
  braces: '<path d="M5 2C3.8 2 3.5 2.7 3.5 3.8v1.4c0 .9-.5 1.3-1.3 1.3.8 0 1.3.4 1.3 1.3v1.4C3.5 10.3 3.8 11 5 11M9 2c1.2 0 1.5.7 1.5 1.8v1.4c0 .9.5 1.3 1.3 1.3-.8 0-1.3.4-1.3 1.3v1.4c0 1.1-.3 1.8-1.5 1.8"/>',
  shield: '<path d="M7 1.5l4.7 1.7v3.4c0 3-2 5.2-4.7 6.2-2.7-1-4.7-3.2-4.7-6.2V3.2z"/><path d="M5 7l1.4 1.4L9.2 5.6"/>',
  camera: '<rect x="1.8" y="4" width="10.4" height="7.2" rx="1.2"/><path d="M5 4l.8-1.5h2.4L9 4"/><circle cx="7" cy="7.5" r="2"/>',
  rocket: '<path d="M7 9.5c3.5-2 4.6-5 4.5-7-2-.1-5 1-7 4.5L3 8.5 5.5 11zM3.5 10.5c-1 .3-1.7 1.5-1.8 2.8 1.3-.1 2.5-.8 2.8-1.8"/>',
  box: '<path d="M7 1.8l5 2.6v5.2l-5 2.6-5-2.6V4.4zM2 4.4l5 2.6 5-2.6M7 7v5.2"/>',
  plus: '<path d="M7 3.5v7M3.5 7h7"/>',
  puzzle: '<path d="M5.5 2.5h3v2a1.25 1.25 0 1 0 2.5 0h.5v3h-2a1.25 1.25 0 1 0 0 2.5v1.5h-3v-2a1.25 1.25 0 1 0-2.5 0h-1.5v-3h2a1.25 1.25 0 1 0 0-2.5z"/>',
  refresh: '<path d="M11.5 7A4.5 4.5 0 1 1 7 2.5c1.8 0 3.2.9 4 2.2M11.5 2v3h-3"/>',
  globe: '<circle cx="7" cy="7" r="5.2"/><path d="M1.8 7h10.4M7 1.8c1.4 1.5 2.1 3.3 2.1 5.2S8.4 10.7 7 12.2C5.6 10.7 4.9 8.9 4.9 7s.7-3.7 2.1-5.2z"/>',
};

// Every sketch the workspace can see - the dialect and probe rows act on
// these, and their absence is what hides the Sketch section entirely.
function sketchFolders() {
  const out = [];
  for (const dir of projectCandidates()) {
    try {
      if (fs.readdirSync(dir).some((name) => name.endsWith(".astra"))) out.push(dir);
    } catch (e) { /* unreadable folder: not a project */ }
  }
  return out;
}

// The engine's dialect tool, beside whichever atlas0.0.1 this workspace has.
function dialectScript() {
  for (const dir of projectCandidates()) {
    const script = path.join(path.dirname(dir), "atlas0.0.1", "tools", "dialect.sh");
    if (fs.existsSync(script)) return script;
    const own = path.join(dir, "tools", "dialect.sh");
    if (fs.existsSync(own)) return own;
  }
  return null;
}

// Which tongue a sketch is written in right now, read from the file itself:
// the header word says it (`game` / `spel`), and a file with no header falls
// back to the words in its body.
function tongueOf(text) {
  if (/^\s*(game|view:)/m.test(text)) return "en";
  if (/^\s*(spel|vy:)/m.test(text)) return "sv";
  return /^\s+(regel|handling|värde|rita|etikett)\b/m.test(text) ? "sv" : "en";
}

function panelProject() {
  for (const folder of vscode.workspace.workspaceFolders || []) {
    const tomlPath = path.join(folder.uri.fsPath, "Orbit.toml");
    if (!fs.existsSync(tomlPath)) continue;
    const toml = fs.readFileSync(tomlPath, "utf8");
    const name = (toml.match(/^name *= *"([^"]*)"/m) || [])[1];
    const version = (toml.match(/^version *= *"([^"]*)"/m) || [])[1];
    const orbs = (toml.match(/^\w[\w.]* *= *"/gm) || []).length - (name ? 1 : 0) - (version ? 1 : 0);
    if (name) return { name, version: version || "", folder: folder.name, orbs: Math.max(0, orbs) };
  }
  return null;
}

function panelHtml() {
  const proj = panelProject();
  const icon = (k) =>
    `<svg viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.1" stroke-linecap="round" stroke-linejoin="round">${PANEL_ICONS[k] || PANEL_ICONS.play}</svg>`;
  const rows = (s) => s.rows.map((r) => `
    <div class="row" data-cmd="${r.command}" title="${r.tip}">
      <span class="ic">${icon(r.icon)}</span>
      <span class="lbl">${r.label}</span>
      <span class="cli">${r.cli}</span>
    </div>`).join("");
  const shown = sketchFolders().length ? PANEL_SECTIONS.concat(ASTRA_SECTIONS) : PANEL_SECTIONS;
  const sections = shown.map((s) => `
    <div class="section">
      <div class="head">${s.title}</div>
      ${rows(s)}
    </div>`).join("");
  const projCard = proj ? `
    <div class="proj">
      <div class="proj-name">${proj.name}<span class="proj-ver">${proj.version}</span></div>
      <div class="proj-sub">${proj.orbs} orb${proj.orbs === 1 ? "" : "s"} · Orbit.toml</div>
    </div>` : `
    <div class="proj">
      <div class="proj-name">Orion</div>
      <div class="proj-sub">no Orbit.toml in this workspace</div>
    </div>`;
  return `<!DOCTYPE html>
<html><head><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline';">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: var(--vscode-font-family);
    color: var(--vscode-foreground);
    padding: 10px 8px 16px;
    user-select: none;
  }
  .proj {
    padding: 10px 12px;
    border: 1px solid var(--vscode-widget-border, rgba(128,128,128,.25));
    border-radius: 6px;
    margin-bottom: 14px;
    background: var(--vscode-editorWidget-background, transparent);
  }
  .proj-name { font-size: 13px; font-weight: 600; letter-spacing: .2px; }
  .proj-ver {
    font-weight: 400; margin-left: 7px; font-size: 11px;
    color: var(--vscode-descriptionForeground);
    font-family: var(--vscode-editor-font-family);
  }
  .proj-sub { margin-top: 3px; font-size: 11px; color: var(--vscode-descriptionForeground); }
  .section { margin-bottom: 12px; }
  .head {
    font-size: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: .12em;
    color: var(--vscode-descriptionForeground);
    padding: 4px 6px 5px;
  }
  .row {
    display: flex; align-items: center; gap: 8px;
    padding: 5px 8px; border-radius: 5px; cursor: pointer;
    line-height: 1;
  }
  .row:hover { background: var(--vscode-list-hoverBackground); }
  .row:active { background: var(--vscode-list-activeSelectionBackground); color: var(--vscode-list-activeSelectionForeground); }
  .ic { width: 14px; height: 14px; flex: none; display: flex; opacity: .9; }
  .ic svg { width: 14px; height: 14px; }
  .lbl { font-size: 12.5px; flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .cli {
    font-size: 10px; color: var(--vscode-descriptionForeground);
    font-family: var(--vscode-editor-font-family);
    opacity: 0; transition: opacity .12s;
  }
  .row:hover .cli { opacity: .85; }
</style></head>
<body>
  ${projCard}
  ${sections}
  <script>
    const vsapi = acquireVsCodeApi();
    for (const el of document.querySelectorAll(".row"))
      el.addEventListener("click", () => vsapi.postMessage({ cmd: el.dataset.cmd }));
  </script>
</body></html>`;
}

class OrionPanelProvider {
  resolveWebviewView(view) {
    view.webview.options = { enableScripts: true };
    view.webview.html = panelHtml();
    view.webview.onDidReceiveMessage((m) => {
      if (m && m.cmd) vscode.commands.executeCommand(m.cmd);
    });
    // Re-read Orbit.toml whenever the panel comes back into view.
    view.onDidChangeVisibility(() => {
      if (view.visible) view.webview.html = panelHtml();
    });
  }
}

// ---- play targets ----
// A project declares its play targets by what it HAS, the same convention the
// repos already follow: src/main.or = the native window (orbit dev), and
// tools/build_web.sh = the browser (build + open dist/*.html). New platforms
// join by adding a tools/build_<target>.sh - no new extension concepts.
// Every project the workspace can see: the active file's project first,
// then each workspace root, then the roots' direct children (the
// llstudios shape: one parent folder, game projects inside it).
function projectCandidates() {
  const seen = new Set();
  const out = [];
  const add = (dir) => {
    if (dir && !seen.has(dir) && fs.existsSync(path.join(dir, "Orbit.toml"))) {
      seen.add(dir);
      out.push(dir);
    }
  };
  const editor = vscode.window.activeTextEditor;
  if (editor) {
    let dir = path.dirname(editor.document.uri.fsPath);
    for (let i = 0; i < 8; i++) {
      if (fs.existsSync(path.join(dir, "Orbit.toml"))) { add(dir); break; }
      const up = path.dirname(dir);
      if (up === dir) break;
      dir = up;
    }
  }
  for (const folder of vscode.workspace.workspaceFolders || []) {
    const root = folder.uri.fsPath;
    add(root);
    try {
      for (const entry of fs.readdirSync(root, { withFileTypes: true }))
        if (entry.isDirectory() && !entry.name.startsWith(".")) add(path.join(root, entry.name));
    } catch { /* an unreadable root just contributes nothing */ }
  }
  return out;
}

// The project play acts on: the first candidate that HAS targets, the
// remembered pick winning when several do.
function playProjectFolder(context) {
  const armed = projectCandidates().filter((dir) => playTargets(dir).length);
  if (!armed.length) return null;
  const saved = context && context.workspaceState.get("orion.playProject");
  return armed.find((dir) => dir === saved) || armed[0];
}

function engineToolsFor(folder) {
  const engine = path.join(path.dirname(folder), "atlas0.0.1", "tools");
  return fs.existsSync(path.join(engine, "game_native.sh")) ? engine : null;
}

function playTargets(folder) {
  const targets = [];
  // A project with its own scripts (pong, the proof project) runs them.
  if (fs.existsSync(path.join(folder, "src", "main.or")))
    targets.push({ id: "native", label: "native window", description: "orbit dev" });
  if (fs.existsSync(path.join(folder, "tools", "build_web.sh")))
    targets.push({ id: "web", label: "web browser", description: "tools/build_web.sh + open dist html" });
  if (fs.existsSync(path.join(folder, "tools", "build_editor.sh")))
    targets.push({ id: "editor", label: "atlas editor", description: "tools/build_editor.sh + open dist html" });
  if (targets.length) return targets;
  // A blank declared game (a sketch and its assets): the ENGINE runs it.
  const sketch = fs.readdirSync(folder).find((name) => name.endsWith(".astra"));
  const engine = engineToolsFor(folder);
  if (sketch && engine) {
    targets.push({ id: "native", label: "native window", description: "engine game_native.sh" });
    targets.push({ id: "web", label: "web browser", description: "engine game_web.sh + open dist html" });
    targets.push({ id: "editor", label: "atlas editor", description: "engine game_editor.sh + open dist html" });
  }
  return targets;
}

function playWeb(folder, output, scriptArgs) {
  return vscode.window.withProgress(
    { location: vscode.ProgressLocation.Window, title: "Orion: building..." },
    () => new Promise((resolve) => {
      execFile("bash", scriptArgs, { cwd: folder, maxBuffer: 16 * 1024 * 1024 },
        (error, stdout, stderr) => {
          output.appendLine(stdout || "");
          if (stderr) output.appendLine(stderr);
          if (error) {
            output.show(true);
            vscode.window.showErrorMessage("Orion: web build failed - see the Orion play output.");
            return resolve();
          }
          const dist = path.join(folder, "dist");
          const pages = fs.existsSync(dist)
            ? fs.readdirSync(dist).filter((f) => f.endsWith(".html"))
                .map((f) => path.join(dist, f))
                .sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs)
            : [];
          if (!pages.length) {
            vscode.window.showErrorMessage("Orion: web build made no dist/*.html.");
            return resolve();
          }
          vscode.env.openExternal(vscode.Uri.file(pages[0]));
          resolve();
        });
    })
  );
}

function activate(context) {
  const command = findServer(context);

  const serverOptions = {
    run: { command, transport: TransportKind.stdio },
    debug: { command, transport: TransportKind.stdio },
  };

  const clientOptions = {
    // A sketch is a source file too: F12 from `bar hunger` to the `stat`
    // that declares it is the difference between reading a sketch and
    // scrolling one.
    documentSelector: [
      { scheme: "file", language: "orion" },
      { scheme: "file", language: "astra" },
    ],
    synchronize: {
      fileEvents: vscode.workspace.createFileSystemWatcher("**/*.{or,astra}"),
    },
    initializationOptions: toolchainOptions(command),
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

  // ---- play: one button, target chosen per workspace ----
  const playOutput = vscode.window.createOutputChannel("Orion play");
  const playStatus = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 90);
  playStatus.command = "orion.play";
  const updatePlayStatus = () => {
    const folder = playProjectFolder(context);
    const targets = folder ? playTargets(folder) : [];
    if (!targets.length) {
      playStatus.hide();
      return;
    }
    const saved = context.workspaceState.get("orion.playTarget");
    const target = targets.find((t) => t.id === saved) || (targets.length === 1 ? targets[0] : null);
    playStatus.text = target ? `$(play) ${path.basename(folder)} ${target.id}` : `$(play) ${path.basename(folder)}`;
    playStatus.tooltip = "Orion: play " + path.basename(folder) + (target ? ` on ${target.label}` : "") +
      " - switch with the command Orion: choose play target";
    playStatus.show();
  };
  updatePlayStatus();
  context.subscriptions.push(playOutput, playStatus,
    vscode.window.onDidChangeActiveTextEditor(updatePlayStatus));

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
    }),
    vscode.commands.registerCommand("orion.play", async () => {
      const candidates = projectCandidates();
      if (!candidates.length) {
        vscode.window.showInformationMessage("Orion: no Orbit.toml in this workspace.");
        return;
      }
      const armed = candidates.filter((dir) => playTargets(dir).length);
      if (!armed.length) {
        vscode.window.showInformationMessage(
          "Orion: no play target in " + candidates.map((d) => path.basename(d)).join(", ") +
          " (src/main.or, tools/build_web.sh, or a .astra sketch beside the engine).");
        return;
      }
      let folder = armed.find((dir) => dir === context.workspaceState.get("orion.playProject")) || armed[0];
      if (armed.length > 1 && !armed.includes(context.workspaceState.get("orion.playProject"))) {
        const picked = await vscode.window.showQuickPick(
          armed.map((dir) => ({ label: path.basename(dir), description: dir, dir })),
          { placeHolder: "Play which project?" });
        if (!picked) return;
        folder = picked.dir;
        await context.workspaceState.update("orion.playProject", folder);
        updatePlayStatus();
      }
      const targets = playTargets(folder);
      let target = targets.find((t) => t.id === context.workspaceState.get("orion.playTarget"));
      if (!target && targets.length === 1) target = targets[0];
      if (!target) {
        target = await vscode.window.showQuickPick(targets, { placeHolder: "Play on which target?" });
        if (!target) return;
        await context.workspaceState.update("orion.playTarget", target.id);
        updatePlayStatus();
      }
      const engine = target.description.startsWith("engine") ? engineToolsFor(folder) : null;
      if (target.id === "web" || target.id === "editor") {
        const script = target.id === "web" ? "build_web.sh" : "build_editor.sh";
        const engineScript = target.id === "web" ? "game_web.sh" : "game_editor.sh";
        playWeb(folder, playOutput,
          engine ? [path.join(engine, engineScript), "."] : ["tools/" + script]);
      } else {
        let term = vscode.window.terminals.find((t) => t.name === "Play");
        if (!term) term = vscode.window.createTerminal({ name: "Play", cwd: folder });
        term.show();
        if (engine) {
          term.sendText('bash "' + path.join(engine, "game_native.sh").replace(/\\/g, "/") + '" .');
        } else {
          // A declared game regenerates from its .astra before running.
          const astraFirst = fs.existsSync(path.join(folder, "tools", "build_astra.sh"))
            ? "bash tools/build_astra.sh; " : "";
          term.sendText(astraFirst + "orbit dev");
        }
      }
    }),
    vscode.commands.registerCommand("orion.playTarget", async () => {
      const armed = projectCandidates().filter((dir) => playTargets(dir).length);
      if (!armed.length) {
        vscode.window.showInformationMessage("Orion: no play target (src/main.or, tools/build_web.sh, or a .astra sketch).");
        return;
      }
      let folder = armed[0];
      if (armed.length > 1) {
        const picked = await vscode.window.showQuickPick(
          armed.map((dir) => ({ label: path.basename(dir), description: dir, dir })),
          { placeHolder: "Play which project?" });
        if (!picked) return;
        folder = picked.dir;
      }
      await context.workspaceState.update("orion.playProject", folder);
      const target = await vscode.window.showQuickPick(playTargets(folder), { placeHolder: "Play on which target?" });
      if (!target) return;
      await context.workspaceState.update("orion.playTarget", target.id);
      updatePlayStatus();
    }),
    vscode.commands.registerCommand("orion.debug", () => runOrbit("Orbit", "debug")),
    vscode.commands.registerCommand("orion.shot", () => runOrbit("Orbit", "shot")),
    vscode.commands.registerCommand("orion.dev", () => runOrbit("Orbit", "dev")),
    vscode.commands.registerCommand("orion.package", () => runOrbit("Orbit", "package")),
    vscode.commands.registerCommand("orion.gates", () => {
      for (const folder of vscode.workspace.workspaceFolders || []) {
        if (fs.existsSync(path.join(folder.uri.fsPath, "tools", "gates.sh"))) {
          let term = vscode.window.terminals.find((t) => t.name === "Gates");
          if (!term) term = vscode.window.createTerminal({ name: "Gates", cwd: folder.uri.fsPath });
          term.show();
          term.sendText("bash tools/gates.sh");
          return;
        }
      }
      vscode.window.showInformationMessage("Orion: no tools/gates.sh in this workspace.");
    })
  );

  // ---- astra: the declared-game commands ----
  // Each one runs the engine script a terminal user would type, in a
  // terminal, on the project the active sketch belongs to.
  const sketchFolder = () => {
    const open = vscode.window.activeTextEditor;
    if (open && open.document.fileName.endsWith(".astra")) {
      const dir = path.dirname(open.document.fileName);
      if (sketchFolders().includes(dir)) return dir;
    }
    return sketchFolders()[0] || null;
  };
  const runEngine = (name, script, args = "") => {
    const folder = sketchFolder();
    const engine = folder && engineToolsFor(folder);
    if (!folder || !engine) {
      vscode.window.showInformationMessage("Astra: no sketch and engine (atlas0.0.1) in this workspace.");
      return;
    }
    let term = vscode.window.terminals.find((t) => t.name === name);
    if (!term) term = vscode.window.createTerminal({ name, cwd: folder });
    term.show();
    term.sendText(`bash "${path.join(engine, script)}" .${args ? " " + args : ""}`);
  };

  // The tongue of the sketch you are looking at, and one click to turn it.
  // The file itself is what changes - no hidden buffer state, no save hook
  // fighting the editor - and `Canonicalize all` is what you run before a
  // commit so the corpus stays one language (see atlas0.0.1/orbs/dialect).
  const tongueStatus = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 89);
  tongueStatus.command = "astra.tongue";
  const tongueNames = { en: "English", sv: "svenska" };
  const updateTongueStatus = () => {
    const open = vscode.window.activeTextEditor;
    if (!open || !open.document.fileName.endsWith(".astra") || !dialectScript()) {
      tongueStatus.hide();
      return;
    }
    const tongue = tongueOf(open.document.getText());
    tongueStatus.text = `$(globe) ${tongueNames[tongue] || tongue}`;
    tongueStatus.tooltip = "This sketch's words. Click to read it in the other tongue - the game is the same either way.";
    tongueStatus.show();
  };
  updateTongueStatus();
  context.subscriptions.push(tongueStatus,
    vscode.window.onDidChangeActiveTextEditor(updateTongueStatus),
    vscode.workspace.onDidSaveTextDocument(updateTongueStatus));

  const turnFiles = (files, tongue) => new Promise((resolve) => {
    const script = dialectScript();
    if (!script || !files.length) return resolve(0);
    let left = files.length;
    for (const file of files) {
      execFile("bash", [script, file, tongue, "--write"], { maxBuffer: 4 * 1024 * 1024 }, () => {
        if (--left === 0) resolve(files.length);
      });
    }
  });

  // Every sketch the workspace holds, so a tongue is a MODE over the
  // project rather than a per-file accident.
  const allSketches = () => {
    const found = [];
    for (const dir of sketchFolders())
      for (const name of fs.readdirSync(dir))
        if (name.endsWith(".astra")) found.push(path.join(dir, name));
    return found;
  };

  // The chosen tongue sticks: it is remembered, every sketch is turned
  // to it, and a file that arrives in the other one (git, a teammate, a
  // generated file) is turned on open. Changing back is the only way out.
  const tongueSetting = () => vscode.workspace.getConfiguration("astra").get("tongue") || "en";
  const setTongue = async (tongue) => {
    await vscode.workspace.getConfiguration("astra").update("tongue", tongue, vscode.ConfigurationTarget.Workspace);
    await vscode.workspace.saveAll(false);
    const turned = await turnFiles(allSketches(), tongue);
    await vscode.commands.executeCommand("workbench.action.files.revert");
    updateTongueStatus();
    return turned;
  };

  context.subscriptions.push(
    vscode.commands.registerCommand("astra.probe", () => runEngine("Probe", "probe.sh")),
    vscode.commands.registerCommand("astra.kin", () => runEngine("Kin", "game_kin.sh")),
    vscode.commands.registerCommand("astra.tongue", async () => {
      if (!dialectScript() || !allSketches().length) {
        vscode.window.showInformationMessage("Astra: no sketch and engine (atlas0.0.1) in this workspace.");
        return;
      }
      const now = tongueSetting();
      const picked = await vscode.window.showQuickPick(
        [
          { label: "English", description: "canonical - what the corpus and the compiler speak", tongue: "en" },
          { label: "svenska", description: "the same sketches, read in Swedish", tongue: "sv" },
        ].map((p) => ({ ...p, picked: p.tongue === now })),
        { placeHolder: `This project's sketches are in ${tongueNames[now]}. Write them in...` }
      );
      if (!picked || picked.tongue === now) return;
      const turned = await setTongue(picked.tongue);
      vscode.window.showInformationMessage(`Astra: ${turned} sketch${turned === 1 ? "" : "es"} in ${tongueNames[picked.tongue]}.`);
    }),
    vscode.commands.registerCommand("astra.canonicalize", async () => {
      if (!dialectScript() || !allSketches().length) {
        vscode.window.showInformationMessage("Astra: no sketches to canonicalize.");
        return;
      }
      const turned = await setTongue("en");
      vscode.window.showInformationMessage(`Astra: ${turned} sketch${turned === 1 ? "" : "es"} back in canonical English.`);
    }),
    // A sketch that arrives in the other tongue joins the project's:
    // pulled from git, written by a teammate, or generated. The mode is
    // the truth, and it holds until you change it.
    vscode.workspace.onDidOpenTextDocument(async (doc) => {
      if (!doc.fileName.endsWith(".astra") || !dialectScript()) return;
      const want = tongueSetting();
      if (tongueOf(doc.getText()) === want) return;
      if (!allSketches().includes(doc.fileName)) return;
      await turnFiles([doc.fileName], want);
      await vscode.commands.executeCommand("workbench.action.files.revert");
      updateTongueStatus();
    })
  );

  // ---- the Orion panel ----
  context.subscriptions.push(
    vscode.window.registerWebviewViewProvider("orionActions", new OrionPanelProvider())
  );
}

function deactivate() {
  if (!client) return undefined;
  return client.stop();
}

module.exports = { activate, deactivate, panelHtml };
