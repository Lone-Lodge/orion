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

/* ---- Console: color capability + VT enable --------------------------
 * ANSI styling is opt-in per stream state: orion_console_color()
 * answers "is stdout an interactive terminal", and on first ask
 * switches the console to UTF-8 + virtual-terminal processing so
 * escape codes and unicode render on classic conhost too. Redirected
 * output (gates, logs) stays plain text. */
#if defined(_WIN32)
#include <io.h>
__declspec(dllimport) void *__stdcall GetStdHandle(unsigned long which);
__declspec(dllimport) int __stdcall GetConsoleMode(void *h, unsigned long *m);
__declspec(dllimport) int __stdcall SetConsoleMode(void *h, unsigned long m);
__declspec(dllimport) int __stdcall SetConsoleOutputCP(unsigned int cp);
static int console_color_state = -1;
long long orion_console_color(void) {
    if (console_color_state >= 0) return console_color_state;
    console_color_state = 0;
    if (_isatty(_fileno(stdout))) {
        void *h = GetStdHandle((unsigned long)-11); /* STD_OUTPUT_HANDLE */
        unsigned long mode = 0;
        if (h && GetConsoleMode(h, &mode) &&
            SetConsoleMode(h, mode | 0x0004 /* VT processing */)) {
            SetConsoleOutputCP(65001);
            console_color_state = 1;
        }
    }
    return console_color_state;
}
#else
#include <unistd.h>
long long orion_console_color(void) { return isatty(1) ? 1 : 0; }
#endif

/* Style fragments for the runtime's own messages. Empty when the
 * stream is not an interactive terminal. */
static const char *c_dim(void) { return orion_console_color() ? "\x1b[2m" : ""; }
static const char *c_red(void) { return orion_console_color() ? "\x1b[31;1m" : ""; }
static const char *c_off(void) { return orion_console_color() ? "\x1b[0m" : ""; }

/* ---- Adaptive regions ------------------------------------------------
 * Regions (arena, frame, pools) start SMALL and the runtime sizes
 * them: at a reset the region is empty by definition, so the backing
 * buffer can be swapped for a bigger one with zero live pointers.
 * Overflow mid-cycle chains onto a per-region list and is freed
 * (poisoned) at that same reset — spill is slow for one cycle, never
 * a leak, and the next reset has grown the buffer to fit. The engine
 * picks how much it needs; nobody hand-tunes byte counts. Grow-only:
 * caps converge to less than ~2.7x the real peak per workload. */

typedef struct orion_ovf {
    struct orion_ovf *next;
    size_t size;
} orion_ovf;

static void *ovf_push(orion_ovf **head, size_t *bytes, size_t size) {
    orion_ovf *b = (orion_ovf *)malloc(sizeof(orion_ovf) + size);
    if (!b) return NULL;
    b->next = *head;
    b->size = size;
    *head = b;
    *bytes += size;
    return (void *)(b + 1);
}

static void ovf_drain(orion_ovf **head, size_t *bytes) {
    orion_ovf *b = *head;
    while (b) {
        orion_ovf *n = b->next;
        memset(b + 1, 0xDD, b->size);
        free(b);
        b = n;
    }
    *head = NULL;
    *bytes = 0;
}

/* Swap an EMPTY region's buffer for one that fits what the last cycle
 * actually needed. Call only at reset. Keeps need <= 3/4 of cap. */
static void region_fit(const char *name, unsigned char **base, size_t *cap,
                       size_t need) {
    size_t want = *cap;
    if (!*base || need <= (*cap / 4) * 3) return;
    while ((want / 4) * 3 < need) want *= 2;
    unsigned char *fresh = (unsigned char *)malloc(want);
    if (!fresh) return; /* keep the old buffer; spill stays slow */
    free(*base);
    *base = fresh;
    *cap = want;
    fprintf(stderr, "%s[orion] %s region sized to %llu KB%s\n", c_dim(), name,
            (unsigned long long)(want / 1024u), c_off());
}

