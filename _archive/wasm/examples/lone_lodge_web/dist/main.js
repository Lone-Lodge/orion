const canvas = document.getElementById('c');
const ctx = canvas.getContext('2d');
let currentFill = '#000';
let currentStroke = '#000';
let memory;
function readUtf8(ptr, len) {
  const bytes = new Uint8Array(memory.buffer, ptr, len);
  return new TextDecoder('utf-8').decode(bytes);
}
const env = {
  set_fill: (r,g,b) => { currentFill = `rgb(${r},${g},${b})`; ctx.fillStyle = currentFill; },
  fill_rect: (x,y,w,h) => { ctx.fillStyle = currentFill; ctx.fillRect(x,y,w,h); },
  set_stroke: (r,g,b) => { currentStroke = `rgb(${r},${g},${b})`; ctx.strokeStyle = currentStroke; },
  stroke_rect: (x,y,w,h) => { ctx.strokeStyle = currentStroke; ctx.strokeRect(x,y,w,h); },
  draw_text: (x,y,ptr,len) => { ctx.fillStyle = '#fff'; ctx.font = '16px system-ui'; ctx.fillText(readUtf8(ptr,len), x, y); }
};

let running = false;
let currentTick = 0;
let renderScene, renderFrame;

function stop() { running = false; }
function startAnimation() { if (running) return; running = true; (function loop(){ if(!running) return; renderFrame(currentTick++); requestAnimationFrame(loop); })(); }

async function boot() {
  try {
    const { instance } = await WebAssembly.instantiateStreaming(fetch('lone_lodge.wasm'), { env });
    memory = instance.exports.memory;
    renderScene = instance.exports.render;
    renderFrame = instance.exports.render_frame;
    document.getElementById('static').onclick = () => { stop(); renderScene(); };
    document.getElementById('animate').onclick = () => { stop(); requestAnimationFrame(startAnimation); };
    renderScene();
  } catch (e) {
    document.body.append(document.createTextNode('boot error: ' + e));
  }
}
boot();
