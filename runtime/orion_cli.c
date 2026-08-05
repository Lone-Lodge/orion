/* orion_cli.c - CLI / OS primitives for self-hosted tools (orbit).
 *
 * The game runtime (orion_rt.c + win32_min.c ...) covers windows/gpu/
 * audio + orion_file_stamp. A command-line TOOL like orbit needs a
 * different surface: spawn processes, filesystem ops, exit. These are
 * that surface.
 *
 * Named to MATCH orbit's own function names (run_command, mkdir_all, ...)
 * and WITHOUT the orion_ prefix - the self-hosted compiler treats any
 * orion_* call as a prelude symbol (skips the declare), but a plain name
 * is auto-declared as a user extern (`declare i64 @name(...)`), which is
 * exactly what links against these. So orbit_main.or's calls resolve here
 * with zero compiler changes.
 *
 * First brick toward archiving lodge-orion: with these + orion-self's
 * existing file_read/file_write/argv/argc/print builtins, orbit's
 * build/run primitives no longer need the Rust interpreter.
 */

#define _CRT_SECURE_NO_WARNINGS 1
#define _CRT_RAND_S 1   /* rand_s (OS entropy) needs this before stdlib.h */
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

/* orion_rt.c wraps a raw C string into a headered orion Text; without it a
 * returned `const char*` isn't a real Text and `==` against a literal fails. */
extern const char *orion_text_from_c(const char *s);

#ifdef _WIN32
#include <windows.h>
#include <wchar.h>   /* wcsstr - window titles are matched wide, not ANSI */

/* Run a command line synchronously; return its exit code (-1 on spawn
 * failure). CreateProcessA needs a mutable command buffer. The os orb's
 * run_command(cmd, [args]) joins into one line and calls this. */
long long sys_run(const char *cmd) {
    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    char buf[32768];
    size_t i = 0;
    while (cmd[i] && i < sizeof(buf) - 1) { buf[i] = cmd[i]; i++; }
    buf[i] = 0;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    ZeroMemory(&pi, sizeof(pi));
    if (!CreateProcessA(NULL, buf, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi))
        return -1;
    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD code = 0;
    GetExitCodeProcess(pi.hProcess, &code);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    return (long long)code;
}

/* Like sys_run, but the child's stdout and stderr go to NUL. Lets a caller
 * (the test runner) keep its own live progress line clean while still reading
 * the child's exit code. */
long long sys_run_quiet(const char *cmd) {
    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    char buf[32768];
    size_t i = 0;
    while (cmd[i] && i < sizeof(buf) - 1) { buf[i] = cmd[i]; i++; }
    buf[i] = 0;
    HANDLE nul = CreateFileA("NUL", GENERIC_WRITE, FILE_SHARE_WRITE, NULL,
                             OPEN_EXISTING, 0, NULL);
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESTDHANDLES;
    si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
    si.hStdOutput = nul;
    si.hStdError = nul;
    ZeroMemory(&pi, sizeof(pi));
    if (!CreateProcessA(NULL, buf, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) {
        if (nul != INVALID_HANDLE_VALUE) CloseHandle(nul);
        return -1;
    }
    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD code = 0;
    GetExitCodeProcess(pi.hProcess, &code);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    if (nul != INVALID_HANDLE_VALUE) CloseHandle(nul);
    return (long long)code;
}

/* Create a directory chain (best-effort recursive: create each prefix). */
long long mkdir_all(const char *path) {
    char buf[4096];
    size_t n = 0;
    while (path[n] && n < sizeof(buf) - 1) { buf[n] = path[n]; n++; }
    buf[n] = 0;
    for (size_t i = 1; i < n; i++) {
        if (buf[i] == '/' || buf[i] == '\\') {
            char c = buf[i]; buf[i] = 0;
            CreateDirectoryA(buf, NULL);
            buf[i] = c;
        }
    }
    CreateDirectoryA(buf, NULL);
    return 0;
}

long long remove_file(const char *path) { return DeleteFileA(path) ? 0 : -1; }

long long file_exists(const char *path) {
    DWORD a = GetFileAttributesA(path);
    return (a != INVALID_FILE_ATTRIBUTES && !(a & FILE_ATTRIBUTE_DIRECTORY)) ? 1 : 0;
}
long long is_dir(const char *path) {
    DWORD a = GetFileAttributesA(path);
    return (a != INVALID_FILE_ATTRIBUTES && (a & FILE_ATTRIBUTE_DIRECTORY)) ? 1 : 0;
}
long long is_file(const char *path) { return file_exists(path); }

/* Milliseconds since boot - the test runner times compiles with now()/elapsed. */
long long now(void) { return (long long)GetTickCount64(); }

long long file_size(const char *path) {
    WIN32_FILE_ATTRIBUTE_DATA d;
    if (!GetFileAttributesExA(path, GetFileExInfoStandard, &d)) return -1;
    return ((long long)d.nFileSizeHigh << 32) | (long long)d.nFileSizeLow;
}

/* Delete a directory and everything under it. Returns 0 when the directory
 * is gone. Clears read-only bits first - a fetched git checkout marks its
 * object files read-only, and DeleteFileA refuses those. */
long long fs_remove_tree(const char *path) {
    char pat[4096];
    WIN32_FIND_DATAA fd;
    snprintf(pat, sizeof(pat), "%s\\*", path);
    HANDLE h = FindFirstFileA(pat, &fd);
    if (h != INVALID_HANDLE_VALUE) {
        do {
            if (strcmp(fd.cFileName, ".") == 0 || strcmp(fd.cFileName, "..") == 0) continue;
            char sub[4096];
            snprintf(sub, sizeof(sub), "%s\\%s", path, fd.cFileName);
            if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
                fs_remove_tree(sub);
            } else {
                SetFileAttributesA(sub, FILE_ATTRIBUTE_NORMAL);
                DeleteFileA(sub);
            }
        } while (FindNextFileA(h, &fd));
        FindClose(h);
    }
    return RemoveDirectoryA(path) ? 0 : -1;
}