/* ---- Frame arena ---------------------------------------------------
 * Every runtime allocation (lists, maps, text concat/join, structs)
 * routes through orion_alloc. Default mode = plain malloc (compilers
 * and tools never notice). A game loop flips to arena mode per epoch:
 *
 *   orion_arena_reset(); orion_arena_on();
 *   ...gameplay + render (all transients land in the bump arena)...
 *   orion_arena_off();   // before mutating persistent state, or keep
 *                        // persistent state pre-sized so in-place
 *                        // set/push_mut never allocates
 */

static unsigned char *arena_base = NULL;
static size_t arena_cap = 0;
static size_t arena_used = 0;
static size_t arena_peak = 0; /* max used since last reset (rewind lowers used) */
static int arena_on = 0;
static orion_ovf *arena_ovf = NULL;
static size_t arena_ovf_bytes = 0;

#define ARENA_START (256u * 1024u)

long long orion_arena_init(long long bytes) {
    if (arena_base) free(arena_base);
    arena_cap = (size_t)bytes;
    arena_base = (unsigned char *)malloc(arena_cap);
    arena_used = 0;
    arena_peak = 0;
    return arena_base ? 1 : 0;
}

long long orion_arena_on(void) {
    if (!arena_base) orion_arena_init(ARENA_START);
    arena_on = 1;
    return 1;
}

long long orion_arena_off(void) { arena_on = 0; return 1; }
long long orion_arena_active(void) { return arena_on; }

/* ---- Frame region: allocations die at end of frame by DEFAULT -------
 * Three lifetimes, nothing else:
 *   epoch   — the bump arena above (render/dispatch), nests innermost
 *   frame   — this region: on for the whole game frame, reset at its
 *             end; the default for everything the frame allocates
 *   persist — orion_persist_on/off scopes route to malloc: the world,
 *             the log, caches — anything that must outlive the frame
 * A missed persist is not a slow leak: the reset POISONS the used
 * range, so a use-after-frame read crashes deterministically on the
 * next frame in every build. */

static unsigned char *frame_base = NULL;
static size_t frame_cap = 0;
static size_t frame_used = 0;
static size_t frame_high = 0;
static int frame_on = 0;
static int persist_depth = 0;
static orion_ovf *frame_ovf = NULL;
static size_t frame_ovf_bytes = 0;

#define FRAME_START (256u * 1024u)

long long orion_frame_init(long long bytes) {
    if (frame_base) free(frame_base);
    frame_cap = (size_t)bytes;
    frame_base = (unsigned char *)malloc(frame_cap);
    frame_used = 0;
    return frame_base ? 1 : 0;
}

long long orion_frame_on(void) {
    if (!frame_base) orion_frame_init(FRAME_START);
    frame_on = 1;
    return 1;
}

long long orion_frame_off(void) { frame_on = 0; return 1; }

long long orion_frame_reset(void) {
    size_t need = frame_used + frame_ovf_bytes;
    ovf_drain(&frame_ovf, &frame_ovf_bytes);
    if (frame_base && frame_used > 0) {
        memset(frame_base, 0xDD, frame_used);
    }
    region_fit("frame", &frame_base, &frame_cap, need);
    frame_used = 0;
    return 1;
}

long long orion_frame_used(void) { return (long long)frame_used; }
long long orion_frame_high(void) { return (long long)frame_high; }
long long orion_frame_cap(void) { return (long long)frame_cap; }

long long orion_persist_on(void) { persist_depth++; return 1; }
long long orion_persist_off(void) {
    if (persist_depth > 0) persist_depth--;
    return 1;
}

/* ---- Pools: generational scratch for retiring data ------------------
 * Two small bump pools for data with RING lifetime (world snapshots):
 * a generation fills one pool while the other's generation ages out of
 * the ring; once retired, the pool resets. Bounded by construction.
 * A pool overrides the persist scope while selected (the caller is
 * explicitly choosing a shorter lifetime). */

