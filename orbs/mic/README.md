# mic

Microphone capture, the other half of the audio stack. atlas_audio can make
sound; nothing in Orion could hear until this.

```orion
if mic_open(16000):
    loop:
        if mic_level() > 20:              # someone started talking
            frames = mic_take_wav("heard.wav")
```

It is a baseline orb and not a game seam on purpose: a mic is a platform
capability like the filesystem, and voice tools, authoring tools and games all
want it on the same terms.

Capture runs on its own thread into a ring that keeps the last 30 seconds and
overwrites the oldest. A listener always wants what was just said, so falling
behind costs you history, never the present.

The device picks its own rate and channel count. `rate` is what YOU want, and
the ring downmixes to mono and decimates on the way in. Speech recognisers want
16000.

## Watch out for

Headless builds link the weak null backend in `orion_rt.c` instead of
`wasapi_min.c`: `mic_open` succeeds, the level is silent forever, and a take
writes nothing. Gates run the whole listen path without a sound card - which is
also why a silent recording on a real machine looks exactly like a headless
build.
