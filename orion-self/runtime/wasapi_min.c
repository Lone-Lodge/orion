/* wasapi_min.c — the in-house potato mixer.
 *
 * Raw WASAPI shared mode, one render thread, 32 voices, three buses
 * (0 sfx, 1 music, 2 ui) under a master. WAV assets (PCM16 / f32,
 * mono/stereo, any rate) are converted to device-rate stereo f32 at
 * load — the mix loop is a dumb fused multiply-add, no DSP graph.
 *
 * This file OVERRIDES the weak no-op stubs in orion_rt.c: link it
 * (orbit native does) and games get sound; leave it out (headless
 * gates) and the same calls count silently. The game-facing seam is
 * AudioCmd data in atlas_audio — swapping this backend for an
 * FMOD/Wwise adapter later never touches game code.
 */
#ifdef _WIN32
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

#define OA_MAX_SOUNDS 64
#define OA_MAX_VOICES 32
#define OA_BUSES 3

typedef struct {
    float *frames; /* stereo interleaved f32 at device rate */
    long long nframes;
} OaSound;

typedef struct {
    int active;
    int sound;
    int loop;
    int bus;
    long long pos_fp; /* 16.16 frame position */
    long long step_fp;
    float gain_l, gain_r;
    float ramp; /* 0..1 kill ramp, 1 = steady */
    int killing;
} OaVoice;

static IAudioClient *oa_client;
static IAudioRenderClient *oa_render;
static HANDLE oa_event, oa_thread;
static CRITICAL_SECTION oa_cs;
static volatile int oa_running;
static int oa_rate = 48000;
static int oa_channels = 2;
static int oa_out_f32 = 1;
static UINT32 oa_buffer_frames;
static OaSound oa_sounds[OA_MAX_SOUNDS];
static int oa_nsounds;
static OaVoice oa_voices[OA_MAX_VOICES];
static float oa_bus_gain[OA_BUSES] = {1.0f, 1.0f, 1.0f};
static float oa_master = 1.0f;
static int oa_music_voice = -1;
static long long oa_total_plays;
static int oa_ok;

static void oa_mix(float *dst, UINT32 nframes) {
    memset(dst, 0, nframes * 2 * sizeof(float));
    EnterCriticalSection(&oa_cs);
    for (int v = 0; v < OA_MAX_VOICES; v++) {
        OaVoice *vo = &oa_voices[v];
        if (!vo->active) continue;
        OaSound *s = &oa_sounds[vo->sound];
        float bg = oa_bus_gain[vo->bus] * oa_master;
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
            if (vo->killing) {
                vo->ramp -= 0.002f; /* ~10ms at 48k */
                if (vo->ramp <= 0.0f) {
                    vo->active = 0;
                    break;
                }
            }
            float g = bg * vo->ramp;
            dst[i * 2] += s->frames[fi * 2] * vo->gain_l * g;
            dst[i * 2 + 1] += s->frames[fi * 2 + 1] * vo->gain_r * g;
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
            /* int16 device: mix to a scratch then convert */
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
    oa_channels = fmt->nChannels;
    oa_out_f32 = 1;
    if (fmt->wFormatTag == WAVE_FORMAT_PCM ||
        (fmt->wFormatTag == WAVE_FORMAT_EXTENSIBLE &&
         ((WAVEFORMATEXTENSIBLE *)fmt)->SubFormat.Data1 == 1))
        oa_out_f32 = 0;
    if (oa_channels != 2) {
        /* mono/quad endpoints exist; v1 supports the 99% stereo case */
        fmt->nChannels = 2;
        fmt->nBlockAlign = (WORD)(2 * fmt->wBitsPerSample / 8);
        fmt->nAvgBytesPerSec = fmt->nSamplesPerSec * fmt->nBlockAlign;
        oa_channels = 2;
    }
    /* 20ms buffer, event driven */
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
        /* linear resample */
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

static long long oa_start(long long id, long long gain, long long pan,
                          long long pitch, long long bus, int loop) {
    if (!oa_ok || id < 0 || id >= oa_nsounds) return -1;
    if (bus < 0 || bus >= OA_BUSES) bus = 0;
    if (pitch < 25) pitch = 25;
    if (pitch > 400) pitch = 400;
    float g = gain / 100.0f;
    float p = pan / 100.0f;
    if (p < -1.0f) p = -1.0f;
    if (p > 1.0f) p = 1.0f;
    EnterCriticalSection(&oa_cs);
    int slot = -1;
    for (int v = 0; v < OA_MAX_VOICES; v++)
        if (!oa_voices[v].active) {
            slot = v;
            break;
        }
    if (slot >= 0) {
        OaVoice *vo = &oa_voices[slot];
        vo->sound = (int)id;
        vo->loop = loop;
        vo->bus = (int)bus;
        vo->pos_fp = 0;
        vo->step_fp = pitch * 65536 / 100;
        vo->gain_l = g * (p <= 0.0f ? 1.0f : 1.0f - p);
        vo->gain_r = g * (p >= 0.0f ? 1.0f : 1.0f + p);
        vo->ramp = 1.0f;
        vo->killing = 0;
        vo->active = 1;
    }
    LeaveCriticalSection(&oa_cs);
    return slot;
}

long long orion_audio_play(long long id, long long gain, long long pan,
                           long long pitch, long long bus) {
    oa_total_plays++;
    return oa_start(id, gain, pan, pitch, bus, 0);
}

long long orion_audio_music(long long id, long long gain) {
    oa_total_plays++;
    if (!oa_ok) return -1;
    EnterCriticalSection(&oa_cs);
    if (oa_music_voice >= 0 && oa_voices[oa_music_voice].active)
        oa_voices[oa_music_voice].killing = 1;
    LeaveCriticalSection(&oa_cs);
    oa_music_voice = (int)oa_start(id, gain, 0, 100, 1, 1);
    return oa_music_voice;
}

long long orion_audio_stop_music(void) {
    if (!oa_ok) return 0;
    EnterCriticalSection(&oa_cs);
    if (oa_music_voice >= 0 && oa_voices[oa_music_voice].active)
        oa_voices[oa_music_voice].killing = 1;
    LeaveCriticalSection(&oa_cs);
    oa_music_voice = -1;
    return 1;
}

long long orion_audio_bus_gain(long long bus, long long gain) {
    if (bus < 0 || bus >= OA_BUSES) return 0;
    float g = gain / 100.0f;
    if (g < 0.0f) g = 0.0f;
    if (g > 2.0f) g = 2.0f;
    oa_bus_gain[bus] = g;
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
