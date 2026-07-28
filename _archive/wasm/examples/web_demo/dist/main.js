const canvas = document.getElementById('c');
const ctx = canvas.getContext('2d');
const palette = ['#ef4444','#f97316','#eab308','#22c55e','#3b82f6','#a855f7'];

async function boot() {
  try {
    const response = await fetch('demo.wasm');
    const env = {
      fill_rect: (x, y, w, h, colour) => {
        ctx.fillStyle = palette[colour % palette.length];
        ctx.fillRect(x, y, w, h);
      }
    };
    const { instance } = await WebAssembly.instantiateStreaming(response, { env });
    instance.exports.draw();
  } catch (e) {
    document.body.append(document.createTextNode('boot error: ' + e));
  }
}
boot();
