//! `image` — PNG decode/encode. Public API is pure Orion
//! (`orbs/image/lib.or`); implement PNG codec primitives here using
//! a small Rust-based decoder built on miniz_oxide for zlib/DEFLATE.

use std::fs;
use std::sync::Arc;

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
    let bytes = fs::read(path).ok()?;
    // Check signature
    if bytes.len() < 8 || &bytes[0..8] != b"\x89PNG\r\n\x1a\n" { return None; }
    let mut offset = 8usize;
    let mut width: u32 = 0;
    let mut height: u32 = 0;
    let mut bit_depth: u8 = 0;
    let mut color_type: u8 = 0;
    let mut compression_method: u8 = 0;
    let mut filter_method: u8 = 0;
    let mut interlace_method: u8 = 0;
    let mut idat_acc: Vec<u8> = Vec::new();

    while offset + 8 <= bytes.len() {
        let len = read_be_u32(&bytes[offset..offset+4]) as usize;
        let ctype = &bytes[offset+4..offset+8];
        let data_start = offset + 8;
        let data_end = data_start + len;
        if data_end + 4 > bytes.len() { return None; }
        let data = &bytes[data_start..data_end];
        // let crc = read_be_u32(&bytes[data_end..data_end+4]); // skipping CRC check
        if ctype == b"IHDR" {
            if data.len() < 13 { return None; }
            width = read_be_u32(&data[0..4]);
            height = read_be_u32(&data[4..8]);
            bit_depth = data[8];
            color_type = data[9];
            compression_method = data[10];
            filter_method = data[11];
            interlace_method = data[12];
            // enforce subset
            if bit_depth != 8 || compression_method != 0 || filter_method != 0 || interlace_method != 0 {
                return None;
            }
            if !(color_type == 0 || color_type == 2 || color_type == 4 || color_type == 6) { return None; }
        } else if ctype == b"IDAT" {
            idat_acc.extend_from_slice(data);
        } else if ctype == b"IEND" {
            break;
        }
        offset = data_end + 4;
    }

    // Decompress zlib-wrapped DEFLATE stream
    let decompressed = match miniz_oxide::inflate::decompress_to_vec_zlib(&idat_acc) {
        Ok(v) => v,
        Err(_) => return None,
    };

    // Reconstruct scanlines: each scanline starts with a filter byte then pixel bytes
    let bpp = match color_type {
        0 => 1, // gray
        2 => 3, // rgb
        4 => 2, // gray + alpha
        6 => 4, // rgba
        _ => return None,
    };
    let stride = (bpp as usize) * (width as usize);
    let expected = (stride + 1) * (height as usize);
    if decompressed.len() < expected { return None; }

    let mut out_pixels: Vec<u8> = vec![0u8; (width as usize) * (height as usize) * 4];
    let mut prev_row: Vec<u8> = vec![0u8; stride];
    let mut src_off = 0usize;
    for row in 0..(height as usize) {
        let filter = decompressed[src_off] as u8;
        src_off += 1;
        let row_bytes = &decompressed[src_off..src_off+stride];
        src_off += stride;
        let mut recon: Vec<u8> = vec![0u8; stride];
        match filter {
            0 => { recon.clone_from_slice(row_bytes); }
            1 => { // Sub
                for i in 0..stride {
                    let left = if i >= bpp as usize { recon[i - bpp as usize] } else { 0 };
                    recon[i] = row_bytes[i].wrapping_add(left);
                }
            }
            2 => { // Up
                for i in 0..stride {
                    let up = prev_row[i];
                    recon[i] = row_bytes[i].wrapping_add(up);
                }
            }
            3 => { // Average
                for i in 0..stride {
                    let left = if i >= bpp as usize { recon[i - bpp as usize] } else { 0 };
                    let up = prev_row[i];
                    let avg = ((left as u16 + up as u16) / 2) as u8;
                    recon[i] = row_bytes[i].wrapping_add(avg);
                }
            }
            4 => { // Paeth
                for i in 0..stride {
                    let a = if i >= bpp as usize { recon[i - bpp as usize] } else { 0 };
                    let b = prev_row[i];
                    let c = if i >= bpp as usize { prev_row[i - bpp as usize] } else { 0 };
                    let p = paeth_predictor(a as i32, b as i32, c as i32) as u8;
                    recon[i] = row_bytes[i].wrapping_add(p);
                }
            }
            _ => return None,
        }
        // expand to RGBA
        let pixel_row_start = row * (width as usize) * 4;
        for px in 0..(width as usize) {
            let src_idx = px * (bpp as usize);
            let dst_idx = pixel_row_start + px * 4;
            match color_type {
                0 => { // gray -> R=G=B=gray, A=255
                    let g = recon[src_idx];
                    out_pixels[dst_idx] = g;
                    out_pixels[dst_idx+1] = g;
                    out_pixels[dst_idx+2] = g;
                    out_pixels[dst_idx+3] = 255;
                }
                2 => { // RGB
                    out_pixels[dst_idx] = recon[src_idx];
                    out_pixels[dst_idx+1] = recon[src_idx+1];
                    out_pixels[dst_idx+2] = recon[src_idx+2];
                    out_pixels[dst_idx+3] = 255;
                }
                4 => { // gray+alpha
                    let g = recon[src_idx];
                    out_pixels[dst_idx] = g;
                    out_pixels[dst_idx+1] = g;
                    out_pixels[dst_idx+2] = g;
                    out_pixels[dst_idx+3] = recon[src_idx+1];
                }
                6 => { // RGBA
                    out_pixels[dst_idx] = recon[src_idx];
                    out_pixels[dst_idx+1] = recon[src_idx+1];
                    out_pixels[dst_idx+2] = recon[src_idx+2];
                    out_pixels[dst_idx+3] = recon[src_idx+3];
                }
                _ => {}
            }
        }
        prev_row = recon;
    }

    Some(build_image_map(width, height, 4, &out_pixels))
}

