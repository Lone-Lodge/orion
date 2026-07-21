#!/usr/bin/env bash
# PNG loader regression (host_image_load). Self-contained: a 4x2 RGBA PNG
# is embedded as bytes (red, green, blue, transparent | white x4), written
# to a temp file, decoded, and every pixel checked — exercises the sfnt
# chunk walk, zlib/DEFLATE inflate, and RGBA extraction with alpha=0.
# Pure C against the runtime; runs anywhere a C compiler is on PATH.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RT="$ROOT/runtime/orion_rt.c"
CC="${CC:-cc}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/png_test.c" <<'EOF'
#include <stdio.h>
extern const char *host_image_load(const char *path);
static long long tlen(const char *p){ return ((const long long*)p)[-1]; }
static const unsigned char PNG[] = {
137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,0,4,0,0,0,2,8,6,0,0,0,127,
168,125,99,0,0,0,22,73,68,65,84,120,218,99,248,207,192,240,31,12,25,254,3,49,
3,136,66,5,0,41,7,21,235,145,129,129,165,0,0,0,0,73,69,78,68,174,66,96,130 };
static int fails = 0;
static void px(const unsigned char *d, int i, int R, int G, int B, int A) {
    const unsigned char *p = d + 8 + i * 4;
    if (p[0]!=R||p[1]!=G||p[2]!=B||p[3]!=A) {
        printf("  FAIL px%d = %d,%d,%d,%d expected %d,%d,%d,%d\n",
               i,p[0],p[1],p[2],p[3],R,G,B,A);
        fails++;
    }
}
int main(int argc, char **argv) {
    FILE *f = fopen(argv[1], "wb");
    fwrite(PNG, 1, sizeof(PNG), f);
    fclose(f);
    const char *t = host_image_load(argv[1]);
    if (tlen(t) == 0) { printf("FAIL: decode returned empty\n"); return 1; }
    const unsigned char *d = (const unsigned char *)t;
    int w = d[0]|d[1]<<8|d[2]<<16|d[3]<<24, h = d[4]|d[5]<<8|d[6]<<16|d[7]<<24;
    if (w != 4 || h != 2) { printf("FAIL: %dx%d expected 4x2\n", w, h); return 1; }
    px(d,0,255,0,0,255); px(d,1,0,255,0,255); px(d,2,0,0,255,255);
    px(d,3,0,0,0,0);     px(d,4,255,255,255,255);
    if (fails) { printf("PNG loader FAILED (%d)\n", fails); return 1; }
    printf("PASS: 4x2 RGBA PNG decoded, alpha preserved\n");
    return 0;
}
EOF

"$CC" "$WORK/png_test.c" "$RT" -o "$WORK/png_test"
"$WORK/png_test" "$WORK/probe.png"
