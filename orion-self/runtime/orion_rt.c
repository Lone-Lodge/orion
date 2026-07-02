/* orion_rt.c — runtime helpers for the native compiler.
 *
 * Compiled alongside generated .ll files to provide:
 *   - __orion_perform_int / __orion_resume_int — one-shot continuations
 *     for algebraic effects, backed by setjmp/longjmp.
 *
 * Single int parameter, single int return for the MVP. Generalize later
 * with __orion_perform_text, __orion_perform_n etc. as needed.
 */

#include <setjmp.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

/* ---- Frame arena ---------------------------------------------------
 * Every runtime allocation (lists, maps, text concat/join, structs)
 * routes through orion_alloc. Default mode = plain malloc (compilers
 * and tools never notice). A game loop flips to arena mode per frame:
 *
 *   orion_arena_reset(); orion_arena_on();
 *   ...gameplay + render (all transients land in the bump arena)...
 *   orion_arena_off();   // before mutating persistent state, or keep
 *                        // persistent state pre-sized so in-place
 *                        // set/push_mut never allocates
 *
 * Overflow falls back to malloc (correct but leaky) with a one-time
 * stderr warning — raise the size with orion_arena_init(bytes). */

static unsigned char *arena_base = NULL;
static size_t arena_cap = 0;
static size_t arena_used = 0;
static int arena_on = 0;
static int arena_warned = 0;

/* Measured high-water with the obstack eval: ~300KB (cubsy, busiest
 * dispatch). 4MB covers the render epoch (~2.5MB) with headroom; overflow falls back to malloc
 * with a stderr warning, so undersizing degrades instead of breaking. */
#define ARENA_DEFAULT (4u * 1024u * 1024u)

long long orion_arena_init(long long bytes) {
    if (arena_base) free(arena_base);
    arena_cap = (size_t)bytes;
    arena_base = (unsigned char *)malloc(arena_cap);
    arena_used = 0;
    return arena_base ? 1 : 0;
}

long long orion_arena_on(void) {
    if (!arena_base) orion_arena_init(ARENA_DEFAULT);
    arena_on = 1;
    return 1;
}

long long orion_arena_off(void) { arena_on = 0; return 1; }
long long orion_arena_active(void) { return arena_on; }

/* Lifetime tripwire: a pointer that lies inside the arena buffer is
 * arena-born and dies at the next reset — storing it in a persistent
 * structure is always a latent use-after-reset. Emitted slot-store
 * code calls this for every pointer value; costs two compares. */
void orion_arena_ptr_guard(const char *p, const char *key) {
    static int warned = 0;
    if (!arena_base || warned >= 16) return;
    if ((const unsigned char *)p >= arena_base &&
        (const unsigned char *)p < arena_base + arena_cap) {
        fprintf(stderr,
                "[orion] WARNING: arena pointer stored in persistent slot "
                "'%s' - it dangles at the next arena reset\n",
                key);
        warned++;
    }
}

/* Change stamp for a file: mixes mtime and size, 0 when missing.
 * Lets hot-reload polls skip reading unchanged files entirely. */
long long orion_file_stamp(const char *path) {
#if defined(_WIN32)
    struct _stat64 st;
    if (_stat64(path, &st) != 0) return 0;
    return (long long)st.st_mtime * 131 + (long long)st.st_size;
#else
    struct stat st;
    if (stat(path, &st) != 0) return 0;
    return (long long)st.st_mtime * 131 + (long long)st.st_size;
#endif
}
long long orion_arena_reset(void) { arena_used = 0; return 1; }
long long orion_arena_used(void) { return (long long)arena_used; }
/* Obstack-style partial rewind — callers save a watermark, evacuate
 * their result, and free everything above it in one move. */
long long orion_arena_rewind(long long mark) {
    if (mark >= 0 && (size_t)mark <= arena_used) arena_used = (size_t)mark;
    return 1;
}

/* Unbuffered stdout so prints survive crashes and kills. MSVCRT treats
 * _IOLBF as full buffering, so _IONBF is the only honest option; game
 * print volume is low enough that it costs nothing. */
#if defined(__GNUC__) || defined(__clang__)
__attribute__((constructor)) static void orion_stdio_init(void) {
    setvbuf(stdout, NULL, _IONBF, 0);
}
#endif

/* Embedded assets: a build step generates a strong scripts_embed.c
 * (tools/embed_assets.ps1) that overrides these weak defaults; the
 * plain build misses every lookup and games read from disk instead.
 * Callers must gate orion_embedded_text behind orion_embedded_has. */
#if defined(__GNUC__) || defined(__clang__)
__attribute__((weak)) long long orion_embedded_has(const char *path) {
    (void)path;
    return 0;
}
__attribute__((weak)) const char *orion_embedded_text(const char *path) {
    (void)path;
    return "";
}
/* Newline-joined paths of every embedded asset — lets ship builds
 * enumerate "directories" they no longer have. */
__attribute__((weak)) const char *orion_embedded_list(void) {
    return "";
}
#endif

/* Allocation telemetry: total requested bytes, and the subset served
 * by malloc (arena misses + arena-off) — perf probes read both. */
static long long alloc_total = 0;
static long long alloc_malloc = 0;
long long orion_alloc_total(void) { return alloc_total; }
long long orion_alloc_malloc_total(void) { return alloc_malloc; }

static size_t arena_high = 0;
long long orion_arena_high(void) { return (long long)arena_high; }

