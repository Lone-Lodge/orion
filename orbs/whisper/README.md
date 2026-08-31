# whisper

Speech to text, offline, on the CPU. The `mic` orb made Orion able to hear;
this makes it able to understand.

```orion
ear = hear_open("ggml-small.bin")
if ear >= 0:
    said = hear(ear, "heard.wav", "sv")
```

## Linking

The engine is the vendored whisper.cpp under `vendor/whisper/`, built once into
a static library. A project that uses this orb names both in its `Orbit.toml`:

```
link = "vendor/orion_whisper.c dist/libwhisper.a"
```

Build the library with `bash tools/whisper_build.sh`. It takes a minute and
then never runs again until the vendored source changes.

## Watch out for

Models are the ggml `.bin` files from `huggingface.co/ggerganov/whisper.cpp`
and are NOT vendored - `small` is half a gigabyte. `tiny` is enough to prove a
pipeline works; `small` is where Swedish starts being usable.

Audio comes in as a wav path and not a buffer, which is exactly what
`mic_take_wav` writes: mono PCM16 at 16 kHz. The two orbs are built to hand off
to each other with nothing in between.
