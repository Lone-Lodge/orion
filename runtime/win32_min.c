// win32_min.c - minimal window shim for native Orion.
//
// Exposes 3 functions to Orion via extern:
//   win_open(title, w, h) -> hwnd (as i64; 0 on failure)
//   win_pump()            -> 1 to keep going, 0 when WM_QUIT
//   win_close(hwnd)
//
// Title is a C string (i8*). We convert to wide for CreateWindowExW.
// Class is registered lazily on first win_open.

#define WIN32_LEAN_AND_MEAN
#define UNICODE
#define _UNICODE
#include <windows.h>
#include <mmsystem.h>   /* WAVEFORMATEX/WAVEHDR types only - winmm.dll loads dynamically */
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>

/* ---- Input events -------------------------------------------------
 * Fixed ring buffer filled by wnd_proc during win_pump; drained from
 * Orion via win_event_next()/win_event_kind()/x/y/key. All-i64 API so
 * the Orion externs stay trivially typed.
 *
 * Kinds: 1 mouse_down, 2 mouse_up, 3 mouse_move, 4 key_down,
 *        5 key_up, 6 close, 7 resize.
 * key: mouse button (1 left, 2 right, 3 middle) or virtual-key code.
 * For resize, x/y carry the new client width/height. */

typedef struct { long long kind, key, x, y; } OrionEvent;

#define EV_CAP 256
static OrionEvent ev_ring[EV_CAP];
static int ev_head = 0, ev_tail = 0;   /* pop at head, push at tail */
static OrionEvent ev_current;

/* Input-to-present latency, CPU side: stamp the moment the OS hands
 * us a user event; the engine samples the age right after present.
 * (GPU/DWM tail is invisible from here - this measures OUR share.) */
static LARGE_INTEGER g_last_input_qpc;

static void ev_push(long long kind, long long key, long long x, long long y) {
    int next = (ev_tail + 1) % EV_CAP;
    if (next == ev_head) return;       /* full: drop newest (potato-simple) */
    if (kind >= 1 && kind <= 5)
        QueryPerformanceCounter(&g_last_input_qpc);
    ev_ring[ev_tail].kind = kind;
    ev_ring[ev_tail].key = key;
    ev_ring[ev_tail].x = x;
    ev_ring[ev_tail].y = y;
    ev_tail = next;
}

/* Modifier probe for deliberate dev gestures (Ctrl+rightclick =
 * rewind): async key state, no event plumbing needed. */
long long win_key_held(long long vk) {
    return (GetAsyncKeyState((int)vk) & 0x8000) ? 1 : 0;
}

/* Microseconds since the last user input event landed; -1 = never. */
long long win_input_age_us(void) {
    if (g_last_input_qpc.QuadPart == 0) return -1;
    LARGE_INTEGER now, freq;
    QueryPerformanceCounter(&now);
    QueryPerformanceFrequency(&freq);
    return (now.QuadPart - g_last_input_qpc.QuadPart) * 1000000 /
           freq.QuadPart;
}

long long win_event_next(void) {
    if (ev_head == ev_tail) return 0;
    ev_current = ev_ring[ev_head];
    ev_head = (ev_head + 1) % EV_CAP;
    return 1;
}

long long win_event_kind(void) { return ev_current.kind; }
long long win_event_key(void)  { return ev_current.key; }
long long win_event_x(void)    { return ev_current.x; }
long long win_event_y(void)    { return ev_current.y; }

static long long lp_x(LPARAM lp) { return (long long)(short)LOWORD(lp); }
static long long lp_y(LPARAM lp) { return (long long)(short)HIWORD(lp); }

/* Software backends (gdi_min) register a repaint hook so WM_PAINT
 * restores the framebuffer instead of erasing to the class brush. */
void (*win_paint_hook)(void) = 0;

