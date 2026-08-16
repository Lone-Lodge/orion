/* orion_whisper.c - the bridge between the whisper orb and whisper.cpp.
 *
 * A project that says `use whisper` links this file plus the whisper
 * static library in its Orbit.toml:
 *
 *     link = "vendor/orion_whisper.c dist/libwhisper.a"
 *
 * (build the library once with `bash tools/whisper_build.sh` - the C++
 * sources under vendor/whisper/ take a minute and never change again.)
 *
 * Shape: model handles are small ints into a fixed table, exactly like
 * the sqlite bridge. Audio comes in as a FILE, not a buffer - the mic
 * orb already writes mono PCM16 wav and whisper wants 16 kHz mono
 * floats, so the conversion belongs here where both ends are known.
 *
 * Transcription returns ONE text with the segments joined by spaces.
 * Timestamps are deliberately not exposed yet: nothing needs them, and
 * a segment list would have to cross as [text] with its own separator
 * convention. Add it the day something asks.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "whisper.h"

extern const char *orion_text_from_c(const char *s);

#define WH_MAX 4
#define WH_RATE 16000

static struct whisper_context *wh_ctx[WH_MAX];
static char wh_err[WH_MAX][512];

static void wh_set_err(long long h, const char *msg) {
    if (h < 0 || h >= WH_MAX) return;
    snprintf(wh_err[h], sizeof wh_err[h], "%s", msg ? msg : "");
}

/* Load a ggml model (ggml-small.bin and friends). A handle >= 0, or -1. */
long long wh_open(const char *model_path) {
    for (long long i = 0; i < WH_MAX; i++) {
        if (wh_ctx[i]) continue;
        struct whisper_context_params cp = whisper_context_default_params();
        wh_ctx[i] = whisper_init_from_file_with_params(model_path, cp);
        if (!wh_ctx[i]) {
            wh_set_err(i, "could not load model");
            return -1;
        }
        wh_err[i][0] = 0;
        return i;
    }
    return -1;
}

long long wh_close(long long h) {
    if (h < 0 || h >= WH_MAX || !wh_ctx[h]) return -1;
    whisper_free(wh_ctx[h]);
    wh_ctx[h] = NULL;
    return 0;
}

const char *wh_error(long long h) {
    return orion_text_from_c((h >= 0 && h < WH_MAX) ? wh_err[h] : "");
}

static unsigned long wh_rd32(const unsigned char *p) {
    return (unsigned long)p[0] | ((unsigned long)p[1] << 8) |
           ((unsigned long)p[2] << 16) | ((unsigned long)p[3] << 24);
}

static unsigned wh_rd16(const unsigned char *p) {
    return (unsigned)p[0] | ((unsigned)p[1] << 8);
}

/* Mono PCM16 wav at WH_RATE -> floats. Walks the chunk list rather than
 * assuming a 44-byte header, because plenty of writers slip a LIST chunk
 * in between. Returns frames, or -1 with `why` set. */
static long long wh_read_wav(const char *path, float **out, const char **why) {
    *out = NULL;
    FILE *f = fopen(path, "rb");
    if (!f) { *why = "cannot open wav"; return -1; }
    unsigned char hdr[12];
    if (fread(hdr, 1, 12, f) != 12 || memcmp(hdr, "RIFF", 4) ||
        memcmp(hdr + 8, "WAVE", 4)) {
        fclose(f); *why = "not a RIFF/WAVE file"; return -1;
    }
    unsigned channels = 0, bits = 0;
    unsigned long rate = 0;
    for (;;) {
        unsigned char ch[8];
        if (fread(ch, 1, 8, f) != 8) {
            fclose(f); *why = "wav has no data chunk"; return -1;
        }
        unsigned long size = wh_rd32(ch + 4);
        if (!memcmp(ch, "fmt ", 4)) {
            unsigned char fmt[16];
            if (size < 16 || fread(fmt, 1, 16, f) != 16) {
                fclose(f); *why = "short fmt chunk"; return -1;
            }
            channels = wh_rd16(fmt + 2);
            rate = wh_rd32(fmt + 4);
            bits = wh_rd16(fmt + 14);
            if (size > 16) fseek(f, (long)(size - 16), SEEK_CUR);
        } else if (!memcmp(ch, "data", 4)) {
            if (channels != 1 || bits != 16) {
                fclose(f); *why = "need mono 16-bit wav"; return -1;
            }
            if (rate != WH_RATE) {
                fclose(f); *why = "need 16 kHz wav"; return -1;
            }
            long long n = (long long)(size / 2);
            if (n <= 0) { fclose(f); *why = "wav has no samples"; return -1; }
            short *raw = (short *)malloc((size_t)n * sizeof(short));
            float *pcm = (float *)malloc((size_t)n * sizeof(float));
            if (!raw || !pcm) {
                free(raw); free(pcm); fclose(f);
                *why = "out of memory"; return -1;
            }
            n = (long long)fread(raw, sizeof(short), (size_t)n, f);
            for (long long i = 0; i < n; i++) pcm[i] = raw[i] / 32768.0f;
            free(raw);
            fclose(f);
            *out = pcm;
            return n;
        } else {
            fseek(f, (long)(size + (size & 1)), SEEK_CUR);
        }
    }
}

/* Transcribe `wav_path`. `lang` is "sv", "en", ... or "" to auto-detect.
 * "" on failure, with wh_error(h) saying why. */
const char *wh_hear(long long h, const char *wav_path, const char *lang) {
    if (h < 0 || h >= WH_MAX || !wh_ctx[h]) return orion_text_from_c("");
    const char *why = "";
    float *pcm = NULL;
    long long n = wh_read_wav(wav_path, &pcm, &why);
    if (n < 0) {
        wh_set_err(h, why);
        return orion_text_from_c("");
    }

    struct whisper_full_params p =
        whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    p.print_progress = false;
    p.print_realtime = false;
    p.print_special = false;
    p.print_timestamps = false;
    p.translate = false;
    p.single_segment = false;
    p.language = (lang && lang[0]) ? lang : NULL;
    p.detect_language = !(lang && lang[0]);

    if (whisper_full(wh_ctx[h], p, pcm, (int)n) != 0) {
        free(pcm);
        wh_set_err(h, "whisper_full failed");
        return orion_text_from_c("");
    }
    free(pcm);

    size_t cap = 1024, len = 0;
    char *buf = (char *)malloc(cap);
    if (!buf) { wh_set_err(h, "out of memory"); return orion_text_from_c(""); }
    buf[0] = 0;
    int segments = whisper_full_n_segments(wh_ctx[h]);
    for (int i = 0; i < segments; i++) {
        const char *seg = whisper_full_get_segment_text(wh_ctx[h], i);
        if (!seg) continue;
        size_t need = len + strlen(seg) + 2;
        if (need > cap) {
            while (cap < need) cap *= 2;
            char *nb = (char *)realloc(buf, cap);
            if (!nb) { free(buf); wh_set_err(h, "out of memory");
                       return orion_text_from_c(""); }
            buf = nb;
        }
        if (len > 0) buf[len++] = ' ';
        memcpy(buf + len, seg, strlen(seg));
        len += strlen(seg);
        buf[len] = 0;
    }
    /* Whisper pads every segment with a leading space. */
    char *start = buf;
    while (*start == ' ') start++;
    wh_err[h][0] = 0;
    const char *out = orion_text_from_c(start);
    free(buf);
    return out;
}
