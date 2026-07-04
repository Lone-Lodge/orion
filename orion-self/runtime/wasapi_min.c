/* wasapi_min.c — the in-house potato mixer, v2.
 *
 * Raw WASAPI shared mode, one render thread, 32 voices, three buses
 * (0 sfx, 1 music, 2 ui) under a master. WAV assets (PCM16 / f32,
 * mono/stereo, any rate) are converted to device-rate stereo f32 at
 * load — the mix loop is a dumb fused multiply-add, no DSP graph.
 *
 * v2 adds what a full game needs and nothing more:
 *   - per-voice volume FADES (fade_ms on start, gain change, stop) —
 *     crossfades and rule-driven ducking without clicks
 *   - LOOP voices with stable handles (slot+generation) so scripts
 *     can start, retune and stop named loops
 *   - LAYERS: loop voices sample-synced to the music clock — vertical
 *     interactive music driven by gain fades
 *   - voice STEALING: when full, the quietest fading/one-shot dies
 *     (loops and music are never stolen)
 *
 * This file OVERRIDES the weak no-op stubs in orion_rt.c: link it
 * (orbit native does) and games get sound; leave it out (headless
 * gates) and the same calls count silently. The game-facing seam is
 * atlas_audio — swapping this backend for an FMOD/Wwise adapter
 * later never touches game code.
 */
#ifdef _WIN32
#define _CRT_SECURE_NO_WARNINGS
#define WIN32_LEAN_AND_MEAN
#define COBJMACROS
#define INITGUID
#include <windows.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

DEFINE_GUID(OA_CLSID_MMDeviceEnumerator, 0xBCDE0395, 0xE52F, 0x467C,
            0x8E, 0x3D, 0xC4, 0x57, 0x92, 0x91, 0x69, 0x2E);
DEFINE_GUID(OA_IID_IMMDeviceEnumerator, 0xA95664D2, 0x9614, 0x4F35,
            0xA7, 0x46, 0xDE, 0x8D, 0xB6, 0x36, 0x17, 0xE6);
DEFINE_GUID(OA_IID_IAudioClient, 0x1CB9AD4C, 0xDBFA, 0x4C32, 0xB1,
            0x78, 0xC2, 0xF5, 0x68, 0xA7, 0x03, 0xB2);
DEFINE_GUID(OA_IID_IAudioRenderClient, 0xF294ACFC, 0x3146, 0x4483,
            0xA7, 0xBF, 0xAD, 0xDC, 0xA7, 0xC2, 0x60, 0xE2);

#define OA_MAX_SOUNDS 256
#define OA_MAX_VOICES 32
#define OA_BUSES 3

typedef struct {
    float *frames; /* stereo interleaved f32 at device rate */
    long long nframes;
} OaSound;

typedef struct {
    int active;
    int gen; /* bumps on reuse — stale handles miss */
    int sound;
    int loop;
    int bus;
    long long pos_fp; /* 16.16 frame position */
    long long step_fp;
    float pan_l, pan_r;
    float vol;        /* current volume, walks toward target */
    float vol_target;
    float vol_step;   /* per-frame delta */
    int die_on_zero;  /* stop request: deactivate when vol hits 0 */
} OaVoice;

static IAudioClient *oa_client;
static IAudioRenderClient *oa_render;
static HANDLE oa_event, oa_thread;
static CRITICAL_SECTION oa_cs;
static volatile int oa_running;
static int oa_rate = 48000;
static int oa_out_f32 = 1;
static UINT32 oa_buffer_frames;
static OaSound oa_sounds[OA_MAX_SOUNDS];
static int oa_nsounds;
static OaVoice oa_voices[OA_MAX_VOICES];
static float oa_bus_vol[OA_BUSES] = {1.0f, 1.0f, 1.0f};
static float oa_bus_target[OA_BUSES] = {1.0f, 1.0f, 1.0f};
static float oa_bus_step[OA_BUSES];
static float oa_master = 1.0f;
static int oa_music_voice = -1;
static long long oa_total_plays;
static int oa_ok;

static float oa_step_for(float from, float to, long long fade_ms) {
    if (fade_ms <= 0) return 2.0f; /* bigger than any gap: instant */
    float frames = (float)fade_ms * oa_rate / 1000.0f;
    float d = to - from;
    if (d < 0) d = -d;
    if (frames < 1.0f) frames = 1.0f;
    return d / frames;
}

