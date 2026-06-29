//! Tests for the `audio` orb — WAV decode + lifecycle. We don't actually play
//! audio in CI (no output device available); the playback path is exercised
//! via `audio_init`/`audio_play` returning without panicking.

use orion::interp::Interp;
use orion::stdlib;
use orion::value::Value;

fn run_with_orb(orb: &str, user: &str, fname: &str) -> Value {
    let o = stdlib::find(orb).expect(orb);
    let src = format!("{}\n{}", o.source, user);
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    orion::check::check(&p).unwrap();
    orion::typeck::check_types(&p).unwrap();
    let interp = Interp::new(&p);
    (o.register)(&interp);
    interp.call(fname, vec![]).unwrap()
}

/// Hand-build a 16-bit mono PCM WAV with the given samples — same shape as a
/// short SFX file produced by Audacity, etc.
fn synth_wav(samples: &[i16], sample_rate: u32) -> Vec<u8> {
    let data_size = samples.len() * 2;
    let riff_size = 36 + data_size;

    let mut bytes = Vec::with_capacity(44 + data_size);
    bytes.extend_from_slice(b"RIFF");
    bytes.extend_from_slice(&(riff_size as u32).to_le_bytes());
    bytes.extend_from_slice(b"WAVE");

    bytes.extend_from_slice(b"fmt ");
    bytes.extend_from_slice(&16u32.to_le_bytes());
    bytes.extend_from_slice(&1u16.to_le_bytes());                 // PCM int
    bytes.extend_from_slice(&1u16.to_le_bytes());                 // mono
    bytes.extend_from_slice(&sample_rate.to_le_bytes());
    bytes.extend_from_slice(&(sample_rate * 2).to_le_bytes());    // byte rate
    bytes.extend_from_slice(&2u16.to_le_bytes());                 // block align
    bytes.extend_from_slice(&16u16.to_le_bytes());                // bits

    bytes.extend_from_slice(b"data");
    bytes.extend_from_slice(&(data_size as u32).to_le_bytes());
    for s in samples {
        bytes.extend_from_slice(&s.to_le_bytes());
    }
    bytes
}

#[test]
fn wav_decoder_reads_pcm16_mono() {
    // Three samples: max-positive, silence, max-negative.
    let wav = synth_wav(&[i16::MAX, 0, i16::MIN], 44100);
    let tmp = std::env::temp_dir().join(format!("orion_test_{}.wav", std::process::id()));
    std::fs::write(&tmp, &wav).unwrap();
    let path = tmp.to_str().unwrap().replace('\\', "\\\\");

    let orb = stdlib::find("audio").unwrap();
    let src = format!(
        "{}\nfn sr() -> int = get(audio_load_wav(\"{path}\"), \"sample_rate\")\nfn ch() -> int = get(audio_load_wav(\"{path}\"), \"channels\")\nfn n() -> int = len(get(audio_load_wav(\"{path}\"), \"samples\"))\nfn s0() -> f64 = at(get(audio_load_wav(\"{path}\"), \"samples\"), 0)\n",
        orb.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (orb.register)(&interp);
    assert_eq!(interp.call("sr", vec![]).unwrap(), Value::Int(44100));
    assert_eq!(interp.call("ch", vec![]).unwrap(), Value::Int(1));
    assert_eq!(interp.call("n", vec![]).unwrap(), Value::Int(3));

    // First sample is i16::MAX / 32768 ≈ 0.99997
    if let Value::Float(s0) = interp.call("s0", vec![]).unwrap() {
        assert!((s0 - 0.99997).abs() < 1e-4, "got {s0}");
    } else { panic!() }

    let _ = std::fs::remove_file(&tmp);
}

#[test]
fn wav_load_missing_file_returns_none() {
    let src = "fn f() = audio_load_wav(\"this_does_not_exist_xyz.wav\")";
    assert_eq!(run_with_orb("audio", src, "f"), Value::None);
}

#[test]
fn wav_load_garbage_returns_none() {
    let tmp = std::env::temp_dir().join(format!("orion_badwav_{}.wav", std::process::id()));
    std::fs::write(&tmp, b"this is not a wav file").unwrap();
    let path = tmp.to_str().unwrap().replace('\\', "\\\\");
    let src = format!("fn f() = audio_load_wav(\"{path}\")");
    assert_eq!(run_with_orb("audio", &src, "f"), Value::None);
    let _ = std::fs::remove_file(&tmp);
}

// cpal opens a real audio device and runs a callback thread; on a headless
// CI box (no driver) it can block for a long time. Run with `--ignored` to
// verify real playback locally.
#[test]
#[ignore]
fn audio_init_and_sample_rate_dont_crash() {
    // We can't assert init returns true (CI may have no output device) but it
    // must not panic, and sample_rate must be coherent with init's result.
    let orb = stdlib::find("audio").unwrap();
    let src = format!(
        "{}\nfn init() -> bool = audio_init()\nfn sr() -> int = audio_sample_rate()\n",
        orb.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (orb.register)(&interp);

    let initialized = matches!(interp.call("init", vec![]).unwrap(), Value::Bool(true));
    let sr = interp.call("sr", vec![]).unwrap();
    match (initialized, sr) {
        (true, Value::Int(n)) => assert!(n > 0, "init succeeded but sample_rate is {n}"),
        (false, Value::Int(0)) => {} // headless / no output device — expected
        other => panic!("inconsistent audio state: {other:?}"),
    }
}

#[test]
#[ignore]
fn audio_play_and_stop_dont_crash() {
    let orb = stdlib::find("audio").unwrap();
    let src = format!(
        "{}\nfn run():\n    _ = audio_init()\n    audio_play([0.0, 0.1, 0.2])\n    audio_stop()\n",
        orb.source
    );
    let p = orion::parse(&orion::lex(&src).unwrap()).unwrap();
    let interp = Interp::new(&p);
    (orb.register)(&interp);
    // Just verify it runs to completion.
    interp.call("run", vec![]).unwrap();
}

#[test]
fn audio_orb_is_registered() {
    let names: Vec<&str> = stdlib::ORBS.iter().map(|o| o.name).collect();
    assert!(names.contains(&"audio"));
}
