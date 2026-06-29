//! `audio` — cpal output stream + a hand-rolled RIFF/WAV decoder. The stream
//! is kept alive in a thread-local because cpal's `Stream` is `!Send` on some
//! platforms; the bound closures push samples through an Arc<Mutex<VecDeque>>.

use std::cell::RefCell;
use std::collections::VecDeque;
use std::fs;
use std::sync::{Arc, Mutex};

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};

use crate::interp::Interp;
use crate::value::Value;

pub const SOURCE: &str = include_str!("../../../orbs/audio/lib.or");

struct AudioState {
    queue: Arc<Mutex<VecDeque<f32>>>,
    _stream: cpal::Stream,
    sample_rate: u32,
}

thread_local! {
    static AUDIO: RefCell<Option<AudioState>> = const { RefCell::new(None) };
}

pub fn register(interp: &Interp) {
    interp.register_extern("__os_audio_init", |_args| {
        Ok(Value::Bool(AUDIO.with(|a| {
            let mut a = a.borrow_mut();
            if a.is_some() {
                return true;
            }
            match start_stream() {
                Some(state) => { *a = Some(state); true }
                None => false,
            }
        })))
    });

    interp.register_extern("__os_audio_sample_rate", |_args| {
        Ok(Value::Int(AUDIO.with(|a| {
            a.borrow().as_ref().map(|s| s.sample_rate as i64).unwrap_or(0)
        })))
    });

    interp.register_extern("__os_audio_play", |args| {
        let samples = as_floats(&args[0]);
        AUDIO.with(|a| {
            if let Some(state) = a.borrow().as_ref() {
                if let Ok(mut q) = state.queue.lock() {
                    for s in samples {
                        q.push_back((s as f32).clamp(-1.0, 1.0));
                    }
                }
            }
        });
        Ok(Value::Unit)
    });

    interp.register_extern("__os_audio_stop", |_args| {
        AUDIO.with(|a| {
            if let Some(state) = a.borrow().as_ref() {
                if let Ok(mut q) = state.queue.lock() {
                    q.clear();
                }
            }
        });
        Ok(Value::Unit)
    });

    interp.register_extern("__os_audio_load_wav", |args| {
        let path = as_text(&args[0]);
        Ok(decode_wav(&path).unwrap_or(Value::None))
    });
}

fn start_stream() -> Option<AudioState> {
    let host = cpal::default_host();
    let device = host.default_output_device()?;
    let config = device.default_output_config().ok()?;
    let sample_rate = config.sample_rate().0;
    let channels = config.channels() as usize;
    let stream_cfg: cpal::StreamConfig = config.into();

    let queue: Arc<Mutex<VecDeque<f32>>> = Arc::new(Mutex::new(VecDeque::new()));
    let queue_cb = queue.clone();

    let stream = device.build_output_stream(
        &stream_cfg,
        move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
            let mut q = match queue_cb.lock() {
                Ok(g) => g,
                Err(p) => p.into_inner(),
            };
            // The device may want N channels; we feed the queue per-frame and
            // duplicate the same sample across channels so a mono buffer plays
            // centred on stereo hardware.
            let frames = data.len() / channels.max(1);
            for f in 0..frames {
                let s = q.pop_front().unwrap_or(0.0);
                for c in 0..channels {
                    data[f * channels + c] = s;
                }
            }
        },
        |err| eprintln!("audio stream error: {err}"),
        None,
    ).ok()?;
    stream.play().ok()?;

    Some(AudioState { queue, _stream: stream, sample_rate })
}

// ---- WAV decoder ----