/* Pools are DYNAMIC: every world allocates its own set via
 * orion_pool_alloc (atlas takes 4 per world — snapshot ring x2 +
 * tick log x2), so region-as-world scales without shared lifetime
 * clocks. Same retirement proofs, per world. */
#define POOL_START (128u * 1024u)
static unsigned char **pool_base = NULL;
static size_t *pool_cap = NULL;
static size_t *pool_used = NULL;
static size_t *pool_high = NULL;
static orion_ovf **pool_ovf = NULL;
static size_t *pool_ovf_bytes = NULL;
static long long pool_count = 0;
static long long pool_room = 0;
static int pool_active = -1;

long long orion_pool_alloc(void) {
    if (pool_count == pool_room) {
        pool_room = pool_room == 0 ? 8 : pool_room * 2;
        pool_base = (unsigned char **)realloc(pool_base,
                                              pool_room * sizeof(void *));
        pool_cap = (size_t *)realloc(pool_cap, pool_room * sizeof(size_t));
        pool_used = (size_t *)realloc(pool_used, pool_room * sizeof(size_t));
        pool_high = (size_t *)realloc(pool_high, pool_room * sizeof(size_t));
        pool_ovf = (orion_ovf **)realloc(pool_ovf, pool_room * sizeof(void *));
        pool_ovf_bytes =
            (size_t *)realloc(pool_ovf_bytes, pool_room * sizeof(size_t));
    }
    long long i = pool_count;
    pool_base[i] = NULL;
    pool_cap[i] = 0;
    pool_used[i] = 0;
    pool_high[i] = 0;
    pool_ovf[i] = NULL;
    pool_ovf_bytes[i] = 0;
    pool_count++;
    return i;
}

long long orion_pool_on(long long i) {
    if (i < 0 || i >= pool_count) return 0;
    if (!pool_base[i]) {
        pool_base[i] = (unsigned char *)malloc(POOL_START);
        pool_cap[i] = POOL_START;
        pool_used[i] = 0;
    }
    pool_active = (int)i;
    return 1;
}

long long orion_pool_off(void) { pool_active = -1; return 1; }

long long orion_pool_used(long long i) {
    if (i < 0 || i >= pool_count) return 0;
    return (long long)pool_used[i];
}
long long orion_pool_high(long long i) {
    if (i < 0 || i >= pool_count) return 0;
    return (long long)pool_high[i];
}
long long orion_pool_cap(long long i) {
    if (i < 0 || i >= pool_count) return 0;
    return (long long)pool_cap[i];
}

long long orion_pool_reset(long long i) {
    if (i < 0 || i >= pool_count) return 0;
    size_t need = pool_used[i] + pool_ovf_bytes[i];
    ovf_drain(&pool_ovf[i], &pool_ovf_bytes[i]);
    if (pool_base[i] && pool_used[i] > 0) {
        memset(pool_base[i], 0xDD, pool_used[i]);
    }
    region_fit("pool", &pool_base[i], &pool_cap[i], need);
    pool_used[i] = 0;
    return 1;
}

/* Map keys are OWNED by the map: text keys copy on FIRST insert, so a
 * caller's transient key can never dangle inside a longer-lived map.
 * The copy allocates in the current scope — the same lifetime as the
 * spine growth the insert may do. Kills the shared-key-pointer bug
 * class (two poison-caught crashes in one day) at the language level. */
void *orion_alloc(long long size);
const char *orion_key_copy(const char *key) {
    size_t n = strlen(key) + 1;
    char *copy = (char *)orion_alloc((long long)n);
    memcpy(copy, key, n);
    return copy;
}