static void oa_mix(float *dst, UINT32 nframes) {
    memset(dst, 0, nframes * 2 * sizeof(float));
    EnterCriticalSection(&oa_cs);
    for (int b = 0; b < OA_BUSES; b++) {
        /* bus fades step once per BLOCK-frame inside the voice loop
         * below would drift per voice; step them here per frame via a
         * precomputed walk instead: apply per-sample in voice loop
         * using a local copy advanced identically for every voice is
         * overkill for 20ms blocks — step the whole block at once. */
        float step = oa_bus_step[b] * nframes;
        if (oa_bus_vol[b] < oa_bus_target[b]) {
            oa_bus_vol[b] += step;
            if (oa_bus_vol[b] > oa_bus_target[b]) oa_bus_vol[b] = oa_bus_target[b];
        } else if (oa_bus_vol[b] > oa_bus_target[b]) {
            oa_bus_vol[b] -= step;
            if (oa_bus_vol[b] < oa_bus_target[b]) oa_bus_vol[b] = oa_bus_target[b];
        }
    }
    for (int v = 0; v < OA_MAX_VOICES; v++) {
        OaVoice *vo = &oa_voices[v];
        if (!vo->active) continue;
        OaSound *s = &oa_sounds[vo->sound];
        float bg = oa_bus_vol[vo->bus] * oa_master;
        for (UINT32 i = 0; i < nframes; i++) {
            long long fi = vo->pos_fp >> 16;
            if (fi >= s->nframes) {
                if (vo->loop && s->nframes > 0) {
                    vo->pos_fp = 0;
                    fi = 0;
                } else {
                    vo->active = 0;
                    break;
                }
            }
            if (vo->vol < vo->vol_target) {
                vo->vol += vo->vol_step;
                if (vo->vol > vo->vol_target) vo->vol = vo->vol_target;
            } else if (vo->vol > vo->vol_target) {
                vo->vol -= vo->vol_step;
                if (vo->vol < vo->vol_target) vo->vol = vo->vol_target;
            }
            if (vo->die_on_zero && vo->vol <= 0.0001f) {
                vo->active = 0;
                break;
            }
            float g = bg * vo->vol;
            dst[i * 2] += s->frames[fi * 2] * vo->pan_l * g;
            dst[i * 2 + 1] += s->frames[fi * 2 + 1] * vo->pan_r * g;
            vo->pos_fp += vo->step_fp;
        }
    }
    LeaveCriticalSection(&oa_cs);
    /* Soft clip keeps stacked clears from crackling. */
    for (UINT32 i = 0; i < nframes * 2; i++) {
        float x = dst[i];
        if (x > 1.0f) x = 1.0f;
        if (x < -1.0f) x = -1.0f;
        dst[i] = x;
    }
}

static DWORD WINAPI oa_thread_main(LPVOID arg) {
    (void)arg;
    while (oa_running) {
        if (WaitForSingleObject(oa_event, 200) != WAIT_OBJECT_0) continue;
        UINT32 padding = 0;
        if (FAILED(IAudioClient_GetCurrentPadding(oa_client, &padding))) continue;
        UINT32 avail = oa_buffer_frames - padding;
        if (avail == 0) continue;
        BYTE *buf;
        if (FAILED(IAudioRenderClient_GetBuffer(oa_render, avail, &buf))) continue;
        if (oa_out_f32) {
            oa_mix((float *)buf, avail);
        } else {
            static float scratch[4096 * 2];
            UINT32 n = avail > 4096 ? 4096 : avail;
            oa_mix(scratch, n);
            short *out = (short *)buf;
            for (UINT32 i = 0; i < n * 2; i++)
                out[i] = (short)(scratch[i] * 32767.0f);
            avail = n;
        }
        IAudioRenderClient_ReleaseBuffer(oa_render, avail, 0);
    }
    return 0;
}