fn decode_wav(path: &str) -> Option<Value> {
    let bytes = fs::read(path).ok()?;
    if bytes.len() < 44 || &bytes[0..4] != b"RIFF" || &bytes[8..12] != b"WAVE" {
        return None;
    }

    // Walk chunks; only `fmt ` and `data` are interesting.
    let mut fmt: Option<WavFmt> = None;
    let mut data_range: Option<(usize, usize)> = None;
    let mut i = 12;
    while i + 8 <= bytes.len() {
        let id = &bytes[i..i + 4];
        let size = u32::from_le_bytes(bytes[i + 4..i + 8].try_into().ok()?) as usize;
        let body = i + 8;
        let end = body + size;
        if end > bytes.len() {
            return None;
        }
        match id {
            b"fmt " => fmt = parse_fmt(&bytes[body..end]),
            b"data" => data_range = Some((body, end)),
            _ => {}
        }
        // Chunks are padded to even byte boundaries.
        i = end + (end & 1);
    }

    let fmt = fmt?;
    let (lo, hi) = data_range?;
    let samples = decode_samples(&bytes[lo..hi], &fmt)?;

    Some(Value::Map(std::sync::Arc::new(vec![
        (Value::Text("sample_rate".into()), Value::Int(fmt.sample_rate as i64)),
        (Value::Text("channels".into()), Value::Int(fmt.channels as i64)),
        (Value::Text("samples".into()), Value::List(std::sync::Arc::new(samples.into_iter().map(Value::Float).collect()))),
    ])))
}

struct WavFmt {
    format: u16,       // 1 = PCM int, 3 = IEEE float
    channels: u16,
    sample_rate: u32,
    bits_per_sample: u16,
}

fn parse_fmt(body: &[u8]) -> Option<WavFmt> {
    if body.len() < 16 {
        return None;
    }
    Some(WavFmt {
        format: u16::from_le_bytes(body[0..2].try_into().ok()?),
        channels: u16::from_le_bytes(body[2..4].try_into().ok()?),
        sample_rate: u32::from_le_bytes(body[4..8].try_into().ok()?),
        bits_per_sample: u16::from_le_bytes(body[14..16].try_into().ok()?),
    })
}

fn decode_samples(data: &[u8], fmt: &WavFmt) -> Option<Vec<f64>> {
    let bytes_per_sample = (fmt.bits_per_sample / 8) as usize;
    if bytes_per_sample == 0 {
        return None;
    }
    let n = data.len() / bytes_per_sample;
    let mut out = Vec::with_capacity(n);
    match (fmt.format, fmt.bits_per_sample) {
        (1, 16) => {
            for chunk in data.chunks_exact(2) {
                let s = i16::from_le_bytes([chunk[0], chunk[1]]);
                out.push(s as f64 / 32768.0);
            }
        }
        (1, 8) => {
            // 8-bit PCM is unsigned, centred at 128.
            for &b in data {
                out.push((b as f64 - 128.0) / 128.0);
            }
        }
        (1, 24) => {
            for chunk in data.chunks_exact(3) {
                let v = i32::from_le_bytes([chunk[0], chunk[1], chunk[2], if chunk[2] & 0x80 != 0 { 0xFF } else { 0 }]);
                out.push(v as f64 / 8_388_608.0);
            }
        }
        (1, 32) => {
            for chunk in data.chunks_exact(4) {
                let v = i32::from_le_bytes(chunk.try_into().ok()?);
                out.push(v as f64 / 2_147_483_648.0);
            }
        }
        (3, 32) => {
            for chunk in data.chunks_exact(4) {
                out.push(f32::from_le_bytes(chunk.try_into().ok()?) as f64);
            }
        }
        _ => return None, // unusual rate / format
    }
    Some(out)
}

fn as_floats(v: &Value) -> Vec<f64> {
    match v {
        Value::List(items) => items.iter().map(as_f64).collect(),
        _ => Vec::new(),
    }
}
fn as_f64(v: &Value) -> f64 {
    match v { Value::Int(n) => *n as f64, Value::Float(x) => *x, _ => 0.0 }
}
fn as_text(v: &Value) -> String {
    match v { Value::Text(s) => s.clone(), other => other.to_string() }
}
