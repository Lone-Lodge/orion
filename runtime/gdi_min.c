/* gdi_min.c - software renderer with the same og_* API as d3d12_min.c.
 *
 * The potato backend: a CPU framebuffer blitted with StretchDIBits.
 * No GPU, no extra DLLs (user32/gdi32 only), ~instant init. Both
 * backends link into every exe (prefixed sw_ and dx_); ogpu_min.c
 * owns the public og_* names and picks at init. 2D rect fills at
 * these sizes are memset-class work; a full 800x900 repaint is
 * ~0.7MB of writes.
 */
#include <windows.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>

static HWND      g_hwnd;
static int       g_width, g_height;
static uint32_t *g_fb;        /* BGRX, top-down */
static uint32_t  g_clear;

static void blit(void);
extern void (*win_paint_hook)(void);

long long sw_og_init(long long hwnd_i, long long width, long long height) {
    g_hwnd = (HWND)(uintptr_t)hwnd_i;
    g_width = (int)width;
    g_height = (int)height;
    g_fb = (uint32_t *)malloc((size_t)g_width * g_height * 4);
    win_paint_hook = blit;
    return g_fb ? 1 : 0;
}

void sw_og_begin(long long r, long long g, long long b) {
    g_clear = ((uint32_t)r << 16) | ((uint32_t)g << 8) | (uint32_t)b;
    uint32_t *p = g_fb, *end = g_fb + (size_t)g_width * g_height;
    while (p < end) *p++ = g_clear;
}

void sw_og_rect(long long x, long long y, long long w, long long h,
             long long r, long long g, long long b) {
    int x0 = (int)x, y0 = (int)y, x1 = (int)(x + w), y1 = (int)(y + h);
    if (x0 < 0) x0 = 0;
    if (y0 < 0) y0 = 0;
    if (x1 > g_width) x1 = g_width;
    if (y1 > g_height) y1 = g_height;
    uint32_t c = ((uint32_t)r << 16) | ((uint32_t)g << 8) | (uint32_t)b;
    for (int py = y0; py < y1; py++) {
        uint32_t *row = g_fb + (size_t)py * g_width;
        for (int px = x0; px < x1; px++) row[px] = c;
    }
}

/* Vertical gradient fill: colour lerps top (r0,g0,b0) -> bottom (r1,g1,b1)
 * per row. Opaque. Used for backgrounds (the GPU path gets it free from
 * vertex-colour interpolation; software walks the rows). */
void sw_og_vgrad(long long x, long long y, long long w, long long h,
             long long r0, long long g0, long long b0,
             long long r1, long long g1, long long b1) {
    int x0 = (int)x, y0 = (int)y, x1 = (int)(x + w), y1 = (int)(y + h);
    int fy0 = (int)y, fh = (int)h;
    if (x0 < 0) x0 = 0;
    if (y0 < 0) y0 = 0;
    if (x1 > g_width) x1 = g_width;
    if (y1 > g_height) y1 = g_height;
    if (fh < 1) fh = 1;
    for (int py = y0; py < y1; py++) {
        int t = ((py - fy0) * 255) / fh;   /* 0..255 down the band */
        if (t < 0) t = 0; if (t > 255) t = 255;
        unsigned it = 255u - (unsigned)t, st = (unsigned)t;
        unsigned cr = ((unsigned)r0 * it + (unsigned)r1 * st) / 255u;
        unsigned cg = ((unsigned)g0 * it + (unsigned)g1 * st) / 255u;
        unsigned cb = ((unsigned)b0 * it + (unsigned)b1 * st) / 255u;
        uint32_t c = (cr << 16) | (cg << 8) | cb;
        uint32_t *row = g_fb + (size_t)py * g_width;
        for (int px = x0; px < x1; px++) row[px] = c;
    }
}

/* Alpha-composited rect (glass): src OVER dst per channel. a is 0-255.
 * Opaque/empty short-circuit to the plain path / no-op. */
