/* orion_rt.c — runtime helpers for the native compiler.
 *
 * Compiled alongside generated .ll files to provide:
 *   - __orion_perform_int / __orion_resume_int — one-shot continuations
 *     for algebraic effects, backed by setjmp/longjmp.
 *
 * Single int parameter, single int return for the MVP. Generalize later
 * with __orion_perform_text, __orion_perform_n etc. as needed.
 */

/* Portable C uses fopen/strcpy; MSVC's CRT flags them "deprecated" in
 * favour of non-portable _s variants. We stay portable — suppress. */
#define _CRT_SECURE_NO_WARNINGS 1

#include <setjmp.h>
#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>
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

/* ---- Parser recursion guard ------------------------------------------
 * The compiler's parser is recursive descent: nested parens, unary runs,
 * calls and indented blocks each add a native stack frame. On adversarial
 * input (tens of thousands deep) that overran the linked stack and the
 * compiler died with a raw SIGSEGV / ACCESS VIOLATION and no diagnostic —
 * exactly the failure the fuzzer exists to catch. The parser now bumps
 * this counter at each recursion chokepoint and refuses past a limit with
 * a located `ERROR` instead of crashing. Compilation is single-threaded,
 * so a plain global needs no atomics; `defer psr_depth_drop()` balances
 * every bump, and a fresh process starts it at zero. */
static long long psr_depth_level = 0;
long long psr_depth_bump(void) { psr_depth_level += 1; return psr_depth_level; }
long long psr_depth_drop(void) { if (psr_depth_level > 0) psr_depth_level -= 1; return psr_depth_level; }

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

/* Region-lifetime forensics. region_fit frees a region's old buffer when
 * it grows; a struct built in that region and read after the reset now
 * points into freed (or reused) memory — the classic "value outlived its
 * region" bug that is otherwise a cryptic wild-pointer crash. Remember the
 * last few freed ranges (and the live region bounds) so the crash filter
 * can NAME the region a bad pointer belonged to and prescribe the fix. */
#define ORION_FREED_RING 8
static struct {
    uintptr_t lo, hi;
    const char *name;
} orion_freed[ORION_FREED_RING];
static int orion_freed_n = 0;
static int orion_region_resized = 0; /* any region grown+freed this run */

static void orion_note_freed(const char *name, unsigned char *base, size_t cap) {
    int i = orion_freed_n % ORION_FREED_RING;
    orion_freed[i].lo = (uintptr_t)base;
    orion_freed[i].hi = (uintptr_t)base + cap;
    orion_freed[i].name = name;
    orion_freed_n++;
    orion_region_resized = 1;
}

/* Which region does `addr` fall in? Returns a human sentence or NULL. Checks
 * freed ranges first (the actionable case), then the live regions. */
static const char *orion_region_of(uintptr_t a) {
    for (int i = 0; i < ORION_FREED_RING; i++)
        if (orion_freed[i].lo && a >= orion_freed[i].lo && a < orion_freed[i].hi)
            return orion_freed[i].name;
    return NULL;
}

/* Swap an EMPTY region's buffer for one that fits what the last cycle
 * actually needed. Call only at reset.
 *
 * GROW when the last cycle's peak crowds the buffer (> 3/4 of cap):
 * double until it fits, so the next cycle bumps instead of spilling.
 *
 * SHRINK when the buffer DWARFS the region's recent working set and has
 * done so for a SUSTAINED stretch: halve one step. A transient spike — a
 * heavy render frame, a compaction — otherwise pins RSS at the
 * high-water for the whole session (the grow-only bug: fireplace idled
 * at 223 MB because one busy frame grew the arena to 54 MB and it never
 * came back).
 *
 * The hysteresis (`streak`) is what stops thrash. Without it, a game that
 * alternates a busy render frame (need ~700 KB) with an idle frame
 * (need ~0) grows on the busy frame and shrinks on the idle one, every
 * frame, forever. So a region only shrinks after `SHRINK_PATIENCE`
 * CONSECUTIVE resets all sat under 1/4 of cap; any single healthy cycle
 * resets the streak. A cap that matches the working set (need in the
 * comfortable [1/4, 3/4] band) is left exactly alone. `high`, if
 * non-NULL, is retracted to `need` on a shrink so the mem report shows
 * the recent peak, not a stale session high-water. `streak` NULL opts a
 * region out of shrinking (pools are ring-bounded and never spike). */
#define SHRINK_PATIENCE 180 /* ~3 s at 60 fps of sustained low use */
static void region_fit(const char *name, unsigned char **base, size_t *cap,
                       size_t *high, size_t need, size_t floor, int *streak) {
    if (!*base) return;
    if (need > (*cap / 4) * 3) {
        size_t want = *cap;
        while ((want / 4) * 3 < need) want *= 2;
        unsigned char *fresh = (unsigned char *)malloc(want);
        if (!fresh) return; /* keep the old buffer; spill stays slow */
        orion_note_freed(name, *base, *cap);
        free(*base);
        *base = fresh;
        *cap = want;
        if (streak) *streak = 0;
        fprintf(stderr, "%s[orion] %s region sized to %llu KB%s\n", c_dim(),
                name, (unsigned long long)(want / 1024u), c_off());
        return;
    }
    if (!streak || *cap <= floor || need >= *cap / 4) {
        if (streak) *streak = 0; /* healthy use — reset the patience clock */
        return;
    }
    if (++(*streak) < SHRINK_PATIENCE) return;
    size_t want = *cap / 2;
    if (want < floor) want = floor;
    unsigned char *fresh = (unsigned char *)malloc(want);
    if (!fresh) return; /* keep the old buffer; nothing lost */
    orion_note_freed(name, *base, *cap);
    free(*base);
    *base = fresh;
    *cap = want;
    *streak = 0;
    if (high) *high = need;
    fprintf(stderr, "%s[orion] %s region sized down to %llu KB%s\n", c_dim(),
            name, (unsigned long long)(want / 1024u), c_off());
}

/* Thread-local allocation MODE — the foundation for running Orion systems on
 * worker threads. A worker's mode flags default to off/-1 (its own TLS copy),
 * so every allocation it makes falls straight through orion_alloc to malloc
 * (thread-safe) instead of bumping a region pointer shared with the main
 * thread. The bump regions themselves (arena/frame/pool buffers) stay
 * single-threaded: ONLY the main thread ever turns a mode on, so only it ever
 * touches those buffers. Single-threaded behaviour is byte-identical — the main
 * thread is just "thread 0" with the same defaults. Stats counters (alloc_total
 * etc.) may tear across threads; benign (profiling only, never memory safety). */
#if defined(_WIN32) && defined(_MSC_VER) && !defined(__clang__)
#define ORION_TLS __declspec(thread)
#else
#define ORION_TLS _Thread_local
#endif

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
static size_t arena_high = 0; /* recent high-water (retracted on a shrink) */
static int arena_lowstreak = 0; /* consecutive under-used resets (shrink hysteresis) */
static ORION_TLS int arena_on = 0;
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
static int frame_lowstreak = 0; /* shrink hysteresis, see region_fit */
static ORION_TLS int frame_on = 0;
static ORION_TLS int persist_depth = 0;
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
    region_fit("frame", &frame_base, &frame_cap, &frame_high, need, FRAME_START,
               &frame_lowstreak);
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
static ORION_TLS int pool_active = -1;

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

/* Pool selection is a small STACK: a log/snapshot pool selected
 * inside a world-state scope must restore the OUTER pool on off,
 * not drop to persist — that drop was an invisible leak-by-scope. */
static int pool_prev[8];
static int pool_depth = 0;

long long orion_pool_on(long long i) {
    if (i < 0 || i >= pool_count) return 0;
    if (!pool_base[i]) {
        pool_base[i] = (unsigned char *)malloc(POOL_START);
        pool_cap[i] = POOL_START;
        pool_used[i] = 0;
    }
    if (pool_depth < 8) pool_prev[pool_depth++] = pool_active;
    pool_active = (int)i;
    return 1;
}

long long orion_pool_off(void) {
    pool_active = pool_depth > 0 ? pool_prev[--pool_depth] : -1;
    return 1;
}

long long orion_pool_used(long long i) {
    if (i < 0 || i >= pool_count) return 0;
    return (long long)pool_used[i];
}
/* True pressure: in-buffer bytes PLUS the overflow chain — a full
 * pool spills to malloc silently, and compaction thresholds must
 * see that, not a number frozen at capacity. */
long long orion_pool_pressure(long long i) {
    if (i < 0 || i >= pool_count) return 0;
    return (long long)(pool_used[i] + pool_ovf_bytes[i]);
}
long long orion_pool_high(long long i) {
    if (i < 0 || i >= pool_count) return 0;
    return (long long)pool_high[i];
}
long long orion_pool_cap(long long i) {
    if (i < 0 || i >= pool_count) return 0;
    return (long long)pool_cap[i];
}

/* Does this i64, read as an address, point INTO pool i's live buffer?
 *
 * Named atlas_ rather than orion_ deliberately: the emitter skips emitting a
 * `declare` for extern names starting with orion_, on the assumption that it
 * emits their bodies itself. This one lives in orion_rt.c, which is linked
 * per program, so it needs the declare.
 *
 * The persistence boundary is already safe: a pointer born in the arena or
 * frame region and stored into a persistent slot is evacuated as a typed deep
 * copy, or aborts (see orion_arena_ptr_guard / the evacuation codes). What that
 * cannot see is a POOL-GENERATION crossing: at compaction the live state is
 * rebuilt into the other generation and the retiring one is reset, so a value
 * still aiming into the retiring pool is a dangle - and both sides look alike
 * to any persistence check, because both are pools.
 *
 * The cell word that carries such a value is untyped, so the runtime cannot
 * know whether it is an int or a pointer. It CAN say whether it falls inside a
 * live pool buffer, which is enough to build a detector: after a compaction
 * rebuild, any cell field whose value lands inside the RETIRED pool is either a
 * pointer that was copied by bits, or an integer that coincidentally equals a
 * heap address. The first is the bug; the second is a false positive, and the
 * caller reports rather than assumes - which is why this returns a fact, not a
 * verdict. A typed cell layout is what removes the question entirely.
 *
 * Compared against `used`, not `cap`: only the bytes actually handed out can
 * be the target of a live pointer. */
long long atlas_pool_holds(long long i, long long v) {
    if (i < 0 || i >= pool_count) return 0;
    if (!pool_base[i] || pool_used[i] == 0) return 0;
    const unsigned char *p = (const unsigned char *)(intptr_t)v;
    return (p >= pool_base[i] && p < pool_base[i] + pool_used[i]) ? 1 : 0;
}

/* Is this value a TEXT living in some pool - decided structurally, not guessed?
 *
 * The generation-crossing problem exists because a cell word is untyped: an
 * int and a text pointer are the same 64 bits, so compaction cannot know which
 * fields to deep-copy and the writer has had to declare them by hand. Declaring
 * is something you can forget, and forgetting it was a live crash twice in one
 * day.
 *
 * But a text is not shapeless. It is [hash:i64][len:i64][bytes..NUL] with the
 * pointer aimed at the bytes, so a candidate can be CHECKED rather than assumed:
 * it must land inside a live pool, its 16-byte header must fit inside that same
 * pool, the length it claims must fit too, and the byte at that length must be
 * the terminator. An integer that satisfies all four by coincidence is not a
 * thing that happens - it would have to equal a heap address whose preceding
 * sixteen bytes happen to encode its own exact length.
 *
 * That turns "declare your text fields" from a rule you must remember into a
 * question the runtime can answer, which is the difference between a mistake
 * being detectable and being unmakeable. Only POOL texts need this: a literal
 * lives in rodata and a persisted text on the malloc heap, and neither is
 * reclaimed by a generation flip, so sharing those is already safe. */
