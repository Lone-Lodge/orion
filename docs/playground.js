// Field Guide playground. Adds a "Try Orion" editor at the top and makes every
// sample runnable in place. Compiles via the playground server (tools/
// playground.js, POST /api/run -> dist/orion.exe), then instantiates the wasm
// and runs main(), with print_line output shown inline. Styled with the Field
// Guide's own CSS variables so it matches the page in light and dark.
(function () {
  const style = document.createElement('style');
  style.textContent = `
    .pg { margin: 1.2em 0; }
    .pg-bar { display:flex; align-items:center; gap:.8em; margin:0 0 .4em; }
    .pg-run { background:var(--link); color:var(--bg); border:0; border-radius:4px;
              padding:.25em .9em; font:inherit; font-weight:600; font-size:.9em;
              cursor:pointer; }
    .pg-run:disabled { opacity:.5; cursor:default; }
    .pg-run:focus-visible { outline:2px solid var(--focus); outline-offset:2px; }
    .pg-status { font-size:.82em; color:var(--dim); font-family:ui-monospace,monospace; }
    .pg code[contenteditable] { outline:none; display:block; white-space:pre; }
    .pg code[contenteditable]:focus { box-shadow: inset 0 0 0 2px var(--rule); }
    .pg-out { margin:.4em 0 0; padding:.7em 1em; border:1px solid var(--rule);
              border-radius:4px; background:var(--code-bg); color:var(--fg);
              font-family:ui-monospace,SFMono-Regular,monospace; font-size:.86em;
              line-height:1.5; white-space:pre-wrap; overflow:auto; }
    .pg-out .exit { color:var(--dim); }
    .pg-out.err { color:#c0392b; }
    @media (prefers-color-scheme: dark) { .pg-out.err { color:#ff8b7d; } }
    .pg-top { max-width:42rem; margin:1.5rem auto 2.5rem; padding:1.1em 1.2em;
              box-sizing:border-box; border:1px solid var(--rule);
              border-radius:8px; background:var(--code-bg); }
    .pg-top h2 { margin:0 0 .1em; font-size:1.05em; }
    .pg-top p { margin:0 0 .7em; font-size:.9em; color:var(--dim); }
    .pg-top textarea { width:100%; box-sizing:border-box; min-height:16em; resize:vertical;
              background:var(--bg); color:var(--fg); border:1px solid var(--rule);
              border-radius:4px; padding:.7em .9em; font-family:ui-monospace,monospace;
              font-size:.88em; line-height:1.55; tab-size:4; outline:none; }
    .pg-top textarea:focus { box-shadow: inset 0 0 0 1px var(--focus); }
  `;
  document.head.appendChild(style);

  function readText(mem, ptr) {
    const u = new Uint8Array(mem.buffer);
    const len = u[ptr] | (u[ptr + 1] << 8) | (u[ptr + 2] << 16) | (u[ptr + 3] << 24);
    return new TextDecoder().decode(u.subarray(ptr + 4, ptr + 4 + len));
  }

  // Write a [len][utf8] string into wasm linear memory using the module's own
  // bump allocator (the pointer lives at mem[0]) and return its pointer. Lets
  // host functions like file_read/argv hand a Text back to the program.
  function allocText(mem, s) {
    const bytes = new TextEncoder().encode(s);
    const u8 = new Uint8Array(mem.buffer);
    const dv = new DataView(mem.buffer);
    const ptr = dv.getUint32(0, true);
    dv.setUint32(ptr, bytes.length, true);
    u8.set(bytes, ptr + 4);
    dv.setUint32(0, ptr + 4 + bytes.length, true);
    return ptr;
  }

  async function run(source, btn, status, out) {
    btn.disabled = true; status.textContent = 'compiling…';
    out.style.display = 'block'; out.className = 'pg-out'; out.textContent = '';
    try {
      const res = await fetch('/api/run', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ source })
      }).then(r => r.json());
      if (!res.ok) {
        // A wasm-backend limitation reads as a calm note; a real syntax/type
        // error ("ERROR at line:col") stays red.
        if (/the wasm backend does not support/.test(res.error)) {
          const feats = [...new Set([...res.error.matchAll(/does not support `([A-Za-z_]+)`|calling `([A-Za-z_]+)`/g)]
            .map(m => m[1] || m[2]))].slice(0, 5);
          status.textContent = 'native only';
          out.className = 'pg-out';
          out.innerHTML = 'This example uses ' +
            (feats.length ? '<b>' + feats.join(', ') + '</b>' : 'a language feature') +
            ' that runs with the native Orion compiler (<code>orbit run</code>), not the ' +
            'in-browser playground. The playground runs the core: arithmetic, control flow, ' +
            'functions, lists, maps, structs, f64 and text.';
        } else {
          status.textContent = 'error'; out.className = 'pg-out err'; out.textContent = res.error;
        }
        return;
      }
      status.textContent = 'running…';
      const bytes = Uint8Array.from(atob(res.wasm), c => c.charCodeAt(0));
      let mem, text = '';
      const files = {}; // in-memory sandbox filesystem, fresh per run
      const env = {
        __print: (p, nl) => { text += readText(mem, p) + (nl ? '\n' : ''); },
        host_sin: Math.sin, host_cos: Math.cos, host_sqrt: Math.sqrt,
        // OS-IO stubs: a browser has no command line or filesystem, so argv is
        // empty and file IO round-trips through an in-memory sandbox.
        __argc: () => 1,
        __argv: (i) => allocText(mem, i === 0 ? 'playground' : ''),
        __file_write: (p, c) => { files[readText(mem, p)] = readText(mem, c); return 0; },
        __file_read: (p) => allocText(mem, files[readText(mem, p)] || ''),
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

  // --- the "Try Orion" editor at the top of the page ---
  const START = `fn main() -> int:
    print_line("Hello from Orion, compiled to WebAssembly.")
    mut sum = 0
    loop i in 1..=10:
        sum = sum + i
    print_line("sum 1..10 = {sum}")
    return sum`;

  const top = document.createElement('section');
  top.className = 'pg-top';
  top.innerHTML =
    '<h2>Try Orion</h2>' +
    '<p>Write a program and run it. It compiles to WebAssembly and runs right here. ' +
    'Ctrl/Cmd+Enter to run.</p>' +
    '<div class="pg-bar"><button class="pg-run">Run &#9654;</button>' +
    '<span class="pg-status"></span></div>' +
    '<textarea spellcheck="false"></textarea>' +
    '<pre class="pg-out" style="display:none"></pre>';
  const header = document.querySelector('header');
  header.parentNode.insertBefore(top, header.nextSibling);
  const ta = top.querySelector('textarea');
  ta.value = START;
  const topBtn = top.querySelector('.pg-run'), topStatus = top.querySelector('.pg-status'), topOut = top.querySelector('.pg-out');
  topBtn.onclick = () => run(ta.value, topBtn, topStatus, topOut);
  ta.addEventListener('keydown', e => { if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') { e.preventDefault(); topBtn.click(); } });

  // --- make every sample runnable in place ---
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
