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
 *        5 key_up, 6 close, 7 resize, 13 wheel, 14 double click.
 * key: mouse button (1 left, 2 right, 3 middle) or virtual-key code.
 * For resize, x/y carry the new client width/height.
 * `who` is the window the event came from: one process can drive
 * several windows through this one queue, and a resize meant for the
 * side panel must not resize the main one. */

typedef struct { long long kind, key, x, y, who; } OrionEvent;

#define EV_CAP 256
static OrionEvent ev_ring[EV_CAP];
static int ev_head = 0, ev_tail = 0;   /* pop at head, push at tail */
static OrionEvent ev_current;

/* Input-to-present latency, CPU side: stamp the moment the OS hands
 * us a user event; the engine samples the age right after present.
 * (GPU/DWM tail is invisible from here - this measures OUR share.) */
static LARGE_INTEGER g_last_input_qpc;

/* --- who is using this ----------------------------------------------------
 * Four things drive a screen - a mouse, a keyboard, a finger and a pad -
 * and a UI that does not know WHICH gets it subtly wrong: it draws a focus
 * ring nobody asked for, or a hover under a finger that has already left.
 *
 * Touch is the one that hides. Windows turns it into ordinary mouse
 * messages, so touch "works" without anyone doing anything at all; the only
 * signal is a mark Windows puts in the message extra info, documented since
 * Windows 7 and unchanged since.
 *
 * 1 mouse, 2 keys, 3 touch, 4 pad. 0 while nobody has done anything. */
static int g_from_touch;
static int g_last_input;

static int came_from_touch(void) {
    LPARAM x = GetMessageExtraInfo();
    return ((x & 0xFFFFFF80) == 0xFF515700) ? 1 : 0;
}

/* Whether the last pointer message came from a finger rather than a mouse. */
long long oi_touch(void) { return g_from_touch; }

/* Which of the four spoke last. The pad half is set while it is read, over
 * in the controller section. */
long long oi_last_input(void) { return (long long)g_last_input; }