long long atlas_any_pool_text(long long v) {
    if (v == 0) return 0;
    const unsigned char *p = (const unsigned char *)(intptr_t)v;
    for (long long i = 0; i < pool_count; i++) {
        const unsigned char *base = pool_base[i];
        if (!base || pool_used[i] == 0) continue;
        const unsigned char *end = base + pool_used[i];
        if (p < base || p >= end) continue;
        if (p - 16 < base) return 0;              /* header must fit */
        long long len = ((const long long *)p)[-1];
        if (len < 0 || len > (long long)(end - p) - 1) return 0;
        if (p[len] != 0) return 0;                /* NUL where it claims */
        return 1;
    }
    return 0;
}

/* Is this value a non-null pointer into some live pool that is NOT a text?
 *
 * A pool text can be relocated across a generation flip because its shape is
 * self-verifying (atlas_any_pool_text). A pool CONTAINER cannot: a list is
 * [cap][len][elems] and a map [entries][cap][len][ix][mask], with no terminator,
 * so cap/len are just plausible integers - detecting one is not certain enough
 * to safely deep-copy it (a misread would dereference garbage). And even if it
 * were, relocating it needs the element types the cell word has erased.
 *
 * So the honest move is not to relocate it silently but to SEE it at spawn. If a
 * cell value lands inside a live pool and is not a verifiable text, it is either
 * a container that will dangle at the next compaction, or an integer that
 * happens to equal a live pool address - both worth a word at the point of
 * creation rather than a wandering crash later. Reports, never aborts, never
 * dereferences: safe even on the rare coincidental integer. */
long long atlas_unrelocatable_pool_ptr(long long v) {
    if (v == 0) return 0;
    if (atlas_any_pool_text(v) == 1) return 0;
    const unsigned char *p = (const unsigned char *)(intptr_t)v;
    for (long long i = 0; i < pool_count; i++) {
        const unsigned char *base = pool_base[i];
        if (!base || pool_used[i] == 0) continue;
        if (p >= base && p < base + pool_used[i]) return 1;
    }
    return 0;
}

long long orion_pool_reset(long long i) {
    if (i < 0 || i >= pool_count) return 0;
    size_t need = pool_used[i] + pool_ovf_bytes[i];
    ovf_drain(&pool_ovf[i], &pool_ovf_bytes[i]);
    if (pool_base[i] && pool_used[i] > 0) {
        memset(pool_base[i], 0xDD, pool_used[i]);
    }
    region_fit("pool", &pool_base[i], &pool_cap[i], &pool_high[i], need,
               POOL_START, NULL);
    pool_used[i] = 0;
    return 1;
}

/* ---- H1: texts carry identity — [hash:i64][len:i64][bytes..NUL],
 * the POINTER aims at bytes so every strcmp/fprintf/extern keeps
 * working. len() is a load at p[-8]; hash at p[-16] is LAZY for
 * heap texts (0 = not yet computed) and BAKED for constants
 * (rodata is unwritable). Hash algo must be identical here and in
 * the emitter's compile-time baking: polynomial base 131, seed
 * 5381, mod 1e9+7 — no overflow in plain i64, no XOR needed. */
#define OTX_MOD 1000000007LL

void *orion_alloc(long long size);

typedef struct { long long h; long long l; char z[1]; } OrionEmptyText;
static const OrionEmptyText otx_empty = {5381, 0, {0}};
const char *orion_text_empty(void) { return otx_empty.z; }

char *orion_text_alloc(long long len) {
    char *base = (char *)orion_alloc(len + 17);
    ((long long *)base)[0] = 0;
    ((long long *)base)[1] = len;
    base[16 + len] = 0;
    return base + 16;
}

long long orion_tlen_c(const char *p) { return ((const long long *)p)[-1]; }

/* Fix the header length after a C formatter wrote into the buffer
 * (snprintf paths do not know their length up front). */
char *orion_text_seal(char *p) {
    ((long long *)p)[-1] = (long long)strlen(p);
    ((long long *)p)[-2] = 0;
    return p;
}

/* Force a FRESH copy of a text into the current allocation region (pool /
 * arena / persist). The compiler folds a bare "{t}" interpolation of a Text
 * value to the same pointer — correct for value semantics, but it defeats a
 * deep copy: the "copy" then shares the source's backing store. A snapshot
 * never noticed (its source outlives it), but COMPACTION resets the source
 * pool, so a shared text dangles. This primitive is the honest deep copy the
 * snapshot/compaction paths need for standalone text values (type names,
 * map keys, cell field names). Composite keys ("{ty}:eids") already allocate
 * via concat and need no help. */
const char *atlas_text_copy(const char *s) {
    if (!s || !s[0]) return otx_empty.z;
    long long n = orion_tlen_c(s);
    char *p = orion_text_alloc(n);
    memcpy(p, s, (size_t)n);
    return p;
}

/* Wrap a foreign C string (argv, env) into a headered text. */
const char *orion_text_from_c(const char *s) {
    if (!s || !s[0]) return otx_empty.z;
    size_t n = strlen(s);
    char *p = orion_text_alloc((long long)n);
    memcpy(p, s, n);
    return p;
}

#include <time.h>
/* Wall-clock strings for the OrionOS lock screen. Formatted in C (zero-pad;
 * Swedish ASCII day/month names — the glyph pipeline is byte-based) and boxed
 * as Orion Text so a bundle can surface them as ctx bindings. localtime() is
 * the platform's local zone. Named atlas_* so a plain `extern fn` gets its
 * LLVM declare (orion_* names skip that path). */
/* Box under persist so the Text is malloc-stable — a frame-region text would
 * dangle once the value flows through a queued astra:set and the region resets
 * before the drain (the crash this replaced). Only allocates when the string
 * changes (minute / day), reusing the stable pointer in between, so the persist
 * churn is negligible. */
static const char *box_stable(const char *now, char *last, size_t cap,
                              const char **cached) {
    if (!*cached || strncmp(now, last, cap) != 0) {
        size_t i = 0;
        for (; now[i] && i + 1 < cap; i++) last[i] = now[i];
        last[i] = 0;
        orion_persist_on();
        *cached = orion_text_from_c(now);
        orion_persist_off();
    }
    return *cached;
}
const char *atlas_clock_text(void) {
    static char last[8]; static const char *cached = 0;
    time_t t = time(NULL);
    struct tm lt = *localtime(&t);
    char buf[8];
    snprintf(buf, sizeof buf, "%02d:%02d", lt.tm_hour, lt.tm_min);
    return box_stable(buf, last, sizeof last, &cached);
}
const char *atlas_date_text(void) {
    static const char *wd[7] = {"son", "man", "tis", "ons", "tor", "fre", "lor"};
    static const char *mo[12] = {"januari", "februari", "mars", "april", "maj",
                                 "juni", "juli", "augusti", "september",
                                 "oktober", "november", "december"};
    static char last[40]; static const char *cached = 0;
    time_t t = time(NULL);
    struct tm lt = *localtime(&t);
    char buf[40];
    snprintf(buf, sizeof buf, "%s %d %s",
             wd[lt.tm_wday % 7], lt.tm_mday, mo[lt.tm_mon % 12]);
    return box_stable(buf, last, sizeof last, &cached);
}

/* Wall-clock as plain INTS — surfaced as ctx bindings (like mouse_x/y) and
 * copied into state by an every-1s rule, then rendered digit-by-digit
 * ("{h}:{mt}{mo}") so the minute zero-pads. Ints flow through a queued
 * astra:set BY VALUE, so unlike the text form (box_stable above) they never
 * dangle — this is the safe path for a live clock. */
long long atlas_clock_hour(void) {
    time_t t = time(NULL);
    return (long long)localtime(&t)->tm_hour;
}
long long atlas_clock_min_tens(void) {
    time_t t = time(NULL);
    return (long long)(localtime(&t)->tm_min / 10);
}
long long atlas_clock_min_ones(void) {
    time_t t = time(NULL);
    return (long long)(localtime(&t)->tm_min % 10);
}


long long orion_text_hash(const char *p) {
    long long h = ((const long long *)p)[-2];
    if (h != 0) return h;
    long long len = ((const long long *)p)[-1];
    h = 5381;
    for (long long i = 0; i < len; i++)
        h = (h * 131 + (unsigned char)p[i]) % OTX_MOD;
    if (h == 0) h = 1;
    ((long long *)p)[-2] = h;
    return h;
}

/* Map keys are OWNED by the map: text keys copy on FIRST insert, so a
 * caller's transient key can never dangle inside a longer-lived map.
 * The copy allocates in the current scope — the same lifetime as the
 * spine growth the insert may do. Kills the shared-key-pointer bug
 * class (two poison-caught crashes in one day) at the language level. */
