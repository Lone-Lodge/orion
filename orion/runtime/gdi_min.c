/* gdi_min.c — software renderer with the same og_* API as d3d12_min.c.
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

static void blit(void) {
    /* hwnd 0 would make GetDC hand back the SCREEN dc — a headless
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