long long orion_audio_init(void) {
    if (oa_ok) return 1;
    CoInitializeEx(NULL, COINIT_MULTITHREADED);
    IMMDeviceEnumerator *devenum = NULL;
    IMMDevice *dev = NULL;
    WAVEFORMATEX *fmt = NULL;
    if (FAILED(CoCreateInstance(&OA_CLSID_MMDeviceEnumerator, NULL,
                                CLSCTX_ALL, &OA_IID_IMMDeviceEnumerator,
                                (void **)&devenum)))
        return 0;
    if (FAILED(IMMDeviceEnumerator_GetDefaultAudioEndpoint(devenum, eRender,
                                                           eConsole, &dev))) {
        IMMDeviceEnumerator_Release(devenum);
        return 0;
    }
    if (FAILED(IMMDevice_Activate(dev, &OA_IID_IAudioClient, CLSCTX_ALL, NULL,
                                  (void **)&oa_client))) {
        IMMDevice_Release(dev);
        IMMDeviceEnumerator_Release(devenum);
        return 0;
    }
    IAudioClient_GetMixFormat(oa_client, &fmt);
    oa_rate = (int)fmt->nSamplesPerSec;
    oa_out_f32 = 1;
    if (fmt->wFormatTag == WAVE_FORMAT_PCM ||
        (fmt->wFormatTag == WAVE_FORMAT_EXTENSIBLE &&
         ((WAVEFORMATEXTENSIBLE *)fmt)->SubFormat.Data1 == 1))
        oa_out_f32 = 0;
    if (fmt->nChannels != 2) {
        fmt->nChannels = 2;
        fmt->nBlockAlign = (WORD)(2 * fmt->wBitsPerSample / 8);
        fmt->nAvgBytesPerSec = fmt->nSamplesPerSec * fmt->nBlockAlign;
    }
    if (FAILED(IAudioClient_Initialize(oa_client, AUDCLNT_SHAREMODE_SHARED,
                                       AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
                                       200000, 0, fmt, NULL))) {
        CoTaskMemFree(fmt);
        IMMDevice_Release(dev);
        IMMDeviceEnumerator_Release(devenum);
        return 0;
    }
    CoTaskMemFree(fmt);
    IMMDevice_Release(dev);
    IMMDeviceEnumerator_Release(devenum);
    oa_event = CreateEventA(NULL, FALSE, FALSE, NULL);
    IAudioClient_SetEventHandle(oa_client, oa_event);
    IAudioClient_GetBufferSize(oa_client, &oa_buffer_frames);
    if (FAILED(IAudioClient_GetService(oa_client, &OA_IID_IAudioRenderClient,
                                       (void **)&oa_render)))
        return 0;
    InitializeCriticalSection(&oa_cs);
    oa_running = 1;
    oa_thread = CreateThread(NULL, 0, oa_thread_main, NULL, 0, NULL);
    IAudioClient_Start(oa_client);
    oa_ok = 1;
    return 1;
}

/* ---- WAV load: RIFF PCM16/f32, any rate/channels -> device stereo f32 */

static long long oa_rd32(const unsigned char *p) {
    return p[0] | (p[1] << 8) | (p[2] << 16) | ((long long)p[3] << 24);
}
static int oa_rd16(const unsigned char *p) { return p[0] | (p[1] << 8); }

long long orion_audio_load(const char *path) {
    if (oa_nsounds >= OA_MAX_SOUNDS) return -1;
    FILE *f = fopen(path, "rb");
    if (!f) return -1;
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    unsigned char *raw = (unsigned char *)malloc(sz);
    if (!raw || fread(raw, 1, sz, f) != (size_t)sz) {
        fclose(f);
        free(raw);
        return -1;
    }
    fclose(f);
    if (sz < 44 || memcmp(raw, "RIFF", 4) || memcmp(raw + 8, "WAVE", 4)) {
        free(raw);
        return -1;
    }
    int fmt_tag = 0, nch = 0, bits = 0;
    long long src_rate = 0, data_off = -1, data_len = 0;
    long long off = 12;
    while (off + 8 <= sz) {
        long long clen = oa_rd32(raw + off + 4);
        if (!memcmp(raw + off, "fmt ", 4)) {
            fmt_tag = oa_rd16(raw + off + 8);
            nch = oa_rd16(raw + off + 10);
            src_rate = oa_rd32(raw + off + 12);
            bits = oa_rd16(raw + off + 22);
        } else if (!memcmp(raw + off, "data", 4)) {
            data_off = off + 8;
            data_len = clen;
        }
        off += 8 + clen + (clen & 1);
    }
    if (data_off < 0 || src_rate <= 0 || nch < 1 || nch > 2 ||
        !(bits == 16 || (bits == 32 && fmt_tag == 3))) {
        free(raw);
        return -1;
    }
    long long src_frames = data_len / (nch * bits / 8);
    int rate = oa_ok ? oa_rate : 48000;
    long long dst_frames = src_frames * rate / src_rate;
    float *out = (float *)malloc(dst_frames * 2 * sizeof(float));
    if (!out) {
        free(raw);
        return -1;
    }
    const unsigned char *d = raw + data_off;
    for (long long i = 0; i < dst_frames; i++) {
        long long sp = i * src_rate * 65536 / rate;
        long long f0 = sp >> 16;
        long long f1 = f0 + 1 < src_frames ? f0 + 1 : f0;
        float t = (sp & 65535) / 65536.0f;
        float l0, r0, l1, r1;
        if (bits == 16) {
            const short *s = (const short *)d;
            l0 = s[f0 * nch] / 32768.0f;
            r0 = s[f0 * nch + (nch - 1)] / 32768.0f;
            l1 = s[f1 * nch] / 32768.0f;
            r1 = s[f1 * nch + (nch - 1)] / 32768.0f;
        } else {
            const float *s = (const float *)d;
            l0 = s[f0 * nch];
            r0 = s[f0 * nch + (nch - 1)];
            l1 = s[f1 * nch];
            r1 = s[f1 * nch + (nch - 1)];
        }
        out[i * 2] = l0 + (l1 - l0) * t;
        out[i * 2 + 1] = r0 + (r1 - r0) * t;
    }
    free(raw);
    int id = oa_nsounds++;
    oa_sounds[id].frames = out;
    oa_sounds[id].nframes = dst_frames;
    return id;
}