void *orion_alloc(long long size);
const char *orion_key_copy(const char *key) {
    size_t n = strlen(key);
    char *copy = orion_text_alloc((long long)n);
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

/* ---- Persistence-boundary evacuation (memory-safety class 2) ----
 * slot_set with a pointer value routes here instead of the guard: a
 * pointer into the arena/frame region would dangle at the next reset,
 * so the store EVACUATES a deep copy to the malloc heap, typed by the
 * code the emitter derived statically at the callsite:
 *   0 opaque  (struct/fn/unknown — abort if in-region, can't copy)
 *   1 text    2 flat list    3 list of texts
 *   4 map     5 list of maps
 * Layouts mirror the emitted LLVM exactly: list = [cap][len][elems],
 * map handle = [entries][cap][len] with (key,val) i64 pairs. Map keys
 * copy when they point into a region (text keys born there); int keys
 * never alias region addresses in practice. Map VALUES are untyped —
 * an in-region value still aborts, but now with the reason. */
static int oe_in_region(const void *p) {
    return (arena_base && (const unsigned char *)p >= arena_base &&
            (const unsigned char *)p < arena_base + arena_cap) ||
           (frame_base && (const unsigned char *)p >= frame_base &&
            (const unsigned char *)p < frame_base + frame_cap);
}
static void oe_fatal(const char *what, const char *key) {
    fprintf(stderr,
            "%s[orion] FATAL: %s born in a region stored in persistent "
            "slot '%s' - no copier for its type; persist the value "
            "explicitly%s\n",
            c_red(), what, key, c_off());
    fflush(stderr);
    abort();
}
static const char *oe_text(const char *p) {
    if (!p) return otx_empty.z;
    size_t n = strlen(p);
    char *c = (char *)malloc(n + 17);
    ((long long *)c)[0] = 0;
    ((long long *)c)[1] = (long long)n;
    memcpy(c + 16, p, n + 1);
    return c + 16;
}
static long long *oe_list_spine(const long long *src) {
    long long len = src[1];
    long long *dst = (long long *)malloc((size_t)(len * 8 + 16));
    dst[0] = len;
    dst[1] = len;
    memcpy(dst + 2, src + 2, (size_t)len * 8);
    return dst;
}
static const char *oe_map(const char *p, const char *key) {
    const long long *h = (const long long *)p;
    const long long *ent = (const long long *)(uintptr_t)h[0];
    long long cap = h[1], len = h[2];
    if (cap < 4) cap = 4;
    /* 40-byte handle: [entries][cap][len][index][imask]. The evacuated copy
     * starts with NO hash index (slots 3/4 = 0); it is rebuilt lazily on the
     * next set/lookup, and its index (malloc'd) then matches this persist copy's
     * lifetime. See orion_map_idx_build in emit_runtime. */
    long long *nh = (long long *)malloc(40);
    long long *ne = (long long *)malloc((size_t)cap * 16);
    nh[0] = (long long)(uintptr_t)ne;
    nh[1] = cap;
    nh[2] = len;
    nh[3] = 0;
    nh[4] = 0;
    for (long long i = 0; i < len; i++) {
        long long k = ent[i * 2], v = ent[i * 2 + 1];
        if (oe_in_region((const void *)(uintptr_t)k))
            k = (long long)(uintptr_t)oe_text((const char *)(uintptr_t)k);
        if (oe_in_region((const void *)(uintptr_t)v))
            oe_fatal("map value", key);
        ne[i * 2] = k;
        ne[i * 2 + 1] = v;
    }
    return (const char *)nh;
}
const char *orion_slot_evac(const char *p, const char *key, long long code) {
    if (!p || !oe_in_region(p)) return p;
    if (code == 1) return oe_text(p);
    if (code == 2) return (const char *)oe_list_spine((const long long *)p);
    if (code == 3) {
        long long *d = oe_list_spine((const long long *)p);
        for (long long i = 0; i < d[1]; i++)
            if (oe_in_region((const void *)(uintptr_t)d[i + 2]))
                d[i + 2] = (long long)(uintptr_t)
                    oe_text((const char *)(uintptr_t)d[i + 2]);
        return (const char *)d;
    }
    if (code == 4) return oe_map(p, key);
    if (code == 5) {
        long long *d = oe_list_spine((const long long *)p);
        for (long long i = 0; i < d[1]; i++)
            if (oe_in_region((const void *)(uintptr_t)d[i + 2]))
                d[i + 2] = (long long)(uintptr_t)
                    oe_map((const char *)(uintptr_t)d[i + 2], key);
        return (const char *)d;
    }
    oe_fatal("value", key);
    return p;
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
    region_fit("arena", &arena_base, &arena_cap, &arena_high, need, ARENA_START,
               &arena_lowstreak);
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
    return otx_empty.z;
}
/* Newline-joined paths of every embedded asset — lets ship builds
 * enumerate "directories" they no longer have. */
__attribute__((weak)) const char *orion_embedded_list(void) {
    return otx_empty.z;
}
/* Binary assets (WAVs contain NULs, so _text loses the length):
 * returns the byte pointer and writes the true size. */
__attribute__((weak)) const char *orion_embedded_data(const char *path,
                                                      long long *size) {
    (void)path;
    if (size) *size = 0;
    return otx_empty.z;
}
#endif

/* Counter rack for probe builds: temporary orb instrumentation taps
 * orion_ctr_add, gates read totals. Sixteen anonymous slots — the
 * probe defines what they mean, nothing here persists meaning. */
static long long octr[16];
void octr_add(long long i, long long n) {
    if (i >= 0 && i < 16) octr[i] += n;
}
long long octr_get(long long i) { return (i >= 0 && i < 16) ? octr[i] : 0; }

/* Allocation telemetry: total requested bytes, and the subset served
 * by malloc (arena misses + arena-off) — perf probes read both. */
static long long alloc_total = 0;
static long long alloc_malloc = 0;
long long orion_alloc_total(void) { return alloc_total; }
long long orion_alloc_malloc_total(void) { return alloc_malloc; }

long long orion_arena_high(void) { return (long long)arena_high; }

/* Priority: epoch arena (innermost) > selected pool (beats persist —
 * an explicit shorter lifetime) > persist scope (malloc) > frame
 * region (the frame default) > malloc (setup/tools).
 * Regions never fall through on overflow: the spill chains onto the
 * region's overflow list (same lifetime, freed at its reset) and the
 * reset grows the buffer — so overflow costs a slow cycle, not a
 * leak, and does not count as persist growth. */
/* ---- Malloc-fallback ledger: WHO is dripping? ----
 * Orb code brackets suspicious regions with orion_ledger_tag(name);
 * every allocation that falls through to raw malloc credits the
 * innermost active tag. orion_ledger_dump prints the table. Zero
 * bookkeeping on region-served allocations — this watches only the
 * immortal route. Tags nest like pools (small stack). */
#define OL_MAX 32
static char ol_names[OL_MAX][24];
static long long ol_bytes[OL_MAX];
static int ol_count = 0;
static int ol_cur = -1;
static int ol_prev[8];
static int ol_depth = 0;

long long orion_ledger_tag(const char *name) {
    int idx = -1;
    for (int i = 0; i < ol_count; i++)
        if (strncmp(ol_names[i], name, 23) == 0) { idx = i; break; }
    if (idx < 0 && ol_count < OL_MAX) {
        idx = ol_count++;
        size_t n = strlen(name);
        if (n > 23) n = 23;
        memcpy(ol_names[idx], name, n);
        ol_names[idx][n] = 0;
        ol_bytes[idx] = 0;
    }
    if (ol_depth < 8) ol_prev[ol_depth++] = ol_cur;
    ol_cur = idx;
    return idx;
}
long long orion_ledger_off(void) {
    ol_cur = ol_depth > 0 ? ol_prev[--ol_depth] : -1;
    return 1;
}
static long long ol_untagged = 0;
static void ol_note(long long size) {
    if (ol_cur >= 0) ol_bytes[ol_cur] += size;
    else ol_untagged += size;
}
long long orion_ledger_dump(void) {
    long long total = ol_untagged;
    for (int i = 0; i < ol_count; i++) {
        total += ol_bytes[i];
        if (ol_bytes[i] > 0)
            fprintf(stderr, "[ledger] %-23s %lld B\n", ol_names[i],
                    ol_bytes[i]);
    }
    fprintf(stderr, "[ledger] %-23s %lld B\n", "(untagged)", ol_untagged);
    return total;
}

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
    ol_note(size);
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
    char *buf = (char *)malloc(19 + 16);
    ((long long *)buf)[0] = 0;
    ((long long *)buf)[1] = 18;
    snprintf(buf + 16, 19, "0x%016llX", u.i);
    return buf + 16;
}

/* Thread-local stack of one jmp_buf — only one perform pending at a time
 * for the MVP. Nested perform/resume requires a real stack here. */
static jmp_buf *current_k = NULL;
static long long resume_value = 0;

/* Call the handler with N arguments (0..4). Every Orion value is a 64-bit
 * word - an int or a pointer - so one word-typed entry point serves every
 * parameter shape; the cast per arity is what makes the call ABI-correct.
 *
 * This exists because `perform Effect.op(a, b)` used to lower to the
 * single-argument entry below: the second argument was evaluated and then
 * DROPPED, so the handler read whatever happened to be in the register.
 * `perform Math.add(40, 2)` returned 248. Silently. */
static long long orion_call_handler_n(void *h, long long n,
                                      long long a0, long long a1,
                                      long long a2, long long a3) {
    if (n <= 0) return ((long long (*)(void))h)();
    if (n == 1) return ((long long (*)(long long))h)(a0);
    if (n == 2) return ((long long (*)(long long, long long))h)(a0, a1);
    if (n == 3) return ((long long (*)(long long, long long, long long))h)(a0, a1, a2);
    return ((long long (*)(long long, long long, long long, long long))h)(a0, a1, a2, a3);
}

long long __orion_perform_int_n(void *handler, long long n,
                                long long a0, long long a1,
                                long long a2, long long a3) {
    jmp_buf jb;
    jmp_buf *old_k = current_k;
    current_k = &jb;
    long long ret;
    if (setjmp(jb) == 0) {
        ret = orion_call_handler_n(handler, n, a0, a1, a2, a3);
    } else {
        ret = resume_value;
    }
    current_k = old_k;
    return ret;
}

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

