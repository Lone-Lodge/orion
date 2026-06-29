//! `image` — PNG decode/encode. Public API is pure Orion
//! (`orbs/image/lib.or`); only the PNG codec primitives stay native.
//! `image_blank` moved to Orion since it's just zero-filled bytes.

use std::fs::File;
use std::io::{BufReader, BufWriter};

use crate::interp::Interp;
use crate::value::Value;

pub const SOURCE: &str = include_str!("../../../orbs/image/lib.or");

pub fn register(interp: &Interp) {
    interp.register_extern("__os_image_load_png", |args| {
        let path = as_text(&args[0]);
        match load_png(&path) {
            Some(img) => Ok(img),
            None => Ok(Value::None),
        }
    });
    interp.register_extern("__os_image_save_png", |args| {
        let path = as_text(&args[0]);
        let width = as_int(&args[1]).max(0) as u32;
        let height = as_int(&args[2]).max(0) as u32;
        let pixels = as_bytes(&args[3]);
        Ok(Value::Bool(save_png(&path, width, height, &pixels)))
    });
}

fn load_png(path: &str) -> Option<Value> {
    let file = File::open(path).ok()?;
    let decoder = png::Decoder::new(BufReader::new(file));
    let mut reader = decoder.read_info().ok()?;
    let mut buf = vec![0u8; reader.output_buffer_size()];
    let info = reader.next_frame(&mut buf).ok()?;
    let pixels = expand_to_rgba8(&buf[..info.buffer_size()], &info)?;
    Some(build_image_map(info.width, info.height, 4, &pixels))
}

fn expand_to_rgba8(raw: &[u8], info: &png::OutputInfo) -> Option<Vec<u8>> {
    if info.bit_depth != png::BitDepth::Eight {
        return None;
    }
    let pixel_count = (info.width as usize) * (info.height as usize);
    let mut out = Vec::with_capacity(pixel_count * 4);
    match info.color_type {
        png::ColorType::Rgba => out.extend_from_slice(&raw[..pixel_count * 4]),
        png::ColorType::Rgb => {
            for chunk in raw.chunks_exact(3).take(pixel_count) {
                out.extend_from_slice(&[chunk[0], chunk[1], chunk[2], 255]);
            }
        }
        png::ColorType::GrayscaleAlpha => {
            for chunk in raw.chunks_exact(2).take(pixel_count) {
                let g = chunk[0];
                out.extend_from_slice(&[g, g, g, chunk[1]]);
            }
        }
        png::ColorType::Grayscale => {
            for &g in raw.iter().take(pixel_count) {
                out.extend_from_slice(&[g, g, g, 255]);
            }
        }
        png::ColorType::Indexed => return None,
    }
    Some(out)
}

fn save_png(path: &str, width: u32, height: u32, pixels: &[u8]) -> bool {
    let expected = (width as usize) * (height as usize) * 4;
    if pixels.len() < expected {
        return false;
    }
    let file = match File::create(path) {
        Ok(f) => BufWriter::new(f),
        Err(_) => return false,
    };
    let mut encoder = png::Encoder::new(file, width, height);
    encoder.set_color(png::ColorType::Rgba);
    encoder.set_depth(png::BitDepth::Eight);
    let mut writer = match encoder.write_header() {
        Ok(w) => w,
        Err(_) => return false,
    };
    writer.write_image_data(&pixels[..expected]).is_ok()
}

fn build_image_map(width: u32, height: u32, channels: u32, pixels: &[u8]) -> Value {
    let pixel_list: Vec<Value> = pixels.iter().map(|b| Value::Int(*b as i64)).collect();
    Value::Map(std::sync::Arc::new(vec![
        (Value::Text("width".into()), Value::Int(width as i64)),
        (Value::Text("height".into()), Value::Int(height as i64)),
        (Value::Text("channels".into()), Value::Int(channels as i64)),
        (Value::Text("pixels".into()), Value::List(std::sync::Arc::new(pixel_list))),
    ]))
}

fn as_text(v: &Value) -> String {
    match v {
        Value::Text(s) => s.clone(),
        other => other.to_string(),
    }
}

fn as_int(v: &Value) -> i64 {
    match v {
        Value::Int(n) => *n,
        Value::Float(x) => *x as i64,
        _ => 0,
    }
}

fn as_bytes(v: &Value) -> Vec<u8> {
    match v {
        Value::List(items) => items
            .iter()
            .map(|x| match x {
                Value::Int(n) => (*n).max(0).min(255) as u8,
                Value::Float(f) => (*f as i64).max(0).min(255) as u8,
                _ => 0,
            })
            .collect(),
        _ => Vec::new(),
    }
}