/* Last-write time in milliseconds (Windows FILETIME epoch scaled down; only
 * comparisons and deltas are meaningful, same as the POSIX side). -1 if the
 * file cannot be read - a watcher treats that as "changed". */
long long file_mtime(const char *path) {
    WIN32_FILE_ATTRIBUTE_DATA d;
    if (!GetFileAttributesExA(path, GetFileExInfoStandard, &d)) return -1;
    long long t = ((long long)d.ftLastWriteTime.dwHighDateTime << 32) |
                  (long long)d.ftLastWriteTime.dwLowDateTime;
    return t / 10000; /* 100ns ticks -> ms */
}

/* Run a command and capture its stdout as one string (static buffer;
 * orion-self copies the returned bytes into a headered Text). */
const char *capture(const char *cmd) {
    static char cbuf[65536];
    cbuf[0] = 0;
    /* cmd.exe strips the outermost quote pair from a `cmd /c` string, so a
     * command like `"where" "clang"` becomes the garbage `where" "clang`.
     * Wrap in one extra outer pair - cmd strips that, leaving ours intact. */
    char wbuf[65600];
    size_t w = 0, j = 0;
    wbuf[w++] = '"';
    while (cmd[j] && w < sizeof(wbuf) - 8) wbuf[w++] = cmd[j++];
    wbuf[w++] = '"';
    /* Swallow stderr: `where clang` (nb_clang's probe) prints
     * "INFO: Could not find files..." to stderr on a miss, which _popen
     * leaves leaking to the console. We only ever want the stdout here. */
    { const char *r = " 2>nul"; while (*r) wbuf[w++] = *r++; }
    wbuf[w] = 0;
    FILE *p = _popen(wbuf, "r");
    if (!p) return orion_text_from_c(cbuf);
    size_t total = 0, n;
    while (total < sizeof(cbuf) - 1 &&
           (n = fread(cbuf + total, 1, sizeof(cbuf) - 1 - total, p)) > 0)
        total += n;
    cbuf[total] = 0;
    _pclose(p);
    return orion_text_from_c(cbuf);
}

#else /* POSIX */
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <unistd.h>
#include <string.h>

/* system() returns a wait-encoded status, not the child's exit code - the
 * code lives in bits 8-15. Decode it so run_command() yields the real exit
 * code (matching the Windows CreateProcess path, which returns it directly). */
long long sys_run(const char *cmd) {
    int rc = system(cmd);
    if (rc == -1) return -1;
    if (WIFEXITED(rc)) return (long long)WEXITSTATUS(rc);
    return (long long)rc;
}
long long mkdir_all(const char *path) {
    char buf[4096]; strncpy(buf, path, sizeof(buf) - 1); buf[sizeof(buf) - 1] = 0;
    for (char *p = buf + 1; *p; p++) {
        if (*p == '/') { *p = 0; mkdir(buf, 0755); *p = '/'; }
    }
    mkdir(buf, 0755);
    return 0;
}
long long remove_file(const char *path) { return remove(path) == 0 ? 0 : -1; }
long long file_exists(const char *path) {
    struct stat st;
    return (stat(path, &st) == 0 && S_ISREG(st.st_mode)) ? 1 : 0;
}
long long is_dir(const char *path) {
    struct stat st;
    return (stat(path, &st) == 0 && S_ISDIR(st.st_mode)) ? 1 : 0;
}
long long is_file(const char *path) { return file_exists(path); }