static void ev_push(HWND who, long long kind, long long key, long long x, long long y) {
    int next = (ev_tail + 1) % EV_CAP;
    if (next == ev_head) return;       /* full: drop newest (potato-simple) */
    if (kind >= 1 && kind <= 5)
        QueryPerformanceCounter(&g_last_input_qpc);
    /* 1-3 pointer, 4-5 and 12 keyboard, 8-10 touch. A pointer message that
     * came from a finger is touch, not a mouse. */
    if (kind >= 1 && kind <= 3) g_last_input = g_from_touch ? 3 : 1;
    else if ((kind >= 4 && kind <= 5) || kind == 12) g_last_input = 2;
    else if (kind >= 8 && kind <= 10) g_last_input = 3;
    ev_ring[ev_tail].kind = kind;
    ev_ring[ev_tail].key = key;
    ev_ring[ev_tail].x = x;
    ev_ring[ev_tail].y = y;
    ev_ring[ev_tail].who = (long long)(uintptr_t)who;
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
long long win_event_who(void)  { return ev_current.who; }

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

/* The pointer shape over the client area. An I-beam over text and a hand
 * over something clickable is most of what makes a UI feel like a UI, and
 * Windows resets the cursor on every move unless the window says otherwise
 * in WM_SETCURSOR. 0 arrow, 1 I-beam, 2 hand, 3 wait, 4 crosshair. */
static int g_cursor = 0;

/* What this window's screen calls 100%. Windows reports dots per inch and
 * 96 is one to one, so 144 is 150%. Looked up per WINDOW rather than per
 * process, because a laptop with an external monitor has two answers and
 * the right one is the one the window is currently on. */
long long win_dpi(long long window_handle) {
    HWND h = (HWND)(uintptr_t)window_handle;
    if (!h) return 96;
    HMODULE u = GetModuleHandleA("user32.dll");
    if (u) {
        typedef UINT (WINAPI *GetDpiFn)(HWND);
        GetDpiFn fn = (GetDpiFn)(void *)GetProcAddress(u, "GetDpiForWindow");
        if (fn) {
            UINT d = fn(h);
            if (d >= 48 && d <= 960) return (long long)d;
        }
    }
    HDC dc = GetDC(h);
    if (!dc) return 96;
    int d = GetDeviceCaps(dc, LOGPIXELSX);
    ReleaseDC(h, dc);
    return d > 0 ? (long long)d : 96;
}

/* --- controllers ----------------------------------------------------------
 *
 * Windows answers about controllers in two different voices and needs both.
 *
 * XInput answers for Xbox-compatible pads and for nothing else: a DualSense
 * does not exist to it. It has FOUR slots, and asking only the first is how a
 * pad that landed on slot 1 answers nothing at all.
 *
 * Everything else is a HID device opened by WHO MADE IT - the way SDL does
 * it, and the reason a DualSense works there. Windows does not always class
 * such a pad as a game controller, so a search that asks for that class finds
 * nothing on a machine with the pad connected and lit. The vendor is the one
 * question a Bluetooth pad always answers, so that is what gets asked.
 *
 * Both roads end in the same place: a virtual pad. South, east, west and
 * north rather than A/B/X/Y or cross/circle/square/triangle, so a program
 * says what it MEANS and never which plastic is in the hand. That is what
 * makes "different controllers" a sentence with no work left in it.
 */

#define PAD_MAX 4
#define PAD_SOUTH 0
#define PAD_EAST  1
#define PAD_WEST  2
#define PAD_NORTH 3
#define PAD_L1    4
#define PAD_R1    5
#define PAD_BACK  6
#define PAD_START 7
#define PAD_UP    8
#define PAD_DOWN  9
#define PAD_LEFT  10
#define PAD_RIGHT 11
#define PAD_L3    12
#define PAD_R3    13

/* kind: 1 xbox, 2 dualsense, 3 dualshock, 4 switch, 5 something else. */
typedef struct {
    int kind;
    int slot;                 /* the XInput slot, or -1 */
    HANDLE hid;               /* the HID handle, or NULL */
    OVERLAPPED ov;
    unsigned char buf[64];
    unsigned char last[64];
    int len;
    int reading;
    unsigned int id;          /* vid<<16 | pid */
    short axis[6];            /* lx ly rx ry l2 r2, -1000..1000 */
    unsigned int down;        /* the virtual button space */
} Pad;

static Pad g_pad[PAD_MAX];
static int g_pad_n;
static int g_hid_seen;     /* how many HID interfaces Windows offered at all */

typedef DWORD (WINAPI *XIGetStateFn)(DWORD, void *);
static XIGetStateFn g_xi;

static void pad_load(void) {
    static int tried;
    if (tried) return;
    tried = 1;
    const char *names[3] = { "xinput1_4.dll", "xinput1_3.dll", "xinput9_1_0.dll" };
    for (int i = 0; i < 3; i++) {
        HMODULE m = LoadLibraryA(names[i]);
        if (m) {
            g_xi = (XIGetStateFn)(void *)GetProcAddress(m, "XInputGetState");
            if (g_xi) return;
        }
    }
}

/* A thumb resting on a stick is not a push. Below the dead zone is nothing;
 * above it the remaining travel is spread over the whole range, so the first
 * degree past the edge is not a jump. */
static short pad_stick(short v) {
    int dead = 7000;
    int a = v < 0 ? -v : v;
    if (a <= dead) return 0;
    int out = (a - dead) * 1000 / (32767 - dead);
    if (out > 1000) out = 1000;
    return (short)(v < 0 ? -out : out);
}

/* The same, for a HID pad: one byte, with 128 in the middle. */
static short pad_stick_byte(unsigned char v) {
    int c = (int)v - 128;
    int dead = 12;
    int a = c < 0 ? -c : c;
    if (a <= dead) return 0;
    int out = (a - dead) * 1000 / (127 - dead);
    if (out > 1000) out = 1000;
    return (short)(c < 0 ? -out : out);
}

/* Raw XINPUT_STATE is 16 bytes: packet(4), buttons(2), lt(1), rt(1), then
 * lx, ly, rx, ry two bytes each. Read as bytes so no XInput header is
 * needed anywhere. */
static void pad_from_xinput(Pad *p, const unsigned char *st) {
    unsigned short b = (unsigned short)(st[4] | (st[5] << 8));
    unsigned int d = 0;
    if (b & 0x1000) d |= 1u << PAD_SOUTH;
    if (b & 0x2000) d |= 1u << PAD_EAST;
    if (b & 0x4000) d |= 1u << PAD_WEST;
    if (b & 0x8000) d |= 1u << PAD_NORTH;
    if (b & 0x0100) d |= 1u << PAD_L1;
    if (b & 0x0200) d |= 1u << PAD_R1;
    if (b & 0x0020) d |= 1u << PAD_BACK;
    if (b & 0x0010) d |= 1u << PAD_START;
    if (b & 0x0001) d |= 1u << PAD_UP;
    if (b & 0x0002) d |= 1u << PAD_DOWN;
    if (b & 0x0004) d |= 1u << PAD_LEFT;
    if (b & 0x0008) d |= 1u << PAD_RIGHT;
    if (b & 0x0040) d |= 1u << PAD_L3;
    if (b & 0x0080) d |= 1u << PAD_R3;
    p->down = d;
    p->axis[0] = pad_stick((short)(st[8]  | (st[9]  << 8)));
    /* A stick points up; a screen points down. */
    p->axis[1] = (short)-pad_stick((short)(st[10] | (st[11] << 8)));
    p->axis[2] = pad_stick((short)(st[12] | (st[13] << 8)));
    p->axis[3] = (short)-pad_stick((short)(st[14] | (st[15] << 8)));
    p->axis[4] = (short)(st[6] * 1000 / 255);
    p->axis[5] = (short)(st[7] * 1000 / 255);
}

/* The hat, as four directions. 0 is up and it goes clockwise; anything above
 * 7 is centred. Every Sony pad and most others say it exactly this way. */
static unsigned int pad_hat(int h) {
    static const unsigned int by[8] = {
        1u << PAD_UP,
        (1u << PAD_UP) | (1u << PAD_RIGHT),
        1u << PAD_RIGHT,
        (1u << PAD_RIGHT) | (1u << PAD_DOWN),
        1u << PAD_DOWN,
        (1u << PAD_DOWN) | (1u << PAD_LEFT),
        1u << PAD_LEFT,
        (1u << PAD_LEFT) | (1u << PAD_UP),
    };
    return h >= 0 && h < 8 ? by[h] : 0u;
}

/* A Sony report. The same pad says itself four ways, so there are four rows
 * here and no guessing: which byte the sticks start at, which byte the
 * buttons are in, and where the two analogue triggers sit.
 *
 *   0x31, long    DualSense over Bluetooth  (a counter goes first)
 *   0x11, long    DualShock 4 over Bluetooth
 *   0x01, 32+     DualSense over the cable  (triggers before the buttons)
 *   0x01, 10+     DualShock 4 over the cable, and a DualSense in the simple
 *                 Bluetooth mode it starts in until something asks for more
 *
 * A guess was tried first - find the byte whose low nibble looks like a hat -
 * and it reads the wrong byte the moment no face button is down, which is
 * most of the time. Four rows are shorter than one clever line and they can
 * be checked against a real report. */
static void pad_from_sony(Pad *p, const unsigned char *r, int len) {
    int ax, btn, trig;
    if (r[0] == 0x31 && len >= 12)      { ax = 2; btn = 9; trig = 6; }
    else if (r[0] == 0x11 && len >= 12) { ax = 3; btn = 7; trig = 10; }
    else if (r[0] == 0x01 && len >= 32) { ax = 1; btn = 8; trig = 5; }
    else if (r[0] == 0x01 && len >= 10) { ax = 1; btn = 5; trig = 8; }
    else return;
    if (len <= btn + 1 || len <= ax + 3) return;

    p->axis[0] = pad_stick_byte(r[ax + 0]);
    p->axis[1] = pad_stick_byte(r[ax + 1]);
    p->axis[2] = pad_stick_byte(r[ax + 2]);
    p->axis[3] = pad_stick_byte(r[ax + 3]);

    unsigned char b0 = r[btn], b1 = r[btn + 1];
    unsigned int d = pad_hat(b0 & 0x0F);
    if (b0 & 0x10) d |= 1u << PAD_WEST;    /* square   */
    if (b0 & 0x20) d |= 1u << PAD_SOUTH;   /* cross    */
    if (b0 & 0x40) d |= 1u << PAD_EAST;    /* circle   */
    if (b0 & 0x80) d |= 1u << PAD_NORTH;   /* triangle */
    if (b1 & 0x01) d |= 1u << PAD_L1;
    if (b1 & 0x02) d |= 1u << PAD_R1;
    if (b1 & 0x10) d |= 1u << PAD_BACK;    /* share / create */
    if (b1 & 0x20) d |= 1u << PAD_START;   /* options        */
    if (b1 & 0x40) d |= 1u << PAD_L3;
    if (b1 & 0x80) d |= 1u << PAD_R3;
    p->down = d;

    if (len > trig + 1) {
        p->axis[4] = (short)(r[trig + 0] * 1000 / 255);
        p->axis[5] = (short)(r[trig + 1] * 1000 / 255);
    }
}

/* Who made it decides how to read it. Sony 054C, Microsoft 045E, Nintendo
 * 057E, Logitech 046D, 8BitDo 2DC8. */
static int pad_kind_of(unsigned short vid, unsigned short pid) {
    if (vid == 0x054C) return (pid == 0x0CE6 || pid == 0x0DF2) ? 2 : 3;
    if (vid == 0x045E) return 1;
    if (vid == 0x057E) return 4;
    return 5;
}

static int pad_is_maker(unsigned short v) {
    return v == 0x054C || v == 0x045E || v == 0x057E || v == 0x046D || v == 0x2DC8;
}

typedef void (WINAPI *HidD_GetHidGuidFn)(GUID *);
typedef BOOL (WINAPI *HidD_GetAttributesFn)(HANDLE, void *);
typedef void * (WINAPI *SetupDiGetClassDevsAFn)(const GUID *, const char *, HWND, DWORD);
typedef BOOL (WINAPI *SetupDiEnumDeviceInterfacesFn)(void *, void *, const GUID *, DWORD, void *);
typedef BOOL (WINAPI *SetupDiGetDeviceInterfaceDetailAFn)(void *, void *, void *, DWORD, DWORD *, void *);
typedef BOOL (WINAPI *SetupDiDestroyDeviceInfoListFn)(void *);

/* Look for HID pads. A controller switched on after the program started has
 * to be found too, so this runs again now and then rather than once. */
static void pad_look(void) {
    static unsigned long when;
    static int ever;
    unsigned long now = GetTickCount();
    if (ever && now - when < 2000) return;
    when = now; ever = 1;
    g_hid_seen = 0;

    HMODULE hid = LoadLibraryA("hid.dll");
    HMODULE sud = LoadLibraryA("setupapi.dll");
    if (!hid || !sud) return;
    HidD_GetHidGuidFn getGuid = (HidD_GetHidGuidFn)(void *)GetProcAddress(hid, "HidD_GetHidGuid");
    HidD_GetAttributesFn getAttrs = (HidD_GetAttributesFn)(void *)GetProcAddress(hid, "HidD_GetAttributes");
    SetupDiGetClassDevsAFn getDevs = (SetupDiGetClassDevsAFn)(void *)GetProcAddress(sud, "SetupDiGetClassDevsA");
    SetupDiEnumDeviceInterfacesFn enumIf = (SetupDiEnumDeviceInterfacesFn)(void *)GetProcAddress(sud, "SetupDiEnumDeviceInterfaces");
    SetupDiGetDeviceInterfaceDetailAFn detail = (SetupDiGetDeviceInterfaceDetailAFn)(void *)GetProcAddress(sud, "SetupDiGetDeviceInterfaceDetailA");
    SetupDiDestroyDeviceInfoListFn destroy = (SetupDiDestroyDeviceInfoListFn)(void *)GetProcAddress(sud, "SetupDiDestroyDeviceInfoList");
    if (!getGuid || !getAttrs || !getDevs || !enumIf || !detail || !destroy) return;

    GUID guid;
    getGuid(&guid);
    void *set = getDevs(&guid, NULL, NULL, 0x12 /* PRESENT | DEVICEINTERFACE */);
    if (!set || set == INVALID_HANDLE_VALUE) return;

    struct { DWORD cbSize; GUID g; DWORD flags; ULONG_PTR reserved; } iface;
    for (DWORD i = 0; ; i++) {
        memset(&iface, 0, sizeof iface);
        iface.cbSize = sizeof iface;
        if (!enumIf(set, NULL, &guid, i, &iface)) break;
        DWORD need = 0;
        detail(set, &iface, NULL, 0, &need, NULL);
        if (need == 0 || need > 1024) continue;
        /* cbSize of SP_DEVICE_INTERFACE_DETAIL_DATA_A is the field every
         * sample gets wrong: it is the size of the STRUCT, not of the
         * buffer, and it differs with the bitness. Try what x64 wants and
         * then what x86 wants rather than believe either. */
        char blob[1024];
        int got_path = 0;
        for (int cb = 0; cb < 2 && !got_path; cb++) {
            memset(blob, 0, sizeof blob);
            *(DWORD *)blob = cb == 0 ? 8u : 5u;
            if (detail(set, &iface, blob, need, NULL, NULL)) got_path = 1;
        }
        if (!got_path) continue;
        g_hid_seen++;
        if (g_pad_n >= PAD_MAX) continue;
        const char *path = blob + 4;

        /* Ask with NO access at all: Windows holds a keyboard exclusively
         * and refuses GENERIC_READ outright, so a search that opens for
         * reading finds nothing and cannot say why. Zero access is always
         * allowed and answers everything except what the device is saying
         * right now. */
        /* An XInput device ALSO shows up here as plain HID, and opening it
         * both ways is how one controller in one hand becomes two on the
         * screen. Windows marks those paths with "ig_" - the interface an
         * XInput device exposes - so they are left to XInput, which
         * understands the triggers and the rumble that this side does not.
         * SDL skips them on the same mark for the same reason. */
        if (strstr(path, "ig_") || strstr(path, "IG_")) continue;

        HANDLE ask = CreateFileA(path, 0, FILE_SHARE_READ | FILE_SHARE_WRITE,
                                 NULL, OPEN_EXISTING, 0, NULL);
        if (ask == INVALID_HANDLE_VALUE) continue;
        struct { ULONG Size; USHORT Vendor; USHORT Product; USHORT Version; } attrs;
        memset(&attrs, 0, sizeof attrs);
        attrs.Size = sizeof attrs;
        int mine = getAttrs(ask, &attrs) && pad_is_maker(attrs.Vendor);
        CloseHandle(ask);
        if (!mine) continue;

        unsigned int id = ((unsigned int)attrs.Vendor << 16) | attrs.Product;
        int have = 0;
        for (int k = 0; k < g_pad_n; k++) if (g_pad[k].hid && g_pad[k].id == id) have = 1;
        if (have) continue;

        HANDLE r = CreateFileA(path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
                               NULL, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, NULL);
        if (r == INVALID_HANDLE_VALUE) continue;   /* somebody else holds it */
        Pad *p = &g_pad[g_pad_n++];
        memset(p, 0, sizeof *p);
        p->kind = pad_kind_of(attrs.Vendor, attrs.Product);
        p->slot = -1;
        p->hid = r;
        p->id = id;
        p->len = 64;
        p->ov.hEvent = CreateEventA(NULL, TRUE, FALSE, NULL);
    }
    destroy(set);
}

/* Read whatever has arrived, from both kinds, without ever waiting. Every
 * question below calls this, and it does the work at most once a
 * millisecond, so asking about eight buttons costs one read. */
static void pad_pump(void) {
    static unsigned long when;
    unsigned long now = GetTickCount();
    if (when == now) return;
    when = now;
    pad_load();
    pad_look();

    if (g_xi) {
        for (int slot = 0; slot < 4; slot++) {
            unsigned char st[16];
            memset(st, 0, sizeof st);
            if (g_xi((DWORD)slot, st) != 0) continue;
            Pad *p = NULL;
            for (int k = 0; k < g_pad_n; k++) if (g_pad[k].slot == slot) p = &g_pad[k];
            if (!p) {
                if (g_pad_n >= PAD_MAX) continue;
                p = &g_pad[g_pad_n++];
                memset(p, 0, sizeof *p);
                p->kind = 1;
                p->slot = slot;
            }
            pad_from_xinput(p, st);
        }
    }

    for (int k = 0; k < g_pad_n; k++) {
        Pad *p = &g_pad[k];
        if (!p->hid) continue;
        DWORD got = 0;
        if (!p->reading) {
            ResetEvent(p->ov.hEvent);
            if (ReadFile(p->hid, p->buf, (DWORD)p->len, &got, &p->ov)) {
                if (got > 0) { memcpy(p->last, p->buf, got < 64 ? got : 64); p->len = (int)(got < 64 ? got : 64); }
            } else if (GetLastError() == ERROR_IO_PENDING) {
                p->reading = 1;
            }
        } else if (GetOverlappedResult(p->hid, &p->ov, &got, FALSE)) {
            if (got > 0) { memcpy(p->last, p->buf, got < 64 ? got : 64); p->len = (int)(got < 64 ? got : 64); }
            p->reading = 0;
        }
        if (p->kind == 2 || p->kind == 3) pad_from_sony(p, p->last, p->len);
    }

    /* A pad being used is the newest voice in the room. */
    for (int k = 0; k < g_pad_n; k++) {
        if (g_pad[k].down != 0) { g_last_input = 4; return; }
        for (int a = 0; a < 4; a++)
            if (g_pad[k].axis[a] != 0) { g_last_input = 4; return; }
    }
}

/* How many controllers are here right now. */
long long oi_pad_count(void) { pad_pump(); return (long long)g_pad_n; }

/* Which sort the i:th one is: 1 xbox, 2 dualsense, 3 dualshock, 4 switch,
 * 5 something else, 0 there is no such pad. */
long long oi_pad_kind(long long i) {
    pad_pump();
    return (i < 0 || i >= g_pad_n) ? 0 : (long long)g_pad[i].kind;
}

/* vid<<16|pid, so an app can name the exact device. A DualSense is
 * 054C:0CE6. */
long long oi_pad_id(long long i) {
    pad_pump();
    return (i < 0 || i >= g_pad_n) ? 0 : (long long)g_pad[i].id;
}

/* -1000..1000. 0 lx, 1 ly, 2 rx, 3 ry, 4 l2, 5 r2. */
long long oi_pad_axis(long long i, long long which) {
    pad_pump();
    if (i < 0 || i >= g_pad_n || which < 0 || which >= 6) return 0;
    return (long long)g_pad[i].axis[which];
}

/* Whether a virtual button is held: 0 south, 1 east, 2 west, 3 north, 4 l1,
 * 5 r1, 6 back, 7 start, 8 up, 9 down, 10 left, 11 right, 12 l3, 13 r3. */
long long oi_pad_button(long long i, long long b) {
    pad_pump();
    if (i < 0 || i >= g_pad_n || b < 0 || b >= 32) return 0;
    return (g_pad[i].down >> (unsigned)b) & 1u;
}

/* One byte of the newest raw report, and how long that report was. A
 * mapping is checked against what the device actually said rather than
 * against a memory of it, which is the only honest way to add a pad nobody
 * here owns. */
long long oi_pad_byte(long long i, long long at) {
    pad_pump();
    if (i < 0 || i >= g_pad_n || at < 0 || at >= 64) return 0;
    return (long long)g_pad[i].last[at];
}

/* How many HID devices Windows offered the search at all. It says the
 * difference between the three ways this can be empty: a machine with no
 * controller on it (a number here, none of them a pad), a controller that
 * never reached Windows (the same), and a search that could not run at all
 * (zero). Without it, all three look like "no controller". */
long long oi_hid_seen(void) { pad_pump(); return (long long)g_hid_seen; }

long long oi_pad_len(long long i) {
    pad_pump();
    return (i < 0 || i >= g_pad_n) ? 0 : (long long)g_pad[i].len;
}

/* The two questions a menu asks. Both answer what has CHANGED since the
 * last time you asked, so ask them once a frame and not twice - the second
 * ask in the same frame has nothing left to report.
 *
 * A menu wants STEPS and not a velocity: holding the stick over moves the
 * focus once, waits, and then repeats, exactly the way a held arrow key
 * behaves. The wait lives here because the clock does. */
static unsigned int g_pad_was[PAD_MAX];
static int g_step_dir[PAD_MAX][2];
static unsigned long g_step_when[PAD_MAX][2];

/* -1, 0 or 1. axis 0 is left/right, axis 1 is up/down and points DOWN the
 * way a screen does. The d-pad and the left stick both answer, so a menu
 * never cares which one the hand reached for. */
long long oi_pad_step(long long i, long long axis) {
    pad_pump();
    if (i < 0 || i >= g_pad_n || axis < 0 || axis > 1) return 0;
    Pad *p = &g_pad[i];
    short v = p->axis[axis];
    int dir;
    if (axis == 0)
        dir = (p->down & (1u << PAD_LEFT)) ? -1 : (p->down & (1u << PAD_RIGHT)) ? 1
            : (v > 400 ? 1 : v < -400 ? -1 : 0);
    else
        dir = (p->down & (1u << PAD_UP)) ? -1 : (p->down & (1u << PAD_DOWN)) ? 1
            : (v > 400 ? 1 : v < -400 ? -1 : 0);
    unsigned long now = GetTickCount();
    if (dir == 0) { g_step_dir[i][axis] = 0; return 0; }
    if (dir != g_step_dir[i][axis]) {
        g_step_dir[i][axis] = dir;
        g_step_when[i][axis] = now + 380;
        return dir;
    }
    if (now >= g_step_when[i][axis]) {
        g_step_when[i][axis] = now + 90;
        return dir;
    }
    return 0;
}

/* 1 the moment a button goes down. Remembered per button, so asking about
 * south does not swallow the press of east. */
long long oi_pad_pressed(long long i, long long b) {
    pad_pump();
    if (i < 0 || i >= g_pad_n || b < 0 || b >= 32) return 0;
    unsigned int bit = 1u << (unsigned)b;
    int now = (g_pad[i].down & bit) != 0;
    int before = (g_pad_was[i] & bit) != 0;
    if (now) g_pad_was[i] |= bit; else g_pad_was[i] &= ~bit;
    return (now && !before) ? 1 : 0;
}

/* --- text on its way in ----------------------------------------------------
 *
 * Typing Japanese means typing "nihon" and picking which way to write it.
 * Between the keys and the word there is a COMPOSITION: text that exists,
 * belongs in the field, and is not settled yet. Windows sends it as its own
 * messages, and an app that only listens for WM_CHAR never sees a single one
 * of them - which is why so many games simply cannot be typed in.
 *
 * Everything here is one string and one number: what is being composed, and
 * how far into it the caret sits. The app puts the string in the field and
 * underlines that stretch; when the composition ends Windows sends the
 * finished word as ordinary characters and the string goes empty again.
 */
static char g_ime_text[512];
static int g_ime_caret;
static int g_ime_on;

/* imm32 by name, like everything else optional in this file, so no link
 * line anywhere has to grow and a machine without it still starts. */
typedef HIMC (WINAPI *ImmGetContextFn)(HWND);
typedef LONG (WINAPI *ImmGetCompositionStringWFn)(HIMC, DWORD, LPVOID, DWORD);
typedef BOOL (WINAPI *ImmReleaseContextFn)(HWND, HIMC);
static ImmGetContextFn g_imm_get;
static ImmGetCompositionStringWFn g_imm_str;
static ImmReleaseContextFn g_imm_put;

static int ime_load(void) {
    static int tried;
    if (!tried) {
        tried = 1;
        HMODULE m = LoadLibraryA("imm32.dll");
        if (m) {
            g_imm_get = (ImmGetContextFn)(void *)GetProcAddress(m, "ImmGetContext");
            g_imm_str = (ImmGetCompositionStringWFn)(void *)GetProcAddress(m, "ImmGetCompositionStringW");
            g_imm_put = (ImmReleaseContextFn)(void *)GetProcAddress(m, "ImmReleaseContext");
        }
    }
    return g_imm_get && g_imm_str && g_imm_put;
}

static void ime_read(HWND hwnd, LPARAM lp) {
    if (!ime_load()) return;
    HIMC ctx = g_imm_get(hwnd);
    if (!ctx) return;
    if (lp & GCS_COMPSTR) {
        wchar_t w[256];
        LONG bytes = g_imm_str(ctx, GCS_COMPSTR, w, (DWORD)sizeof w - 2);
        int n = bytes > 0 ? (int)(bytes / 2) : 0;
        if (n > 255) n = 255;
        w[n] = 0;
        WideCharToMultiByte(CP_UTF8, 0, w, -1, g_ime_text, (int)sizeof g_ime_text - 1, NULL, NULL);
        /* The caret is given in CHARACTERS of the composition; the app wants
         * bytes, because that is what every other offset here is. */
        LONG at = g_imm_str(ctx, GCS_CURSORPOS, NULL, 0);
        if (at < 0) at = 0;
        if (at > n) at = (LONG)n;
        wchar_t head[256];
        memcpy(head, w, (size_t)at * 2);
        head[at] = 0;
        char utf8[512];
        WideCharToMultiByte(CP_UTF8, 0, head, -1, utf8, (int)sizeof utf8 - 1, NULL, NULL);
        g_ime_caret = (int)strlen(utf8);
    }
    g_imm_put(hwnd, ctx);
}

/* The runtime's own string maker, declared here as well as further down:
 * a composition has to become a real Orion text, not a pointer into a
 * static buffer the allocator knows nothing about. */
extern const char *orion_text_from_c(const char *s);

/* What is being composed right now, as UTF-8. Empty when nothing is. */
const char *oi_composing(void) {
    return orion_text_from_c(g_ime_text);
}

/* How far into it the caret sits, in bytes. */
long long oi_composing_at(void) { return (long long)g_ime_caret; }

/* Whether a composition is open at all, which is not the same as it having
 * text: it opens empty on the first key and an app should already be
 * treating the keyboard as spoken for. */
long long oi_composing_on(void) { return (long long)g_ime_on; }

long long win_cursor(long long shape) {
    g_cursor = (int)shape;
    return 1;
}

static LPCWSTR cursor_name(int shape) {
    if (shape == 1) return IDC_IBEAM;
    if (shape == 2) return IDC_HAND;
    if (shape == 3) return IDC_WAIT;
    if (shape == 4) return IDC_CROSS;
    /* The two a splitter needs: a line you drag sideways, and one you drag
     * up and down. Without them nothing on screen says the line between
     * two panels is a thing you can take hold of. */
    if (shape == 5) return IDC_SIZEWE;
    if (shape == 6) return IDC_SIZENS;
    return IDC_ARROW;
}

long long win_live_resize(long long on, long long bg) {
    g_live_resize = (int)on;
    (void)bg;
    return 1;
}

/* ---- frameless window with custom caption (Tauri-style) ----
 * frameless: WM_NCCALCSIZE returns 0 so the client area fills the
 * whole window - native caption gone, WS_THICKFRAME resize kept.
 * WM_NCHITTEST then hands back resize edges plus a caption drag-zone
 * the app declares: the top `caption_h` pixels act as HTCAPTION,
 * except `caption_left`/`caption_right` pixels reserved at each
 * end for clickable UI (tool icons, window buttons). */
/* PER WINDOW, not per process. One process drives several windows, and
 * these were globals: opening a fixed companion popup switched EVERY
 * window in the process to "the whole surface drags me", so the main
 * window's hit test returned HTCAPTION for every pixel. Nothing in it was
 * clickable and the mouse never produced a client-area message at all -
 * which also meant hover never lit anything. Synthetic clicks still worked,
 * because PostMessage skips the hit test; a real mouse does not. */
#define MAX_DRESSED 8
typedef struct {
    HWND hwnd;
    int frameless, fixed;
    int caption_h, caption_left, caption_right;
    int hole_x, hole_y, hole_w, hole_h;
    int faux_max;
    RECT faux_rect;
} Dress;
static Dress g_dress[MAX_DRESSED];

/* The dressing for this window, claiming a slot on first use. NULL only
 * when all slots are taken. */
static Dress *dress_of(HWND hwnd) {
    for (int i = 0; i < MAX_DRESSED; i++)
        if (g_dress[i].hwnd == hwnd) return &g_dress[i];
    for (int i = 0; i < MAX_DRESSED; i++)
        if (!g_dress[i].hwnd) {
            g_dress[i].hwnd = hwnd;
            g_dress[i].caption_h = 36;
            return &g_dress[i];
        }
    return NULL;
}

/* Read-only: NULL for a plain window nobody has dressed. */
static Dress *dress_find(HWND hwnd) {
    for (int i = 0; i < MAX_DRESSED; i++)
        if (g_dress[i].hwnd == hwnd) return &g_dress[i];
    return NULL;
}

long long win_frameless(long long hwnd_i, long long caption_h,
                        long long left_keep, long long right_keep) {
    HWND hwnd = (HWND)(uintptr_t)hwnd_i;
    Dress *d = dress_of(hwnd);
    if (!d) return 0;
    d->frameless = 1;
    d->caption_h = (int)caption_h;
    d->caption_left = (int)left_keep;
    d->caption_right = (int)right_keep;
    SetWindowPos(hwnd, NULL, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);
    return 1;
}

/* ---- companion-window primitives ----
 * Small dumb functions; the POLICY (a pet window that sits on top of
 * your work) lives in Orion's shell code, composed from these. */

/* Fixed-size popup: no frame at all, no resize edges; the whole
 * surface drags the window (see `fixed` in WM_NCHITTEST) - except an
 * optional CLICK HOLE, where the mouse belongs to the app: a frame
 * skin's bezel drags the pet window, the game area takes the pats. */
long long win_click_hole(long long hwnd_i, long long x, long long y,
                         long long w, long long h) {
    Dress *d = dress_of((HWND)(uintptr_t)hwnd_i);
    if (!d) return 0;
    d->hole_x = (int)x; d->hole_y = (int)y;
    d->hole_w = (int)w; d->hole_h = (int)h;
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
    Dress *d = dress_of(hwnd);
    if (!d) return 0;
    d->fixed = 1;
    d->frameless = 1;
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

/* Gone rather than minimized: no taskbar button, no dark rectangle left
 * on the desktop. What a notification needs when it has nothing to say -
 * minimizing would leave a button sitting there claiming otherwise. */
long long win_visible(long long hwnd_i, long long on) {
    ShowWindow((HWND)(uintptr_t)hwnd_i, on ? SW_SHOWNOACTIVATE : SW_HIDE);
    return 1;
}

long long win_is_min(long long hwnd_i) {
    return IsIconic((HWND)(uintptr_t)hwnd_i) ? 1 : 0;
}

long long win_maximize_toggle(long long hwnd_i) {
    HWND hwnd = (HWND)(uintptr_t)hwnd_i;
    /* Through WM_SYSCOMMAND, not ShowWindow: that is where the frameless
     * work-area fit lives, and it is the path the OS itself uses for a
     * caption double-click or Win+Up. */
    Dress *d = dress_find(hwnd);
    int big = (d && d->faux_max) || IsZoomed(hwnd);
    SendMessageW(hwnd, WM_SYSCOMMAND, big ? SC_RESTORE : SC_MAXIMIZE, 0);
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
    Dress *dr = dress_find(hwnd);
    if (msg == WM_NCCALCSIZE && dr && dr->frameless && wp) return 0;
    if (msg == WM_NCHITTEST && dr && dr->fixed) {
        if (dr->hole_w > 0) {
            RECT rc;
            GetWindowRect(hwnd, &rc);
            int x = (int)(short)LOWORD(lp) - rc.left;
            int y = (int)(short)HIWORD(lp) - rc.top;
            if (x >= dr->hole_x && x < dr->hole_x + dr->hole_w &&
                y >= dr->hole_y && y < dr->hole_y + dr->hole_h)
                return HTCLIENT;
        }
        return HTCAPTION;
    }
    if (msg == WM_NCHITTEST && dr && dr->frameless) {
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
        if (y < dr->caption_h && x >= dr->caption_left && x < w - dr->caption_right)
            return HTCAPTION;
        return HTCLIENT;
    }
    switch (msg) {
    case WM_SETCURSOR:
        /* Only the client area; the frame keeps its resize arrows. */
        if (LOWORD(lp) == HTCLIENT) {
            SetCursor(LoadCursorW(NULL, cursor_name(g_cursor)));
            return TRUE;
        }
        break;
    case WM_PAINT:
        if (win_paint_hook) {
            PAINTSTRUCT ps;
            BeginPaint(hwnd, &ps);
            win_paint_hook();
            EndPaint(hwnd, &ps);
            return 0;
        }
        break;
    /* The wheel arrives in SCREEN coordinates and in notches of 120. Both
     * are converted here so an app never has to know either. */
    /* The IME's three moments: it opens, it changes, it closes. Handled
     * rather than passed on, because DefWindowProc draws its own little
     * composition window over the top of ours. */
    case WM_IME_STARTCOMPOSITION:
        g_ime_on = 1;
        g_ime_text[0] = 0;
        g_ime_caret = 0;
        return 0;
    case WM_IME_COMPOSITION:
        ime_read(hwnd, lp);
        if (lp & GCS_RESULTSTR) return DefWindowProcW(hwnd, msg, wp, lp);
        return 0;
    case WM_IME_ENDCOMPOSITION:
        g_ime_on = 0;
        g_ime_text[0] = 0;
        g_ime_caret = 0;
        return 0;
    case WM_MOUSEWHEEL: {
        POINT pt = {(int)(short)LOWORD(lp), (int)(short)HIWORD(lp)};
        ScreenToClient(hwnd, &pt);
        ev_push(hwnd, 13, (long long)((short)HIWORD(wp)) / WHEEL_DELTA,
                pt.x, pt.y);
        return 0;
    }
    /* A second click inside the double-click time, which the window class
     * has to ask for with CS_DBLCLKS or Windows never sends it. It comes
     * INSTEAD of the second WM_LBUTTONDOWN, so an app that only handles
     * single clicks would lose every other one - the down is pushed too. */
    case WM_LBUTTONDBLCLK:
        ev_push(hwnd, 1, 1, lp_x(lp), lp_y(lp));
        ev_push(hwnd, 14, 1, lp_x(lp), lp_y(lp));
        return 0;
    case WM_LBUTTONDOWN: g_from_touch = came_from_touch(); ev_push(hwnd, 1, 1, lp_x(lp), lp_y(lp)); return 0;
    case WM_RBUTTONDOWN: ev_push(hwnd, 1, 2, lp_x(lp), lp_y(lp)); return 0;
    case WM_MBUTTONDOWN: ev_push(hwnd, 1, 3, lp_x(lp), lp_y(lp)); return 0;
    case WM_LBUTTONUP:   ev_push(hwnd, 2, 1, lp_x(lp), lp_y(lp)); return 0;
    case WM_RBUTTONUP:   ev_push(hwnd, 2, 2, lp_x(lp), lp_y(lp)); return 0;
    case WM_MBUTTONUP:   ev_push(hwnd, 2, 3, lp_x(lp), lp_y(lp)); return 0;
    case WM_MOUSEMOVE:   g_from_touch = came_from_touch(); ev_push(hwnd, 3, 0, lp_x(lp), lp_y(lp)); return 0;
    case WM_KEYDOWN:     ev_push(hwnd, 4, (long long)wp, 0, 0); return 0;
    case WM_KEYUP:       ev_push(hwnd, 5, (long long)wp, 0, 0); return 0;
    case WM_CHAR:        ev_push(hwnd, 12, (long long)wp, 0, 0); return 0;
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
    /* A real maximise sizes a frameless window to the monitor PLUS its
     * invisible resize border: it lands at -8,-8, our own top strip is
     * partly off-screen and the taskbar is covered. Windows ignores both
     * documented levers here (MINMAXINFO, and repositioning from
     * WM_SIZE - a zoomed window snaps straight back), so a frameless
     * window never actually maximises. It fills the work area and
     * remembers where it came from. Same trick as win_fullscreen. */
    case WM_SYSCOMMAND: {
        UINT cmd = (UINT)(wp & 0xFFF0);
        if (dr && dr->frameless && cmd == SC_MAXIMIZE && !dr->faux_max) {
            MONITORINFO mi = { sizeof(mi) };
            GetWindowRect(hwnd, &dr->faux_rect);
            if (GetMonitorInfoW(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST), &mi)) {
                dr->faux_max = 1;
                SetWindowPos(hwnd, NULL, mi.rcWork.left, mi.rcWork.top,
                             mi.rcWork.right - mi.rcWork.left,
                             mi.rcWork.bottom - mi.rcWork.top,
                             SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
                return 0;
            }
        }
        if (dr && dr->frameless && cmd == SC_RESTORE && dr->faux_max) {
            dr->faux_max = 0;
            SetWindowPos(hwnd, NULL, dr->faux_rect.left, dr->faux_rect.top,
                         dr->faux_rect.right - dr->faux_rect.left,
                         dr->faux_rect.bottom - dr->faux_rect.top,
                         SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
            return 0;
        }
        break;
    }
    case WM_SIZE:
        ev_push(hwnd, 7, 0, (long long)LOWORD(lp), (long long)HIWORD(lp));
        if (g_live_resize && &atlas_live_frame && wp != SIZE_MINIMIZED
            && LOWORD(lp) > 0 && HIWORD(lp) > 0) {
            atlas_live_frame((long long)LOWORD(lp), (long long)HIWORD(lp));
        }
        return 0;
    case WM_CLOSE:       ev_push(hwnd, 6, 0, 0, 0); DestroyWindow(hwnd); return 0;
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
    /* CS_DBLCLKS: without it Windows never sends WM_LBUTTONDBLCLK at all,
     * and a double click is indistinguishable from two singles. */
    wc.style = CS_HREDRAW | CS_VREDRAW | CS_DBLCLKS;
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
