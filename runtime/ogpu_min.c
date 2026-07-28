/* ogpu_min.c — renderer dispatch. Owns the public og_* names.
 *
 * Both backends link into every exe; the choice happens at og_init:
 *   pref 0 (auto)  try d3d12, fall back to software
 *   pref 1 (gdi)   software, no GPU touched
 *   pref 2 (gpu)   d3d12 wanted; still falls back if it can't init
 *
 * dx_* are weak no-op stubs here so harness builds that only link
 * gdi_min.c resolve — d3d12_min.c's strong symbols win when present.
 */
#include <stdio.h>

extern long long sw_og_init(long long hwnd, long long w, long long h);
extern void      sw_og_begin(long long r, long long g, long long b);
extern void      sw_og_rect(long long x, long long y, long long w, long long h,
                            long long r, long long g, long long b);
extern void      sw_og_rect_a(long long x, long long y, long long w, long long h,
                            long long r, long long g, long long b, long long a);
extern void      sw_og_vgrad(long long x, long long y, long long w, long long h,
                            long long r0, long long g0, long long b0,
                            long long r1, long long g1, long long b1);
extern long long sw_og_present(void);
extern long long sw_og_vsync(long long on);
extern long long sw_og_resize(long long w, long long h);
extern void      sw_og_shutdown(void);
extern long long sw_og_snapshot(const char *path);

#define WEAK __attribute__((weak))
WEAK long long dx_og_init(long long hwnd, long long w, long long h) {
    (void)hwnd; (void)w; (void)h; return 0;
}
WEAK void      dx_og_begin(long long r, long long g, long long b) {
    (void)r; (void)g; (void)b;
}
WEAK void      dx_og_rect(long long x, long long y, long long w, long long h,
                          long long r, long long g, long long b) {
    (void)x; (void)y; (void)w; (void)h; (void)r; (void)g; (void)b;
}
WEAK void      dx_og_rect_a(long long x, long long y, long long w, long long h,
                          long long r, long long g, long long b, long long a) {
    (void)a; dx_og_rect(x, y, w, h, r, g, b);
}
WEAK void      dx_og_vgrad(long long x, long long y, long long w, long long h,
                          long long r0, long long g0, long long b0,
                          long long r1, long long g1, long long b1) {
    (void)r1; (void)g1; (void)b1; dx_og_rect(x, y, w, h, r0, g0, b0);
}
WEAK long long dx_og_present(void) { return 0; }
WEAK long long dx_og_vsync(long long on) { (void)on; return 0; }
WEAK long long dx_og_resize(long long w, long long h) {
    (void)w; (void)h; return 0;
}
WEAK void      dx_og_shutdown(void) {}
WEAK long long dx_og_texture(const char *path) { (void)path; return -1; }
WEAK void      dx_og_sprite(long long id, long long dx, long long dy,
                            long long dw, long long dh, long long sx,
                            long long sy, long long sw, long long sh,
                            long long tint, long long blend) {
    (void)id; (void)dx; (void)dy; (void)dw; (void)dh; (void)sx; (void)sy;
    (void)sw; (void)sh; (void)tint; (void)blend;
}
WEAK void      dx_og_clip(long long x, long long y, long long w, long long h) {
    (void)x; (void)y; (void)w; (void)h;
}
WEAK void      dx_og_clip_none(void) {}
WEAK long long dx_og_glyph_id(long long key) { (void)key; return -1; }
WEAK long long dx_og_texture_mem(long long key, long long w, long long h,
                                 const long long *rgba) {
    (void)key; (void)w; (void)h; (void)rgba; return -1;
}

static int g_mode = 0;   /* 0 none, 1 software, 2 d3d12 */
static int g_pref = 0;   /* 0 auto, 1 gdi, 2 gpu */
static int g_want_vsync = 0;

long long ogpu_pref(long long pref) { g_pref = (int)pref; return g_pref; }