long long now(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (long long)tv.tv_sec * 1000 + tv.tv_usec / 1000;
}

long long file_size(const char *path) {
    struct stat st;
    return stat(path, &st) == 0 ? (long long)st.st_size : -1;
}

/* Last-write time in milliseconds. Only comparisons and deltas are
 * meaningful (the epoch differs from Windows). -1 if unreadable. */
long long file_mtime(const char *path) {
    struct stat st;
    if (stat(path, &st) != 0) return -1;
    return (long long)st.st_mtime * 1000;
}

#include <dirent.h>

/* Delete a directory and everything under it. 0 when it is gone. */
long long fs_remove_tree(const char *path) {
    DIR *d = opendir(path);
    if (d) {
        struct dirent *e;
        while ((e = readdir(d)) != NULL) {
            if (strcmp(e->d_name, ".") == 0 || strcmp(e->d_name, "..") == 0) continue;
            char sub[4096];
            snprintf(sub, sizeof(sub), "%s/%s", path, e->d_name);
            struct stat st;
            if (lstat(sub, &st) == 0 && S_ISDIR(st.st_mode)) fs_remove_tree(sub);
            else unlink(sub);
        }
        closedir(d);
    }
    return rmdir(path) == 0 ? 0 : -1;
}

const char *capture(const char *cmd) {
    static char cbuf[65536];
    cbuf[0] = 0;
    FILE *p = popen(cmd, "r");
    if (!p) return orion_text_from_c(cbuf);
    size_t total = 0, n;
    while (total < sizeof(cbuf) - 1 &&
           (n = fread(cbuf + total, 1, sizeof(cbuf) - 1 - total, p)) > 0)
        total += n;
    cbuf[total] = 0;
    pclose(p);
    return orion_text_from_c(cbuf);
}
#endif

/* ---- the general-software floor: env, interrupt, entropy, clock time ----
 * Small, portable, and the pieces almost every program eventually asks for.
 * All two-branch #ifdef like the rest of this file (see docs/PLATFORMS.md). */

/* Value of an environment variable, "" when unset. */
const char *env_get(const char *name) {
    const char *v = getenv(name);
    return orion_text_from_c(v ? v : "");
}

/* Ctrl+C as a QUESTION instead of a kill. The first call arms the handler;
 * from then on one Ctrl+C sets a flag the program polls (a server's loop
 * asks between requests and shuts down cleanly). A SECOND Ctrl+C restores
 * the default and kills, so a hung program still dies at the keyboard. */
static volatile long long orion_interrupt_flag = 0;
static long long orion_interrupt_armed = 0;
#ifdef _WIN32
static int __stdcall orion_ctrl_handler(unsigned long type) {
    (void)type;
    orion_interrupt_flag = 1;
    SetConsoleCtrlHandler((PHANDLER_ROUTINE)orion_ctrl_handler, FALSE);
    return 1;
}
#else
#include <signal.h>
static void orion_sigint_handler(int sig) {
    (void)sig;
    orion_interrupt_flag = 1;
    signal(SIGINT, SIG_DFL);
}
#endif
long long interrupt_seen(void) {
    if (!orion_interrupt_armed) {
        orion_interrupt_armed = 1;
#ifdef _WIN32
        SetConsoleCtrlHandler((PHANDLER_ROUTINE)orion_ctrl_handler, TRUE);
#else
        signal(SIGINT, orion_sigint_handler);
#endif
    }
    return orion_interrupt_flag;
}

/* `n` bytes of OS entropy as a fresh list (the [cap,len,data...] layout every
 * list uses). For tokens and keys - the rand orb's PRNG is for games/sims. */
extern void *orion_alloc(long long bytes);
long long *entropy_bytes(long long n) {
    if (n < 0) n = 0;
    long long *out = (long long *)orion_alloc((2 + n) * 8);
    out[0] = n;
    out[1] = n;
#ifdef _WIN32
    for (long long i = 0; i < n; i++) {
        unsigned int v = 0;
        rand_s(&v);   /* CRT wrapper over RtlGenRandom - no extra link dep */
        out[2 + i] = (long long)(v & 0xFF);
    }
#else
    FILE *u = fopen("/dev/urandom", "rb");
    for (long long i = 0; i < n; i++) {
        int c = u ? fgetc(u) : 0;
        out[2 + i] = (long long)(c & 0xFF);
    }
    if (u) fclose(u);
#endif
    return out;
}