/* Lifetime tripwire: a pointer that lies inside the arena buffer is
 * arena-born and dies at the next reset — storing it in a persistent
 * structure is always a latent use-after-reset. Emitted slot-store
 * code calls this for every pointer value; costs two compares.
 * Fail fast: the store is already corrupt the moment this fires, and
 * the alternative is a wandering strcmp crash minutes later. */
void orion_arena_ptr_guard(const char *p, const char *key) {
    if (arena_base && (const unsigned char *)p >= arena_base &&
        (const unsigned char *)p < arena_base + arena_cap) {
        fprintf(stderr,
                "%s[orion] FATAL: arena pointer stored in persistent slot "
                "'%s' - it would dangle at the next arena reset%s\n",
                c_red(), key, c_off());
        fflush(stderr);
        abort();
    }
    if (frame_base && (const unsigned char *)p >= frame_base &&
        (const unsigned char *)p < frame_base + frame_cap) {
        fprintf(stderr,
                "%s[orion] FATAL: frame-region pointer stored in persistent "
                "slot '%s' - wrap the write in a persist scope%s\n",
                c_red(), key, c_off());
        fflush(stderr);
        abort();
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
long long orion_arena_reset(void) {
    size_t need = arena_peak + arena_ovf_bytes;
    ovf_drain(&arena_ovf, &arena_ovf_bytes);
    region_fit("arena", &arena_base, &arena_cap, need);
    arena_used = 0;
    arena_peak = 0;
    return 1;
}
long long orion_arena_used(void) { return (long long)arena_used; }
long long orion_arena_cap(void) { return (long long)arena_cap; }

/* Process commit charge (what Task Manager calls private bytes) — the
 * number the engine's own report anchors on. K32GetProcessMemoryInfo
 * lives in kernel32 on Win7+, declared by hand to skip psapi. */
#if defined(_WIN32)
typedef struct {
    unsigned long cb;
    unsigned long PageFaultCount;
    size_t PeakWorkingSetSize;
    size_t WorkingSetSize;
    size_t QuotaPeakPagedPoolUsage;
    size_t QuotaPagedPoolUsage;
    size_t QuotaPeakNonPagedPoolUsage;
    size_t QuotaNonPagedPoolUsage;
    size_t PagefileUsage;
    size_t PeakPagefileUsage;
} orion_pmc;
__declspec(dllimport) void *__stdcall GetCurrentProcess(void);
__declspec(dllimport) int __stdcall K32GetProcessMemoryInfo(void *proc,
                                                            orion_pmc *pmc,
                                                            unsigned long cb);
long long orion_os_private_kb(void) {
    orion_pmc pmc;
    pmc.cb = sizeof(pmc);
    if (!K32GetProcessMemoryInfo(GetCurrentProcess(), &pmc, sizeof(pmc)))
        return 0;
    return (long long)(pmc.PagefileUsage / 1024u);
}
#else
long long orion_os_private_kb(void) { return 0; }
#endif
/* Obstack-style partial rewind — callers save a watermark, evacuate
 * their result, and free everything above it in one move. */
long long orion_arena_rewind(long long mark) {
    if (mark >= 0 && (size_t)mark <= arena_used) arena_used = (size_t)mark;
    return 1;
}

/* Unbuffered stdout so prints survive crashes and kills. MSVCRT treats
 * _IOLBF as full buffering, so _IONBF is the only honest option; game
 * print volume is low enough that it costs nothing. */
#if defined(_WIN32)
static void orion_crash_filter_install(void);
#endif
#if defined(__GNUC__) || defined(__clang__)
__attribute__((constructor)) static void orion_stdio_init(void) {
    setvbuf(stdout, NULL, _IONBF, 0);
#if defined(_WIN32)
    orion_crash_filter_install();
#endif
}
#endif

/* Audio null backend: weak stubs COUNT instead of play. Linking
 * wasapi_min.c (orbit native does) overrides them with the real
 * mixer; headless gates link without it and assert the counters —
 * audio is testable because emission and playback are separate. */
#if defined(__GNUC__) || defined(__clang__)
static long long audio_null_plays = 0;
static long long audio_null_sounds = 0;
__attribute__((weak)) long long orion_audio_init(void) { return 1; }
__attribute__((weak)) long long orion_audio_load(const char *path) {
    (void)path;
    return audio_null_sounds++;
}
__attribute__((weak)) long long orion_audio_play(long long id, long long gain,
                                                 long long pan, long long pitch,
                                                 long long bus) {
    (void)id; (void)gain; (void)pan; (void)pitch; (void)bus;
    return audio_null_plays++;
}
__attribute__((weak)) long long orion_audio_loop(long long id, long long gain,
                                                 long long pan, long long pitch,
                                                 long long bus,
                                                 long long fade_ms) {
    (void)id; (void)gain; (void)pan; (void)pitch; (void)bus; (void)fade_ms;
    return audio_null_plays++;
}
__attribute__((weak)) long long orion_audio_voice_gain(long long handle,
                                                       long long gain,
                                                       long long fade_ms) {
    (void)handle; (void)gain; (void)fade_ms;
    return 1;
}
__attribute__((weak)) long long orion_audio_stop_voice(long long handle,
                                                       long long fade_ms) {
    (void)handle; (void)fade_ms;
    return 1;
}
__attribute__((weak)) long long orion_audio_music(long long id, long long gain,
                                                  long long fade_ms) {
    (void)id; (void)gain; (void)fade_ms;
    return audio_null_plays++;
}
__attribute__((weak)) long long orion_audio_layer(long long id, long long gain,
                                                  long long fade_ms) {
    (void)id; (void)gain; (void)fade_ms;
    return audio_null_plays++;
}
__attribute__((weak)) long long orion_audio_stop_music(long long fade_ms) {
    (void)fade_ms;
    return 1;
}
__attribute__((weak)) long long orion_audio_bus_gain(long long bus,
                                                     long long gain,
                                                     long long fade_ms) {
    (void)bus; (void)gain; (void)fade_ms;
    return 1;
}
__attribute__((weak)) long long orion_audio_playing(void) { return 0; }
__attribute__((weak)) long long orion_audio_debug_plays(void) {
    return audio_null_plays;
}
__attribute__((weak)) void orion_audio_shutdown(void) {}
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

/* Priority: epoch arena (innermost) > selected pool (beats persist —
 * an explicit shorter lifetime) > persist scope (malloc) > frame
 * region (the frame default) > malloc (setup/tools).
 * Regions never fall through on overflow: the spill chains onto the
 * region's overflow list (same lifetime, freed at its reset) and the
 * reset grows the buffer — so overflow costs a slow cycle, not a
 * leak, and does not count as persist growth. */
void *orion_alloc(long long size) {
    alloc_total += size;
    if (pool_active >= 0 && !arena_on) {
        int i = pool_active;
        size_t need = ((size_t)size + 15u) & ~(size_t)15u;
        if (pool_used[i] + need <= pool_cap[i]) {
            void *p = pool_base[i] + pool_used[i];
            pool_used[i] += need;
            if (pool_used[i] > pool_high[i]) pool_high[i] = pool_used[i];
            return p;
        }
        void *p = ovf_push(&pool_ovf[i], &pool_ovf_bytes[i], (size_t)size);
        if (p) return p;
    }
    if (arena_on && arena_base) {
        size_t need = ((size_t)size + 15u) & ~(size_t)15u;
        if (arena_used + need <= arena_cap) {
            void *p = arena_base + arena_used;
            arena_used += need;
            if (arena_used > arena_peak) arena_peak = arena_used;
            if (arena_used > arena_high) arena_high = arena_used;
            return p;
        }
        void *p = ovf_push(&arena_ovf, &arena_ovf_bytes, (size_t)size);
        if (p) return p;
    }
    if (frame_on && persist_depth == 0 && frame_base && pool_active < 0) {
        size_t need = ((size_t)size + 15u) & ~(size_t)15u;
        if (frame_used + need <= frame_cap) {
            void *p = frame_base + frame_used;
            frame_used += need;
            if (frame_used > frame_high) frame_high = frame_used;
            return p;
        }
        void *p = ovf_push(&frame_ovf, &frame_ovf_bytes, (size_t)size);
        if (p) return p;
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

/* Crash forensics: on an unhandled fault, print the exception code
 * and the MODULE-RELATIVE offset (symbolizable against the link map
 * orbit emits next to the exe) before dying. Fail fast, but say
 * where. */
static LONG WINAPI orion_crash_filter(EXCEPTION_POINTERS *info) {
    unsigned long long base = (unsigned long long)GetModuleHandleA(NULL);
    unsigned long long at =
        (unsigned long long)info->ExceptionRecord->ExceptionAddress;
    fprintf(stderr,
            "%s[orion] FATAL: exception 0x%lx at module+0x%llx - look the "
            "offset up in build/<name>.map%s\n",
            c_red(), (unsigned long)info->ExceptionRecord->ExceptionCode,
            at - base, c_off());
    /* Poor man's backtrace: scan the crashed thread's stack for
     * return addresses inside our module and print them
     * module-relative — every line greps straight into the link map.
     * No dbghelp, no symbols, always works. */
    if (info->ContextRecord) {
        unsigned long long rip = info->ContextRecord->Rip;
        unsigned long long rsp = info->ContextRecord->Rsp;
        unsigned long long lo = base, hi = base + 0x200000ULL;
        fprintf(stderr, "%s[orion]        stack:", c_red());
        int printed = 0;
        if (rip >= lo && rip < hi) {
            fprintf(stderr, " +0x%llx", rip - base);
            printed++;
        }
        unsigned long long *sp = (unsigned long long *)rsp;
        for (int i = 0; i < 512 && printed < 12; i++) {
            unsigned long long v = sp[i];
            if (v >= lo && v < hi) {
                fprintf(stderr, " +0x%llx", v - base);
                printed++;
            }
        }
        fprintf(stderr, "%s\n", c_off());
    }
    /* Self-service minidump: WER is unreliable on dev boxes, so the
     * filter writes crash.dmp next to the exe (dbghelp loaded
     * dynamically — zero link cost for headless builds). Open with
     * `lldb exe -c crash.dmp -o bt`. */
    {
        HMODULE dh = LoadLibraryA("dbghelp.dll");
        if (dh) {
            typedef BOOL(WINAPI *MdwFn)(HANDLE, DWORD, HANDLE, int, void *,
                                        void *, void *);
            MdwFn mdw = (MdwFn)GetProcAddress(dh, "MiniDumpWriteDump");
            if (mdw) {
                HANDLE f = CreateFileA("crash.dmp", GENERIC_READ | GENERIC_WRITE, 0, NULL,
                                       CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL,
                                       NULL);
                if (f != INVALID_HANDLE_VALUE) {
                    struct {
                        DWORD ThreadId;
                        PEXCEPTION_POINTERS ExceptionPointers;
                        BOOL ClientPointers;
                    } mei = {GetCurrentThreadId(), info, FALSE};
                    /* try full memory, fall back to normal */
                    BOOL ok = mdw(GetCurrentProcess(), GetCurrentProcessId(),
                                  f, 2, &mei, NULL, NULL);
                    if (!ok)
                        ok = mdw(GetCurrentProcess(), GetCurrentProcessId(),
                                 f, 0, &mei, NULL, NULL);
                    if (!ok)
                        fprintf(stderr, "[orion]        dump failed: %lu\n",
                                (unsigned long)GetLastError());
                    CloseHandle(f);
                    if (ok)
                    fprintf(stderr,
                            "%s[orion]        crash.dmp written — lldb "
                            "<exe> -c crash.dmp -o bt%s\n",
                            c_red(), c_off());
                }
            }
        }
    }
    /* Access violations carry the faulting data address; a 0xdd..dd
     * byte pattern means a read through region memory poisoned at
     * reset — a lifetime bug, not a wild pointer. */
    if (info->ExceptionRecord->ExceptionCode == 0xC0000005 &&
        info->ExceptionRecord->NumberParameters >= 2) {
        unsigned long long bad = info->ExceptionRecord->ExceptionInformation[1];
        int poison = ((bad >> 8) & 0xffffffffULL) == 0xddddddddULL ||
                     (bad & 0xffffffff00ULL) == 0xdddddddd00ULL ||
                     ((bad >> 16) & 0xffffffffULL) == 0xddddddddULL;
        fprintf(stderr, "%s[orion]        %s address 0x%llx%s%s\n", c_red(),
                info->ExceptionRecord->ExceptionInformation[0] ? "writing"
                                                               : "reading",
                bad, poison ? " (0xDD poison: reset region memory)" : "",
                c_off());
    }
    fflush(stderr);
    return EXCEPTION_CONTINUE_SEARCH; /* still crash, still WER */
}

static void orion_crash_filter_install(void) {
    SetUnhandledExceptionFilter(orion_crash_filter);
}

/* Newline-joined file names in `dir` (no paths, no subdirs). Empty
 * text when the directory is missing — callers fall back to the
 * embedded asset list in ship builds. */
/* Non-blocking console line: returns a COMPLETE line once, else "".
 * Polled once per frame by the dev console. Interactive terminals
 * accumulate keystrokes (echoed, backspace handled) via _kbhit;
 * redirected stdin (an agent driving a running game through a pipe)
 * drains available bytes via PeekNamedPipe. Zero alloc when idle. */
#include <conio.h>
const char *orion_console_readline(void) {
    static char buf[512];
    static size_t blen = 0;
    static char out[512];
    if (_isatty(_fileno(stdin))) {
        while (_kbhit()) {
            int c = _getch();
            if (c == '\r' || c == '\n') {
                putchar('\n');
                buf[blen] = 0;
                memcpy(out, buf, blen + 1);
                blen = 0;
                if (out[0] != 0) return out;
                continue;
            }
            if (c == 8) {
                if (blen > 0) {
                    blen--;
                    printf("\b \b");
                }
                continue;
            }
            if (c >= 32 && c < 127 && blen < 511) {
                buf[blen++] = (char)c;
                putchar(c);
            }
        }
        return "";
    }
    HANDLE h = GetStdHandle((DWORD)-10); /* STD_INPUT_HANDLE */
    DWORD avail = 0;
    if (!PeekNamedPipe(h, NULL, 0, NULL, &avail, NULL)) return "";
    while (avail > 0 && blen < 511) {
        char c;
        DWORD rd = 0;
        if (!ReadFile(h, &c, 1, &rd, NULL) || rd == 0) break;
        avail--;
        if (c == '\n') {
            buf[blen] = 0;
            memcpy(out, buf, blen + 1);
            blen = 0;
            if (out[0] != 0) return out;
            continue;
        }
        if (c != '\r') buf[blen++] = c;
    }
    return "";
}

/* Newline-joined SUBDIRECTORY names in `dir` (no . / .., one level).
 * Feature-grouped script dirs are discovered with this. */
const char *orion_dir_subdirs(const char *dir) {
    char pattern[1024];
    WIN32_FIND_DATAA fd;
    snprintf(pattern, sizeof(pattern), "%s\\*", dir);
    HANDLE h = FindFirstFileA(pattern, &fd);
    if (h == INVALID_HANDLE_VALUE) return "";
    size_t cap = 1024, len = 0;
    char *out = (char *)malloc(cap);
    out[0] = 0;
    do {
        if (!(fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)) continue;
        if (fd.cFileName[0] == '.') continue;
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
