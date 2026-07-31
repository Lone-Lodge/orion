// Loads demo.wasm (compiled from demo.or by orion.exe) and runs it on a
// canvas. The wasm module calls back into these host functions; JS owns
// the graphics and the clock, Orion owns the animation logic.
const canvas = document.getElementById('c');
const ctx = canvas.getContext('2d');

const palette = [
  '#ff5a5f', '#ffb400', '#ffe66d', '#8ac926',
  '#22c1c3', '#3a86ff', '#8338ec', '#ff5ca2',
];

const env = {
  clear() {
    ctx.fillStyle = '#12131a';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
  },
  fill_circle(x, y, r, color) {
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fillStyle = palette[((color % 8) + 8) % 8];
    ctx.fill();
  },
  host_sin: Math.sin,
  host_cos: Math.cos,
};

WebAssembly.instantiateStreaming(fetch('demo.wasm'), { env }).then(({ instance }) => {
  const render = instance.exports.render;
  const start = performance.now();
  function frame() {
    render((performance.now() - start) / 1000);
    requestAnimationFrame(frame);
  }
  frame();
  document.getElementById('status').textContent = 'running: demo.wasm (compiled from demo.or)';
}).catch(err => {
  document.getElementById('status').textContent = 'error: ' + err;
});