/* Unix time in seconds, and strftime-formatting of one - the floor a date
 * orb builds on. `local` 1 = the machine's timezone, 0 = UTC. */
long long unix_now(void) { return (long long)time(NULL); }

/* Calendar parts (UTC) -> unix seconds. -1 on an impossible date. */
long long time_from_parts(long long y, long long mo, long long d,
                          long long h, long long mi, long long s) {
    struct tm tmv;
    memset(&tmv, 0, sizeof(tmv));
    tmv.tm_year = (int)(y - 1900);
    tmv.tm_mon = (int)(mo - 1);
    tmv.tm_mday = (int)d;
    tmv.tm_hour = (int)h;
    tmv.tm_min = (int)mi;
    tmv.tm_sec = (int)s;
#ifdef _WIN32
    long long r = (long long)_mkgmtime(&tmv);
#else
    long long r = (long long)timegm(&tmv);
#endif
    return r;
}

const char *time_format(long long unix_s, const char *fmt, long long local) {
    static char buf[256];
    time_t t = (time_t)unix_s;
    struct tm tmv;
#ifdef _WIN32
    if (local) localtime_s(&tmv, &t); else gmtime_s(&tmv, &t);
#else
    if (local) localtime_r(&t, &tmv); else gmtime_r(&t, &tmv);
#endif
    if (strftime(buf, sizeof(buf), fmt, &tmv) == 0) buf[0] = 0;
    return orion_text_from_c(buf);
}

/* ---- fs completeness: rename, copy, cwd - the standard trio ---- */

/* Move/rename a file or directory. 0 on success. Overwrites a file at the
 * target on POSIX; on Windows rename() refuses, so remove first when you
 * mean replace. */
long long fs_rename(const char *from, const char *to) {
    return rename(from, to) == 0 ? 0 : -1;
}

/* Byte-for-byte file copy (binary-safe). 0 on success. */
long long fs_copy_file(const char *from, const char *to) {
    FILE *in = fopen(from, "rb");
    if (!in) return -1;
    FILE *out = fopen(to, "wb");
    if (!out) { fclose(in); return -1; }
    char buf[65536];
    size_t n;
    long long ok = 0;
    while ((n = fread(buf, 1, sizeof(buf), in)) > 0) {
        if (fwrite(buf, 1, n, out) != n) { ok = -1; break; }
    }
    if (ferror(in)) ok = -1;
    fclose(in);
    if (fclose(out) != 0) ok = -1;
    return ok;
}

/* The current working directory, "" on failure. */
const char *fs_cwd(void) {
    static char buf[4096];
#ifdef _WIN32
    DWORD n = GetCurrentDirectoryA((DWORD)sizeof buf, buf);
    if (n == 0 || n >= sizeof buf) buf[0] = 0;
#else
    if (!getcwd(buf, sizeof buf)) buf[0] = 0;
#endif
    return orion_text_from_c(buf);
}

/* Format a float with a fixed number of decimals - the one formatting ask
 * to_text cannot answer. Decimals clamped to 0..17. */
const char *fmt_float(double x, long long decimals) {
    static char buf[64];
    if (decimals < 0) decimals = 0;
    if (decimals > 17) decimals = 17;
    snprintf(buf, sizeof buf, "%.*f", (int)decimals, x);
    return orion_text_from_c(buf);
}

/* ---- sha256 (FIPS 180-4), dependency-free ----
 * The stdlib's content hash: checksums, cache keys, integrity. Proven by
 * the FIPS test vectors in the encoding orb's example lines. */