fn save_png(path: &str, width: u32, height: u32, pixels: &[u8]) -> bool {
    // Create a minimal non-interlaced RGBA8 PNG writer using zlib (deflate)
    // We will build raw scanlines with filter 0 and compress with zlib.
    let expected = (width as usize) * (height as usize) * 4;
    if pixels.len() < expected { return false; }

    // Build IHDR
    let mut out: Vec<u8> = Vec::new();
    out.extend_from_slice(b"\x89PNG\r\n\x1a\n");
    fn push_u32_be(v: &mut Vec<u8>, x: u32) { v.push(((x>>24)&0xFF) as u8); v.push(((x>>16)&0xFF) as u8); v.push(((x>>8)&0xFF) as u8); v.push((x&0xFF) as u8); }
    fn push_chunk(v: &mut Vec<u8>, typ: &[u8;4], data: &[u8]) {
        push_u32_be(v, data.len() as u32);
        v.extend_from_slice(typ);
        v.extend_from_slice(data);
        // CRC omitted (set to 0) — conservative but many decoders tolerate CRC 0
        v.push(0); v.push(0); v.push(0); v.push(0);
    }
    let mut ihdr: Vec<u8> = Vec::new();
    push_u32_be(&mut ihdr, width);
    push_u32_be(&mut ihdr, height);
    ihdr.push(8); // bit depth
    ihdr.push(6); // color type RGBA
    ihdr.push(0); // compression
    ihdr.push(0); // filter
    ihdr.push(0); // interlace
    push_chunk(&mut out, b"IHDR", &ihdr);

    // Build IDAT data (scanlines with filter 0)
    let mut scanlines: Vec<u8> = Vec::new();
    for row in 0..(height as usize) {
        scanlines.push(0); // filter 0
        let start = row * (width as usize) * 4;
        scanlines.extend_from_slice(&pixels[start..start + (width as usize)*4]);
    }
    // compress with zlib
    let compressed = miniz_oxide::deflate::compress_to_vec_zlib(&scanlines, 6);
    push_chunk(&mut out, b"IDAT", &compressed);
    push_chunk(&mut out, b"IEND", &[]);

    fs::write(path, out).is_ok()
}

fn build_image_map(width: u32, height: u32, channels: u32, pixels: &[u8]) -> Value {
    let pixel_list: Vec<Value> = pixels.iter().map(|b| Value::Int(*b as i64)).collect();
    Value::Map(Arc::new(vec![
        (Value::Text("width".into()), Value::Int(width as i64)),
        (Value::Text("height".into()), Value::Int(height as i64)),
        (Value::Text("channels".into()), Value::Int(channels as i64)),
        (Value::Text("pixels".into()), Value::List(Arc::new(pixel_list))),
    ]))
}

fn as_text(v: &Value) -> String {
    match v { Value::Text(s) => s.clone(), other => other.to_string() }
}

fn as_int(v: &Value) -> i64 {
    match v { Value::Int(n) => *n, Value::Float(x) => *x as i64, _ => 0 }
}

fn as_bytes(v: &Value) -> Vec<u8> {
    match v {
        Value::List(items) => items.iter().map(|x| match x { Value::Int(n) => (*n).max(0).min(255) as u8, Value::Float(f) => (*f as i64).max(0).min(255) as u8, _ => 0 }).collect(),
        _ => Vec::new(),
    }
}

fn read_be_u32(buf: &[u8]) -> u32 {
    ((buf[0] as u32) << 24) | ((buf[1] as u32) << 16) | ((buf[2] as u32) << 8) | (buf[3] as u32)
}

fn paeth_predictor(a: i32, b: i32, c: i32) -> i32 {
    let p = a + b - c;
    let pa = (p - a).abs();
    let pb = (p - b).abs();
    let pc = (p - c).abs();
    if pa <= pb && pa <= pc { a } else if pb <= pc { b } else { c }
}
