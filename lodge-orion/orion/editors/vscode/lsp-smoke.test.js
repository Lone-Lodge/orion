// Smoke test for the bundled orion-lsp binary.
// Spawns it, sends an LSP `initialize` request over stdio, and checks that
// the response includes a server capability we know orion-lsp exposes.
//
// Run with: node lsp-smoke.test.js

const cp = require("child_process");
const path = require("path");

const bin = path.join(
  __dirname,
  "bin",
  process.platform === "win32" ? "orion-lsp.exe" : "orion-lsp"
);

const proc = cp.spawn(bin, [], { stdio: ["pipe", "pipe", "pipe"] });

let buf = Buffer.alloc(0);
let done = false;

const finish = (msg, ok) => {
  if (done) return;
  done = true;
  console.log(ok ? "  ok  " : "  FAIL", msg);
  try {
    proc.kill();
  } catch (_) {}
  if (!ok) process.exitCode = 1;
};

proc.stdout.on("data", (chunk) => {
  buf = Buffer.concat([buf, chunk]);
  const headerEnd = buf.indexOf("\r\n\r\n");
  if (headerEnd === -1) return;
  const headers = buf.slice(0, headerEnd).toString();
  const m = /Content-Length:\s*(\d+)/i.exec(headers);
  if (!m) return finish("no Content-Length in response headers", false);
  const len = parseInt(m[1], 10);
  const bodyStart = headerEnd + 4;
  if (buf.length < bodyStart + len) return; // wait for full body
  const body = buf.slice(bodyStart, bodyStart + len).toString();
  let resp;
  try {
    resp = JSON.parse(body);
  } catch (e) {
    return finish(`response body is not JSON: ${e.message}`, false);
  }
  if (!resp.result || !resp.result.capabilities) {
    return finish("initialize response missing capabilities", false);
  }
  finish("LSP initialize handshake works", true);
});

proc.stderr.on("data", (chunk) => {
  process.stderr.write(chunk);
});

const req = JSON.stringify({
  jsonrpc: "2.0",
  id: 1,
  method: "initialize",
  params: { processId: null, rootUri: null, capabilities: {} },
});

proc.stdin.write(`Content-Length: ${Buffer.byteLength(req)}\r\n\r\n${req}`);

setTimeout(() => finish("LSP did not respond within 3s", false), 3000);