static const unsigned int sha256_k[64] = {
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
};
#define SHA_ROR(x, n) (((x) >> (n)) | ((x) << (32 - (n))))
static void sha256_block(unsigned int st[8], const unsigned char *p) {
    unsigned int w[64];
    for (int i = 0; i < 16; i++)
        w[i] = (unsigned int)p[i*4] << 24 | (unsigned int)p[i*4+1] << 16 |
               (unsigned int)p[i*4+2] << 8 | (unsigned int)p[i*4+3];
    for (int i = 16; i < 64; i++) {
        unsigned int s0 = SHA_ROR(w[i-15], 7) ^ SHA_ROR(w[i-15], 18) ^ (w[i-15] >> 3);
        unsigned int s1 = SHA_ROR(w[i-2], 17) ^ SHA_ROR(w[i-2], 19) ^ (w[i-2] >> 10);
        w[i] = w[i-16] + s0 + w[i-7] + s1;
    }
    unsigned int a=st[0],b=st[1],c=st[2],d=st[3],e=st[4],f=st[5],g=st[6],h=st[7];
    for (int i = 0; i < 64; i++) {
        unsigned int S1 = SHA_ROR(e,6) ^ SHA_ROR(e,11) ^ SHA_ROR(e,25);
        unsigned int ch = (e & f) ^ (~e & g);
        unsigned int t1 = h + S1 + ch + sha256_k[i] + w[i];
        unsigned int S0 = SHA_ROR(a,2) ^ SHA_ROR(a,13) ^ SHA_ROR(a,22);
        unsigned int mj = (a & b) ^ (a & c) ^ (b & c);
        unsigned int t2 = S0 + mj;
        h=g; g=f; f=e; e=d+t1; d=c; c=b; b=a; a=t1+t2;
    }
    st[0]+=a; st[1]+=b; st[2]+=c; st[3]+=d; st[4]+=e; st[5]+=f; st[6]+=g; st[7]+=h;
}
const char *sha256_hex(const char *msg) {
    static char out[65];
    unsigned int st[8] = {0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,
                          0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19};
    size_t len = strlen(msg);
    size_t full = len / 64;
    for (size_t i = 0; i < full; i++) sha256_block(st, (const unsigned char *)msg + i*64);
    unsigned char tail[128];
    size_t rest = len - full*64;
    memcpy(tail, msg + full*64, rest);
    tail[rest] = 0x80;
    size_t padded = (rest + 1 + 8 <= 64) ? 64 : 128;
    memset(tail + rest + 1, 0, padded - rest - 1 - 8);
    unsigned long long bits = (unsigned long long)len * 8;
    for (int i = 0; i < 8; i++) tail[padded - 1 - i] = (unsigned char)(bits >> (8*i));
    sha256_block(st, tail);
    if (padded == 128) sha256_block(st, tail + 64);
    for (int i = 0; i < 8; i++) snprintf(out + i*8, 9, "%08x", st[i]);
    return orion_text_from_c(out);
}

/* Every knob on the window whose TITLE contains `needle`: keep it above every
 * other window, how solid it is, whether a frame is drawn around it, where it
 * sits, and the three buttons a frameless window has to answer for itself.
 * Together they are what a local web app needs to look like a native one: its
 * own translucent bar, floating over the work at 60%.
 * All answer 0 when the window was found, -1 when it was not. Windows-only -
 * elsewhere they answer -1 and the app says so. */
/* user32 loads DYNAMICALLY: linking it statically would make every CLI
 * program (and every test probe) demand -luser32 - measured, it broke the
 * whole battery. LoadLibrary costs one call on the first use. */
/* Titles go through the WIDE calls: GetWindowTextA would hand back the local
 * codepage and "Skärmbild" from the browser is UTF-8, so the two never match. */
