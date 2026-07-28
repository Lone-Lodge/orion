/* linux_min.c — X11 window + software renderer for Orion apps on Linux.
 *
 *   ⚠ UNVERIFIED FIRST CUT ⚠
 *   Written on a Windows host that cannot compile or run it. The X11 API
 *   calls follow the standard Xlib playbook and mirror the contract of
 *   win32_min.c + gdi_min.c, but NOTHING here has been built or run. Every
 *   `ASSUME:` note marks a thing to confirm on the first real Linux build.
 *   Build + verify:  orbit shot   (headless, no X needed — exercises the
 *   rasterizer path) then  orbit dev  under an X server (WSLg / a desktop).
 *
 * This is one self-contained file on purpose: it provides BOTH halves the
 * app links on Linux —
 *   - the windowing contract the `window` orb externs (win_open, win_pump,
 *     win_event_*, win_close, + chrome stubs), mirroring win32_min.c;
 *   - the software renderer the `ogpu_min.c` dispatch externs (sw_og_*),
 *     a BGRX CPU framebuffer presented with XPutImage instead of GDI.
 * The rasterizer duplicates gdi_min.c's ~40 lines for now; unify the three
 * backends (win/linux/eink) into a shared soft_raster.c AFTER this is
 * verified against a real target — never refactor the working Windows path
 * toward an unproven one.
 *
 * Deliberately minimal: window + present + core input + resize + close.
 * Chrome (frameless, fullscreen, rounded, live-resize, clipboard) is
 * stubbed — get pixels on screen and clicks flowing first; add chrome once
 * the vertical slice is proven. This is the PineNote/e-ink track's desktop
 * proving ground; the framebuffer here is the same buffer a panel receives.
 */
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* ---------- shared X state ---------- */
static Display *g_dpy = 0;
static Window   g_win;
static GC       g_gc;
static Atom     g_wm_delete;
static int      g_screen;

/* ---------- software framebuffer (BGRX, top-down) ---------- */
static uint32_t *g_fb = 0;
static int       g_width, g_height;
static XImage   *g_ximage = 0;

/* The app registers a repaint hook so an Expose re-blits the last frame
 * instead of leaving the window blank (mirrors win32_min.c's win_paint_hook). */
void (*win_paint_hook)(void) = 0;

/* ---------- event queue ----------
 * win_pump() drains the X queue into these slots; win_event_next() walks
 * them one at a time, matching win32_min.c's one-event-at-a-time accessor
 * model. Fixed ring is plenty for one frame's worth of input. */
#define EVQ_MAX 256
static struct { int kind, key, x, y; } g_evq[EVQ_MAX];
static int g_evq_head, g_evq_tail;   /* tail = write, head = read cursor */
static int g_evq_cur = -1;           /* index the win_event_* accessors read */

static void evq_push(int kind, int key, int x, int y) {
    int nxt = (g_evq_tail + 1) % EVQ_MAX;
    if (nxt == g_evq_head) return;   /* full: drop (input, not state) */
    g_evq[g_evq_tail].kind = kind;
    g_evq[g_evq_tail].key  = key;
    g_evq[g_evq_tail].x    = x;
    g_evq[g_evq_tail].y    = y;
    g_evq_tail = nxt;
}

/* ---------- present ---------- */
/* The XImage is created lazily here, on first present, NOT in sw_og_init.
 * That keeps the framebuffer path X-free until a window actually exists, so
 * a headless run (`orbit shot` — no window, g_dpy NULL) fills g_fb and
 * snapshots it without ever touching Xlib. */
static void present_current(void) {
    if (!g_dpy || !g_fb) return;           /* headless: no window to present to */
    if (!g_ximage) {
        Visual *vis = DefaultVisual(g_dpy, g_screen);
        int depth   = DefaultDepth(g_dpy, g_screen);
        g_ximage = XCreateImage(g_dpy, vis, depth, ZPixmap, 0,
                                (char *)g_fb, g_width, g_height, 32, 0);
        if (!g_ximage) return;
    }
    XPutImage(g_dpy, g_win, g_gc, g_ximage, 0, 0, 0, 0, g_width, g_height);
    XFlush(g_dpy);
}

/* ---------- software renderer (og_* backend, sw_ prefix) ---------- */
long long sw_og_init(long long hwnd_i, long long width, long long height) {
    (void)hwnd_i;                    /* Linux tracks its own window globally */
    g_width  = (int)width;
    g_height = (int)height;
    g_fb = (uint32_t *)malloc((size_t)g_width * g_height * 4);
    win_paint_hook = present_current;
    /* No Xlib here — the XImage is built lazily on first present (see
     * present_current), so a headless render just needs g_fb. */
    return g_fb ? 1 : 0;
}