/* Text-returning handler, N word-sized arguments (see the int version). */
char *__orion_perform_text_n(void *handler, long long n,
                             long long a0, long long a1,
                             long long a2, long long a3) {
    jmp_buf jb;
    jmp_buf *old_k = current_k;
    current_k = &jb;
    char *ret;
    if (setjmp(jb) == 0) {
        ret = (char *)(intptr_t)orion_call_handler_n(handler, n, a0, a1, a2, a3);
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
/* ---- The WHY: cause breadcrumbs (PORTABLE) ----
 * The engine always knows which bundle/event/rule is executing — a crash
 * should say so. Dispatch layers drop crumbs (bounded copies into static
 * rings, zero alloc, ~20ns). Recording is zero-API, so it lives OUTSIDE the
 * platform guard: the emitter calls orion_crumb / orion_crumb_rule on every
 * platform (astra's `rule` construct does). Only the crash READER below —
 * which prints the trail newest-first — is Windows-specific for now. */
#define CRUMB_N 8
static char crumb_bundle[CRUMB_N][40];
static char crumb_event[CRUMB_N][24];
static long long crumb_tick_v[CRUMB_N];
static int crumb_head = -1;
static char crumb_rule[64];

static void crumb_copy(char *dst, const char *src, size_t cap) {
    size_t i = 0;
    if (src)
        while (src[i] && i < cap - 1) { dst[i] = src[i]; i++; }
    dst[i] = 0;
}

void orion_crumb(const char *bundle, const char *event, long long tick) {
    crumb_head = (crumb_head + 1) % CRUMB_N;
    crumb_copy(crumb_bundle[crumb_head], bundle, sizeof crumb_bundle[0]);
    crumb_copy(crumb_event[crumb_head], event, sizeof crumb_event[0]);
    crumb_tick_v[crumb_head] = tick;
    crumb_rule[0] = 0;
}

void orion_crumb_rule(const char *rule) {
    crumb_copy(crumb_rule, rule, sizeof crumb_rule);
}

/* Word i of a list's DATA. A list is [cap, len, data…], so the data starts at
 * word 2; a closure is a list too ([fn_ptr, flag, captures…]), which is why
 * the guard, the parallel driver and the closure caller all want this one
 * read. Reading it here rather than calling the compiler-emitted
 * `orion_list_at` keeps orion_rt.c linkable ON ITS OWN, which every pure-C
 * harness depends on (tools/region_shrink_test.sh died with "undefined symbol:
 * orion_list_at" when it did not).
 *
 * It lives ABOVE the _WIN32 block on purpose. There used to be three identical
 * copies of it, and the one the parallel system driver called was the copy
 * inside `#ifdef _WIN32` — so on Linux and Mac that call had no declaration
 * and no definition, and the runtime did not compile at all. Nothing caught
 * it, because the only machine that ever built it was Windows. */
static long long orion_rt_slot(void *p, long long i) {
    return ((long long *)p)[2 + i];
}

#ifdef _WIN32
#include <windows.h>

/* Crash forensics: on an unhandled fault, print the exception code
 * and the MODULE-RELATIVE offset (symbolizable against the link map
 * orbit emits next to the exe) before dying. Fail fast, but say
 * where. The crumb trail recorded above prints newest-first. */

/* The report goes to stderr AND crash.txt — a console window dies
 * with the process, a file survives to be read (by the pilot or by
 * the recovery boot). */
static FILE *crash_tee = NULL;
static void crash_line(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    fprintf(stderr, "%s", c_red());
    vfprintf(stderr, fmt, ap);
    fprintf(stderr, "%s\n", c_off());
    va_end(ap);
    if (crash_tee) {
        va_start(ap, fmt);
        vfprintf(crash_tee, fmt, ap);
        fprintf(crash_tee, "\n");
        va_end(ap);
    }
}

static void crash_print_crumbs(void) {
    if (crumb_head < 0) return;
    if (crumb_rule[0])
        crash_line("[orion]   while rule `%s`", crumb_rule);
    char trail[512];
    trail[0] = 0;
    size_t off = 0;
    for (int k = 0; k < CRUMB_N; k++) {
        int i = (crumb_head - k + CRUMB_N) % CRUMB_N;
        if (!crumb_bundle[i][0] && !crumb_event[i][0]) break;
        int wrote = snprintf(trail + off, sizeof(trail) - off, " %s/%s@%lld",
                             crumb_bundle[i], crumb_event[i], crumb_tick_v[i]);
        if (wrote <= 0) break;
        off += (size_t)wrote;
        if (off >= sizeof(trail) - 1) break;
    }
    crash_line("[orion]   cause trail:%s", trail);
}

/* Crashes symbolize THEMSELVES: the filter loads the link map that
 * orbit always emits next to the exe (<exe>.map) and resolves every
 * module-relative offset to `function +0x..` inline. No debugger,
 * no post-processing, no "look it up" — the crash line IS the
 * diagnosis. Falls back to raw offsets when the map is missing. */
static char *crash_map_buf = NULL;
static void crash_map_load(void) {
    char path[1024];
    DWORD n = GetModuleFileNameA(NULL, path, sizeof path);
    if (n == 0 || n > sizeof(path) - 5) return;
    /* swap .exe -> .map */
    char *dot = strrchr(path, '.');
    if (!dot) return;
    strcpy(dot, ".map");
    FILE *f = fopen(path, "rb");
    if (!f) return;
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    crash_map_buf = (char *)malloc(sz + 1);
    if (crash_map_buf && fread(crash_map_buf, 1, sz, f) == (size_t)sz)
        crash_map_buf[sz] = 0;
    else {
        free(crash_map_buf);
        crash_map_buf = NULL;
    }
    fclose(f);
}
/* Returns 1 when it resolved to a confident named symbol, 0 otherwise.
 * A match more than 8 KB past the nearest .map symbol is almost always the
 * WRONG function (the real one is absent from the map) — a confident-looking
 * bogus name like "RtlUnwind+0x8630" is worse than nothing, so callers can
 * drop those frames and show only the real trace. */
static int crash_sym(unsigned long long off, char *out, size_t cap) {
    snprintf(out, cap, "0x%llx", off);
    if (!crash_map_buf) return 0;
    /* Map lines: " 0001:HHHHHHHH  name ..." — module offset is the
     * section address + 0x1000. Find the greatest base <= off. */
    unsigned long long best = 0;
    char best_name[192] = {0};
    const char *p = crash_map_buf;
    while ((p = strstr(p, " 0001:")) != NULL) {
        unsigned long long a = strtoull(p + 6, NULL, 16) + 0x1000ULL;
        if (a <= off && a >= best) {
            const char *q = p + 6;
            while (*q && *q != ' ') q++;
            while (*q == ' ') q++;
            size_t i = 0;
            while (q[i] && q[i] != ' ' && q[i] != '\r' && q[i] != '\n' &&
                   i < sizeof(best_name) - 1) {
                best_name[i] = q[i];
                i++;
            }
            best_name[i] = 0;
            best = a;
        }
        p += 6;
    }
    if (best_name[0] && (off - best) <= 0x2000ULL) {
        snprintf(out, cap, "%s+0x%llx", best_name, off - best);
        return 1;
    }
    return 0;
}

/* Common Windows exception codes → a plain-language name, so the crash
 * header reads as English instead of a bare hex code. */
static const char *orion_exc_name(unsigned long code) {
    switch (code) {
        case 0xC0000005UL: return "ACCESS VIOLATION (bad pointer)";
        case 0xC00000FDUL: return "STACK OVERFLOW (runaway recursion)";
        case 0xC0000094UL: return "INTEGER DIVIDE BY ZERO";
        case 0xC0000095UL: return "INTEGER OVERFLOW";
        case 0xC000001DUL: return "ILLEGAL INSTRUCTION";
        case 0xC0000090UL: return "FLOAT INVALID OPERATION";
        case 0x80000003UL: return "BREAKPOINT";
        default:           return "exception";
    }
}

/* Games run with a build/ dir beside their exe; drop crash artifacts there
 * so the project root stays clean. Programs with no build/ (the compiler,
 * CLI tools) fall back to the current directory. */
static const char *orion_artifact(const char *name, char *buf, size_t n) {
    DWORD a = GetFileAttributesA("build");
    if (a != INVALID_FILE_ATTRIBUTES && (a & FILE_ATTRIBUTE_DIRECTORY)) {
        snprintf(buf, n, "build\\%s", name);
        return buf;
    }
    return name;
}

static LONG WINAPI orion_crash_filter(EXCEPTION_POINTERS *info) {
    unsigned long long base = (unsigned long long)GetModuleHandleA(NULL);
    unsigned long long at =
        (unsigned long long)info->ExceptionRecord->ExceptionAddress;
    char sym[256];
    char artbuf[512];
    crash_map_load();
    crash_tee = fopen(orion_artifact("crash.txt", artbuf, sizeof artbuf), "w");
    /* Unbuffered: the filter itself may die (nested fault in dbghelp
     * etc.) — every line must hit disk the moment it is written. */
    if (crash_tee)
        setvbuf(crash_tee, NULL, _IONBF, 0);
    crash_sym(at - base, sym, sizeof sym);
    crash_line("[orion] FATAL: %s  (0x%lx)  at %s",
               orion_exc_name(info->ExceptionRecord->ExceptionCode),
               (unsigned long)info->ExceptionRecord->ExceptionCode, sym);
    crash_print_crumbs();
    /* Backtrace: scan the crashed thread's stack for return addresses
     * inside our module, symbolized inline. No dbghelp, always works. */
    if (info->ContextRecord) {
        unsigned long long rip = info->ContextRecord->Rip;
        unsigned long long rsp = info->ContextRecord->Rsp;
        unsigned long long lo = base, hi = base + 0x200000ULL;
        int printed = 0;
        if (rip >= lo && rip < hi) {
            crash_sym(rip - base, sym, sizeof sym);
            crash_line("[orion]   at  %s", sym);
        }
        crash_line("[orion]   call stack (nearest first):");
        /* Scan only committed stack: a shallow crash puts the stack
         * top within 512 words of rsp, and reading past it would
         * nested-fault and kill the filter mid-report. */
        unsigned long long slo = 0, shi = 0;
        GetCurrentThreadStackLimits((PULONG_PTR)&slo, (PULONG_PTR)&shi);
        unsigned long long *sp = (unsigned long long *)rsp;
        for (int i = 0; i < 512 && printed < 12; i++) {
            if (shi && (unsigned long long)(sp + i + 1) > shi)
                break;
            unsigned long long v = sp[i];
            /* Only frames that resolve to a REAL named symbol: a stack scan
             * turns up stale return addresses and misresolved slots, and a
             * page of bogus "RtlUnwind+0x…" lines buries the real trace. */
            if (v >= lo && v < hi && crash_sym(v - base, sym, sizeof sym)) {
                crash_line("[orion]   #%d %s", printed, sym);
                printed++;
            }
        }
        if (printed == 0)
            crash_line("[orion]   (no named frames — see crash.dmp)");
    }
    /* Access violations carry the faulting data address; a 0xdd..dd
     * byte pattern means a read through region memory poisoned at
     * reset — a lifetime bug, not a wild pointer. Printed BEFORE the
     * minidump attempt: dbghelp can nested-fault and kill the filter,
     * and the diagnosis must never depend on it. */
    if (info->ExceptionRecord->ExceptionCode == 0xC0000005 &&
        info->ExceptionRecord->NumberParameters >= 2) {
        unsigned long long bad = info->ExceptionRecord->ExceptionInformation[1];
        int poison = ((bad >> 8) & 0xffffffffULL) == 0xddddddddULL ||
                     (bad & 0xffffffff00ULL) == 0xdddddddd00ULL ||
                     ((bad >> 16) & 0xffffffffULL) == 0xddddddddULL;
        const char *why;
        if (poison)
            why = " — 0xDD poison: memory used after its arena was reset (lifetime bug)";
        else if (bad == 0xffffffffffffffffULL)
            why = " — value is -1: an uninitialized field or a missing map key read as a pointer";
        else if (bad < 0x1000ULL)
            why = " — near-null: an unset struct field or empty/missing value";
        else
            why = "";
        crash_line("[orion]        %s address 0x%llx%s",
                   info->ExceptionRecord->ExceptionInformation[0] ? "writing"
                                                                  : "reading",
                   bad, why);
        /* Region-lifetime forensics. If the bad address lands in a region
         * buffer we freed at a resize, this is a value that outlived its
         * region — name it and prescribe persist. Even when the address is
         * -1/near-null (the region buffer was freed AND reused, so the
         * dangling read returns garbage rather than the old range), a resize
         * having happened at all is the tell — surface it so the next person
         * doesn't spend hours: this was fireplace's Renderer-in-frame-region
         * crash exactly. */
        const char *region = orion_region_of((uintptr_t)bad);
        if (region)
            crash_line("[orion]        ^ points into the %s region's buffer, freed at a resize "
                       "— LIFETIME BUG: this value outlived its region; build it under "
                       "orion_persist_on()", region);
        else if (orion_region_resized && (poison || bad == 0xffffffffffffffffULL || bad < 0x1000ULL))
            crash_line("[orion]        ^ a region was resized (buffer freed) earlier this run — "
                       "if a struct built in the arena/frame region is read after its reset it "
                       "dangles; build it under orion_persist_on() (see the 'region sized' line above)");
    }
    fflush(stderr);
    if (crash_tee) {
        fclose(crash_tee);
        crash_tee = NULL;
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
                char dmpbuf[512];
                HANDLE f = CreateFileA(orion_artifact("crash.dmp", dmpbuf, sizeof dmpbuf),
                                       GENERIC_READ | GENERIC_WRITE, 0, NULL,
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
    return EXCEPTION_CONTINUE_SEARCH; /* still crash, still WER */
}

static void orion_crash_filter_install(void) {
    SetUnhandledExceptionFilter(orion_crash_filter);
}

/* ---- Supervision: run a rule dispatch under a fault net (B6 step 2).
 * sup_guard5/7 call an Orion fn ref with the caller's own arguments; a
 * hardware fault inside does NOT kill the process. The vectored handler
 * writes the full crash report first (same trinity, same crash.txt —
 * supervision never costs diagnosis), then steers the faulting thread
 * into a longjmp back here and the guard returns -1 so the engine can
 * quarantine the rule and rewind the world. The net exists only while
 * a guard is armed on this thread; everything else still dies loudly
 * through the unhandled filter. Stack overflow stays fatal by design:
 * the report machinery cannot run on an exhausted stack. */
static jmp_buf guard_jb;
static volatile unsigned long guard_tid = 0;
static volatile int guard_armed = 0;

static void guard_bounce(void) { longjmp(guard_jb, 1); }

static LONG WINAPI orion_guard_vector(EXCEPTION_POINTERS *info) {
    if (!guard_armed || GetCurrentThreadId() != guard_tid)
        return EXCEPTION_CONTINUE_SEARCH;
    DWORD code = info->ExceptionRecord->ExceptionCode;
    if (code != 0xC0000005 /* AV */ && code != 0xC0000094 /* idiv 0 */ &&
        code != 0xC000001D /* illegal instr */)
        return EXCEPTION_CONTINUE_SEARCH;
    guard_armed = 0; /* a fault inside the report must fall through */
    orion_crash_filter(info);
    fprintf(stderr, "%s[orion] caught by supervisor — quarantine + rewind%s\n",
            c_red(), c_off());
    /* The longjmp must run OUTSIDE the exception dispatcher: point the
     * resumed context at guard_bounce. Rsp realigned as if just called
     * (entry alignment = 16n-8); the garbage return address is fine,
     * guard_bounce never returns. */
    info->ContextRecord->Rsp = (info->ContextRecord->Rsp & ~0xFULL) - 8;
    info->ContextRecord->Rip = (unsigned long long)(void *)guard_bounce;
    return EXCEPTION_CONTINUE_EXECUTION;
}

/* The fault may abandon region scopes mid-flight (arena on, pool or
 * ledger stack pushed, persist depth held) — snapshot on arm, restore
 * on catch, or every later allocation lands in the wrong lifetime. */
typedef struct {
    int arena, pactive, pdepth, olc, old, persist;
} guard_alloc_state;

static void guard_save(guard_alloc_state *s) {
    s->arena = arena_on;
    s->pactive = pool_active;
    s->pdepth = pool_depth;
    s->olc = ol_cur;
    s->old = ol_depth;
    s->persist = persist_depth;
}

static void guard_restore(const guard_alloc_state *s) {
    arena_on = s->arena;
    pool_active = s->pactive;
    pool_depth = s->pdepth;
    ol_cur = s->olc;
    ol_depth = s->old;
    persist_depth = s->persist;
}

static void guard_install(void) {
    static void *vh = NULL;
    if (!vh) vh = AddVectoredExceptionHandler(1, orion_guard_vector);
}

/* An Orion fn-ref arrives here as a CLOSURE list [fn_addr, flag] — the
 * compiler wraps every fn-ref value that way (flag 1 = a lambda that takes
 * its env as a leading arg, else a plain fn-ref). The old code cast this
 * list pointer straight to code and jumped into the list's own memory (the
 * wild 0xAA crash the GUI hit; soak never armed the guard). Unwrap it the
 * way closure_call does: element 0 is the real function, element 1 the flag. */
long long sup_guard5(long long fn, long long a, long long b, long long c,
                     long long d, long long e) {
    guard_install();
    guard_alloc_state st;
    guard_save(&st);
    if (setjmp(guard_jb)) {
        guard_restore(&st);
        return -1;
    }
    /* Zero the SEH frame slot: longjmp becomes a plain register
     * restore instead of RtlUnwindEx through frames the fault left
     * in an unknown state. Nothing between arm and fault owns
     * destructors — this runtime has none. */
    ((unsigned long long *)guard_jb)[0] = 0;
    guard_tid = GetCurrentThreadId();
    guard_armed = 1;
    void *clos = (void *)fn;
    long long real = orion_rt_slot(clos, 0);
    long long lam = orion_rt_slot(clos, 1);
    long long r;
    if (lam == 1)
        r = ((long long (*)(void *, long long, long long, long long, long long,
                            long long))(void *)real)(clos, a, b, c, d, e);
    else
        r = ((long long (*)(long long, long long, long long, long long,
                            long long))(void *)real)(a, b, c, d, e);
    guard_armed = 0;
    return r;
}

long long sup_guard7(long long fn, long long a, long long b, long long c,
                     long long d, long long e, long long f, long long g) {
    guard_install();
    guard_alloc_state st;
    guard_save(&st);
    if (setjmp(guard_jb)) {
        guard_restore(&st);
        return -1;
    }
    ((unsigned long long *)guard_jb)[0] = 0;
    guard_tid = GetCurrentThreadId();
    guard_armed = 1;
    void *clos = (void *)fn;
    long long real = orion_rt_slot(clos, 0);
    long long lam = orion_rt_slot(clos, 1);
    long long r;
    if (lam == 1)
        r = ((long long (*)(void *, long long, long long, long long, long long,
                            long long, long long, long long))(void *)real)(
            clos, a, b, c, d, e, f, g);
    else
        r = ((long long (*)(long long, long long, long long, long long,
                            long long, long long, long long))(void *)real)(
            a, b, c, d, e, f, g);
    guard_armed = 0;
    return r;
}

/* Which rule was executing when the guard tripped — the quarantine
 * key. Headered per H1 (every Text the runtime hands out carries
 * [hash][len]). */
const char *sup_rule_name(void) {
    return orion_text_from_c(crumb_rule[0] ? crumb_rule : "");
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
    static char out_raw[512 + 16];
    char *out = out_raw + 16;
    if (_isatty(_fileno(stdin))) {
        while (_kbhit()) {
            int c = _getch();
            if (c == '\r' || c == '\n') {
                putchar('\n');
                buf[blen] = 0;
                memcpy(out, buf, blen + 1);
                blen = 0;
                if (out[0] != 0) return orion_text_seal(out);
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
        return otx_empty.z;
    }
    HANDLE h = GetStdHandle((DWORD)-10); /* STD_INPUT_HANDLE */
    DWORD avail = 0;
    if (!PeekNamedPipe(h, NULL, 0, NULL, &avail, NULL)) return otx_empty.z;
    while (avail > 0 && blen < 511) {
        char c;
        DWORD rd = 0;
        if (!ReadFile(h, &c, 1, &rd, NULL) || rd == 0) break;
        avail--;
        if (c == '\n') {
            buf[blen] = 0;
            memcpy(out, buf, blen + 1);
            blen = 0;
            if (out[0] != 0) return orion_text_seal(out);
            continue;
        }
        if (c != '\r') buf[blen++] = c;
    }
    return otx_empty.z;
}

/* Newline-joined SUBDIRECTORY names in `dir` (no . / .., one level).
 * Feature-grouped script dirs are discovered with this. */
const char *orion_dir_subdirs(const char *dir) {
    char pattern[1024];
    WIN32_FIND_DATAA fd;
    snprintf(pattern, sizeof(pattern), "%s\\*", dir);
    HANDLE h = FindFirstFileA(pattern, &fd);
    if (h == INVALID_HANDLE_VALUE) return otx_empty.z;
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
    /* Evacuate into the scope allocator and free the growth buffer —
     * the raw malloc leaked one listing per call, forever (the soak
     * ledger billed script reloads ~16KB each for these). */
    {
        char *evac = orion_text_alloc((long long)len);
        memcpy(evac, out, len + 1);
        free(out);
        return evac;
    }
}

const char *orion_dir_list(const char *dir) {
    char pattern[1024];
    WIN32_FIND_DATAA fd;
    snprintf(pattern, sizeof(pattern), "%s\\*", dir);
    HANDLE h = FindFirstFileA(pattern, &fd);
    if (h == INVALID_HANDLE_VALUE) return otx_empty.z;
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
    {
        char *evac = orion_text_alloc((long long)len);
        memcpy(evac, out, len + 1);
        free(out);
        return evac;
    }
}
/* Absolute path of the running executable — lets orbit find its own toolchain
 * (orion.exe + runtime beside it) so projects never hard-code the engine path.
 * Placed here, after windows.h, so GetModuleFileNameA/DWORD are in scope. */
const char *host_self_exe(void) {
    char path[4096];
    DWORD n = GetModuleFileNameA(NULL, path, (DWORD)sizeof path);
    if (n == 0 || n >= sizeof path) return otx_empty.z;
    path[n] = 0;
    return orion_text_from_c(path);
}
/* Subdirectories of `dir` (newline-separated, excludes . and ..). Lets orbit
 * scan a workspace for orbs regardless of folder layout. host_* so the
 * compiler auto-declares it. */
const char *host_subdirs(const char *dir) {
    char pattern[1024];
    WIN32_FIND_DATAA fd;
    snprintf(pattern, sizeof(pattern), "%s\\*", dir);
    HANDLE h = FindFirstFileA(pattern, &fd);
    if (h == INVALID_HANDLE_VALUE) return otx_empty.z;
    size_t cap = 4096, len = 0;
    char *out = (char *)malloc(cap);
    out[0] = 0;
    do {
        if (!(fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)) continue;
        if (fd.cFileName[0] == '.' &&
            (fd.cFileName[1] == 0 || (fd.cFileName[1] == '.' && fd.cFileName[2] == 0)))
            continue;
        size_t n = strlen(fd.cFileName);
        if (len + n + 2 > cap) { cap *= 2; out = (char *)realloc(out, cap); }
        if (len > 0) out[len++] = '\n';
        memcpy(out + len, fd.cFileName, n + 1);
        len += n;
    } while (FindNextFileA(h, &fd));
    FindClose(h);
    {
        char *evac = orion_text_alloc((long long)len);
        memcpy(evac, out, len + 1);
        free(out);
        return evac;
    }
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
/* Same QPC source in microseconds: sub-millisecond frame costs round to
 * 0 in the ms clock, so any per-frame capability metric needs this.
 * Named atlas_* (not orion_*) on purpose: orion_* symbols are treated as
 * compiler builtins and skip the auto-extern-declare path, so a plain
 * `extern fn` on an orion_-named symbol never gets its LLVM `declare`. */
long long atlas_monotonic_us(void) {
    static LARGE_INTEGER freq;
    LARGE_INTEGER c;
    if (!freq.QuadPart) QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&c);
    return (long long)(c.QuadPart * 1000000 / freq.QuadPart);
}
/* Best-effort mkdir (single dir) — games route saves under saves/. Named
 * atlas_* so the compiler auto-declares it for a plain `extern fn`. */
long long atlas_mkdir(const char *path) {
    CreateDirectoryA(path, NULL);
    return 1;
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
long long atlas_monotonic_us(void) {
    struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long)ts.tv_sec * 1000000 + ts.tv_nsec / 1000;
}
/* Best-effort mkdir (single dir) — games route saves under saves/. Named
 * atlas_* so the compiler auto-declares it for a plain `extern fn`. */
long long atlas_mkdir(const char *path) {
    mkdir(path, 0755);
    return 1;
}
void __orion_sleep_ms(long long ms) {
    if (ms > 0) {
        struct timespec t = { ms / 1000, (ms % 1000) * 1000000 };
        nanosleep(&t, NULL);
    }
}
#include <dirent.h>
/* POSIX mirror of the Windows FindFirstFile version: newline-separated file
 * names (directories skipped), returned as a headered Text. */
const char *orion_dir_list(const char *dir) {
    DIR *d = opendir(dir);
    if (!d) return otx_empty.z;
    size_t cap = 4096, len = 0;
    char *out = (char *)malloc(cap);
    out[0] = 0;
    struct dirent *ent;
    while ((ent = readdir(d))) {
        char full[4096];
        struct stat st;
        snprintf(full, sizeof(full), "%s/%s", dir, ent->d_name);
        if (stat(full, &st) == 0 && S_ISDIR(st.st_mode)) continue;
        size_t n = strlen(ent->d_name);
        if (len + n + 2 > cap) { cap *= 2; out = (char *)realloc(out, cap); }
        if (len > 0) out[len++] = '\n';
        memcpy(out + len, ent->d_name, n + 1);
        len += n;
    }
    closedir(d);
    {
        char *evac = orion_text_alloc((long long)len);
        memcpy(evac, out, len + 1);
        free(out);
        return evac;
    }
}
/* Absolute path of the running executable (POSIX mirror). unistd.h for
 * readlink is included with the other POSIX headers. */
const char *host_self_exe(void) {
    char path[4096];
    ssize_t n = readlink("/proc/self/exe", path, sizeof path - 1);
    if (n <= 0) return otx_empty.z;
    path[n] = 0;
    return orion_text_from_c(path);
}
/* Subdirectories of `dir` (newline-separated, excludes . and ..). Lets orbit
 * scan a workspace for orbs regardless of folder layout. */
const char *host_subdirs(const char *dir) {
    DIR *d = opendir(dir);
    if (!d) return otx_empty.z;
    size_t cap = 4096, len = 0;
    char *out = (char *)malloc(cap);
    out[0] = 0;
    struct dirent *ent;
    while ((ent = readdir(d))) {
        if (ent->d_name[0] == '.' &&
            (ent->d_name[1] == 0 || (ent->d_name[1] == '.' && ent->d_name[2] == 0)))
            continue;
        char full[4096];
        struct stat st;
        snprintf(full, sizeof(full), "%s/%s", dir, ent->d_name);
        if (!(stat(full, &st) == 0 && S_ISDIR(st.st_mode))) continue;
        size_t n = strlen(ent->d_name);
        if (len + n + 2 > cap) { cap *= 2; out = (char *)realloc(out, cap); }
        if (len > 0) out[len++] = '\n';
        memcpy(out + len, ent->d_name, n + 1);
        len += n;
    }
    closedir(d);
    {
        char *evac = orion_text_alloc((long long)len);
        memcpy(evac, out, len + 1);
        free(out);
        return evac;
    }
}

/* Same contract as the Windows one above it: newline-joined subdirectory
 * names, one level. It skips EVERY dot-entry, not just . and .. — the callers
 * are looking for project directories and have no use for .git or .vscode.
 *
 * This had no POSIX half at all, so the LSP referenced a symbol that only
 * existed on Windows and did not link on Linux. Nothing caught it, because
 * nothing built the LSP anywhere else. */
const char *orion_dir_subdirs(const char *dir) {
    DIR *d = opendir(dir);
    if (!d) return otx_empty.z;
    size_t cap = 1024, len = 0;
    char *out = (char *)malloc(cap);
    out[0] = 0;
    struct dirent *ent;
    while ((ent = readdir(d))) {
        if (ent->d_name[0] == '.') continue;
        char full[4096];
        struct stat st;
        snprintf(full, sizeof(full), "%s/%s", dir, ent->d_name);
        if (!(stat(full, &st) == 0 && S_ISDIR(st.st_mode))) continue;
        size_t n = strlen(ent->d_name);
        if (len + n + 2 > cap) { cap *= 2; out = (char *)realloc(out, cap); }
        if (len > 0) out[len++] = '\n';
        memcpy(out + len, ent->d_name, n + 1);
        len += n;
    }
    closedir(d);
    /* Evacuate into the scope allocator and free the growth buffer — the raw
     * malloc would leak one listing per call, the way the Windows half used
     * to before the soak ledger caught it. */
    {
        char *evac = orion_text_alloc((long long)len);
        memcpy(evac, out, len + 1);
        free(out);
        return evac;
    }
}

/* POSIX half of the console poll. Same contract as the Windows one: never
 * blocks, returns an empty text until a whole line has arrived.
 *
 * REDIRECTED stdin only — an agent or a script driving a running program
 * through a pipe, which is the case that matters and the case that can be
 * tested. On an interactive terminal this returns empty and does nothing,
 * deliberately: keystroke-at-a-time input needs raw termios, and a half-right
 * version of that leaves the user's shell in cbreak mode when the program
 * dies. Better a feature that plainly is not there yet than one that breaks
 * the terminal it was supposed to read.
 *
 * It exists at all because the compiler DECLARES this symbol in every module
 * it emits. Windows-only definition meant any program that actually called it
 * failed at the linker on Linux with no hint as to why. */
#include <unistd.h>
#include <sys/select.h>
const char *orion_console_readline(void) {
    static char buf[512];
    static size_t blen = 0;
    static char out_raw[512 + 16];
    char *out = out_raw + 16;
    if (isatty(0)) return otx_empty.z;
    for (;;) {
        fd_set r;
        struct timeval zero = {0, 0};
        FD_ZERO(&r);
        FD_SET(0, &r);
        if (select(1, &r, NULL, NULL, &zero) <= 0) break;
        char c;
        if (read(0, &c, 1) != 1) break;
        if (c == '\n') {
            buf[blen] = 0;
            memcpy(out, buf, blen + 1);
            blen = 0;
            if (out[0] != 0) return orion_text_seal(out);
            continue;
        }
        if (c != '\r' && blen < 511) buf[blen++] = c;
    }
    return otx_empty.z;
}
#endif

/* Host OS for the few places Orion code must branch on it (path separators,
 * clang target). 0 = Windows, 1 = Linux/other POSIX, 2 = macOS. */
#if defined(_WIN32)
long long host_os(void) { return 0; }
#elif defined(__APPLE__)
long long host_os(void) { return 2; }
#else
long long host_os(void) { return 1; }
#endif

/* PNG sprite loader (host_image_load) — see png_min.c */
#include "png_min.c"

/* --- Parallel multiply-add: dst[i] += src[i]*k, split across CPU cores.
 * The multicore ECS system loop. Output ranges are DISJOINT (each thread owns
 * a contiguous slice), so there are no data races and no locks, and the result
 * is bit-identical to the serial version regardless of thread count or timing
 * - parallel AND deterministic. List layout is [i64 len, data...]. */
#if defined(_WIN32)
#include <windows.h>
#define ORION_POOL_MAX 64
typedef struct { long long *dd; long long *sd; long long k; long long lo; long long hi; } orion_madd_task;
/* Persistent worker pool: threads are created ONCE (lazily) and parked on an
 * auto-reset "go" event, so per-tick dispatch costs a SetEvent + a wait, not a
 * thread creation. Each worker owns a disjoint output slice -> no races. */
static HANDLE orion_pool_threads[ORION_POOL_MAX];
static HANDLE orion_pool_go[ORION_POOL_MAX];
static HANDLE orion_pool_done[ORION_POOL_MAX];
static orion_madd_task orion_pool_tasks[ORION_POOL_MAX];
static long long orion_pool_n = 0;
static DWORD WINAPI orion_pool_worker(LPVOID arg) {
    long long idx = (long long)arg;
    for (;;) {
        WaitForSingleObject(orion_pool_go[idx], INFINITE);
        orion_madd_task *t = &orion_pool_tasks[idx];
        long long i;
        for (i = t->lo; i < t->hi; i++) t->dd[i] += t->sd[i] * t->k;
        SetEvent(orion_pool_done[idx]);
    }
}
static void orion_pool_init(void) {
    if (orion_pool_n != 0) return;
    SYSTEM_INFO si; GetSystemInfo(&si);
    long long nt = (long long)si.dwNumberOfProcessors;
    if (nt < 1) nt = 1;
    if (nt > ORION_POOL_MAX) nt = ORION_POOL_MAX;
    long long i;
    for (i = 0; i < nt; i++) {
        orion_pool_go[i] = CreateEvent(NULL, FALSE, FALSE, NULL);
        orion_pool_done[i] = CreateEvent(NULL, FALSE, FALSE, NULL);
        orion_pool_threads[i] = CreateThread(NULL, 0, orion_pool_worker, (LPVOID)i, 0, NULL);
    }
    orion_pool_n = nt;
}
void *orion_par_madd(void *dstp, void *srcp, long long k) {
    orion_pool_init();
    long long *dst = (long long *)dstp;
    long long *src = (long long *)srcp;
    long long n = dst[0];
    long long *dd = dst + 1;
    long long *sd = src + 1;
    long long nt = orion_pool_n;
    if (nt > n) nt = (n > 0 ? n : 1);
    long long chunk = (n + nt - 1) / nt;
    HANDLE dones[ORION_POOL_MAX];
    long long made = 0, i;
    for (i = 0; i < nt; i++) {
        long long lo = i * chunk;
        long long hi = lo + chunk;
        if (hi > n) hi = n;
        if (lo >= hi) break;
        orion_pool_tasks[i].dd = dd; orion_pool_tasks[i].sd = sd; orion_pool_tasks[i].k = k;
        orion_pool_tasks[i].lo = lo; orion_pool_tasks[i].hi = hi;
        dones[made] = orion_pool_done[i];
        made++;
        SetEvent(orion_pool_go[i]);
    }
    if (made > 0) WaitForMultipleObjects((DWORD)made, dones, TRUE, INFINITE);
    return dstp;
}
#else
void *orion_par_madd(void *dstp, void *srcp, long long k) {
    long long *dst = (long long *)dstp;
    long long *src = (long long *)srcp;
    long long n = dst[0];
    long long *dd = dst + 1, *sd = src + 1, i;
    for (i = 0; i < n; i++) dd[i] += sd[i] * k;
    return dstp;
}
#endif

/* --- Parallel SYSTEM runner: run a set of Orion system closures concurrently,
 * one per worker. A system is fn(World, dt)->int; World is a boxed struct, i.e.
 * a single pointer (data values are heap records — see struct_cons), so the ABI
 * is just (ptr world, i64 dt). SAFE only for a footprint BATCH: the scheduler
 * guarantees the systems write DISJOINT columns and only READ shared world
 * state, so there are no data races and the result is bit-identical to running
 * the batch serially. A worker that allocates falls through orion_alloc to
 * malloc (the alloc mode flags are thread-local and default off on a worker),
 * so allocation is thread-safe too. Structural effects (spawn/despawn via
 * apply_effect, which mutate shared world state) are NOT permitted inside a
 * parallel system — those run on the main thread in their own batch.
 *
 * A closure is a list [fn_ptr, flag]; flag 1 = lambda taking its env first. */
static long long orion_call_system(void *clos, void *world, long long dt) {
    long long real = orion_rt_slot(clos, 0);
    long long lam = orion_rt_slot(clos, 1);
    if (lam == 1)
        return ((long long (*)(void *, void *, long long))(void *)real)(clos, world, dt);
    return ((long long (*)(void *, long long))(void *)real)(world, dt);
}

#if defined(_WIN32)
typedef struct { void *clos; void *world; long long dt; } orion_sys_task;
static HANDLE orion_sys_threads[ORION_POOL_MAX];
static HANDLE orion_sys_go[ORION_POOL_MAX];
static HANDLE orion_sys_done[ORION_POOL_MAX];
static orion_sys_task orion_sys_tasks[ORION_POOL_MAX];
static long long orion_sys_n = 0;
static DWORD WINAPI orion_sys_worker(LPVOID arg) {
    long long idx = (long long)arg;
    for (;;) {
        WaitForSingleObject(orion_sys_go[idx], INFINITE);
        orion_sys_task *t = &orion_sys_tasks[idx];
        orion_call_system(t->clos, t->world, t->dt);
        SetEvent(orion_sys_done[idx]);
    }
}
static void orion_sys_pool_init(void) {
    if (orion_sys_n != 0) return;
    SYSTEM_INFO si; GetSystemInfo(&si);
    long long nt = (long long)si.dwNumberOfProcessors;
    if (nt < 1) nt = 1;
    if (nt > ORION_POOL_MAX) nt = ORION_POOL_MAX;
    long long i;
    for (i = 0; i < nt; i++) {
        orion_sys_go[i] = CreateEvent(NULL, FALSE, FALSE, NULL);
        orion_sys_done[i] = CreateEvent(NULL, FALSE, FALSE, NULL);
        orion_sys_threads[i] = CreateThread(NULL, 0, orion_sys_worker, (LPVOID)i, 0, NULL);
    }
    orion_sys_n = nt;
}
/* systems = Orion [Fn] with layout [i64 len, elem0, ...]; each elem is a closure
 * pointer. Runs min(len, cores) on workers; any surplus runs inline here (a
 * batch is normally far smaller than the core count). Returns the count run. */
long long atlas_par_systems(void *systems, void *world, long long dt) {
    orion_sys_pool_init();
    long long cnt = ((long long *)systems)[0];
    long long nt = orion_sys_n;
    HANDLE dones[ORION_POOL_MAX];
    long long made = 0, i;
    for (i = 0; i < cnt && i < nt; i++) {
        orion_sys_tasks[i].clos = (void *)orion_rt_slot(systems, i);
        orion_sys_tasks[i].world = world;
        orion_sys_tasks[i].dt = dt;
        dones[made++] = orion_sys_done[i];
        SetEvent(orion_sys_go[i]);
    }
    for (i = nt; i < cnt; i++)
        orion_call_system((void *)orion_rt_slot(systems, i), world, dt);
    if (made > 0) WaitForMultipleObjects((DWORD)made, dones, TRUE, INFINITE);
    return cnt;
}
#else
long long atlas_par_systems(void *systems, void *world, long long dt) {
    long long cnt = ((long long *)systems)[0];
    long long i;
    for (i = 0; i < cnt; i++)
        orion_call_system((void *)orion_rt_slot(systems, i), world, dt);
    return cnt;
}
#endif

/* --- General parallel run: call each closure(arg) on a worker and return the
 * SUM of their results. A closure is [fn_ptr, flag] (flag 1 = lambda taking
 * its env first). Each worker writes ONLY its own task's result slot, so there
 * are no data races, and the reduction (sum) is order-independent -> the result
 * is deterministic regardless of thread count/timing. Surplus beyond the core
 * count runs inline on the calling thread. Exposed to Orion via `extern fn`. */
static long long orion_call_one(void *clos, long long arg) {
    long long real = orion_rt_slot(clos, 0);
    long long lam = orion_rt_slot(clos, 1);
    if (lam == 1)
        return ((long long (*)(void *, long long))(void *)real)(clos, arg);
    return ((long long (*)(long long))(void *)real)(arg);
}
#if defined(_WIN32)
typedef struct { void *clos; long long arg; long long result; } orion_run_task;
static HANDLE orion_run_threads[ORION_POOL_MAX];
static HANDLE orion_run_go[ORION_POOL_MAX];
static HANDLE orion_run_done[ORION_POOL_MAX];
static orion_run_task orion_run_tasks[ORION_POOL_MAX];
static long long orion_run_n = 0;
static DWORD WINAPI orion_run_worker(LPVOID a) {
    long long idx = (long long)a;
    for (;;) {
        WaitForSingleObject(orion_run_go[idx], INFINITE);
        orion_run_task *t = &orion_run_tasks[idx];
        t->result = orion_call_one(t->clos, t->arg);
        SetEvent(orion_run_done[idx]);
    }
}
static void orion_run_pool_init(void) {
    if (orion_run_n != 0) return;
    SYSTEM_INFO si; GetSystemInfo(&si);
    long long nt = (long long)si.dwNumberOfProcessors;
    if (nt < 1) nt = 1;
    if (nt > ORION_POOL_MAX) nt = ORION_POOL_MAX;
    long long i;
    for (i = 0; i < nt; i++) {
        orion_run_go[i] = CreateEvent(NULL, FALSE, FALSE, NULL);
        orion_run_done[i] = CreateEvent(NULL, FALSE, FALSE, NULL);
        orion_run_threads[i] = CreateThread(NULL, 0, orion_run_worker, (LPVOID)i, 0, NULL);
    }
    orion_run_n = nt;
}
long long orion_par_run(void *closures, long long arg) {
    orion_run_pool_init();
    /* List layout is [cap, len, data...] — slot 1, not slot 0. Reading cap
     * here worked only for a literal list (cap == len); a pushed-into list
     * (what `loop parallel:` builds) grows cap past len, and the extra
     * iterations ran off the end into the bounds trap. */
    long long cnt = ((long long *)closures)[1];
    long long nt = orion_run_n;
    HANDLE dones[ORION_POOL_MAX];
    long long made = 0, i, sum = 0;
    for (i = 0; i < cnt && i < nt; i++) {
        orion_run_tasks[i].clos = (void *)orion_rt_slot(closures, i);
        orion_run_tasks[i].arg = arg;
        dones[made++] = orion_run_done[i];
        SetEvent(orion_run_go[i]);
    }
    for (i = nt; i < cnt; i++)
        sum += orion_call_one((void *)orion_rt_slot(closures, i), arg);
    if (made > 0) WaitForMultipleObjects((DWORD)made, dones, TRUE, INFINITE);
    for (i = 0; i < cnt && i < nt; i++) sum += orion_run_tasks[i].result;
    return sum;
}
#else
long long orion_par_run(void *closures, long long arg) {
    long long cnt = ((long long *)closures)[1];  /* [cap, len, data...] */
    long long i, sum = 0;
    for (i = 0; i < cnt; i++)
        sum += orion_call_one((void *)orion_rt_slot(closures, i), arg);
    return sum;
}
#endif

/* ---- Blocking stdio: what a language server needs -------------------
 * `orion_console_readline` above is the opposite of this: non-blocking,
 * interactive, keystroke-echoing, for a dev console polled once a frame.
 * A Language Server speaks a framed protocol over a pipe and must BLOCK
 * until the next header line / the exact body length arrives, and must
 * write bytes with no newline appended (`print_line` uses puts).
 */
/* One line, terminator stripped. A BLANK line comes back as "\n" and "" means
 * end of stream: the caller has to tell those apart, because in a framed
 * protocol the blank line is what ends the header block. (Returning "" for both
 * made the server read the end of the headers as EOF and answer nothing.) */
const char *orion_stdin_line(void) {
    char buf[8192];
    if (!fgets(buf, (int)sizeof(buf), stdin)) return orion_text_empty();
    size_t n = strlen(buf);
    while (n > 0 && (buf[n - 1] == '\n' || buf[n - 1] == '\r')) n--;
    if (n == 0) {
        char *nl = orion_text_alloc(1);
        nl[0] = '\n';
        nl[1] = 0;
        return nl;
    }
    char *out = orion_text_alloc((long long)n);
    memcpy(out, buf, n);
    out[n] = 0;
    return out;
}

const char *orion_stdin_read(long long want) {
    if (want <= 0) return orion_text_empty();
    char *out = orion_text_alloc(want);
    long long got = 0;
    while (got < want) {
        size_t r = fread(out + got, 1, (size_t)(want - got), stdin);
        if (r == 0) break;
        got += (long long)r;
    }
    out[got] = 0;
    ((long long *)out)[-1] = got;
    return out;
}

long long orion_stdout_write(const char *s) {
    long long n = orion_tlen_c(s);
    if (n > 0) fwrite(s, 1, (size_t)n, stdout);
    fflush(stdout);
    return n;
}

/* stderr, for server-side logging that must not corrupt the protocol
 * stream on stdout. */
long long orion_stderr_line(const char *s) {
    fprintf(stderr, "%s\n", s);
    fflush(stderr);
    return 0;
}

/* ---- Async: stackful coroutines + a cooperative scheduler ------------
 *
 * `orbs/async` and `orbs/scheduler` both said the same thing in a comment: a
 * real scheduler needs "libco (or Windows fibers) for stack switching" and that
 * was "future work". Until then a task could not SUSPEND: the effect machinery
 * is one-shot setjmp/longjmp, which can resume a continuation but cannot park
 * one and come back to it later. So `async` was timers and `scheduler` was a
 * deadline queue that ran each task to completion — cooperative in name only.
 *
 * This is the missing layer. Every task gets its own stack (a Windows fiber, or
 * a ucontext elsewhere), so `orion_task_yield()` parks mid-computation and the
 * scheduler picks it up where it left off. Cooperative and single-threaded on
 * purpose: `par_run` / `loop parallel:` is the parallel primitive, this is the
 * concurrency one, and keeping them separate keeps both explainable.
 *
 * Where no stack switching exists at all, spawn RUNS the closure immediately
 * and yield is a no-op: results stay correct for tasks that never yield, and a
 * task that does yield simply does not interleave. That is stated out loud
 * rather than pretending to suspend.
 */
#define ORION_MAX_TASKS 256
#define ORION_TASK_STACK (256 * 1024)

/* 0 = free, 1 = ready, 2 = running, 3 = done, 4 = sleeping until `wake_ms` */
typedef struct {
    void *stack_ctx;
    void *clos;
    long long arg;
    long long result;
    long long wake_ms;
    int state;
} orion_task_slot;

static orion_task_slot orion_tasks[ORION_MAX_TASKS];
static int orion_task_current = -1;
static int orion_task_live = 0;

static int orion_task_alloc(void *clos, long long arg) {
    for (int i = 0; i < ORION_MAX_TASKS; i++) {
        if (orion_tasks[i].state == 0) {
            orion_tasks[i].clos = clos;
            orion_tasks[i].arg = arg;
            orion_tasks[i].result = 0;
            orion_tasks[i].state = 1;
            orion_tasks[i].wake_ms = 0;
            orion_tasks[i].stack_ctx = NULL;
            orion_task_live++;
            return i;
        }
    }
    return -1;
}

#if defined(_WIN32)
static void *orion_sched_fiber = NULL;

/* Forward decls: the multi-shot machinery lives further down but the task entry
 * is where a replay has to land. */
typedef struct orion_ms_slot_s orion_ms_slot_fwd;
long long orion_ms_replay_wanted(int idx);
void orion_ms_do_replay(int idx);
void *orion_ms_handler_of(int idx);
void orion_ms_set_base(int idx, char *base);

static void __stdcall orion_task_entry(void *param) {
    int idx = (int)(long long)param;
    /* The high end of this task's live stack, remembered for the multi-shot
     * snapshot: everything the task pushes lives below it. */
    orion_ms_set_base(idx, (char *)&idx);
    orion_tasks[idx].result = orion_call_one(orion_tasks[idx].clos, orion_tasks[idx].arg);
    orion_tasks[idx].state = 3;
    /* A fiber must never return. Park, and give control to whoever is owed it:
     * a handler waiting for this continuation's result, otherwise the
     * scheduler. A REPLAY request jumps back to the captured perform point —
     * the stack has already been restored under us. */
    for (;;) {
        void *back = orion_ms_handler_of(idx);
        if (back) SwitchToFiber(back); else SwitchToFiber(orion_sched_fiber);
        if (orion_ms_replay_wanted(idx)) orion_ms_do_replay(idx);
    }
}

long long orion_task_spawn(void *clos, long long arg) {
    if (!orion_sched_fiber) {
        orion_sched_fiber = ConvertThreadToFiber(NULL);
        if (!orion_sched_fiber) orion_sched_fiber = GetCurrentFiber();
    }
    int idx = orion_task_alloc(clos, arg);
    if (idx < 0) return -1;
    orion_tasks[idx].stack_ctx = CreateFiber(ORION_TASK_STACK, orion_task_entry, (void *)(long long)idx);
    if (!orion_tasks[idx].stack_ctx) {
        orion_tasks[idx].state = 0;
        orion_task_live--;
        return -1;
    }
    return idx;
}

long long orion_task_yield(void) {
    int me = orion_task_current;
    if (me < 0) return 0;              /* not inside a task: nothing to park */
    orion_tasks[me].state = 1;
    SwitchToFiber(orion_sched_fiber);
    return 1;
}

/* Wake every sleeper whose deadline has passed. Returns the shortest remaining
 * wait in ms, or -1 when nobody is sleeping. */
static long long orion_sched_wake_due(void) {
    long long now = __orion_monotonic_ms();
    long long soonest = -1;
    for (int i = 0; i < ORION_MAX_TASKS; i++) {
        if (orion_tasks[i].state != 4) continue;
        if (orion_tasks[i].wake_ms <= now) {
            orion_tasks[i].state = 1;
        } else {
            long long left = orion_tasks[i].wake_ms - now;
            if (soonest < 0 || left < soonest) soonest = left;
        }
    }
    return soonest;
}

/* Run ready tasks round-robin until `until_idx` is done (or, with -1, until
 * nothing is ready). Returns the number of switches performed.
 *
 * A SLEEPING task does not hold the scheduler: when nothing is runnable but a
 * timer is pending, this sleeps ONCE for the shortest remaining wait and then
 * wakes whoever is due. That is what makes N tasks each waiting 100ms finish in
 * ~100ms instead of N*100ms — with plain `sleep_ms` inside a task, the whole
 * scheduler was parked in the OS. */
static long long orion_sched_drive(int until_idx) {
    long long switches = 0;
    for (;;) {
        if (until_idx >= 0 && orion_tasks[until_idx].state == 3) break;
        orion_sched_wake_due();
        int ran = 0;
        for (int i = 0; i < ORION_MAX_TASKS; i++) {
            if (orion_tasks[i].state != 1) continue;
            orion_task_current = i;
            orion_tasks[i].state = 2;
            SwitchToFiber(orion_tasks[i].stack_ctx);
            orion_task_current = -1;
            ran = 1;
            switches++;
            if (until_idx >= 0 && orion_tasks[until_idx].state == 3) break;
        }
        if (!ran) {
            long long wait = orion_sched_wake_due();
            if (wait <= 0) break;      /* nothing runnable, no timers: stop */
            __orion_sleep_ms(wait);
        }
    }
    return switches;
}

/* Park the current task until `ms` from now. Outside a task this is an ordinary
 * blocking sleep, so the same call is correct in both places. */
long long orion_task_sleep(long long ms) {
    int me = orion_task_current;
    if (me < 0) {
        __orion_sleep_ms(ms);
        return 0;
    }
    orion_tasks[me].wake_ms = __orion_monotonic_ms() + (ms > 0 ? ms : 0);
    orion_tasks[me].state = 4;
    SwitchToFiber(orion_sched_fiber);
    return 1;
}

static void orion_task_release(int idx) {
    if (orion_tasks[idx].stack_ctx) DeleteFiber(orion_tasks[idx].stack_ctx);
    orion_tasks[idx].stack_ctx = NULL;
    orion_tasks[idx].state = 0;
    orion_task_live--;
}

#else
#include <ucontext.h>
static ucontext_t orion_sched_ctx;
static ucontext_t orion_task_ctx[ORION_MAX_TASKS];
static char *orion_task_stack[ORION_MAX_TASKS];
static int orion_entry_idx = -1;

static void orion_task_entry(void) {
    int idx = orion_entry_idx;
    orion_tasks[idx].result = orion_call_one(orion_tasks[idx].clos, orion_tasks[idx].arg);
    orion_tasks[idx].state = 3;
    swapcontext(&orion_task_ctx[idx], &orion_sched_ctx);
}

long long orion_task_spawn(void *clos, long long arg) {
    int idx = orion_task_alloc(clos, arg);
    if (idx < 0) return -1;
    orion_task_stack[idx] = (char *)malloc(ORION_TASK_STACK);
    if (!orion_task_stack[idx]) {
        orion_tasks[idx].state = 0;
        orion_task_live--;
        return -1;
    }
    getcontext(&orion_task_ctx[idx]);
    orion_task_ctx[idx].uc_stack.ss_sp = orion_task_stack[idx];
    orion_task_ctx[idx].uc_stack.ss_size = ORION_TASK_STACK;
    orion_task_ctx[idx].uc_link = &orion_sched_ctx;
    orion_entry_idx = idx;
    makecontext(&orion_task_ctx[idx], orion_task_entry, 0);
    return idx;
}

long long orion_task_yield(void) {
    int me = orion_task_current;
    if (me < 0) return 0;
    orion_tasks[me].state = 1;
    swapcontext(&orion_task_ctx[me], &orion_sched_ctx);
    return 1;
}

static long long orion_sched_wake_due(void) {
    long long now = __orion_monotonic_ms();
    long long soonest = -1;
    for (int i = 0; i < ORION_MAX_TASKS; i++) {
        if (orion_tasks[i].state != 4) continue;
        if (orion_tasks[i].wake_ms <= now) {
            orion_tasks[i].state = 1;
        } else {
            long long left = orion_tasks[i].wake_ms - now;
            if (soonest < 0 || left < soonest) soonest = left;
        }
    }
    return soonest;
}

static long long orion_sched_drive(int until_idx) {
    long long switches = 0;
    for (;;) {
        if (until_idx >= 0 && orion_tasks[until_idx].state == 3) break;
        orion_sched_wake_due();
        int ran = 0;
        for (int i = 0; i < ORION_MAX_TASKS; i++) {
            if (orion_tasks[i].state != 1) continue;
            orion_task_current = i;
            orion_tasks[i].state = 2;
            orion_entry_idx = i;
            swapcontext(&orion_sched_ctx, &orion_task_ctx[i]);
            orion_task_current = -1;
            ran = 1;
            switches++;
            if (until_idx >= 0 && orion_tasks[until_idx].state == 3) break;
        }
        if (!ran) {
            long long wait = orion_sched_wake_due();
            if (wait <= 0) break;
            __orion_sleep_ms(wait);
        }
    }
    return switches;
}

long long orion_task_sleep(long long ms) {
    int me = orion_task_current;
    if (me < 0) {
        __orion_sleep_ms(ms);
        return 0;
    }
    orion_tasks[me].wake_ms = __orion_monotonic_ms() + (ms > 0 ? ms : 0);
    orion_tasks[me].state = 4;
    swapcontext(&orion_task_ctx[me], &orion_sched_ctx);
    return 1;
}

static void orion_task_release(int idx) {
    free(orion_task_stack[idx]);
    orion_task_stack[idx] = NULL;
    orion_tasks[idx].state = 0;
    orion_task_live--;
}
#endif

/* Drive until this task finishes, then take its result. A task is awaited
 * exactly once; awaiting a finished or unknown id yields 0 rather than
 * corrupting the table. */
long long orion_task_await(long long id) {
    if (id < 0 || id >= ORION_MAX_TASKS) return 0;
    int idx = (int)id;
    if (orion_tasks[idx].state == 0) return 0;
    orion_sched_drive(idx);
    long long r = orion_tasks[idx].result;
    if (orion_tasks[idx].state == 3) orion_task_release(idx);
    return r;
}

/* Run every ready task to completion; returns how many finished. Results are
 * still collected with await. */
long long orion_task_run_all(void) {
    orion_sched_drive(-1);
    long long done = 0;
    for (int i = 0; i < ORION_MAX_TASKS; i++)
        if (orion_tasks[i].state == 3) done++;
    return done;
}

long long orion_task_state(long long id) {
    if (id < 0 || id >= ORION_MAX_TASKS) return 0;
    return orion_tasks[(int)id].state;
}

long long orion_task_live_count(void) { return orion_task_live; }

/* ---- Delimited continuations: the handler survives the resume --------
 *
 * `resume(v)` in an ordinary `handle` block is a longjmp: control leaves for
 * the perform site and the handler's frame is GONE. So a handler can never do
 * anything after the continuation runs — not clean up, not inspect the result,
 * and certainly not resume a second time.
 *
 * Here the handler runs on ITS OWN FIBER, so it survives:
 *
 *   1. capture — snapshot the task's live stack from the perform point up to
 *                its base, and setjmp;
 *   2. handle  — switch to a fresh fiber and run the handler there;
 *   3. resume  — hand control back to the task and RETURN ITS RESULT to the
 *                handler when the rest of the task finishes.
 *
 * `resume_with(v)` therefore returns a value, which one-shot `resume` cannot.
 * The continuation is delimited by the TASK.
 *
 * A SECOND resume is refused, loudly. Replaying would mean putting the task's
 * stack back as it was at the perform point, and that invalidates the context
 * the OS parked the fiber at: the switch then lands on a stack whose saved
 * frame no longer describes it. That was measured, not assumed — the first
 * resume returns correctly, the second faulted at the switch. Getting past it
 * needs a context switcher of our own or per-resume stack copies with full
 * pointer relocation, and neither belongs in a half-built state.
 *
 * WINDOWS ONLY for now (fibers). Elsewhere this reports -1 rather than
 * pretending: an untested ucontext version of something this delicate would be
 * worse than an honest refusal.
 */
typedef struct {
    jmp_buf ctx;
    char *lo;
    size_t len;
    char *snap;
    size_t snap_cap;
    void *handler_fiber;
    void *handler_clos;
    long long handler_arg;
    long long handler_result;
    long long resume_in;
    int resume_pending;
    int ran_once;
    int replay;
    int active;
} orion_ms_slot;

static orion_ms_slot orion_ms[ORION_MAX_TASKS];
static char *orion_task_base[ORION_MAX_TASKS];
static int orion_ms_serving = -1;   /* which task the running handler serves */

#if defined(_WIN32)
static void __stdcall orion_ms_handler_entry(void *param) {
    int idx = (int)(long long)param;
    orion_ms_serving = idx;
    orion_ms[idx].handler_result = orion_call_one(orion_ms[idx].handler_clos, orion_ms[idx].handler_arg);
    orion_ms_serving = -1;
    /* The handler is done. If it never resumed, the task is still parked at the
     * perform point and must come back with the handler's own value. If it did
     * resume, the task already finished, so hand control to the scheduler. */
    int resumed = orion_ms[idx].ran_once;
    orion_ms[idx].handler_fiber = NULL;
    orion_ms[idx].active = 0;
    if (!resumed) {
        /* Never resumed: the task is still parked at the perform point and the
         * handler's value is what that point yields. */
        SwitchToFiber(orion_tasks[idx].stack_ctx);
    } else {
        /* It resumed, so the continuation already ran and the task is done. In
         * a delimited handler the HANDLER's value is the value of the handled
         * computation, so it replaces the continuation's own result: the
         * handler is the outer expression, not a callback. */
        orion_tasks[idx].result = orion_ms[idx].handler_result;
    }
    for (;;) SwitchToFiber(orion_sched_fiber);
}

/* Called from INSIDE a task: run `handler` with `arg`, letting it resume this
 * point any number of times. Returns whatever the perform site should see. */
long long orion_ms_perform(void *handler_clos, long long arg) {
    int idx = orion_task_current;
    if (idx < 0) return orion_call_one(handler_clos, arg);   /* not in a task */
    volatile char marker = 0;
    orion_ms_slot *m = &orion_ms[idx];
    m->lo = (char *)&marker;
    if (orion_task_base[idx] <= m->lo) return orion_call_one(handler_clos, arg);
    m->len = (size_t)(orion_task_base[idx] - m->lo);
    if (m->len > m->snap_cap) {
        free(m->snap);
        m->snap = (char *)malloc(m->len);
        m->snap_cap = m->snap ? m->len : 0;
        if (!m->snap) return orion_call_one(handler_clos, arg);
    }
    memcpy(m->snap, m->lo, m->len);
    m->handler_clos = handler_clos;
    m->handler_arg = arg;
    m->ran_once = 0;
    m->replay = 0;
    m->resume_pending = 0;
    m->active = 1;
    if (setjmp(m->ctx) == 0) {
        m->handler_fiber = CreateFiber(ORION_TASK_STACK, orion_ms_handler_entry, (void *)(long long)idx);
        if (!m->handler_fiber) { m->active = 0; return orion_call_one(handler_clos, arg); }
        SwitchToFiber(m->handler_fiber);
        /* Back without a longjmp: either the first resume, or the handler
         * finished without resuming at all. */
        if (m->resume_pending) { m->resume_pending = 0; return m->resume_in; }
        return m->handler_result;
    }
    /* Back via longjmp: a LATER resume replayed the snapshot. */
    m->resume_pending = 0;
    return m->resume_in;
}

/* Called from inside a handler started by orion_ms_perform. Runs the rest of
 * the task with `v` and returns what the task produced. */
long long orion_ms_resume(long long v) {
    int idx = orion_ms_serving;
    if (idx < 0 || !orion_ms[idx].active) return 0;
    orion_ms_slot *m = &orion_ms[idx];
    if (m->ran_once) {
        /* ONE resume per capture. A second one would have to put the task's
         * stack back the way it was at the perform point — and restoring it
         * invalidates the very context the OS parked that fiber at, so the
         * switch lands on a stack whose saved frame no longer describes it.
         * (Measured, not assumed: the first resume works and returns the
         * continuation's result; the second faulted at the switch.)
         *
         * Doing better needs a context switcher of our own, or per-resume stack
         * COPIES with every frame pointer relocated. Neither is something to
         * half-build, so this says no instead of corrupting the process. */
        fprintf(stderr, "orion: resume_with called twice for one `ask` — the continuation is one-shot (see orbs/async)\n");
        return -1;
    }
    m->resume_in = v;
    m->resume_pending = 1;
    m->ran_once = 1;
    orion_tasks[idx].state = 2;
    SwitchToFiber(orion_tasks[idx].stack_ctx);
    orion_ms_serving = idx;
    return orion_tasks[idx].result;
}

long long orion_ms_supported(void) { return 1; }
#else
long long orion_ms_perform(void *handler_clos, long long arg) {
    (void)handler_clos; (void)arg;
    return -1;
}
long long orion_ms_resume(long long v) { (void)v; return -1; }
long long orion_ms_supported(void) { return 0; }
#endif

/* Accessors the task entry needs (it is defined above this block). */
void orion_ms_set_base(int idx, char *base) { orion_task_base[idx] = base; }
void *orion_ms_handler_of(int idx) { return orion_ms[idx].handler_fiber; }
long long orion_ms_replay_wanted(int idx) { return orion_ms[idx].replay ? 1 : 0; }
void orion_ms_do_replay(int idx) {
    orion_ms[idx].replay = 0;
    longjmp(orion_ms[idx].ctx, 1);
}