#ifdef _WIN32
typedef int (__stdcall *wt_enum_fn)(void *, LONG_PTR);
static int (__stdcall *wt_EnumWindows)(wt_enum_fn, LONG_PTR);
static int (__stdcall *wt_IsWindowVisible)(void *);
static int (__stdcall *wt_GetWindowTextW)(void *, wchar_t *, int);
static int (__stdcall *wt_SetWindowPos)(void *, void *, int, int, int, int, unsigned int);
static LONG_PTR (__stdcall *wt_GetWindowLongPtr)(void *, int);
static LONG_PTR (__stdcall *wt_SetWindowLongPtr)(void *, int, LONG_PTR);
static int (__stdcall *wt_SetLayeredWindowAttributes)(void *, unsigned long, unsigned char, unsigned long);
static int (__stdcall *wt_ShowWindow)(void *, int);
static LRESULT (__stdcall *wt_PostMessageW)(void *, unsigned int, WPARAM, LPARAM);
static int (__stdcall *wt_IsZoomed)(void *);
static int (__stdcall *wt_GetWindowRect)(void *, RECT *);
static int (__stdcall *wt_SetWindowRgn)(void *, void *, int);
static void *(__stdcall *wt_MonitorFromWindow)(void *, unsigned long);
static int (__stdcall *wt_GetMonitorInfoW)(void *, MONITORINFO *);
static int (__stdcall *wt_GetClientRect)(void *, RECT *);
static int (__stdcall *wt_ClientToScreen)(void *, POINT *);
static void *(__stdcall *wt_CreateRoundRectRgn)(int, int, int, int, int, int);
static wchar_t win_needle[256];
static void *win_found;
static int __stdcall win_find_scan(void *h, LONG_PTR unused) {
    wchar_t title[512];
    RECT r;
    (void)unused;
    if (!wt_IsWindowVisible(h)) return 1;
    /* a window on its way out keeps its title for a moment while its rect
       collapses to nothing - it must not shadow the live one */
    if (wt_GetWindowRect && wt_GetWindowRect(h, &r) && r.right <= r.left) return 1;
    title[0] = 0;
    wt_GetWindowTextW(h, title, 512);
    if (title[0] && wcsstr(title, win_needle)) { win_found = h; return 0; }
    return 1;
}
/* The window itself, or NULL. Loads user32 on the first call. */
static void *win_by_title(const char *needle) {
    if (!wt_EnumWindows) {
        HMODULE u = LoadLibraryA("user32.dll");
        if (!u) return NULL;
        wt_EnumWindows = (int (__stdcall *)(wt_enum_fn, LONG_PTR))(void *)GetProcAddress(u, "EnumWindows");
        wt_IsWindowVisible = (int (__stdcall *)(void *))(void *)GetProcAddress(u, "IsWindowVisible");
        wt_GetWindowTextW = (int (__stdcall *)(void *, wchar_t *, int))(void *)GetProcAddress(u, "GetWindowTextW");
        wt_SetWindowPos = (int (__stdcall *)(void *, void *, int, int, int, int, unsigned int))(void *)GetProcAddress(u, "SetWindowPos");
        /* 64-bit exports the Ptr forms; 32-bit only has the plain ones. */
        wt_GetWindowLongPtr = (LONG_PTR (__stdcall *)(void *, int))(void *)GetProcAddress(u, "GetWindowLongPtrA");
        if (!wt_GetWindowLongPtr) wt_GetWindowLongPtr = (LONG_PTR (__stdcall *)(void *, int))(void *)GetProcAddress(u, "GetWindowLongA");
        wt_SetWindowLongPtr = (LONG_PTR (__stdcall *)(void *, int, LONG_PTR))(void *)GetProcAddress(u, "SetWindowLongPtrA");
        if (!wt_SetWindowLongPtr) wt_SetWindowLongPtr = (LONG_PTR (__stdcall *)(void *, int, LONG_PTR))(void *)GetProcAddress(u, "SetWindowLongA");
        wt_SetLayeredWindowAttributes = (int (__stdcall *)(void *, unsigned long, unsigned char, unsigned long))(void *)GetProcAddress(u, "SetLayeredWindowAttributes");
        wt_ShowWindow = (int (__stdcall *)(void *, int))(void *)GetProcAddress(u, "ShowWindow");
        wt_PostMessageW = (LRESULT (__stdcall *)(void *, unsigned int, WPARAM, LPARAM))(void *)GetProcAddress(u, "PostMessageW");
        wt_IsZoomed = (int (__stdcall *)(void *))(void *)GetProcAddress(u, "IsZoomed");
        wt_GetWindowRect = (int (__stdcall *)(void *, RECT *))(void *)GetProcAddress(u, "GetWindowRect");
        wt_SetWindowRgn = (int (__stdcall *)(void *, void *, int))(void *)GetProcAddress(u, "SetWindowRgn");
        wt_GetClientRect = (int (__stdcall *)(void *, RECT *))(void *)GetProcAddress(u, "GetClientRect");
        wt_ClientToScreen = (int (__stdcall *)(void *, POINT *))(void *)GetProcAddress(u, "ClientToScreen");
        wt_MonitorFromWindow = (void *(__stdcall *)(void *, unsigned long))(void *)GetProcAddress(u, "MonitorFromWindow");
        wt_GetMonitorInfoW = (int (__stdcall *)(void *, MONITORINFO *))(void *)GetProcAddress(u, "GetMonitorInfoW");
        {   /* the rounded region itself is gdi32's */
            HMODULE gdi = LoadLibraryA("gdi32.dll");
            if (gdi) wt_CreateRoundRectRgn = (void *(__stdcall *)(int, int, int, int, int, int))(void *)GetProcAddress(gdi, "CreateRoundRectRgn");
        }
        if (!wt_EnumWindows || !wt_IsWindowVisible || !wt_GetWindowTextW || !wt_SetWindowPos) return NULL;
    }
    win_needle[0] = 0;
    MultiByteToWideChar(CP_UTF8, 0, needle, -1, win_needle, 256);
    win_found = NULL;
    wt_EnumWindows(win_find_scan, 0);
    return win_found;
}
long long win_set_topmost(const char *needle, long long on) {
    void *h = win_by_title(needle);
    if (!h) return -1;
    wt_SetWindowPos(h, (void *)(intptr_t)(on ? -1 : -2) /* HWND_TOPMOST : HWND_NOTOPMOST */,
                    0, 0, 0, 0, 0x0001 | 0x0002 /* SWP_NOSIZE|SWP_NOMOVE */);
    return 0;
}
/* percent 100 takes the layered style back off, so a solid window pays
 * nothing for having once been faded - unless it is clicking through, which
 * is built on the same style bit. */