void sw_og_begin(long long r, long long g, long long b) {
    uint32_t c = ((uint32_t)r << 16) | ((uint32_t)g << 8) | (uint32_t)b;
    uint32_t *p = g_fb, *end = g_fb + (size_t)g_width * g_height;
    while (p < end) *p++ = c;
}

void sw_og_rect(long long x, long long y, long long w, long long h,
                long long r, long long g, long long b) {
    int x0 = (int)x, y0 = (int)y, x1 = (int)(x + w), y1 = (int)(y + h);
    if (x0 < 0) x0 = 0;
    if (y0 < 0) y0 = 0;
    if (x1 > g_width)  x1 = g_width;
    if (y1 > g_height) y1 = g_height;
    uint32_t c = ((uint32_t)r << 16) | ((uint32_t)g << 8) | (uint32_t)b;
    for (int py = y0; py < y1; py++) {
        uint32_t *row = g_fb + (size_t)py * g_width;
        for (int px = x0; px < x1; px++) row[px] = c;
    }
}

long long sw_og_present(void) { present_current(); return 1; }
long long sw_og_vsync(long long on) { (void)on; return 1; }
long long sw_og_caps(void) { return 1; }

long long sw_og_resize(long long w, long long h) {
    if (w <= 0 || h <= 0) return 0;
    uint32_t *fresh = (uint32_t *)malloc((size_t)w * h * 4);
    if (!fresh) return 0;
    if (g_ximage) { g_ximage->data = 0; XDestroyImage(g_ximage); g_ximage = 0; }
    free(g_fb);
    g_fb = fresh;
    g_width = (int)w;
    g_height = (int)h;
    /* g_ximage cleared → present_current rebuilds it against the new size. */
    return 1;
}

void sw_og_shutdown(void) {
    win_paint_hook = 0;
    if (g_ximage) { g_ximage->data = 0; XDestroyImage(g_ximage); g_ximage = 0; }
    free(g_fb);
    g_fb = 0;
}

/* Headless framebuffer dump — identical to gdi_min.c's, so `orbit shot`
 * works on Linux with no X server. g_fb is BGRX = BMP byte order. */
long long sw_og_snapshot(const char *path) {
    if (!g_fb || !path) return 0;
    FILE *f = fopen(path, "wb");
    if (!f) return 0;
    uint32_t img = (uint32_t)g_width * (uint32_t)g_height * 4u;
    uint32_t fsz = 54u + img;
    int32_t  nh  = -g_height;
    unsigned char hdr[54] = {0};
    hdr[0] = 'B'; hdr[1] = 'M';
    hdr[2] = (unsigned char)fsz; hdr[3] = (unsigned char)(fsz >> 8);
    hdr[4] = (unsigned char)(fsz >> 16); hdr[5] = (unsigned char)(fsz >> 24);
    hdr[10] = 54; hdr[14] = 40;
    hdr[18] = (unsigned char)g_width; hdr[19] = (unsigned char)(g_width >> 8);
    hdr[20] = (unsigned char)(g_width >> 16); hdr[21] = (unsigned char)(g_width >> 24);
    hdr[22] = (unsigned char)nh; hdr[23] = (unsigned char)(nh >> 8);
    hdr[24] = (unsigned char)(nh >> 16); hdr[25] = (unsigned char)(nh >> 24);
    hdr[26] = 1; hdr[28] = 32;
    hdr[34] = (unsigned char)img; hdr[35] = (unsigned char)(img >> 8);
    hdr[36] = (unsigned char)(img >> 16); hdr[37] = (unsigned char)(img >> 24);
    fwrite(hdr, 1, 54, f);
    fwrite(g_fb, 1, img, f);
    fclose(f);
    return 1;
}

/* d3d12 has no Linux backend; ogpu_min.c's dx_* weak stubs stay no-ops and
 * og_init falls to software. renderer=gpu simply gets software here. */