void sw_og_rect_a(long long x, long long y, long long w, long long h,
             long long r, long long g, long long b, long long a) {
    if (a >= 255) { sw_og_rect(x, y, w, h, r, g, b); return; }
    if (a <= 0) return;
    int x0 = (int)x, y0 = (int)y, x1 = (int)(x + w), y1 = (int)(y + h);
    if (x0 < 0) x0 = 0;
    if (y0 < 0) y0 = 0;
    if (x1 > g_width) x1 = g_width;
    if (y1 > g_height) y1 = g_height;
    unsigned sa = (unsigned)a, ia = 255u - sa;
    unsigned sr = (unsigned)r * sa, sg = (unsigned)g * sa, sb = (unsigned)b * sa;
    for (int py = y0; py < y1; py++) {
        uint32_t *row = g_fb + (size_t)py * g_width;
        for (int px = x0; px < x1; px++) {
            uint32_t d = row[px];
            unsigned nr = (((d >> 16) & 255u) * ia + sr) / 255u;
            unsigned ng = (((d >> 8) & 255u) * ia + sg) / 255u;
            unsigned nb = ((d & 255u) * ia + sb) / 255u;
            row[px] = (nr << 16) | (ng << 8) | nb;
        }
    }
}

static void blit(void) {
    /* hwnd 0 would make GetDC hand back the SCREEN dc - a headless
     * harness must never paint the desktop. */
    if (!g_fb || !g_hwnd) return;
    BITMAPINFO bi = {0};
    bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth = g_width;
    bi.bmiHeader.biHeight = -g_height;   /* top-down */
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;
    HDC dc = GetDC(g_hwnd);
    StretchDIBits(dc, 0, 0, g_width, g_height, 0, 0, g_width, g_height,
                  g_fb, &bi, DIB_RGB_COLORS, SRCCOPY);
    ReleaseDC(g_hwnd, dc);
}

long long sw_og_present(void) {
    blit();
    return 1;
}

/* sw_og_snapshot(path): dump the software framebuffer to a top-down 32-bit
 * BMP. Pure stdio - no windowing - so it works headless (hwnd 0) and on any
 * OS: this is the portable "render a frame to a file" primitive, the same
 * pixel buffer an e-ink panel would receive. g_fb is BGRX little-endian,
 * which is exactly BMP's byte order (B,G,R,X per pixel). Negative height =
 * top-down, matching g_fb. Returns 1 on success. */
long long sw_og_snapshot(const char *path) {
    if (!g_fb || !path) return 0;
    FILE *f = fopen(path, "wb");
    if (!f) return 0;
    uint32_t img = (uint32_t)g_width * (uint32_t)g_height * 4u;
    uint32_t fsz = 54u + img;
    int32_t  nh  = -g_height;   /* top-down */
    unsigned char hdr[54] = {0};
    hdr[0] = 'B'; hdr[1] = 'M';
    hdr[2] = (unsigned char)fsz; hdr[3] = (unsigned char)(fsz >> 8);
    hdr[4] = (unsigned char)(fsz >> 16); hdr[5] = (unsigned char)(fsz >> 24);
    hdr[10] = 54;                                   /* pixel data offset */
    hdr[14] = 40;                                   /* DIB header size */
    hdr[18] = (unsigned char)g_width; hdr[19] = (unsigned char)(g_width >> 8);
    hdr[20] = (unsigned char)(g_width >> 16); hdr[21] = (unsigned char)(g_width >> 24);
    hdr[22] = (unsigned char)nh; hdr[23] = (unsigned char)(nh >> 8);
    hdr[24] = (unsigned char)(nh >> 16); hdr[25] = (unsigned char)(nh >> 24);
    hdr[26] = 1;                                    /* planes */
    hdr[28] = 32;                                   /* bits per pixel */
    hdr[34] = (unsigned char)img; hdr[35] = (unsigned char)(img >> 8);
    hdr[36] = (unsigned char)(img >> 16); hdr[37] = (unsigned char)(img >> 24);
    fwrite(hdr, 1, 54, f);
    fwrite(g_fb, 1, img, f);
    fclose(f);
    return 1;
}

long long sw_og_vsync(long long on) {
    (void)on; /* software blit has no vblank to wait on */
    return 1;
}

long long sw_og_caps(void) { return 1; /* 1 = software, 2 = d3d12 */ }

long long sw_og_resize(long long w, long long h) {
    if (w <= 0 || h <= 0) return 0;
    uint32_t *fresh = (uint32_t *)malloc((size_t)w * h * 4);
    if (!fresh) return 0;
    free(g_fb);
    g_fb = fresh;
    g_width = (int)w;
    g_height = (int)h;
    return 1;
}

void sw_og_shutdown(void) {
    win_paint_hook = 0;
    free(g_fb);
    g_fb = NULL;
}