void *orion_alloc(long long size) {
    alloc_total += size;
    if (arena_on && arena_base) {
        size_t need = ((size_t)size + 15u) & ~(size_t)15u;
        if (arena_used + need <= arena_cap) {
            void *p = arena_base + arena_used;
            arena_used += need;
            if (arena_used > arena_high) arena_high = arena_used;
            return p;
        }
        if (!arena_warned) {
            fprintf(stderr,
                "[orion] arena overflow (%llu bytes cap) - falling back to "
                "malloc; raise with orion_arena_init\n",
                (unsigned long long)arena_cap);
            arena_warned = 1;
        }
    }
    alloc_malloc += size;
    return malloc((size_t)size);
}

/* Float-literal support for the compiler: parse a decimal literal with
 * strtod and return its IEEE-754 bit pattern as a 16-digit hex string
 * ("0x3FE0000000000000"). String-in/string-out so the COMPILER's own
 * source needs no double type — the previous-generation compiler can
 * always build the next one (no bootstrap chicken-egg). */
const char *orion_f64_literal_hex(const char *s) {
    union { double d; unsigned long long i; } u;
    u.d = strtod(s, NULL);
    char *buf = (char *)malloc(19);
    snprintf(buf, 19, "0x%016llX", u.i);
    return buf;
}

/* Thread-local stack of one jmp_buf — only one perform pending at a time
 * for the MVP. Nested perform/resume requires a real stack here. */
static jmp_buf *current_k = NULL;
static long long resume_value = 0;

/* Call handler with arg. If handler returns normally, that's the result.
 * If handler invokes __orion_resume_int, longjmp lands back here and we
 * return the resumed value instead. */
long long __orion_perform_int(long long (*handler)(long long), long long arg) {
    jmp_buf jb;
    jmp_buf *old_k = current_k;
    current_k = &jb;
    long long ret;
    if (setjmp(jb) == 0) {
        ret = handler(arg);
    } else {
        ret = resume_value;
    }
    current_k = old_k;
    return ret;
}

/* Resume the current continuation with `value`. Does not return. */
void __orion_resume_int(long long value) {
    resume_value = value;
    longjmp(*current_k, 1);
}

/* Text variants — same setjmp dance, but the value is a char*. We use a
 * separate global to avoid type confusion when both kinds of perform
 * are nested (rare but possible). */
static char *resume_text_value = NULL;

char *__orion_perform_text(char *(*handler)(char *), char *arg) {
    jmp_buf jb;
    jmp_buf *old_k = current_k;
    current_k = &jb;
    char *ret;
    if (setjmp(jb) == 0) {
        ret = handler(arg);
    } else {
        ret = resume_text_value;
    }
    current_k = old_k;
    return ret;
}

void __orion_resume_text(char *value) {
    resume_text_value = value;
    longjmp(*current_k, 1);
}

/* Timing primitives — backbone of the async runtime. Windows-only for now;
 * port to POSIX (clock_gettime + nanosleep) is a few extra ifdefs. */
#ifdef _WIN32
#include <windows.h>

/* Newline-joined file names in `dir` (no paths, no subdirs). Empty
 * text when the directory is missing — callers fall back to the
 * embedded asset list in ship builds. */
const char *orion_dir_list(const char *dir) {
    char pattern[1024];
    WIN32_FIND_DATAA fd;
    snprintf(pattern, sizeof(pattern), "%s\\*", dir);
    HANDLE h = FindFirstFileA(pattern, &fd);
    if (h == INVALID_HANDLE_VALUE) return "";
    size_t cap = 4096, len = 0;
    char *out = (char *)malloc(cap);
    out[0] = 0;
    do {
        if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) continue;
        size_t n = strlen(fd.cFileName);
        if (len + n + 2 > cap) {
            cap *= 2;
            out = (char *)realloc(out, cap);
        }
        if (len > 0) out[len++] = '\n';
        memcpy(out + len, fd.cFileName, n + 1);
        len += n;
    } while (FindNextFileA(h, &fd));
    FindClose(h);
    return out;
}
long long __orion_time_now_ms(void) {
    FILETIME ft; GetSystemTimeAsFileTime(&ft);
    unsigned long long t = ((unsigned long long)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
    /* FILETIME is 100ns intervals since 1601-01-01; offset to Unix epoch. */
    return (long long)((t - 116444736000000000ULL) / 10000ULL);
}
/* QPC + high-res waitable timer: GetTickCount64/Sleep quantize to the
 * 15.6ms scheduler tick, capping any sleep-paced loop at ~30fps. */
long long __orion_monotonic_ms(void) {
    static LARGE_INTEGER freq;
    LARGE_INTEGER c;
    if (!freq.QuadPart) QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&c);
    return (long long)(c.QuadPart * 1000 / freq.QuadPart);
}
#ifndef CREATE_WAITABLE_TIMER_HIGH_RESOLUTION
#define CREATE_WAITABLE_TIMER_HIGH_RESOLUTION 0x00000002
#endif
void __orion_sleep_ms(long long ms) {
    static HANDLE timer;
    if (ms <= 0) return;
    if (!timer)
        timer = CreateWaitableTimerExW(NULL, NULL,
                    CREATE_WAITABLE_TIMER_HIGH_RESOLUTION, TIMER_ALL_ACCESS);
    if (timer) {
        LARGE_INTEGER due;
        due.QuadPart = -ms * 10000LL;
        SetWaitableTimer(timer, &due, 0, NULL, NULL, FALSE);
        WaitForSingleObject(timer, INFINITE);
    } else {
        Sleep((DWORD)ms);
    }
}
#else
#include <time.h>
long long __orion_time_now_ms(void) {
    struct timespec ts; clock_gettime(CLOCK_REALTIME, &ts);
    return (long long)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}
long long __orion_monotonic_ms(void) {
    struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}
void __orion_sleep_ms(long long ms) {
    if (ms > 0) {
        struct timespec t = { ms / 1000, (ms % 1000) * 1000000 };
        nanosleep(&t, NULL);
    }
}
#endif