/* Live-resize: Windows runs a modal message loop while the user drags
 * a window edge, so our main render loop is paused and DWM stretches
 * the last frame. When win_live_resize is on we call atlas_live_frame
 * right here in WM_SIZE - it reattaches the swap chain, re-runs the
 * layout tree, and draws - so the UI reflows LIVE during the drag,
 * exactly like a webview. atlas_live_frame is a pub Orion fn resolved
 * as an extern symbol; declared weak so non-atlas hosts still link. */
__attribute__((weak)) void atlas_live_frame(long long w, long long h);
static int g_live_resize = 0;

long long win_live_resize(long long on, long long bg) {
    g_live_resize = (int)on;
    (void)bg;
    return 1;
}

/* ---- frameless window with custom caption (Tauri-style) ----
 * frameless: WM_NCCALCSIZE returns 0 so the client area fills the
 * whole window - native caption gone, WS_THICKFRAME resize kept.
 * WM_NCHITTEST then hands back resize edges plus a caption drag-zone
 * the app declares: the top `g_caption_h` pixels act as HTCAPTION,
 * except `g_caption_left`/`g_caption_right` pixels reserved at each
 * end for clickable UI (tool icons, window buttons). */
static int g_frameless = 0;
static int g_caption_h = 36, g_caption_left = 0, g_caption_right = 0;

long long win_frameless(long long hwnd_i, long long caption_h,
                        long long left_keep, long long right_keep) {
    HWND hwnd = (HWND)(uintptr_t)hwnd_i;
    g_frameless = 1;
    g_caption_h = (int)caption_h;
    g_caption_left = (int)left_keep;
    g_caption_right = (int)right_keep;
    SetWindowPos(hwnd, NULL, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);
    return 1;
}

/* ---- companion-window primitives ----
 * Small dumb functions; the POLICY (a pet window that sits on top of
 * your work) lives in Orion's shell code, composed from these. */

/* Fixed-size popup: no frame at all, no resize edges; the whole
 * surface drags the window (see g_fixed in WM_NCHITTEST) - except an
 * optional CLICK HOLE, where the mouse belongs to the app: a frame
 * skin's bezel drags the pet window, the game area takes the pats. */
static int g_fixed = 0;
static int g_hole_x = 0, g_hole_y = 0, g_hole_w = 0, g_hole_h = 0;

long long win_click_hole(long long hwnd_i, long long x, long long y,
                         long long w, long long h) {
    (void)hwnd_i;
    g_hole_x = (int)x; g_hole_y = (int)y;
    g_hole_w = (int)w; g_hole_h = (int)h;
    return 1;
}

/* Layered color key: every pixel of exactly this color becomes truly
 * transparent - the desktop shows through and clicks fall through.
 * The frame skin's rounded corners, for free. */