/* ---------- windowing (window orb contract, win_ prefix) ---------- */
long long win_open(const char *title, long long w, long long h) {
    if (!g_dpy) {
        g_dpy = XOpenDisplay(NULL);
        if (!g_dpy) { fprintf(stderr, "[x11] cannot open display\n"); return 0; }
    }
    g_screen = DefaultScreen(g_dpy);
    unsigned long black = BlackPixel(g_dpy, g_screen);
    g_win = XCreateSimpleWindow(g_dpy, RootWindow(g_dpy, g_screen),
                                0, 0, (unsigned)w, (unsigned)h, 0, black, black);
    XSelectInput(g_dpy, g_win,
                 ExposureMask | ButtonPressMask | ButtonReleaseMask |
                 PointerMotionMask | KeyPressMask | KeyReleaseMask |
                 StructureNotifyMask);
    g_wm_delete = XInternAtom(g_dpy, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(g_dpy, g_win, &g_wm_delete, 1);
    if (title) XStoreName(g_dpy, g_win, title);
    g_gc = DefaultGC(g_dpy, g_screen);
    XMapWindow(g_dpy, g_win);
    XFlush(g_dpy);
    /* ASSUME: the app uses this return only as a truthy handle + passes it to
     * og_init (which ignores it on Linux). Non-zero = a window exists. */
    return (long long)g_win;
}

/* Drain the X queue into the event ring. Returns 0 when the window should
 * close (matches win_pump's keep semantics), 1 otherwise. */
long long win_pump(void) {
    long long keep = 1;
    if (!g_dpy) return 0;
    while (XPending(g_dpy) > 0) {
        XEvent ev;
        XNextEvent(g_dpy, &ev);
        switch (ev.type) {
            case Expose:
                if (win_paint_hook) win_paint_hook();
                break;
            case ButtonPress:
                /* buttons 1..3 = left/middle/right; 4/5 = wheel (skip) */
                if (ev.xbutton.button <= 3)
                    evq_push(1, (int)ev.xbutton.button, ev.xbutton.x, ev.xbutton.y);
                break;
            case ButtonRelease:
                if (ev.xbutton.button <= 3)
                    evq_push(2, (int)ev.xbutton.button, ev.xbutton.x, ev.xbutton.y);
                break;
            case MotionNotify:
                evq_push(3, 0, ev.xmotion.x, ev.xmotion.y);
                break;
            case KeyPress: {
                /* ASSUME: downstream input wants an ASCII/keysym-ish code in
                 * `key`. XLookupKeysym gives the keysym; low byte is ASCII for
                 * printable keys. Refine the mapping against atlas_input once
                 * running (char events, kind 12, may need XLookupString). */
                KeySym ks = XLookupKeysym(&ev.xkey, 0);
                evq_push(4, (int)ks, ev.xkey.x, ev.xkey.y);
                break;
            }
            case KeyRelease: {
                KeySym ks = XLookupKeysym(&ev.xkey, 0);
                evq_push(5, (int)ks, ev.xkey.x, ev.xkey.y);
                break;
            }
            case ConfigureNotify:
                if (ev.xconfigure.width != g_width || ev.xconfigure.height != g_height)
                    evq_push(7, 0, ev.xconfigure.width, ev.xconfigure.height);
                break;
            case ClientMessage:
                if ((Atom)ev.xclient.data.l[0] == g_wm_delete) {
                    evq_push(6, 0, 0, 0);
                    keep = 0;
                }
                break;
            default: break;
        }
    }
    return keep;
}

long long win_event_next(void) {
    if (g_evq_head == g_evq_tail) { g_evq_cur = -1; return 0; }
    g_evq_cur = g_evq_head;
    g_evq_head = (g_evq_head + 1) % EVQ_MAX;
    return 1;
}
long long win_event_kind(void) { return g_evq_cur < 0 ? 0 : g_evq[g_evq_cur].kind; }
long long win_event_key(void)  { return g_evq_cur < 0 ? 0 : g_evq[g_evq_cur].key; }
long long win_event_x(void)    { return g_evq_cur < 0 ? 0 : g_evq[g_evq_cur].x; }
long long win_event_y(void)    { return g_evq_cur < 0 ? 0 : g_evq[g_evq_cur].y; }

void win_close(long long hwnd) {
    (void)hwnd;
    if (g_dpy) { XDestroyWindow(g_dpy, g_win); XFlush(g_dpy); }
}

void win_set_title(long long hwnd, const char *title) {
    (void)hwnd;
    if (g_dpy && title) XStoreName(g_dpy, g_win, title);
}

/* ---------- chrome: stubbed for the first slice (documented no-ops) ---------- */
long long win_fullscreen(long long hwnd, long long on) { (void)hwnd; (void)on; return 0; }
long long win_frameless(long long hwnd, long long ch, long long l, long long r) {
    (void)hwnd; (void)ch; (void)l; (void)r; return 0;   /* TODO: _MOTIF_WM_HINTS */
}
long long win_minimize(long long hwnd) { (void)hwnd; return 0; }        /* TODO: XIconifyWindow */
long long win_maximize_toggle(long long hwnd) { (void)hwnd; return 0; } /* TODO: _NET_WM_STATE */
long long win_request_close(long long hwnd) { (void)hwnd; evq_push(6, 0, 0, 0); return 0; }
long long win_round_corners(long long hwnd, long long pref) { (void)hwnd; (void)pref; return 0; }
long long win_live_resize(long long on, long long bg) { (void)on; (void)bg; return 0; }

/* Clipboard: X11 selections need an event round-trip; stub for now so links
 * resolve. TODO: XSetSelectionOwner / XConvertSelection over PRIMARY+CLIPBOARD. */
const char *win_clipboard_get(void) { return ""; }
long long   win_clipboard_set(const char *t) { (void)t; return 0; }