long long win_set_opacity(const char *needle, long long percent) {
    void *h = win_by_title(needle);
    LONG_PTR ex;
    if (!h || !wt_GetWindowLongPtr || !wt_SetWindowLongPtr || !wt_SetLayeredWindowAttributes) return -1;
    if (percent < 10) percent = 10;
    if (percent > 100) percent = 100;
    ex = wt_GetWindowLongPtr(h, -20 /* GWL_EXSTYLE */);
    if (percent >= 100) {
        if (ex & 0x00000020 /* WS_EX_TRANSPARENT */)
            wt_SetLayeredWindowAttributes(h, 0, 255, 0x2 /* LWA_ALPHA */);
        else
            wt_SetWindowLongPtr(h, -20, ex & ~(LONG_PTR)0x00080000 /* WS_EX_LAYERED */);
        return 0;
    }
    wt_SetWindowLongPtr(h, -20, ex | 0x00080000);
    wt_SetLayeredWindowAttributes(h, 0, (unsigned char)(percent * 255 / 100), 0x2 /* LWA_ALPHA */);
    return 0;
}
/* Let the mouse fall straight through the window to whatever is under it -
 * the reference-board trick: the board floats over the work and you paint,
 * click and drag as if it were not there. The KEYBOARD still arrives, which
 * is the way back: alt-tab to the window and the page's own key handler can
 * turn this off. (WS_EX_TRANSPARENT only takes the window out of mouse hit
 * testing; it needs WS_EX_LAYERED beside it to hold for a composited
 * window, and win_set_opacity knows not to strip that bit while this is on.)
 * 1 = clicking through, 0 = solid, -1 = no such window. */
long long win_set_click_through(const char *needle, long long on) {
    void *h = win_by_title(needle);
    LONG_PTR ex;
    if (!h || !wt_GetWindowLongPtr || !wt_SetWindowLongPtr) return -1;
    ex = wt_GetWindowLongPtr(h, -20 /* GWL_EXSTYLE */);
    if (on) ex |= 0x00080000 | 0x00000020;   /* WS_EX_LAYERED|WS_EX_TRANSPARENT */
    else ex &= ~(LONG_PTR)0x00000020;
    wt_SetWindowLongPtr(h, -20, ex);
    return on ? 1 : 0;
}
/* Whether it is clicking through right now (1/0), or -1 for no such window. */
long long win_click_through_on(const char *needle) {
    void *h = win_by_title(needle);
    if (!h || !wt_GetWindowLongPtr) return -1;
    return (wt_GetWindowLongPtr(h, -20) & 0x00000020) ? 1 : 0;
}
/* Take the frame off, so the page IS the window and can draw its own bar.
 *
 * The browser draws its title strip INSIDE the window, so no style bit can
 * remove it - clearing WS_CAPTION only takes the buttons away. What does work
 * is a window REGION: everything above the page's own viewport is clipped, and
 * clipped pixels are neither drawn nor hit-tested. The strip is simply gone.
 *
 * The page sends `view_h`, the height of its own viewport in device pixels
 * (innerHeight * devicePixelRatio). Everything else is measured here: the
 * client area minus that viewport IS the strip, and the client area's offset
 * inside the window frame is the rest. Nothing guesses a caption height, at
 * any DPI. The region is in window coordinates and does not follow a resize,
 * so the page re-asks on resize - which is also where a native snap-maximise
 * gets turned into ours. */