long long og_init(long long hwnd, long long w, long long h) {
    g_mode = 0;
    if (g_pref != 1 && dx_og_init(hwnd, w, h)) {
        g_mode = 2;
        dx_og_vsync(g_want_vsync);
        return 1;
    }
    if (g_pref == 2)
        fprintf(stderr, "[gpu] d3d12 unavailable - software fallback\n");
    if (sw_og_init(hwnd, w, h)) {
        g_mode = 1;
        return 1;
    }
    return 0;
}

void og_begin(long long r, long long g, long long b) {
    if (g_mode == 2) dx_og_begin(r, g, b);
    else if (g_mode == 1) sw_og_begin(r, g, b);
}

void og_rect(long long x, long long y, long long w, long long h,
             long long r, long long g, long long b) {
    if (g_mode == 2) dx_og_rect(x, y, w, h, r, g, b);
    else if (g_mode == 1) sw_og_rect(x, y, w, h, r, g, b);
}

void og_rect_a(long long x, long long y, long long w, long long h,
             long long r, long long g, long long b, long long a) {
    if (g_mode == 2) dx_og_rect_a(x, y, w, h, r, g, b, a);
    else if (g_mode == 1) sw_og_rect_a(x, y, w, h, r, g, b, a);
}

void og_vgrad(long long x, long long y, long long w, long long h,
             long long r0, long long g0, long long b0,
             long long r1, long long g1, long long b1) {
    if (g_mode == 2) dx_og_vgrad(x, y, w, h, r0, g0, b0, r1, g1, b1);
    else if (g_mode == 1) sw_og_vgrad(x, y, w, h, r0, g0, b0, r1, g1, b1);
}

long long og_present(void) {
    if (g_mode == 2) return dx_og_present();
    if (g_mode == 1) return sw_og_present();
    return 0;
}

long long og_vsync(long long on) {
    g_want_vsync = (int)on;
    if (g_mode == 2) return dx_og_vsync(on);
    if (g_mode == 1) return sw_og_vsync(on);
    return 0;
}

long long og_caps(void) { return g_mode; }

/* Textured sprites: only the d3d12 backend has them; software returns -1
 * from og_texture so callers fall back (e.g. to the rect blit). */
long long og_texture(const char *path) {
    if (g_mode == 2) return dx_og_texture(path);
    return -1;
}
void og_sprite(long long id, long long dx, long long dy, long long dw,
               long long dh, long long sx, long long sy, long long sw,
               long long sh, long long tint, long long blend) {
    if (g_mode == 2) dx_og_sprite(id, dx, dy, dw, dh, sx, sy, sw, sh, tint, blend);
}
void og_clip(long long x, long long y, long long w, long long h) {
    if (g_mode == 2) dx_og_clip(x, y, w, h);
}
void og_clip_none(void) {
    if (g_mode == 2) dx_og_clip_none();
}
long long og_glyph_id(long long key) {
    if (g_mode == 2) return dx_og_glyph_id(key);
    return -1;
}
long long og_texture_mem(long long key, long long w, long long h,
                         const long long *rgba) {
    if (g_mode == 2) return dx_og_texture_mem(key, w, h, rgba);
    return -1;
}

long long og_resize(long long w, long long h) {
    if (g_mode == 2) return dx_og_resize(w, h);
    if (g_mode == 1) return sw_og_resize(w, h);
    return 0;
}

/* Snapshot the current frame to a file. Only the software backend keeps a
 * CPU framebuffer, so a shot forces software mode (renderer = gdi). In d3d12
 * mode there is no g_fb to read, so this returns 0. */
long long og_snapshot(const char *path) {
    if (g_mode == 1) return sw_og_snapshot(path);
    return 0;
}

void og_shutdown(void) {
    if (g_mode == 2) dx_og_shutdown();
    else if (g_mode == 1) sw_og_shutdown();
    g_mode = 0;
}
