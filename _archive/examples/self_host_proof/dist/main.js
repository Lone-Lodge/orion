const canvas = document.getElementById('c');
const ctx = canvas.getContext('2d');
let currentFill = '#000';
let currentStroke = '#000';
let memory;
function readUtf8(p, l) { return new TextDecoder().decode(new Uint8Array(memory.buffer, p, l)); }
const env = {
  set_fill: (r,g,b) => { currentFill = `rgb(${r},${g},${b})`; ctx.fillStyle = currentFill; },
  fill_rect: (x,y,w,h) => { ctx.fillStyle = currentFill; ctx.fillRect(x,y,w,h); },
  set_stroke: (r,g,b) => { currentStroke = `rgb(${r},${g},${b})`; ctx.strokeStyle = currentStroke; },
  stroke_rect: (x,y,w,h) => { ctx.strokeStyle = currentStroke; ctx.strokeRect(x,y,w,h); },
  draw_text: (x,y,p,l) => { ctx.fillStyle = currentFill; ctx.font = '16px system-ui'; ctx.fillText(readUtf8(p,l), x, y); }
};
async function boot() {
  const { instance } = await WebAssembly.instantiateStreaming(fetch('self_host.wasm'), { env });
  memory = instance.exports.memory;
  if (instance.exports.render) instance.exports.render();
  if (instance.exports.render_frame) { let t=0; (function loop(){ instance.exports.render_frame(t++); requestAnimationFrame(loop); })(); }
}
boot();
