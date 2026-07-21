const canvas = document.getElementById('c');
const ctx = canvas.getContext('2d');
let currentFill = '#000';
const env = {
  set_fill: (r,g,b) => { currentFill = `rgb(${r},${g},${b})`; ctx.fillStyle = currentFill; },
  fill_rect: (x,y,w,h) => { ctx.fillStyle = currentFill; ctx.fillRect(x,y,w,h); }
};

async function boot() {
  try {
    const { instance } = await WebAssembly.instantiateStreaming(fetch('atlas.wasm'), { env });
    const render = instance.exports.render;
    let tick = 0;
    function frame() {
      render(tick);
      tick += 1;
      requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
  } catch (e) {
    document.body.append(document.createTextNode('boot error: ' + e));
  }
}
boot();