long long win_colorkey(long long hwnd_i, long long rgb) {
    HWND hwnd = (HWND)(uintptr_t)hwnd_i;
    SetWindowLongW(hwnd, GWL_EXSTYLE,
                   GetWindowLongW(hwnd, GWL_EXSTYLE) | WS_EX_LAYERED);
    COLORREF key = RGB((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);
    SetLayeredWindowAttributes(hwnd, key, 0, LWA_COLORKEY);
    return 1;
}

long long win_popup(long long hwnd_i, long long width, long long height) {
    HWND hwnd = (HWND)(uintptr_t)hwnd_i;
    g_fixed = 1;
    g_frameless = 1;
    SetWindowLongW(hwnd, GWL_STYLE, WS_POPUP | WS_VISIBLE);
    /* A popup has no frame: outer size IS client size. Set it exactly,
     * or the client keeps the old frame's slack and the framebuffer
     * shows with a dead border. */
    SetWindowPos(hwnd, NULL, 0, 0, (int)width, (int)height,
                 SWP_NOMOVE | SWP_NOZORDER | SWP_FRAMECHANGED);
    return 1;
}

long long win_topmost(long long hwnd_i, long long on) {
    SetWindowPos((HWND)(uintptr_t)hwnd_i, on ? HWND_TOPMOST : HWND_NOTOPMOST,
                 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
    return 1;
}

/* (win_move is taken by orion_cli's find-window-by-title helper.) */
long long win_place(long long hwnd_i, long long x, long long y) {
    SetWindowPos((HWND)(uintptr_t)hwnd_i, NULL, (int)x, (int)y, 0, 0,
                 SWP_NOSIZE | SWP_NOZORDER);
    return 1;
}

/* The desktop work area (screen minus taskbar), for corner placement. */
long long win_workarea_w(void) {
    RECT rc;
    SystemParametersInfoW(SPI_GETWORKAREA, 0, &rc, 0);
    return rc.right - rc.left;
}

long long win_workarea_h(void) {
    RECT rc;
    SystemParametersInfoW(SPI_GETWORKAREA, 0, &rc, 0);
    return rc.bottom - rc.top;
}

/* Wall-clock seconds since the Unix epoch - for stamping save files.
 * The GAME never sees this: shells stamp saves and feed bounded
 * catch-up ticks, so the world stays a pure function of its inputs. */
long long win_epoch_seconds(void) {
    return (long long)time(NULL);
}

/* The LOCAL calendar day as one whole number (a julian day count).
 * The shell's answer to "what day is it" - so a game can live daily
 * rules and away-days as fed intents without ever reading a clock. */
long long win_local_day(void) {
    time_t now = time(NULL);
    struct tm *lt = localtime(&now);
    long long y = lt->tm_year + 1900, m = lt->tm_mon + 1, d = lt->tm_mday;
    long long a = (14 - m) / 12, yy = y + 4800 - a, mm = m + 12 * a - 3;
    return d + (153 * mm + 2) / 5 + 365 * yy + yy / 4 - yy / 100 + yy / 400 - 32045;
}

/* ---- one-shot sounds: a small waveOut voice pool ----
 * Raw PCM in, fire and forget: each play takes a free voice (or
 * steals the oldest), copies the bytes (the caller's buffer is pool
 * memory and dies), and Windows mixes the voices. winmm loads
 * dynamically like the timer above - headless builds never touch it. */
#define ORION_VOICES 4
typedef struct { void* dev; char* buf; char hdr[64]; int open; } orion_voice;
static orion_voice g_voice[ORION_VOICES];
static int g_voice_next = 0;
static HMODULE g_winmm = NULL;
typedef unsigned int (WINAPI *WoOpenFn)(void**, unsigned int, const void*, uintptr_t, uintptr_t, unsigned int);
typedef unsigned int (WINAPI *WoHdrFn)(void*, void*, unsigned int);
typedef unsigned int (WINAPI *WoCloseFn)(void*);
static WoOpenFn wo_open; static WoHdrFn wo_prepare, wo_write, wo_unprepare;
static WoCloseFn wo_close, wo_reset;
typedef unsigned int (WINAPI *WoVolFn)(void*, unsigned int);
static WoVolFn wo_volume;

/* left/right are 0..1000 shares - the shell's pan law and volume bus
 * both land here as two plain numbers. */
long long win_sound_play(const char* data, long long from, long long bytes,
                         long long rate, long long channels, long long bits,
                         long long left, long long right) {
    if (!g_winmm) {
        g_winmm = LoadLibraryA("winmm.dll");
        if (!g_winmm) return 0;
        wo_open = (WoOpenFn)GetProcAddress(g_winmm, "waveOutOpen");
        wo_prepare = (WoHdrFn)GetProcAddress(g_winmm, "waveOutPrepareHeader");
        wo_write = (WoHdrFn)GetProcAddress(g_winmm, "waveOutWrite");
        wo_unprepare = (WoHdrFn)GetProcAddress(g_winmm, "waveOutUnprepareHeader");
        wo_close = (WoCloseFn)GetProcAddress(g_winmm, "waveOutClose");
        wo_reset = (WoCloseFn)GetProcAddress(g_winmm, "waveOutReset");
        wo_volume = (WoVolFn)GetProcAddress(g_winmm, "waveOutSetVolume");
    }
    if (!wo_open || !wo_write || bytes <= 0) return 0;
    orion_voice* v = &g_voice[g_voice_next];
    g_voice_next = (g_voice_next + 1) % ORION_VOICES;
    if (v->open) {
        wo_reset(v->dev);
        wo_unprepare(v->dev, v->hdr, sizeof v->hdr);
        wo_close(v->dev);
        free(v->buf);
        v->open = 0;
    }
    WAVEFORMATEX fmt;
    memset(&fmt, 0, sizeof fmt);
    fmt.wFormatTag = 1; /* PCM */
    fmt.nChannels = (WORD)channels;
    fmt.nSamplesPerSec = (DWORD)rate;
    fmt.wBitsPerSample = (WORD)bits;
    fmt.nBlockAlign = (WORD)(channels * bits / 8);
    fmt.nAvgBytesPerSec = fmt.nSamplesPerSec * fmt.nBlockAlign;
    if (wo_open(&v->dev, 0xFFFFFFFFu /* WAVE_MAPPER */, &fmt, 0, 0, 0) != 0)
        return 0;
    if (wo_volume) {
        if (left < 0) left = 0; if (left > 1000) left = 1000;
        if (right < 0) right = 0; if (right > 1000) right = 1000;
        unsigned int lv = (unsigned int)(left * 65535 / 1000);
        unsigned int rv = (unsigned int)(right * 65535 / 1000);
        wo_volume(v->dev, lv | (rv << 16));
    }
    v->buf = (char*)malloc((size_t)bytes);
    if (!v->buf) { wo_close(v->dev); return 0; }
    memcpy(v->buf, data + from, (size_t)bytes);
    WAVEHDR* h = (WAVEHDR*)v->hdr;
    memset(h, 0, sizeof(WAVEHDR));
    h->lpData = v->buf;
    h->dwBufferLength = (DWORD)bytes;
    wo_prepare(v->dev, h, sizeof(WAVEHDR));
    wo_write(v->dev, h, sizeof(WAVEHDR));
    v->open = 1;
    return 1;
}

/* Is this window the foreground window? A companion polls keys via
 * GetAsyncKeyState (global), so its shell must gate on focus or typing
 * in your editor would feed the pet. */
long long win_has_focus(long long hwnd_i) {
    return GetForegroundWindow() == (HWND)(uintptr_t)hwnd_i ? 1 : 0;
}

long long win_minimize(long long hwnd_i) {
    ShowWindow((HWND)(uintptr_t)hwnd_i, SW_MINIMIZE);
    return 1;
}

/* The companion's hidden mode is a MINIMIZED window: the taskbar
 * button stays (so a person can always bring her back or close for
 * real), the sim keeps ticking, and a reminder restores her. */
long long win_restore(long long hwnd_i) {
    ShowWindow((HWND)(uintptr_t)hwnd_i, SW_RESTORE);
    return 1;
}

long long win_is_min(long long hwnd_i) {
    return IsIconic((HWND)(uintptr_t)hwnd_i) ? 1 : 0;
}

long long win_maximize_toggle(long long hwnd_i) {
    HWND hwnd = (HWND)(uintptr_t)hwnd_i;
    ShowWindow(hwnd, IsZoomed(hwnd) ? SW_RESTORE : SW_MAXIMIZE);
    return 1;
}

long long win_request_close(long long hwnd_i) {
    PostMessageW((HWND)(uintptr_t)hwnd_i, WM_CLOSE, 0, 0);
    return 1;
}

/* Windows 11 rounded window corners via DWM. Loaded dynamically so
 * the exe still links + runs on Windows 10 (the call just no-ops).
 * pref: 0 default, 1 square, 2 round, 3 round-small. */
long long win_round_corners(long long hwnd_i, long long pref) {
    typedef long (WINAPI *DwmSetFn)(HWND, DWORD, const void *, DWORD);
    HMODULE dwm = LoadLibraryW(L"dwmapi.dll");
    if (!dwm) return 0;
    DwmSetFn set = (DwmSetFn)(void *)GetProcAddress(dwm, "DwmSetWindowAttribute");
    long ok = 0;
    if (set) {
        DWORD attr = 33; /* DWMWA_WINDOW_CORNER_PREFERENCE */
        DWORD value = (DWORD)pref;
        ok = (set((HWND)(uintptr_t)hwnd_i, attr, &value, sizeof value) >= 0) ? 1 : 0;
    }
    FreeLibrary(dwm);
    return ok;
}

long long win_fullscreen(long long hwnd_i, long long on); /* defined below */

static LRESULT CALLBACK orion_wnd_proc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (msg == WM_NCCALCSIZE && g_frameless && wp) return 0;
    if (msg == WM_NCHITTEST && g_fixed) {
        if (g_hole_w > 0) {
            RECT rc;
            GetWindowRect(hwnd, &rc);
            int x = (int)(short)LOWORD(lp) - rc.left;
            int y = (int)(short)HIWORD(lp) - rc.top;
            if (x >= g_hole_x && x < g_hole_x + g_hole_w &&
                y >= g_hole_y && y < g_hole_y + g_hole_h)
                return HTCLIENT;
        }
        return HTCAPTION;
    }
    if (msg == WM_NCHITTEST && g_frameless) {
        RECT rc;
        GetWindowRect(hwnd, &rc);
        int x = (int)(short)LOWORD(lp) - rc.left;
        int y = (int)(short)HIWORD(lp) - rc.top;
        int w = rc.right - rc.left, h = rc.bottom - rc.top;
        int m = 8; /* resize margin */
        if (!IsZoomed(hwnd)) {
            int top = y < m, bot = y >= h - m, lef = x < m, rig = x >= w - m;
            if (top && lef) return HTTOPLEFT;
            if (top && rig) return HTTOPRIGHT;
            if (bot && lef) return HTBOTTOMLEFT;
            if (bot && rig) return HTBOTTOMRIGHT;
            if (top) return HTTOP;
            if (bot) return HTBOTTOM;
            if (lef) return HTLEFT;
            if (rig) return HTRIGHT;
        }
        if (y < g_caption_h && x >= g_caption_left && x < w - g_caption_right)
            return HTCAPTION;
        return HTCLIENT;
    }
    switch (msg) {
    case WM_PAINT:
        if (win_paint_hook) {
            PAINTSTRUCT ps;
            BeginPaint(hwnd, &ps);
            win_paint_hook();
            EndPaint(hwnd, &ps);
            return 0;
        }
        break;
    case WM_LBUTTONDOWN: ev_push(1, 1, lp_x(lp), lp_y(lp)); return 0;
    case WM_RBUTTONDOWN: ev_push(1, 2, lp_x(lp), lp_y(lp)); return 0;
    case WM_MBUTTONDOWN: ev_push(1, 3, lp_x(lp), lp_y(lp)); return 0;
    case WM_LBUTTONUP:   ev_push(2, 1, lp_x(lp), lp_y(lp)); return 0;
    case WM_RBUTTONUP:   ev_push(2, 2, lp_x(lp), lp_y(lp)); return 0;
    case WM_MBUTTONUP:   ev_push(2, 3, lp_x(lp), lp_y(lp)); return 0;
    case WM_MOUSEMOVE:   ev_push(3, 0, lp_x(lp), lp_y(lp)); return 0;
    case WM_KEYDOWN:     ev_push(4, (long long)wp, 0, 0); return 0;
    case WM_KEYUP:       ev_push(5, (long long)wp, 0, 0); return 0;
    case WM_CHAR:        ev_push(12, (long long)wp, 0, 0); return 0;
    case WM_SYSKEYDOWN:
        /* Alt+Enter → our own borderless fullscreen (crisp, native res).
         * DXGI's stretched exclusive mode is disabled via
         * MakeWindowAssociation. Other Alt-combos fall through. */
        if (wp == VK_RETURN) {
            static int g_alt_fs = 0;
            g_alt_fs = !g_alt_fs;
            win_fullscreen((long long)(uintptr_t)hwnd, g_alt_fs);
            return 0;
        }
        break;
    case WM_SIZE:
        ev_push(7, 0, (long long)LOWORD(lp), (long long)HIWORD(lp));
        if (g_live_resize && &atlas_live_frame && wp != SIZE_MINIMIZED
            && LOWORD(lp) > 0 && HIWORD(lp) > 0) {
            atlas_live_frame((long long)LOWORD(lp), (long long)HIWORD(lp));
        }
        return 0;
    case WM_CLOSE:       ev_push(6, 0, 0, 0); DestroyWindow(hwnd); return 0;
    case WM_DESTROY:     PostQuitMessage(0); return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

/* Borderless fullscreen: WS_POPUP over the whole monitor, windowed
 * rect saved for the way back. The WM_SIZE this fires is the whole
 * integration - the engine's resize path does everything else. */
static RECT g_saved_rect;
static LONG g_saved_style;
long long win_fullscreen(long long hwnd_i, long long on) {
    HWND hwnd = (HWND)(uintptr_t)hwnd_i;
    if (on) {
        g_saved_style = GetWindowLongW(hwnd, GWL_STYLE);
        GetWindowRect(hwnd, &g_saved_rect);
        MONITORINFO mi = { sizeof(mi) };
        GetMonitorInfoW(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST), &mi);
        SetWindowLongW(hwnd, GWL_STYLE, WS_POPUP | WS_VISIBLE);
        SetWindowPos(hwnd, HWND_TOP, mi.rcMonitor.left, mi.rcMonitor.top,
                     mi.rcMonitor.right - mi.rcMonitor.left,
                     mi.rcMonitor.bottom - mi.rcMonitor.top,
                     SWP_FRAMECHANGED);
    } else {
        SetWindowLongW(hwnd, GWL_STYLE,
                       g_saved_style ? g_saved_style
                                     : (LONG)(WS_OVERLAPPEDWINDOW | WS_VISIBLE));
        SetWindowPos(hwnd, HWND_TOP, g_saved_rect.left, g_saved_rect.top,
                     g_saved_rect.right - g_saved_rect.left,
                     g_saved_rect.bottom - g_saved_rect.top,
                     SWP_FRAMECHANGED);
    }
    return 1;
}

/* ---- clipboard: CF_UNICODETEXT <-> UTF-8 Orion Text ----
 * get returns an Orion Text (via orion_text_from_c) so the value is a
 * proper runtime string, not a raw C pointer the allocator can't see.
 * set takes the UTF-8 payload pointer Orion passes for Text params. */
extern const char *orion_text_from_c(const char *s);

const char *win_clipboard_get(void) {
    static char buf[1 << 16];
    buf[0] = 0;
    if (OpenClipboard(NULL)) {
        HANDLE h = GetClipboardData(CF_UNICODETEXT);
        if (h) {
            const wchar_t *w = (const wchar_t *)GlobalLock(h);
            if (w) {
                WideCharToMultiByte(CP_UTF8, 0, w, -1, buf, (int)sizeof buf - 1,
                                    NULL, NULL);
                GlobalUnlock(h);
            }
        }
        CloseClipboard();
    }
    return orion_text_from_c(buf);
}

long long win_clipboard_set(const char *utf8) {
    int wlen = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, NULL, 0);
    if (wlen <= 0) return 0;
    HGLOBAL h = GlobalAlloc(GMEM_MOVEABLE, (SIZE_T)wlen * sizeof(wchar_t));
    if (!h) return 0;
    wchar_t *w = (wchar_t *)GlobalLock(h);
    MultiByteToWideChar(CP_UTF8, 0, utf8, -1, w, wlen);
    GlobalUnlock(h);
    if (!OpenClipboard(NULL)) { GlobalFree(h); return 0; }
    EmptyClipboard();
    SetClipboardData(CF_UNICODETEXT, h); /* system owns h after this */
    CloseClipboard();
    return 1;
}

static int class_registered = 0;
static const wchar_t* WCLASS = L"OrionMinWnd";

static void ensure_class(void) {
    if (class_registered) return;
    WNDCLASSEXW wc = {0};
    wc.cbSize = sizeof(wc);
    wc.style = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc = orion_wnd_proc;
    wc.hInstance = GetModuleHandleW(NULL);
    wc.hCursor = LoadCursorW(NULL, IDC_ARROW);
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    wc.lpszClassName = WCLASS;
    RegisterClassExW(&wc);
    class_registered = 1;
}

// Convert UTF-8 → UTF-16. Caller frees.
static wchar_t* to_wide(const char* s) {
    int n = MultiByteToWideChar(CP_UTF8, 0, s, -1, NULL, 0);
    wchar_t* w = (wchar_t*)malloc(n * sizeof(wchar_t));
    MultiByteToWideChar(CP_UTF8, 0, s, -1, w, n);
    return w;
}

int64_t win_open(const char* title, int64_t w, int64_t h) {
    ensure_class();
    /* 1ms timer resolution: without it every Sleep() rounds up to
     * ~15.6ms and the frame-budget pacing quantizes to 16/31ms -
     * which plays as sub-30fps stutter. Loaded dynamically so
     * headless builds never touch winmm. */
    {
        HMODULE mm = LoadLibraryA("winmm.dll");
        if (mm) {
            typedef unsigned int (WINAPI *TbpFn)(unsigned int);
            TbpFn tbp = (TbpFn)GetProcAddress(mm, "timeBeginPeriod");
            if (tbp) tbp(1);
        }
    }
    wchar_t* wtitle = to_wide(title);
    /* w/h are the requested CLIENT size - grow the outer rect by the
     * frame so games get exactly the pixels they laid out for. */
    RECT rc = {0, 0, (LONG)w, (LONG)h};
    AdjustWindowRect(&rc, WS_OVERLAPPEDWINDOW, FALSE);
    HWND hwnd = CreateWindowExW(
        0, WCLASS, wtitle,
        WS_OVERLAPPEDWINDOW | WS_VISIBLE,
        CW_USEDEFAULT, CW_USEDEFAULT,
        (int)(rc.right - rc.left), (int)(rc.bottom - rc.top),
        NULL, NULL, GetModuleHandleW(NULL), NULL);
    free(wtitle);
    if (!hwnd) return 0;
    ShowWindow(hwnd, SW_SHOW);
    UpdateWindow(hwnd);
    return (int64_t)(uintptr_t)hwnd;
}

void win_set_title(int64_t hwnd, const char* title) {
    wchar_t* wtitle = to_wide(title);
    SetWindowTextW((HWND)(uintptr_t)hwnd, wtitle);
    free(wtitle);
}

// Returns 1 if the window loop should keep going, 0 on WM_QUIT.
int64_t win_pump(void) {
    MSG msg;
    while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) {
        if (msg.message == WM_QUIT) return 0;
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
    /* No sleep here - frame pacing is the app loop's job
     * (atlas app_frame_sleep_since). A raw Sleep(16) quantizes to the
     * 15.6ms scheduler tick and doubled up with the app's own pacing,
     * capping every game at ~25fps. */
    return 1;
}

void win_close(int64_t hwnd) {
    if (hwnd) DestroyWindow((HWND)(uintptr_t)hwnd);
}

/* Sleep until timeout OR any input/window message arrives - the
 * event-driven idle with ZERO added input latency: a click lands,
 * the loop wakes instantly instead of finishing a Sleep() quantum. */
int64_t win_wait_input(int64_t ms) {
    if (ms <= 0) return 0;
    /* 0x04FF = QS_ALLINPUT */
    return (int64_t)MsgWaitForMultipleObjects(0, NULL, FALSE, (DWORD)ms,
                                              0x04FF);
}
