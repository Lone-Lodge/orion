// Makes every Orion sample in the Field Guide editable and runnable in place.
// Needs the playground server (tools/playground.js) for /api/run, which compiles
// the snippet to wasm; the browser then instantiates and runs main().
(function () {
  const style = document.createElement('style');
  style.textContent = `
    .pg { margin: 1em 0; }
    .pg pre { margin: 0; }
    .pg-bar { display:flex; align-items:center; gap:12px; margin-bottom:6px; }
    .pg-run { background:#8ac926; color:#0b0b0b; border:0; border-radius:6px;
              padding:4px 14px; font-weight:600; font-size:13px; cursor:pointer;
              font-family:inherit; }
    .pg-run:disabled { opacity:.5; cursor:default; }
    .pg-status { font-size:12px; color:#888; font-family:ui-monospace,monospace; }
    .pg code[contenteditable] { outline:none; display:block; }
    .pg code[contenteditable]:focus { box-shadow: inset 0 0 0 2px #8ac92655; }
    .pg-out { margin:6px 0 0; padding:10px 14px; border-radius:8px;
              background:#12131a; color:#dfe2ee; font-family:ui-monospace,monospace;
              font-size:12.5px; line-height:1.5; white-space:pre-wrap; overflow:auto; }
    .pg-out .exit { color:#7c8099; }
    .pg-out.err { color:#ff6b6b; }
  `;
  document.head.appendChild(style);

  function readText(mem, ptr) {
    const u = new Uint8Array(mem.buffer);
    const len = u[ptr] | (u[ptr + 1] << 8) | (u[ptr + 2] << 16) | (u[ptr + 3] << 24);
    return new TextDecoder().decode(u.subarray(ptr + 4, ptr + 4 + len));
  }

  async function run(source, btn, status, out) {
    btn.disabled = true; status.textContent = 'compiling...';
    out.style.display = 'block'; out.className = 'pg-out'; out.textContent = '';
    try {
      const res = await fetch('/api/run', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ source })
      }).then(r => r.json());
      if (!res.ok) {
        // A wasm-backend limitation (feature runs natively) reads as a calm note,
        // not a red error. A real syntax/type error ('ERROR at line:col') stays red.
        if (/the wasm backend does not support/.test(res.error)) {
          const feats = [...new Set([...res.error.matchAll(/does not support `([A-Za-z_]+)`|calling `([A-Za-z_]+)`/g)]
            .map(m => m[1] || m[2]))].slice(0, 5);
          status.textContent = 'native only';
          out.className = 'pg-out';
          out.innerHTML = '<span style="color:#8b90a8">This example uses ' +
            (feats.length ? '<b style="color:#b0b4c8">' + feats.join(', ') + '</b>' : 'a language feature') +
            ' that runs with the native Orion compiler (<code>orbit run</code>), not the in-browser playground.<br>' +
            'The playground runs the core: arithmetic, control flow, functions, lists, maps, structs, f64 and text.</span>';
        } else {
          status.textContent = 'error'; out.className = 'pg-out err'; out.textContent = res.error;
        }
        return;
      }
      status.textContent = 'running...';
      const bytes = Uint8Array.from(atob(res.wasm), c => c.charCodeAt(0));
      let mem, text = '';
      const env = {
        __print: (p, nl) => { text += readText(mem, p) + (nl ? '\n' : ''); },
        host_sin: Math.sin, host_cos: Math.cos, host_sqrt: Math.sqrt,
      };
      const { instance } = await WebAssembly.instantiate(bytes, { env });
      mem = instance.exports.memory;
      const rv = instance.exports.main ? instance.exports.main() : null;
      out.textContent = text;
      const exit = document.createElement('span');
      exit.className = 'exit';
      exit.textContent = (text && !text.endsWith('\n') ? '\n' : '') + '→ exit ' + rv;
      out.appendChild(exit);
      status.textContent = '';
    } catch (e) {
      status.textContent = 'error'; out.className = 'pg-out err'; out.textContent = String(e);
    } finally { btn.disabled = false; }
  }

  document.querySelectorAll('pre > code[data-or]').forEach(code => {
    const pre = code.parentElement;
    const box = document.createElement('div'); box.className = 'pg';
    pre.replaceWith(box);
    const bar = document.createElement('div'); bar.className = 'pg-bar';
    const btn = document.createElement('button'); btn.className = 'pg-run'; btn.innerHTML = 'Run &#9654;';
    const status = document.createElement('span'); status.className = 'pg-status';
    bar.appendChild(btn); bar.appendChild(status);
    const out = document.createElement('pre'); out.className = 'pg-out'; out.style.display = 'none';
    code.setAttribute('contenteditable', 'true');
    code.setAttribute('spellcheck', 'false');
    box.appendChild(bar); box.appendChild(pre); box.appendChild(out);
    btn.onclick = () => run(code.textContent, btn, status, out);
  });
})();