/* ---- voices ---- */

/* Handle = slot + generation*64: a recycled slot invalidates every
 * old handle, so a script stopping a long-dead loop is a no-op, never
 * a hit on some unrelated voice. */
static long long oa_handle(int slot) {
    return slot + (long long)oa_voices[slot].gen * OA_MAX_VOICES;
}

static OaVoice *oa_resolve(long long handle) {
    if (handle < 0) return NULL;
    int slot = (int)(handle % OA_MAX_VOICES);
    int gen = (int)(handle / OA_MAX_VOICES);
    OaVoice *vo = &oa_voices[slot];
    if (!vo->active || vo->gen != gen) return NULL;
    return vo;
}

/* Steal policy: never loops (music/layers/held loops), otherwise the
 * quietest voice. One-shots are short; the quietest is the least
 * missed. Caller holds the CS. */
static int oa_free_slot(void) {
    int slot = -1;
    float quietest = 1e9f;
    for (int v = 0; v < OA_MAX_VOICES; v++) {
        if (!oa_voices[v].active) return v;
        if (!oa_voices[v].loop && oa_voices[v].vol < quietest) {
            quietest = oa_voices[v].vol;
            slot = v;
        }
    }
    return slot;
}

static long long oa_start(long long id, long long gain, long long pan,
                          long long pitch, long long bus, int loop,
                          long long fade_ms, long long sync_pos) {
    if (!oa_ok || id < 0 || id >= oa_nsounds) return -1;
    if (bus < 0 || bus >= OA_BUSES) bus = 0;
    if (pitch < 25) pitch = 25;
    if (pitch > 400) pitch = 400;
    float g = gain / 100.0f;
    float p = pan / 100.0f;
    if (p < -1.0f) p = -1.0f;
    if (p > 1.0f) p = 1.0f;
    EnterCriticalSection(&oa_cs);
    int slot = oa_free_slot();
    long long h = -1;
    if (slot >= 0) {
        OaVoice *vo = &oa_voices[slot];
        vo->gen = (vo->gen + 1) & 0xffff;
        vo->sound = (int)id;
        vo->loop = loop;
        vo->bus = (int)bus;
        vo->pos_fp = sync_pos >= 0 ? sync_pos : 0;
        if ((vo->pos_fp >> 16) >= oa_sounds[id].nframes) vo->pos_fp = 0;
        vo->step_fp = pitch * 65536 / 100;
        vo->pan_l = p <= 0.0f ? 1.0f : 1.0f - p;
        vo->pan_r = p >= 0.0f ? 1.0f : 1.0f + p;
        vo->vol = fade_ms > 0 ? 0.0f : g;
        vo->vol_target = g;
        vo->vol_step = oa_step_for(0.0f, g, fade_ms);
        vo->die_on_zero = 0;
        vo->active = 1;
        h = oa_handle(slot);
    }
    LeaveCriticalSection(&oa_cs);
    return h;
}

long long orion_audio_play(long long id, long long gain, long long pan,
                           long long pitch, long long bus) {
    oa_total_plays++;
    return oa_start(id, gain, pan, pitch, bus, 0, 0, -1);
}

long long orion_audio_loop(long long id, long long gain, long long pan,
                           long long pitch, long long bus, long long fade_ms) {
    oa_total_plays++;
    return oa_start(id, gain, pan, pitch, bus, 1, fade_ms, -1);
}

