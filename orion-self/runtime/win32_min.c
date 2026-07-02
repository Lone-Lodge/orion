// win32_min.c — minimal window shim for native Orion.
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
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

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

static void ev_push(long long kind, long long key, long long x, long long y) {
    int next = (ev_tail + 1) % EV_CAP;
    if (next == ev_head) return;       /* full: drop newest (potato-simple) */
    ev_ring[ev_tail].kind = kind;
    ev_ring[ev_tail].key = key;
    ev_ring[ev_tail].x = x;
    ev_ring[ev_tail].y = y;
    ev_tail = next;
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

static LRESULT CALLBACK orion_wnd_proc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
    case WM_LBUTTONDOWN: ev_push(1, 1, lp_x(lp), lp_y(lp)); return 0;
    case WM_RBUTTONDOWN: ev_push(1, 2, lp_x(lp), lp_y(lp)); return 0;
    case WM_MBUTTONDOWN: ev_push(1, 3, lp_x(lp), lp_y(lp)); return 0;
    case WM_LBUTTONUP:   ev_push(2, 1, lp_x(lp), lp_y(lp)); return 0;
    case WM_RBUTTONUP:   ev_push(2, 2, lp_x(lp), lp_y(lp)); return 0;
    case WM_MBUTTONUP:   ev_push(2, 3, lp_x(lp), lp_y(lp)); return 0;
    case WM_MOUSEMOVE:   ev_push(3, 0, lp_x(lp), lp_y(lp)); return 0;
    case WM_KEYDOWN:     ev_push(4, (long long)wp, 0, 0); return 0;
    case WM_KEYUP:       ev_push(5, (long long)wp, 0, 0); return 0;
    case WM_SIZE:        ev_push(7, 0, (long long)LOWORD(lp), (long long)HIWORD(lp)); return 0;
    case WM_CLOSE:       ev_push(6, 0, 0, 0); DestroyWindow(hwnd); return 0;
    case WM_DESTROY:     PostQuitMessage(0); return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
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
    wchar_t* wtitle = to_wide(title);
    HWND hwnd = CreateWindowExW(
        0, WCLASS, wtitle,
        WS_OVERLAPPEDWINDOW | WS_VISIBLE,
        CW_USEDEFAULT, CW_USEDEFAULT,
        (int)w, (int)h,
        NULL, NULL, GetModuleHandleW(NULL), NULL);
    free(wtitle);
    if (!hwnd) return 0;
    ShowWindow(hwnd, SW_SHOW);
    UpdateWindow(hwnd);
    return (int64_t)(uintptr_t)hwnd;
}

// Returns 1 if the window loop should keep going, 0 on WM_QUIT.
int64_t win_pump(void) {
    MSG msg;
    while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) {
        if (msg.message == WM_QUIT) return 0;
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
    Sleep(16);  // ~60 Hz — trivial frame pacing so we don't burn CPU.
    return 1;
}

void win_close(int64_t hwnd) {
    if (hwnd) DestroyWindow((HWND)(uintptr_t)hwnd);
}
