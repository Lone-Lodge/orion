// host imports map directly to <canvas> 2D ops. Pure Orion wasm
// drives the sequence; this file is the painter.
const canvas = document.getElementById('c');
const ctx = canvas.getContext('2d');

// Tiny glyph table â the wasm passes the index, we paint the label.
const glyphs = ['Header', 'Item', 'Veil', 'Click'];

let currentFont = '16px system-ui, sans-serif';
let currentFill = '#000';
let currentStroke = '#000';

const env = {
  set_fill: (r, g, b) => {
    currentFill = `rgb(${r}, ${g}, ${b})`;
    ctx.fillStyle = currentFill;
  },
  fill_rect: (x, y, w, h) => {
    ctx.fillStyle = currentFill;
    ctx.fillRect(x, y, w, h);
  },
  set_stroke: (r, g, b) => {
    currentStroke = `rgb(${r}, ${g}, ${b})`;
    ctx.strokeStyle = currentStroke;
  },
  stroke_rect: (x, y, w, h) => {
    ctx.strokeStyle = currentStroke;
    ctx.strokeRect(x, y, w, h);
  },
  set_font_px: (size) => {
    currentFont = `${size}px system-ui, sans-serif`;
    ctx.font = currentFont;
  },
  draw_text: (x, y, glyphIdx) => {
    ctx.font = currentFont;
    ctx.fillStyle = currentFill;
    ctx.fillText(glyphs[glyphIdx] || '?', x, y);
  }
};

async function boot() {
  try {
    const response = await fetch('veil.wasm');
    const { instance } = await WebAssembly.instantiateStreaming(response, { env });
    instance.exports.render();
  } catch (e) {
    document.body.append(document.createTextNode('boot error: ' + e));
  }
}
boot();