long long orion_audio_voice_gain(long long handle, long long gain,
                                 long long fade_ms) {
    if (!oa_ok) return 0;
    long long hit = 0;
    EnterCriticalSection(&oa_cs);
    OaVoice *vo = oa_resolve(handle);
    if (vo) {
        vo->vol_target = gain / 100.0f;
        vo->vol_step = oa_step_for(vo->vol, vo->vol_target, fade_ms);
        vo->die_on_zero = 0;
        hit = 1;
    }
    LeaveCriticalSection(&oa_cs);
    return hit;
}

long long orion_audio_stop_voice(long long handle, long long fade_ms) {
    if (!oa_ok) return 0;
    long long hit = 0;
    EnterCriticalSection(&oa_cs);
    OaVoice *vo = oa_resolve(handle);
    if (vo) {
        vo->vol_target = 0.0f;
        vo->vol_step = oa_step_for(vo->vol, 0.0f, fade_ms > 0 ? fade_ms : 10);
        vo->die_on_zero = 1;
        hit = 1;
    }
    LeaveCriticalSection(&oa_cs);
    return hit;
}

long long orion_audio_music(long long id, long long gain, long long fade_ms) {
    oa_total_plays++;
    if (!oa_ok) return -1;
    EnterCriticalSection(&oa_cs);
    if (oa_music_voice >= 0 && oa_voices[oa_music_voice].active) {
        OaVoice *old = &oa_voices[oa_music_voice];
        old->vol_target = 0.0f;
        old->vol_step = oa_step_for(old->vol, 0.0f, fade_ms > 0 ? fade_ms : 10);
        old->die_on_zero = 1;
    }
    LeaveCriticalSection(&oa_cs);
    long long h = oa_start(id, gain, 0, 100, 1, 1, fade_ms, -1);
    oa_music_voice = h < 0 ? -1 : (int)(h % OA_MAX_VOICES);
    return h;
}

/* Layer: a loop on the music bus, started at the MUSIC VOICE'S exact
 * sample position — equal-length stems stay phase-locked forever.
 * Drive intensity by fading layer gains, never by restarting. */
long long orion_audio_layer(long long id, long long gain, long long fade_ms) {
    oa_total_plays++;
    if (!oa_ok) return -1;
    long long sync = -1;
    EnterCriticalSection(&oa_cs);
    if (oa_music_voice >= 0 && oa_voices[oa_music_voice].active)
        sync = oa_voices[oa_music_voice].pos_fp;
    LeaveCriticalSection(&oa_cs);
    return oa_start(id, gain, 0, 100, 1, 1, fade_ms, sync);
}

long long orion_audio_stop_music(long long fade_ms) {
    if (!oa_ok) return 0;
    EnterCriticalSection(&oa_cs);
    if (oa_music_voice >= 0 && oa_voices[oa_music_voice].active) {
        OaVoice *vo = &oa_voices[oa_music_voice];
        vo->vol_target = 0.0f;
        vo->vol_step = oa_step_for(vo->vol, 0.0f, fade_ms > 0 ? fade_ms : 10);
        vo->die_on_zero = 1;
    }
    LeaveCriticalSection(&oa_cs);
    oa_music_voice = -1;
    return 1;
}

long long orion_audio_bus_gain(long long bus, long long gain,
                               long long fade_ms) {
    if (!oa_ok) return 0; /* uninited oa_cs = write into zero page */
    if (bus < 0 || bus >= OA_BUSES) return 0;
    float g = gain / 100.0f;
    if (g < 0.0f) g = 0.0f;
    if (g > 2.0f) g = 2.0f;
    EnterCriticalSection(&oa_cs);
    oa_bus_target[bus] = g;
    oa_bus_step[bus] = oa_step_for(oa_bus_vol[bus], g, fade_ms) ;
    if (fade_ms <= 0) oa_bus_vol[bus] = g;
    LeaveCriticalSection(&oa_cs);
    return 1;
}

long long orion_audio_playing(void) {
    if (!oa_ok) return 0;
    long long n = 0;
    EnterCriticalSection(&oa_cs);
    for (int v = 0; v < OA_MAX_VOICES; v++)
        if (oa_voices[v].active) n++;
    LeaveCriticalSection(&oa_cs);
    return n;
}

long long orion_audio_debug_plays(void) { return oa_total_plays; }

void orion_audio_shutdown(void) {
    if (!oa_ok) return;
    oa_running = 0;
    WaitForSingleObject(oa_thread, 500);
    IAudioClient_Stop(oa_client);
    oa_ok = 0;
}
#endif