static int win_clip;                 /* how much is being clipped, 0 = framed */
static RECT win_restore;             /* the size to come back to from maximised */
static int win_maxed;
static void win_pseudo_max(void *h, int clip) {
    MONITORINFO mi;
    void *mon;
    if (!wt_MonitorFromWindow || !wt_GetMonitorInfoW) return;
    mi.cbSize = sizeof mi;
    mon = wt_MonitorFromWindow(h, 2 /* MONITOR_DEFAULTTONEAREST */);
    if (!mon || !wt_GetMonitorInfoW(mon, &mi)) return;
    wt_SetWindowPos(h, NULL, mi.rcWork.left, mi.rcWork.top - clip,
                    mi.rcWork.right - mi.rcWork.left,
                    mi.rcWork.bottom - mi.rcWork.top + clip, 0x0004 /* SWP_NOZORDER */);
}
long long win_set_frameless(const char *needle, long long on, long long view_h) {
    void *h = win_by_title(needle);
    RECT r, c;
    POINT o;
    int strip;
    void *rgn;
    if (!h || !wt_SetWindowRgn || !wt_GetWindowRect || !wt_CreateRoundRectRgn) return -1;
    if (!wt_GetClientRect || !wt_ClientToScreen) return -1;
    if (!on) {
        win_clip = 0; win_maxed = 0;
        wt_SetWindowRgn(h, NULL, 1);
        return 0;
    }
    /* a native maximise would leave the clipped strip as a gap at the top of
       the screen, so take it over: come back down, and the resize this causes
       brings the page here again with fresh numbers */
    if (wt_IsZoomed && wt_IsZoomed(h)) {
        wt_ShowWindow(h, 9 /* SW_RESTORE */);
        win_maxed = 1;
        return 0;
    }
    wt_GetWindowRect(h, &r);
    wt_GetClientRect(h, &c);
    o.x = 0; o.y = 0;
    wt_ClientToScreen(h, &o);
    strip = (c.bottom - c.top) - (int)view_h;      /* what the browser draws */
    if (strip < 0) strip = 0;
    win_clip = (o.y - r.top) + strip;
    if (win_maxed) { win_pseudo_max(h, win_clip); wt_GetWindowRect(h, &r); }
    rgn = wt_CreateRoundRectRgn(0, win_clip, r.right - r.left + 1, r.bottom - r.top + 1, 12, 12);
    wt_SetWindowRgn(h, rgn, 1);      /* the window owns the region from here */
    return 0;
}
/* Put the window's top-left corner at x,y (device pixels). The bar drags with
 * this: the browser owns the pointer and will not let another process start
 * the OS move loop for it (neither WM_NCLBUTTONDOWN nor SC_MOVE - measured),
 * so the page follows its own pointer and says where to be. */
long long win_move(const char *needle, long long x, long long y) {
    void *h = win_by_title(needle);
    if (!h) return -1;
    wt_SetWindowPos(h, NULL, (int)x, (int)y, 0, 0,
                    0x0001 | 0x0004 /* SWP_NOSIZE|SWP_NOZORDER */);
    return 0;
}
/* The rest of what a frameless window's own bar needs: the three buttons. */
long long win_command(const char *needle, const char *what) {
    void *h = win_by_title(needle);
    if (!h || !wt_ShowWindow || !wt_PostMessageW) return -1;
    if (!strcmp(what, "min")) { wt_ShowWindow(h, 6 /* SW_MINIMIZE */); return 0; }
    if (!strcmp(what, "max")) {
        if (!win_clip) {          /* framed: the OS knows how to do this */
            wt_ShowWindow(h, wt_IsZoomed && wt_IsZoomed(h) ? 9 /* SW_RESTORE */ : 3 /* SW_MAXIMIZE */);
            return 0;
        }
        if (win_maxed) {
            win_maxed = 0;
            wt_SetWindowPos(h, NULL, win_restore.left, win_restore.top,
                            win_restore.right - win_restore.left,
                            win_restore.bottom - win_restore.top, 0x0004 /* SWP_NOZORDER */);
        } else {
            wt_GetWindowRect(h, &win_restore);
            win_maxed = 1;
            win_pseudo_max(h, win_clip);
        }
        return 0;               /* the resize brings the page back to re-clip */
    }
    if (!strcmp(what, "close")) { wt_PostMessageW(h, 0x0010 /* WM_CLOSE */, 0, 0); return 0; }
    return -1;
}
#else
long long win_set_topmost(const char *needle, long long on) { (void)needle; (void)on; return -1; }
long long win_set_opacity(const char *needle, long long percent) { (void)needle; (void)percent; return -1; }
long long win_set_frameless(const char *needle, long long on, long long view_h) { (void)needle; (void)on; (void)view_h; return -1; }
long long win_set_click_through(const char *needle, long long on) { (void)needle; (void)on; return -1; }
long long win_click_through_on(const char *needle) { (void)needle; return -1; }
long long win_move(const char *needle, long long x, long long y) { (void)needle; (void)x; (void)y; return -1; }
long long win_command(const char *needle, const char *what) { (void)needle; (void)what; return -1; }
#endif

/* Exit the process with a code. */
long long exit_with(long long code) {
    exit((int)code);
    return 0;
}

/* Print a line to stderr (diagnostics / usage). */
long long eprint(const char *s) {
    fputs(s, stderr);
    fputc('\n', stderr);
    return 0;
}
