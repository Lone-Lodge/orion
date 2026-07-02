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
long long __orion_time_now_ms(void) {
    FILETIME ft; GetSystemTimeAsFileTime(&ft);
    unsigned long long t = ((unsigned long long)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
    /* FILETIME is 100ns intervals since 1601-01-01; offset to Unix epoch. */
    return (long long)((t - 116444736000000000ULL) / 10000ULL);
}
long long __orion_monotonic_ms(void) {
    return (long long)GetTickCount64();
}
void __orion_sleep_ms(long long ms) {
    if (ms > 0) Sleep((DWORD)ms);
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
