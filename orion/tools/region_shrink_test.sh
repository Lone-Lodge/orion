#!/usr/bin/env bash
# Region shrink-back regression.
#
# region_fit (runtime/orion_rt.c) used to be GROW-ONLY: once a single busy
# cycle grew a region, the buffer was pinned at that high-water for the whole
# session. A heavy render frame grew the arena to 54 MB and fireplace then
# idled at 223 MB, never giving it back. This proves the shrink-back path:
# after a spike, quiet cycles walk the cap back down to the region's floor
# and the reported high-water retracts to the recent peak.
#
# Pure C against the runtime — no orbit build needed. Runs anywhere clang/gcc
# is on PATH.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RT="$ROOT/runtime/orion_rt.c"
CC="${CC:-cc}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/region_shrink_test.c" <<'EOF'
#include <stdio.h>
#include <stdlib.h>

extern long long orion_arena_on(void);
extern long long orion_arena_reset(void);
extern long long orion_arena_cap(void);
extern long long orion_arena_high(void);
extern void *orion_alloc(long long size);

#define ARENA_START (256u * 1024u)

int main(void) {
    orion_arena_on();
    orion_arena_reset();

    /* Two heavy cycles: the first overflows and grows the buffer at reset;
     * the second bumps inside the now-large arena so used/high climb to the
     * real peak (how a busy render frame behaves). */
    for (int i = 0; i < 40; i++) orion_alloc(1024 * 1024);
    orion_arena_reset();
    for (int i = 0; i < 40; i++) orion_alloc(1024 * 1024);
    orion_arena_reset();
    long long spike_cap = orion_arena_cap();
    printf("after spike: cap=%lld KB high=%lld KB\n",
           spike_cap / 1024, orion_arena_high() / 1024);
    if (spike_cap < 40LL * 1024 * 1024) {
        printf("FAIL: arena did not grow to hold the spike\n");
        return 1;
    }

    /* Quiet cycles: tiny allocation each, reset each. Cap must shrink. */
    int steps = 0;
    for (int c = 0; c < 64; c++) {
        orion_alloc(256);
        orion_arena_reset();
        steps++;
        if (orion_arena_cap() <= (long long)ARENA_START) break;
    }
    long long final_cap = orion_arena_cap();
    printf("after %d quiet cycles: cap=%lld KB high=%lld KB\n",
           steps, final_cap / 1024, orion_arena_high() / 1024);

    if (final_cap > (long long)ARENA_START) {
        printf("FAIL: arena cap did not return to the floor\n");
        return 1;
    }
    if (orion_arena_high() > 1024 * 1024) {
        printf("FAIL: high-water was not retracted after shrink\n");
        return 1;
    }
    printf("PASS: arena grew for the spike then shrank back to the floor\n");
    return 0;
}
EOF

"$CC" "$WORK/region_shrink_test.c" "$RT" -o "$WORK/region_shrink_test"
"$WORK/region_shrink_test"
