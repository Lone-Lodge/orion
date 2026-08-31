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
/* effektinspelningen (orion_rt.c): spela in/av programnivans effekter */
extern long long orion_fx_i64(const char *tag, long long live);
/* textens EGEN langd (orion_rt.c), inte strlen: binart innehall bar NUL */
extern long long orion_tlen_c(const char *p);

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
/* The whole path already there is the COMMON case - a writer that drops many
 * files into the same directory calls this before every one. Walking the path
 * and asking CreateDirectory per component costs one syscall per level every
 * time, all but the first refused with ALREADY_EXISTS. One attribute lookup
 * answers it instead. Measured on a content-addressed store: 14 ms per file
 * down to 2 ms. */
long long mkdir_all(const char *path) {
    DWORD a = GetFileAttributesA(path);
    if (a != INVALID_FILE_ATTRIBUTES && (a & FILE_ATTRIBUTE_DIRECTORY)) return 0;
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

/* Mark a file read-only, or take the mark off. A shared working tree uses
 * this to say "someone else is holding this one": the editor the person is
 * actually drawing in refuses to save, instead of the refusal arriving
 * afterwards from a tool. 0 on success, -1 if the file is not there. */
long long file_readonly(const char *path, long long on) {
    DWORD a = GetFileAttributesA(path);
    if (a == INVALID_FILE_ATTRIBUTES) return -1;
    DWORD n = on ? (a | FILE_ATTRIBUTE_READONLY) : (a & ~FILE_ATTRIBUTE_READONLY);
    if (n == a) return 0;
    return SetFileAttributesA(path, n) ? 0 : -1;
}

long long file_exists(const char *path) {
    DWORD a = GetFileAttributesA(path);
    return orion_fx_i64("fe", (a != INVALID_FILE_ATTRIBUTES && !(a & FILE_ATTRIBUTE_DIRECTORY)) ? 1 : 0);
}
long long is_dir(const char *path) {
    DWORD a = GetFileAttributesA(path);
    return orion_fx_i64("fd", (a != INVALID_FILE_ATTRIBUTES && (a & FILE_ATTRIBUTE_DIRECTORY)) ? 1 : 0);
}
long long is_file(const char *path) { return file_exists(path); }

/* Milliseconds since boot - the test runner times compiles with now()/elapsed. */
long long now(void) { return orion_fx_i64("now", (long long)GetTickCount64()); }

long long file_size(const char *path) {
    WIN32_FILE_ATTRIBUTE_DATA d;
    if (!GetFileAttributesExA(path, GetFileExInfoStandard, &d)) return orion_fx_i64("fs", -1);
    return orion_fx_i64("fs", ((long long)d.nFileSizeHigh << 32) | (long long)d.nFileSizeLow);
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
    if (!GetFileAttributesExA(path, GetFileExInfoStandard, &d)) return orion_fx_i64("fm", -1);
    long long t = ((long long)d.ftLastWriteTime.dwHighDateTime << 32) |
                  (long long)d.ftLastWriteTime.dwLowDateTime;
    return orion_fx_i64("fm", t / 10000); /* 100ns ticks -> ms */
}

/* Run a command and capture its output as one string (static buffer;
 * orion-self copies the returned bytes into a headered Text). `redir`
 * decides what happens to the child's stderr - see capture/capture_all. */
static const char *capture_with(const char *cmd, const char *redir) {
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
    { const char *r = redir; while (*r) wbuf[w++] = *r++; }
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

/* Swallow stderr: `where clang` (nb_clang's probe) prints
 * "INFO: Could not find files..." to stderr on a miss, which _popen
 * leaves leaking to the console. We only ever want the stdout here. */
const char *capture(const char *cmd) { return capture_with(cmd, " 2>nul"); }

/* Keep stderr: a terminal or debug view wants BOTH streams, interleaved
 * the way a console would show them (git and trap trails print to stderr). */
const char *capture_all(const char *cmd) { return capture_with(cmd, " 2>&1"); }

#else /* POSIX */
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <unistd.h>
#include <string.h>
#ifdef __APPLE__
#include <mach-o/dyld.h>   /* _NSGetExecutablePath - see exe_path */
#endif

/* system() returns a wait-encoded status, not the child's exit code - the
 * code lives in bits 8-15. Decode it so run_command() yields the real exit
 * code (matching the Windows CreateProcess path, which returns it directly). */
long long sys_run(const char *cmd) {
    int rc = system(cmd);
    if (rc == -1) return -1;
    if (WIFEXITED(rc)) return (long long)WEXITSTATUS(rc);
    return (long long)rc;
}

/* The POSIX half of sys_run_quiet. It existed only on Windows, so `os` could
 * declare run_command_quiet and every Linux link of orbit failed on an
 * undefined reference - the test runner is its caller, so nothing that runs
 * on this machine ever noticed. */
long long sys_run_quiet(const char *cmd) {
    char buf[32768];
    int n = snprintf(buf, sizeof(buf), "%s >/dev/null 2>&1", cmd ? cmd : "");
    if (n < 0 || (size_t)n >= sizeof(buf)) return -1;
    return sys_run(buf);
}

/* A ghost window is a Windows idea: the OS is asked to let clicks fall
 * through everywhere except the named rectangles. There is no X11 or Cocoa
 * equivalent worth faking, so this says no rather than pretending - the same
 * answer resumable_ok() gives where fibers do not exist. */
long long win_ghost(const char *needle, const char *rects) {
    (void)needle; (void)rects;
    return 1;
}
/* Already there is the common case - see the Windows branch. */
long long mkdir_all(const char *path) {
    struct stat mst;
    if (stat(path, &mst) == 0 && S_ISDIR(mst.st_mode)) return 0;
    char buf[4096]; strncpy(buf, path, sizeof(buf) - 1); buf[sizeof(buf) - 1] = 0;
    for (char *p = buf + 1; *p; p++) {
        if (*p == '/') { *p = 0; mkdir(buf, 0755); *p = '/'; }
    }
    mkdir(buf, 0755);
    return 0;
}
long long remove_file(const char *path) { return remove(path) == 0 ? 0 : -1; }

/* See the Windows branch. Clearing gives the owner write back; setting takes
 * it from everyone, so the mark survives a umask that would hand it back. */
long long file_readonly(const char *path, long long on) {
    struct stat rst;
    if (stat(path, &rst) != 0) return -1;
    mode_t m = on ? (rst.st_mode & ~(S_IWUSR | S_IWGRP | S_IWOTH)) : (rst.st_mode | S_IWUSR);
    return chmod(path, m) == 0 ? 0 : -1;
}
long long file_exists(const char *path) {
    struct stat st;
    return orion_fx_i64("fe", (stat(path, &st) == 0 && S_ISREG(st.st_mode)) ? 1 : 0);
}
long long is_dir(const char *path) {
    struct stat st;
    return orion_fx_i64("fd", (stat(path, &st) == 0 && S_ISDIR(st.st_mode)) ? 1 : 0);
}
long long is_file(const char *path) { return file_exists(path); }

long long now(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return orion_fx_i64("now", (long long)tv.tv_sec * 1000 + tv.tv_usec / 1000);
}

long long file_size(const char *path) {
    struct stat st;
    return orion_fx_i64("fs", stat(path, &st) == 0 ? (long long)st.st_size : -1);
}

/* Last-write time in milliseconds. Only comparisons and deltas are
 * meaningful (the epoch differs from Windows). -1 if unreadable. */
long long file_mtime(const char *path) {
    struct stat st;
    if (stat(path, &st) != 0) return orion_fx_i64("fm", -1);
    /* st_mtime is SECONDS. This function promises milliseconds, and a
     * caller that asks "has the file changed since I looked" gets a whole
     * second of blindness from it: rune's stat cache missed an edit made in
     * the same second that kept the same size, and only Linux showed it.
     * st_mtim carries the nanoseconds; macOS spells it st_mtimespec. */
#if defined(__APPLE__)
    return orion_fx_i64("fm", (long long)st.st_mtimespec.tv_sec * 1000 + st.st_mtimespec.tv_nsec / 1000000);
#else
    return orion_fx_i64("fm", (long long)st.st_mtim.tv_sec * 1000 + st.st_mtim.tv_nsec / 1000000);
#endif
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

static const char *capture_with(const char *cmd, const char *redir) {
    static char cbuf[65536];
    cbuf[0] = 0;
    char wbuf[65600];
    snprintf(wbuf, sizeof(wbuf), "%s%s", cmd, redir);
    FILE *p = popen(wbuf, "r");
    if (!p) return orion_text_from_c(cbuf);
    size_t total = 0, n;
    while (total < sizeof(cbuf) - 1 &&
           (n = fread(cbuf + total, 1, sizeof(cbuf) - 1 - total, p)) > 0)
        total += n;
    cbuf[total] = 0;
    pclose(p);
    return orion_text_from_c(cbuf);
}

const char *capture(const char *cmd) { return capture_with(cmd, ""); }

/* Merge stderr into the capture - terminal/debug views want both streams. */
const char *capture_all(const char *cmd) { return capture_with(cmd, " 2>&1"); }
#endif

/* ---- the general-software floor: env, interrupt, entropy, clock time ----
 * Small, portable, and the pieces almost every program eventually asks for.
 * All two-branch #ifdef like the rest of this file (see docs/PLATFORMS.md). */

/* env_get lives in orion_rt.c - GUI builds do not link this file. */

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
long long unix_now(void) { return orion_fx_i64("unow", (long long)time(NULL)); }

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

/* Ask the person which folder, and answer with its path ("" if they said no).
 * A program started from a Start-menu shortcut has no arguments to read, so
 * this is how it finds out what to work on. Windows-only today; elsewhere ""
 * and the caller falls back to an argument. */
#ifdef _WIN32
typedef struct {                       /* BROWSEINFOW, without shlobj.h */
    void *hwndOwner;
    const void *pidlRoot;
    wchar_t *pszDisplayName;
    const wchar_t *lpszTitle;
    unsigned int ulFlags;
    void *lpfn;
    LPARAM lParam;
    int iImage;
} pf_browseinfo;
const char *pick_folder(const char *title) {
    static char out[4096];
    wchar_t wtitle[256], wpath[4096];
    pf_browseinfo bi;
    void *pidl;
    void *(__stdcall *SHBrowse)(pf_browseinfo *);
    int (__stdcall *SHGetPath)(const void *, wchar_t *);
    void (__stdcall *CoFree)(void *);
    HMODULE shell = LoadLibraryA("shell32.dll"), ole = LoadLibraryA("ole32.dll");
    out[0] = 0;
    if (!shell || !ole) return orion_text_from_c(out);
    SHBrowse = (void *(__stdcall *)(pf_browseinfo *))(void *)GetProcAddress(shell, "SHBrowseForFolderW");
    SHGetPath = (int (__stdcall *)(const void *, wchar_t *))(void *)GetProcAddress(shell, "SHGetPathFromIDListW");
    CoFree = (void (__stdcall *)(void *))(void *)GetProcAddress(ole, "CoTaskMemFree");
    if (!SHBrowse || !SHGetPath || !CoFree) return orion_text_from_c(out);
    { /* the dialog is COM; a GUI app that never called this would get nothing */
        HRESULT (__stdcall *CoInit)(void *, unsigned long) =
            (HRESULT (__stdcall *)(void *, unsigned long))(void *)GetProcAddress(ole, "CoInitializeEx");
        if (CoInit) CoInit(NULL, 0x2 /* APARTMENTTHREADED */);
    }
    wtitle[0] = 0;
    MultiByteToWideChar(CP_UTF8, 0, title, -1, wtitle, 256);
    memset(&bi, 0, sizeof bi);
    bi.lpszTitle = wtitle;
    bi.ulFlags = 0x0001 /* RETURNONLYFSDIRS */ | 0x0040 /* NEWDIALOGSTYLE */;
    pidl = SHBrowse(&bi);
    if (!pidl) return orion_text_from_c(out);
    wpath[0] = 0;
    if (SHGetPath(pidl, wpath))
        WideCharToMultiByte(CP_UTF8, 0, wpath, -1, out, sizeof out, NULL, NULL);
    CoFree(pidl);
    return orion_text_from_c(out);
}
#else
const char *pick_folder(const char *title) { (void)title; return orion_text_from_c(""); }
#endif

/* This program's own file, in full, "" on failure. argv[0] is whatever the
 * caller typed and can be relative or a bare name, so a shipped app cannot
 * use it to find the files that ship beside it - this can. */
const char *exe_path(void) {
    static char buf[4096];
    buf[0] = 0;
#ifdef _WIN32
    if (!GetModuleFileNameA(NULL, buf, (DWORD)sizeof buf)) buf[0] = 0;
#elif defined(__APPLE__)
    {
        unsigned int n = (unsigned int)sizeof buf;
        if (_NSGetExecutablePath(buf, &n) != 0) buf[0] = 0;
    }
#else
    {
        ssize_t n = readlink("/proc/self/exe", buf, sizeof buf - 1);
        buf[n > 0 ? n : 0] = 0;
    }
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
    size_t len = (size_t)orion_tlen_c(msg);
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
/* Raising a window is not just showing it: Windows refuses the foreground to a
 * process that did not just receive input, so a summoned palette would only
 * flash in the taskbar. Borrowing the current foreground thread's input queue
 * for the length of the call is the documented way to ask honestly. */
static void *(__stdcall *wt_GetForegroundWindow)(void);
static int (__stdcall *wt_SetForegroundWindow)(void *);
static unsigned long (__stdcall *wt_GetWindowThreadProcessId)(void *, unsigned long *);
static int (__stdcall *wt_AttachThreadInput)(unsigned long, unsigned long, int);
static wchar_t win_needle[256];
static void *win_found;
/* Normally only visible windows count (a hidden one cannot be the app's).
 * "show" is the exception: the window it is looking for is hidden by
 * definition, which is why it asked. */
static int win_any;
static int __stdcall win_find_scan(void *h, LONG_PTR unused) {
    wchar_t title[512];
    RECT r;
    (void)unused;
    if (!win_any && !wt_IsWindowVisible(h)) return 1;
    /* a window on its way out keeps its title for a moment while its rect
       collapses to nothing - it must not shadow the live one */
    if (wt_GetWindowRect && wt_GetWindowRect(h, &r) && r.right <= r.left) return 1;
    title[0] = 0;
    wt_GetWindowTextW(h, title, 512);
    if (title[0] && wcsstr(title, win_needle)) { win_found = h; return 0; }
    return 1;
}
/* The app's OWN window when one exists - the needle search below is a
 * SUBSTRING match over every top-level window, so "dots" also matches
 * "dots - Visual Studio Code" and friends. When the runtime opened its own
 * window it must never guess: the verbs go straight to that hwnd. The
 * needle path remains for the borrowed-Edge fallback. */
static HWND ow_hwnd;
static volatile LONG ow_ready;
static volatile LONG ow_abandoned;
static void *win_target(const char *needle);
static void *ow_x_front(void);   /* the extra window in front, or NULL - own-window block */

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
        wt_GetForegroundWindow = (void *(__stdcall *)(void))(void *)GetProcAddress(u, "GetForegroundWindow");
        wt_SetForegroundWindow = (int (__stdcall *)(void *))(void *)GetProcAddress(u, "SetForegroundWindow");
        wt_GetWindowThreadProcessId = (unsigned long (__stdcall *)(void *, unsigned long *))(void *)GetProcAddress(u, "GetWindowThreadProcessId");
        wt_AttachThreadInput = (int (__stdcall *)(unsigned long, unsigned long, int))(void *)GetProcAddress(u, "AttachThreadInput");
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
static void *win_target(const char *needle) {
    /* the search also lazy-loads the wt_* verb pointers - run it always,
     * then prefer our own window over whatever the needle matched. Only a
     * FULLY up own window counts: a half-born one (webview still coming,
     * or an abandoned attempt) must not swallow verbs meant for the
     * borrowed-Edge fallback. */
    void *found = win_by_title(needle);
    void *front = ow_x_front();
    /* a verb from a page in an extra window means THAT window - the one in
       front when the bar was clicked */
    if (front) return front;
    if (ow_hwnd && ow_ready == 1) return ow_hwnd;
    return found;
}
long long win_set_topmost(const char *needle, long long on) {
    void *h = win_target(needle);
    if (!h) return -1;
    wt_SetWindowPos(h, (void *)(intptr_t)(on ? -1 : -2) /* HWND_TOPMOST : HWND_NOTOPMOST */,
                    0, 0, 0, 0, 0x0001 | 0x0002 /* SWP_NOSIZE|SWP_NOMOVE */);
    return 0;
}
/* How solid the window is. percent 100 takes the layered style back off, so a
 * solid window pays nothing for having once been faded - unless it is
 * clicking through, which is built on the same style bit.
 *
 * (Not here, and measured: a colour key - LWA_COLORKEY, one exact colour
 * punched out of the window - does nothing to a browser window. Its pixels
 * arrive through the compositor, where the per-pixel comparison never
 * happens. A see-through background needs a window we own.) */
long long win_set_opacity(const char *needle, long long percent) {
    void *h = win_target(needle);
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
static void ow_through_hotkey(void *h, int on);   /* defined with the own-window block */
static int ow_is_own_window(void *h);
static long long ow_ghost_query(void *h);
long long win_set_click_through(const char *needle, long long on) {
    void *h = win_target(needle);
    LONG_PTR ex;
    if (!h || !wt_GetWindowLongPtr || !wt_SetWindowLongPtr) return -1;
    ex = wt_GetWindowLongPtr(h, -20 /* GWL_EXSTYLE */);
    if (on) ex |= 0x00080000 | 0x00000020;   /* WS_EX_LAYERED|WS_EX_TRANSPARENT */
    else ex &= ~(LONG_PTR)0x00000020;
    wt_SetWindowLongPtr(h, -20, ex);
    /* a window the mouse cannot reach needs a way back the keyboard owns
       from ANYWHERE - our own window arms ctrl+alt+c while this is on */
    ow_through_hotkey(h, on ? 1 : 0);
    return on ? 1 : 0;
}
/* Whether it is clicking through right now (1/0), or -1 for no such window.
 * An own window in ghost mode answers yes even while the cursor is over an
 * interactive island - the MODE is on, which is what the page asks about. */
long long win_click_through_on(const char *needle) {
    void *h = win_target(needle);
    if (!h || !wt_GetWindowLongPtr) return -1;
    if (ow_is_own_window(h) && ow_ghost_query(h)) return 1;
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
static int ow_is_own_window(void *h);   /* defined with the own-window block below */
static void ow_set_visible(void *h, int on);   /* likewise */
static void ow_take_foreground(void *h);
static void ow_xwindow_watch(void *webview);   /* extra windows, with the own-window block */
static void *ow_x_front(void);                 /* the extra window in front, or NULL */
static void ow_place_save(HWND h);             /* window placement memory, with the own-window block */
long long win_set_frameless(const char *needle, long long on, long long view_h) {
    void *h = win_target(needle);
    RECT r, c;
    POINT o;
    int strip;
    void *rgn;
    /* our own webview window has no browser strip: nothing to clip, and a
       GDI region would cost it DWM's rounded corners and shadow */
    if (h && ow_is_own_window(h)) return 0;
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
    void *h = win_target(needle);
    if (!h) return -1;
    wt_SetWindowPos(h, NULL, (int)x, (int)y, 0, 0,
                    0x0001 | 0x0004 /* SWP_NOSIZE|SWP_NOZORDER */);
    return 0;
}
/* A drag the OS cannot see: the page reports pointer deltas, the window
 * follows from where it WAS at the start (the page's screenX lies under
 * hwnd hosting, so the rect is read here, not there). */
static RECT win_drag_start;
static void *win_drag_h;
long long win_drag(const char *needle, long long phase, long long dx, long long dy) {
    static int (__stdcall *get_rect)(void *, RECT *);
    if (!get_rect) {
        HMODULE u = LoadLibraryA("user32.dll");
        if (u) get_rect = (int (__stdcall *)(void *, RECT *))(void *)GetProcAddress(u, "GetWindowRect");
        if (!get_rect) return -1;
    }
    if (phase == 0) {
        win_drag_h = win_target(needle);
        if (!win_drag_h || !get_rect(win_drag_h, &win_drag_start)) { win_drag_h = NULL; return -1; }
        return 0;
    }
    if (!win_drag_h || !wt_SetWindowPos) return -1;
    wt_SetWindowPos(win_drag_h, NULL, (int)(win_drag_start.left + dx), (int)(win_drag_start.top + dy), 0, 0,
                    0x0001 | 0x0004 /* SWP_NOSIZE|SWP_NOZORDER */);
    return 0;
}
/* The rest of what a frameless window's own bar needs: the three buttons. */
long long win_command(const char *needle, const char *what) {
    void *h;
    if (!strcmp(what, "show")) win_any = 1;
    h = win_target(needle);
    win_any = 0;
    if (!h || !wt_ShowWindow || !wt_PostMessageW) return -1;
    if (!strcmp(what, "min")) { wt_ShowWindow(h, 6 /* SW_MINIMIZE */); return 0; }
    if (!strcmp(what, "hide")) {
        ow_set_visible(h, 0);
        wt_ShowWindow(h, 0 /* SW_HIDE */);
        return 0;
    }
    if (!strcmp(what, "show")) {
        wt_ShowWindow(h, 5 /* SW_SHOW */);
        /* z-order is part of showing. Set once at startup it does not survive
           the window still settling in; asserted on every summon it always
           does - and a summoned window that comes up behind something is the
           same as one that did not come up. */
        wt_SetWindowPos(h, (void *)(intptr_t)-1 /* HWND_TOPMOST */, 0, 0, 0, 0,
                        0x0001 | 0x0002 /* SWP_NOSIZE|SWP_NOMOVE */);
        ow_set_visible(h, 1);
        ow_take_foreground(h);
        return 0;
    }
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
/* ---- a program's icon, as pixels -------------------------------------
 * The start menu is shortcuts, and a shortcut's icon is whatever the shell
 * decides it is (the target's, an overridden one, a folder's) - so ask the
 * shell rather than reading the file. What comes back is an HICON, which is
 * a pair of bitmaps; drawing it into a 32-bit top-down DIB is what turns it
 * into pixels we can hand out.
 *
 * Base64 and not the bytes: a returned string is copied out at its NUL, and
 * icon pixels are full of those. The caller gets ASCII and the page turns it
 * back into an image - which is rendering, and belongs there. */
static char ico_out[65536];
static const char ico_alphabet[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static int (__stdcall *ico_DrawIconEx)(HDC, int, int, HICON, int, int, UINT, HBRUSH, UINT);
static int (__stdcall *ico_DestroyIcon)(HICON);
static HDC (__stdcall *ico_CreateCompatibleDC)(HDC);
static int (__stdcall *ico_DeleteDC)(HDC);
static void *(__stdcall *ico_CreateDIBSection)(HDC, const BITMAPINFO *, UINT, void **, HANDLE, DWORD);
static void *(__stdcall *ico_SelectObject)(HDC, void *);
static int (__stdcall *ico_DeleteObject)(void *);
static DWORD_PTR (__stdcall *ico_SHGetFileInfoA)(const char *, DWORD, void *, UINT, UINT);

static int ico_ready(void) {
    HMODULE u, g, s;
    if (ico_SHGetFileInfoA) return 1;
    u = LoadLibraryA("user32.dll");
    g = LoadLibraryA("gdi32.dll");
    s = LoadLibraryA("shell32.dll");
    if (!u || !g || !s) return 0;
    ico_DrawIconEx = (int (__stdcall *)(HDC, int, int, HICON, int, int, UINT, HBRUSH, UINT))(void *)GetProcAddress(u, "DrawIconEx");
    ico_DestroyIcon = (int (__stdcall *)(HICON))(void *)GetProcAddress(u, "DestroyIcon");
    ico_CreateCompatibleDC = (HDC (__stdcall *)(HDC))(void *)GetProcAddress(g, "CreateCompatibleDC");
    ico_DeleteDC = (int (__stdcall *)(HDC))(void *)GetProcAddress(g, "DeleteDC");
    ico_CreateDIBSection = (void *(__stdcall *)(HDC, const BITMAPINFO *, UINT, void **, HANDLE, DWORD))(void *)GetProcAddress(g, "CreateDIBSection");
    ico_SelectObject = (void *(__stdcall *)(HDC, void *))(void *)GetProcAddress(g, "SelectObject");
    ico_DeleteObject = (int (__stdcall *)(void *))(void *)GetProcAddress(g, "DeleteObject");
    ico_SHGetFileInfoA = (DWORD_PTR (__stdcall *)(const char *, DWORD, void *, UINT, UINT))(void *)GetProcAddress(s, "SHGetFileInfoA");
    return ico_DrawIconEx && ico_CreateDIBSection && ico_SHGetFileInfoA ? 1 : 0;
}

const char *icon_base64(const char *path, long long size) {
    struct { HICON hIcon; int iIcon; DWORD attrs; char name[260]; char type[80]; } sfi;
    BITMAPINFO bi;
    HDC dc = NULL;
    void *dib = NULL, *old = NULL;
    unsigned char *px = NULL;
    int n, i, j, opaque = 0;
    size_t out = 0;

    char win[4096];
    size_t p;

    ico_out[0] = 0;
    /* 64 is the ceiling the output buffer allows: 64*64*4 bytes of pixels
       become 21848 characters of base64. */
    if (!ico_ready() || size < 8 || size > 64) return orion_text_from_c(ico_out);
    /* The shell parses paths rather than opening them, and it does not take
       forward slashes - which is how the rest of this codebase writes them. */
    for (p = 0; path[p] && p < sizeof(win) - 1; p++) win[p] = path[p] == '/' ? '\\' : path[p];
    win[p] = 0;
    memset(&sfi, 0, sizeof sfi);
    /* 0x100 SHGFI_ICON, 0x0 SHGFI_LARGEICON (32px source) */
    if (!ico_SHGetFileInfoA(win, 0, &sfi, (UINT)sizeof sfi, 0x100 | 0x0) || !sfi.hIcon)
        return orion_text_from_c(ico_out);

    n = (int)size;
    memset(&bi, 0, sizeof bi);
    bi.bmiHeader.biSize = sizeof bi.bmiHeader;
    bi.bmiHeader.biWidth = n;
    bi.bmiHeader.biHeight = -n;          /* top-down: row 0 is the top row */
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = 0;      /* BI_RGB */
    dc = ico_CreateCompatibleDC(NULL);
    if (dc) dib = ico_CreateDIBSection(dc, &bi, 0 /* DIB_RGB_COLORS */, (void **)&px, NULL, 0);
    if (dc && dib && px) {
        old = ico_SelectObject(dc, dib);
        memset(px, 0, (size_t)n * n * 4);
        ico_DrawIconEx(dc, 0, 0, sfi.hIcon, n, n, 0, NULL, 0x0003 /* DI_NORMAL */);
        /* An icon with no alpha channel draws with alpha left at zero, which
           would come out completely invisible. Its shape is then the whole
           square, and saying so is better than showing nothing. */
        for (i = 0; i < n * n; i++) if (px[i * 4 + 3]) { opaque = 1; break; }
        if (!opaque) for (i = 0; i < n * n; i++) px[i * 4 + 3] = 255;

        {   /* plain base64, padded - the tail matters: it is a whole pixel */
            int total = n * n * 4;
            for (i = 0; i < total; i += 3) {
                int have = total - i;
                unsigned long v = (unsigned long)px[i] << 16;
                if (have > 1) v |= (unsigned long)px[i + 1] << 8;
                if (have > 2) v |= px[i + 2];
                for (j = 18; j >= 0; j -= 6) ico_out[out++] = ico_alphabet[(v >> j) & 63];
                if (have == 1) { ico_out[out - 2] = '='; ico_out[out - 1] = '='; }
                else if (have == 2) ico_out[out - 1] = '=';
            }
        }
        ico_out[out] = 0;
        ico_SelectObject(dc, old);
    }
    if (dib) ico_DeleteObject(dib);
    if (dc) ico_DeleteDC(dc);
    if (ico_DestroyIcon) ico_DestroyIcon(sfi.hIcon);
    return orion_text_from_c(ico_out);
}

/* No blur verb here, and the reason is worth keeping so nobody spends the
 * afternoon again. A window that hosts its content through DirectComposition
 * (ours, for the per-pixel alpha ghost mode needs) cannot have a blurred
 * backdrop. BOTH mechanisms were built and measured:
 *
 *   SetWindowCompositionAttribute (accent policy, undocumented) - accepted,
 *   then paints its accent INSTEAD of the composition surface. The window
 *   goes blank.
 *
 *   DwmSetWindowAttribute(DWMWA_SYSTEMBACKDROP_TYPE, acrylic) - accepted,
 *   returns S_OK, and changes nothing. DWM draws behind a redirection
 *   surface, and this window does not have one.
 *
 * Translucent yes, frosted no - not without giving up the alpha.
 *
 * A window nobody should be able to reach by accident: no taskbar button, no
 * alt-tab entry, no window list. It exists when it is called for and not
 * before. WS_EX_TOOLWINDOW is that, and it only takes effect over a hide and
 * a show - which is exactly what a summoned window does anyway. */
long long win_set_toolwindow(const char *needle, long long on) {
    void *h;
    LONG_PTR ex;
    win_any = 1;
    h = win_target(needle);
    win_any = 0;
    if (!h || !wt_GetWindowLongPtr || !wt_SetWindowLongPtr) return -1;
    ex = wt_GetWindowLongPtr(h, -20 /* GWL_EXSTYLE */);
    if (on) ex = (ex | 0x00000080 /* WS_EX_TOOLWINDOW */) & ~(LONG_PTR)0x00040000 /* WS_EX_APPWINDOW */;
    else ex = ex & ~(LONG_PTR)0x00000080;
    wt_SetWindowLongPtr(h, -20, ex);
    return 0;
}
/* A summoning key, pressed anywhere. The window raises ITSELF from its own
 * wndproc, which is the only place the foreground is granted without asking
 * for it: the hotkey IS the recent input Windows wants to see. The program
 * finds out on its next poll. */
#define OW_MSG_HOTKEY  (0x8000 + 43)   /* WM_APP + 43, wparam = mods, lparam = vk */
static volatile LONG ow_hot_hit;
static volatile LONG ow_hot_ok;   /* did the registration take? see the wndproc */
/* Windows refuses the foreground to a process that did not just receive
 * input, and receiving a HOTKEY does not count. A window raised that way is
 * visible and dead: no key reaches it, so nothing can be typed and nothing
 * can dismiss it. Borrowing the current foreground thread's input queue for
 * the length of the call is the documented way to ask honestly - and it has
 * to happen on BOTH ways in, the call and the key. */
static void ow_take_foreground(void *h) {
    unsigned long tf = 0, tw = 0;
    void *fg = wt_GetForegroundWindow ? wt_GetForegroundWindow() : NULL;
    if (wt_GetWindowThreadProcessId) {
        if (fg) tf = wt_GetWindowThreadProcessId(fg, NULL);
        tw = wt_GetWindowThreadProcessId(h, NULL);
    }
    if (tf && tw && tf != tw && wt_AttachThreadInput) wt_AttachThreadInput(tf, tw, 1);
    if (wt_SetForegroundWindow) wt_SetForegroundWindow(h);
    if (tf && tw && tf != tw && wt_AttachThreadInput) wt_AttachThreadInput(tf, tw, 0);
}

/* `mods` is MOD_ALT 1 | MOD_CONTROL 2 | MOD_SHIFT 4 | MOD_WIN 8, `key` a
 * virtual key code. Only posted here - the window thread registers it (see
 * OW_MSG_HOTKEY), because WM_HOTKEY lands in the queue of whoever registered.
 * The window it summons is hidden by definition, so the lookup may see
 * hidden ones. */
long long win_hotkey(const char *needle, long long mods, long long key) {
    void *h;
    win_any = 1;
    h = win_target(needle);
    win_any = 0;
    if (!h || !wt_PostMessageW) return -1;
    wt_PostMessageW(h, OW_MSG_HOTKEY, (WPARAM)mods, (LPARAM)key);
    return 0;
}
/* 1 exactly once per press: the program asks on its own schedule and must not
 * see the same summon twice. */
long long win_hotkey_taken(void) { return InterlockedExchange(&ow_hot_hit, 0); }
/* 1 while the combination is ours. Asking is the only way to tell a stolen
 * key from a bug: the registration fails quietly. */
long long win_hotkey_held(void) { return ow_hot_ok; }
/* Open whatever the shell would open: a .lnk, a folder, a document, a URL.
 * CreateProcess cannot run a shortcut, and the Start menu is nothing but
 * shortcuts, so a launcher needs this and not run_command. */
long long shell_open(const char *path) {
    static HINSTANCE (__stdcall *se)(HWND, const char *, const char *, const char *, const char *, int);
    if (!se) {
        HMODULE s = LoadLibraryA("shell32.dll");
        if (!s) return -1;
        se = (HINSTANCE (__stdcall *)(HWND, const char *, const char *, const char *, const char *, int))
             (void *)GetProcAddress(s, "ShellExecuteA");
        if (!se) return -1;
    }
    return (long long)(uintptr_t)se(NULL, "open", path, NULL, NULL, 1 /* SW_SHOWNORMAL */) > 32 ? 0 : -1;
}
/* Give the window a size and put it in the middle of its monitor's work area.
 * A browser --app window opens at whatever size the profile last had; an
 * installer wants one known shape, centered, and this is the only caller that
 * can decide that (the page cannot resize its own OS window). */
long long win_resize(const char *needle, long long w, long long h) {
    void *h_ = win_target(needle);
    MONITORINFO mi;
    void *mon;
    int x = 0, y = 0;
    if (!h_) return -1;
    if (wt_MonitorFromWindow && wt_GetMonitorInfoW) {
        mi.cbSize = sizeof mi;
        mon = wt_MonitorFromWindow(h_, 2 /* MONITOR_DEFAULTTONEAREST */);
        if (mon && wt_GetMonitorInfoW(mon, &mi)) {
            x = mi.rcWork.left + (int)(mi.rcWork.right - mi.rcWork.left - w) / 2;
            y = mi.rcWork.top + (int)(mi.rcWork.bottom - mi.rcWork.top - h) / 2;
        }
    }
    wt_SetWindowPos(h_, NULL, x, y, (int)w, (int)h, 0x0004 /* SWP_NOZORDER */);
    return 0;
}
#else
long long win_set_topmost(const char *needle, long long on) { (void)needle; (void)on; return -1; }
long long win_set_opacity(const char *needle, long long percent) { (void)needle; (void)percent; return -1; }
long long win_set_frameless(const char *needle, long long on, long long view_h) { (void)needle; (void)on; (void)view_h; return -1; }
long long win_set_click_through(const char *needle, long long on) { (void)needle; (void)on; return -1; }
long long win_click_through_on(const char *needle) { (void)needle; return -1; }
long long win_move(const char *needle, long long x, long long y) { (void)needle; (void)x; (void)y; return -1; }
long long win_drag(const char *needle, long long phase, long long dx, long long dy) { (void)needle; (void)phase; (void)dx; (void)dy; return -1; }
long long win_drag_room(const char *needle, const char *payload, const char *url, long long whole) { (void)needle; (void)payload; (void)url; (void)whole; return -1; }
long long win_command(const char *needle, const char *what) { (void)needle; (void)what; return -1; }
long long win_resize(const char *needle, long long w, long long h) { (void)needle; (void)w; (void)h; return -1; }
long long win_hotkey(const char *needle, long long mods, long long key) { (void)needle; (void)mods; (void)key; return -1; }
long long win_hotkey_taken(void) { return 0; }
long long win_hotkey_held(void) { return 0; }
long long win_set_toolwindow(const char *needle, long long on) { (void)needle; (void)on; return -1; }
const char *icon_base64(const char *path, long long size) { (void)path; (void)size; return orion_text_from_c(""); }
/* The desktop opener each platform already ships. */
long long shell_open(const char *path) {
    char cmd[4200];
#if defined(__APPLE__)
    snprintf(cmd, sizeof cmd, "open \"%s\" >/dev/null 2>&1 &", path);
#else
    snprintf(cmd, sizeof cmd, "xdg-open \"%s\" >/dev/null 2>&1 &", path);
#endif
    return system(cmd) == 0 ? 0 : -1;
}
#endif

/* ---- our own window, the OS webview inside: the Tauri model ----
 * open_window borrows an Edge --app window, which carries a browser strip
 * the app can only CLIP away - leaving a see-through band the window still
 * reserves. This is the real thing instead: a window WE create (so there is
 * no strip and nothing to clip) with the system WebView2 inside filling the
 * whole client area. The caption is removed in WM_NCCALCSIZE (left/right/
 * bottom resize borders kept); DWM still rounds and shadows it; the title
 * FOLLOWS document.title so the app orb's title-needle verbs (topmost,
 * opacity, move, min/max/close) keep working unchanged on it.
 *
 * WebView2Loader.dll (vendored beside the runtime, shipped beside a packaged
 * exe) is looked up beside the exe, on the normal search path, then in
 * %TEMP%\orion-webview\ - where a single-file setup exe unpacks it. All COM
 * is spoken raw through vtable indices: three tiny handlers, no SDK headers.
 * One own-window per process; own_window_gone() is how the app's serve loop
 * learns the person closed it. */
#ifdef _WIN32
typedef HRESULT (__stdcall *ow_fn1)(void *);
typedef HRESULT (__stdcall *ow_fn2)(void *, void *);
typedef HRESULT (__stdcall *ow_fn3)(void *, void *, void *);
typedef HRESULT (__stdcall *ow_flag_fn)(void *, int);
typedef HRESULT (__stdcall *ow_bounds_fn)(void *, RECT);
typedef struct { unsigned char a, r, g, b; } ow_color;   /* COREWEBVIEW2_COLOR */
static void *ow_vt(void *obj, int i) { return (*(void ***)obj)[i]; }

/* user32/ole32 by GetProcAddress, same reason as the wt_ block above: a
 * static -luser32 would be demanded by every CLI program and test probe. */
static ATOM (__stdcall *owu_RegisterClassW)(const WNDCLASSW *);
static HWND (__stdcall *owu_CreateWindowExW)(DWORD, const wchar_t *, const wchar_t *, DWORD, int, int, int, int, HWND, HMENU, HINSTANCE, void *);
static LRESULT (__stdcall *owu_DefWindowProcW)(HWND, UINT, WPARAM, LPARAM);
static int (__stdcall *owu_DestroyWindow)(HWND);
static int (__stdcall *owu_ShowWindow)(HWND, int);
static int (__stdcall *owu_GetMessageW)(MSG *, HWND, UINT, UINT);
static int (__stdcall *owu_TranslateMessage)(const MSG *);
static LRESULT (__stdcall *owu_DispatchMessageW)(const MSG *);
static void (__stdcall *owu_PostQuitMessage)(int);
static int (__stdcall *owu_GetClientRect)(HWND, RECT *);
static int (__stdcall *owu_SetWindowTextW)(HWND, const wchar_t *);
static HCURSOR (__stdcall *owu_LoadCursorW)(HINSTANCE, const wchar_t *);
static HICON (__stdcall *owu_LoadIconA)(HINSTANCE, const char *);
static HICON (__stdcall *owu_LoadIconW)(HINSTANCE, const wchar_t *);
static int (__stdcall *owu_GetSystemMetrics)(int);
static HMONITOR (__stdcall *owu_MonitorFromWindow)(HWND, DWORD);
static int (__stdcall *owu_GetMonitorInfoW)(HMONITOR, MONITORINFO *);
static int (__stdcall *owu_SetWindowPos)(HWND, HWND, int, int, int, int, UINT);
static int (__stdcall *owu_RegisterHotKey)(HWND, int, UINT, UINT);
static int (__stdcall *owu_UnregisterHotKey)(HWND, int);
static int (__stdcall *owu_SetForegroundWindow)(HWND);
static HCURSOR (__stdcall *owu_SetCursor)(HCURSOR);
static UINT_PTR (__stdcall *owu_SetTimer)(HWND, UINT_PTR, UINT, void *);
static int (__stdcall *owu_KillTimer)(HWND, UINT_PTR);
static int (__stdcall *owu_GetCursorPos)(POINT *);
static int (__stdcall *owu_ScreenToClient)(HWND, POINT *);
static HWND (__stdcall *owu_SetCapture)(HWND);
static int (__stdcall *owu_ReleaseCapture)(void);
static int (__stdcall *owu_TrackMouseEvent)(TRACKMOUSEEVENT *);
static HRESULT (__stdcall *owu_CoInitializeEx)(void *, DWORD);
static void (__stdcall *owu_CoTaskMemFree)(void *);

/* What the host did, stage by stage, in %TEMP%\orion-webview\host.log - the
 * window is async COM across a browser process, and when it comes up blank
 * in the field this file is the only witness. */
static void ow_log(const char *what, long long v) {
    const char *tmp = getenv("TEMP");
    char path[1024];
    FILE *f;
    if (!tmp) return;
    snprintf(path, sizeof path, "%s\\orion-webview", tmp);
    CreateDirectoryA(path, NULL);
    snprintf(path, sizeof path, "%s\\orion-webview\\host.log", tmp);
    f = fopen(path, "a");
    if (!f) return;
    fprintf(f, "%s %lld\n", what, v);
    fclose(f);
}
static int ow_load_user(void) {
    HMODULE u, o;
    if (owu_CreateWindowExW) return 1;
    u = LoadLibraryA("user32.dll");
    o = LoadLibraryA("ole32.dll");
    if (!u || !o) return 0;
    owu_RegisterClassW = (ATOM (__stdcall *)(const WNDCLASSW *))(void *)GetProcAddress(u, "RegisterClassW");
    owu_CreateWindowExW = (HWND (__stdcall *)(DWORD, const wchar_t *, const wchar_t *, DWORD, int, int, int, int, HWND, HMENU, HINSTANCE, void *))(void *)GetProcAddress(u, "CreateWindowExW");
    owu_DefWindowProcW = (LRESULT (__stdcall *)(HWND, UINT, WPARAM, LPARAM))(void *)GetProcAddress(u, "DefWindowProcW");
    owu_DestroyWindow = (int (__stdcall *)(HWND))(void *)GetProcAddress(u, "DestroyWindow");
    owu_ShowWindow = (int (__stdcall *)(HWND, int))(void *)GetProcAddress(u, "ShowWindow");
    owu_GetMessageW = (int (__stdcall *)(MSG *, HWND, UINT, UINT))(void *)GetProcAddress(u, "GetMessageW");
    owu_TranslateMessage = (int (__stdcall *)(const MSG *))(void *)GetProcAddress(u, "TranslateMessage");
    owu_DispatchMessageW = (LRESULT (__stdcall *)(const MSG *))(void *)GetProcAddress(u, "DispatchMessageW");
    owu_PostQuitMessage = (void (__stdcall *)(int))(void *)GetProcAddress(u, "PostQuitMessage");
    owu_GetClientRect = (int (__stdcall *)(HWND, RECT *))(void *)GetProcAddress(u, "GetClientRect");
    owu_SetWindowTextW = (int (__stdcall *)(HWND, const wchar_t *))(void *)GetProcAddress(u, "SetWindowTextW");
    owu_LoadCursorW = (HCURSOR (__stdcall *)(HINSTANCE, const wchar_t *))(void *)GetProcAddress(u, "LoadCursorW");
    owu_LoadIconA = (HICON (__stdcall *)(HINSTANCE, const char *))(void *)GetProcAddress(u, "LoadIconA");
    owu_LoadIconW = (HICON (__stdcall *)(HINSTANCE, const wchar_t *))(void *)GetProcAddress(u, "LoadIconW");
    owu_GetSystemMetrics = (int (__stdcall *)(int))(void *)GetProcAddress(u, "GetSystemMetrics");
    owu_MonitorFromWindow = (HMONITOR (__stdcall *)(HWND, DWORD))(void *)GetProcAddress(u, "MonitorFromWindow");
    owu_GetMonitorInfoW = (int (__stdcall *)(HMONITOR, MONITORINFO *))(void *)GetProcAddress(u, "GetMonitorInfoW");
    owu_SetWindowPos = (int (__stdcall *)(HWND, HWND, int, int, int, int, UINT))(void *)GetProcAddress(u, "SetWindowPos");
    owu_RegisterHotKey = (int (__stdcall *)(HWND, int, UINT, UINT))(void *)GetProcAddress(u, "RegisterHotKey");
    owu_SetForegroundWindow = (int (__stdcall *)(HWND))(void *)GetProcAddress(u, "SetForegroundWindow");
    owu_UnregisterHotKey = (int (__stdcall *)(HWND, int))(void *)GetProcAddress(u, "UnregisterHotKey");
    owu_SetCursor = (HCURSOR (__stdcall *)(HCURSOR))(void *)GetProcAddress(u, "SetCursor");
    owu_SetTimer = (UINT_PTR (__stdcall *)(HWND, UINT_PTR, UINT, void *))(void *)GetProcAddress(u, "SetTimer");
    owu_KillTimer = (int (__stdcall *)(HWND, UINT_PTR))(void *)GetProcAddress(u, "KillTimer");
    owu_GetCursorPos = (int (__stdcall *)(POINT *))(void *)GetProcAddress(u, "GetCursorPos");
    owu_ScreenToClient = (int (__stdcall *)(HWND, POINT *))(void *)GetProcAddress(u, "ScreenToClient");
    owu_SetCapture = (HWND (__stdcall *)(HWND))(void *)GetProcAddress(u, "SetCapture");
    owu_ReleaseCapture = (int (__stdcall *)(void))(void *)GetProcAddress(u, "ReleaseCapture");
    owu_TrackMouseEvent = (int (__stdcall *)(TRACKMOUSEEVENT *))(void *)GetProcAddress(u, "TrackMouseEvent");
    owu_CoInitializeEx = (HRESULT (__stdcall *)(void *, DWORD))(void *)GetProcAddress(o, "CoInitializeEx");
    owu_CoTaskMemFree = (void (__stdcall *)(void *))(void *)GetProcAddress(o, "CoTaskMemFree");
    return owu_RegisterClassW && owu_CreateWindowExW && owu_DefWindowProcW && owu_GetMessageW && owu_CoInitializeEx;
}

typedef struct ow_handler {
    void **vtbl;
    HRESULT (__stdcall *invoke)(struct ow_handler *, void *, void *);
} ow_handler;
static HRESULT __stdcall ow_h_qi(ow_handler *self, const void *riid, void **out) {
    (void)riid; *out = self; return 0;
}
static ULONG __stdcall ow_h_addref(ow_handler *self) { (void)self; return 1; }
static ULONG __stdcall ow_h_release(ow_handler *self) { (void)self; return 1; }
static HRESULT __stdcall ow_h_invoke(ow_handler *self, void *a, void *b) {
    return self->invoke(self, a, b);
}
static void *ow_handler_vtbl[4] = { (void *)ow_h_qi, (void *)ow_h_addref, (void *)ow_h_release, (void *)ow_h_invoke };

static HWND ow_hwnd;
static int ow_is_own_window(void *h) { return h && h == (void *)ow_hwnd; }

/* ---- visual hosting: DirectComposition, so pixels can be HOLES ----
 * hwnd hosting puts the webview in a child window: whole-window alpha works,
 * per-pixel does not (colorkey measured dead - the child composes past the
 * redirection surface). Visual hosting hands the webview a DComp visual on a
 * WS_EX_NOREDIRECTIONBITMAP window instead: where the page paints nothing,
 * there IS nothing - the work shows through at 100%. The price is that input
 * becomes ours to forward (mouse + cursor below); the prize is ghost mode. */
typedef struct { unsigned long a; unsigned short b, c; unsigned char d[8]; } ow_guid;
static const ow_guid OW_IID_ENV3 = {0x80A22AE3, 0xBE7C, 0x4CE2, {0xAF, 0xE1, 0x5A, 0x50, 0x05, 0x6C, 0xDE, 0xEB}};
static const ow_guid OW_IID_CONTROLLER = {0x4D00C0D1, 0x9434, 0x4EB6, {0x80, 0x78, 0x86, 0x97, 0xA5, 0x60, 0x33, 0x4F}};
static const ow_guid OW_IID_CONTROLLER2 = {0xC979903E, 0xD4CA, 0x4228, {0x92, 0xEB, 0x47, 0xEE, 0x3F, 0xA9, 0x6E, 0xAB}};
static const ow_guid OW_IID_DXGI_DEVICE = {0x54EC77FA, 0x1377, 0x44E6, {0x8C, 0x32, 0x88, 0xFD, 0x5F, 0x44, 0xC8, 0x4C}};
static const ow_guid OW_IID_DCOMP_DEVICE = {0xC37EA93A, 0xE7AA, 0x450D, {0xB1, 0x6F, 0x97, 0x46, 0xCB, 0x04, 0x07, 0xF3}};
static HRESULT ow_qi(void *obj, const ow_guid *iid, void **out) {
    *out = NULL;
    return ((HRESULT (__stdcall *)(void *, const void *, void **))ow_vt(obj, 0))(obj, iid, out);
}

static void *ow_dcdev, *ow_dctarget, *ow_dcvisual;
static void *ow_comp;                   /* ICoreWebView2CompositionController */
static int ow_visual;                   /* 1 = visual hosting is live */
static void ow_dcommit(void) {
    if (ow_dcdev) ((ow_fn1)ow_vt(ow_dcdev, 3 /* Commit */))(ow_dcdev);
}
/* D3D device -> DXGI -> DComp device -> target for our hwnd -> root visual.
 * All dynamic (d3d11.dll / dcomp.dll); any miss means hwnd hosting instead. */
static int ow_dcomp_init(HWND hwnd) {
    HMODULE d3d = LoadLibraryA("d3d11.dll"), dc = LoadLibraryA("dcomp.dll");
    HRESULT (__stdcall *create_d3d)(void *, int, HMODULE, UINT, const int *, UINT, UINT, void **, int *, void **);
    HRESULT (__stdcall *create_dcomp)(void *, const void *, void **);
    void *dev = NULL, *dxgi = NULL;
    if (!d3d || !dc) return 0;
    create_d3d = (HRESULT (__stdcall *)(void *, int, HMODULE, UINT, const int *, UINT, UINT, void **, int *, void **))(void *)GetProcAddress(d3d, "D3D11CreateDevice");
    create_dcomp = (HRESULT (__stdcall *)(void *, const void *, void **))(void *)GetProcAddress(dc, "DCompositionCreateDevice");
    if (!create_d3d || !create_dcomp) return 0;
    if (create_d3d(NULL, 1 /* HARDWARE */, NULL, 0x20 /* BGRA_SUPPORT */, NULL, 0, 7 /* D3D11_SDK_VERSION */, &dev, NULL, NULL) != 0 || !dev) return 0;
    if (ow_qi(dev, &OW_IID_DXGI_DEVICE, &dxgi) != 0 || !dxgi) return 0;
    if (create_dcomp(dxgi, &OW_IID_DCOMP_DEVICE, &ow_dcdev) != 0 || !ow_dcdev) return 0;
    if (((HRESULT (__stdcall *)(void *, HWND, int, void **))ow_vt(ow_dcdev, 6 /* CreateTargetForHwnd */))(ow_dcdev, hwnd, 1, &ow_dctarget) != 0 || !ow_dctarget) return 0;
    if (((ow_fn2)ow_vt(ow_dcdev, 7 /* CreateVisual */))(ow_dcdev, (void *)&ow_dcvisual) != 0 || !ow_dcvisual) return 0;
    if (((ow_fn2)ow_vt(ow_dctarget, 3 /* SetRoot */))(ow_dctarget, ow_dcvisual) != 0) return 0;
    ow_dcommit();
    return 1;
}

/* ---- ghost mode: the background is a hole, the images are solid ----
 * The page sends the rectangles that should stay INTERACTIVE (items + bar)
 * in device pixels, client coords. A 30ms timer follows the cursor: over a
 * rect the window takes input as usual; over the void it wears
 * WS_EX_TRANSPARENT and the click lands on the work underneath. ctrl+alt+c
 * ends the mode from anywhere, and the page's state poll follows. */
#define OW_MSG_GHOST (0x8000 + 42)     /* WM_APP + 42, lparam = malloc'd csv */
#define OW_GHOST_TIMER 7
static int ow_rects[256][4];
static int ow_rect_count;
static volatile LONG ow_ghost_on;
static long long ow_ghost_query(void *h) { (void)h; return ow_ghost_on ? 1 : 0; }
static void ow_ghost_styles(HWND h, int transparent) {
    LONG_PTR ex;
    if (!wt_GetWindowLongPtr || !wt_SetWindowLongPtr) return;
    ex = wt_GetWindowLongPtr(h, -20 /* GWL_EXSTYLE */);
    if (transparent) ex |= 0x00080000 | 0x00000020;      /* LAYERED|TRANSPARENT */
    else ex &= ~(LONG_PTR)(0x00080000 | 0x00000020);
    wt_SetWindowLongPtr(h, -20, ex);
}
static void ow_ghost_apply(HWND h, const char *csv) {
    const char *p = csv;
    ow_rect_count = 0;
    while (*p && ow_rect_count < 256) {
        int *r = ow_rects[ow_rect_count];
        r[0] = (int)strtol(p, (char **)&p, 10); if (*p == ',') p++;
        r[1] = (int)strtol(p, (char **)&p, 10); if (*p == ',') p++;
        r[2] = (int)strtol(p, (char **)&p, 10); if (*p == ',') p++;
        r[3] = (int)strtol(p, (char **)&p, 10);
        ow_rect_count++;
        while (*p && *p != ';') p++;
        if (*p == ';') p++;
    }
    if (csv[0]) {
        if (!ow_ghost_on) {
            InterlockedExchange(&ow_ghost_on, 1);
            if (owu_SetTimer) owu_SetTimer(h, OW_GHOST_TIMER, 30, NULL);
            if (owu_RegisterHotKey) owu_RegisterHotKey(h, 1, 0x0002 | 0x0001, 'C');
        }
    } else if (ow_ghost_on) {
        InterlockedExchange(&ow_ghost_on, 0);
        ow_rect_count = 0;
        if (owu_KillTimer) owu_KillTimer(h, OW_GHOST_TIMER);
        if (owu_UnregisterHotKey) owu_UnregisterHotKey(h, 1);
        ow_ghost_styles(h, 0);
    }
}
static void ow_ghost_tick(HWND h) {
    POINT p;
    int i, inside = 0;
    if (!ow_ghost_on || !owu_GetCursorPos || !owu_ScreenToClient) return;
    owu_GetCursorPos(&p);
    owu_ScreenToClient(h, &p);
    for (i = 0; i < ow_rect_count; i++) {
        if (p.x >= ow_rects[i][0] && p.x < ow_rects[i][0] + ow_rects[i][2] &&
            p.y >= ow_rects[i][1] && p.y < ow_rects[i][1] + ow_rects[i][3]) { inside = 1; break; }
    }
    ow_ghost_styles(h, !inside);
}
/* The page's seam: rectangles that stay interactive, "" turns ghost off.
 * Own windows only - the borrowed Edge window cannot make holes. */
long long win_ghost(const char *needle, const char *rects) {
    void *h = win_target(needle);
    char *copy;
    if (!h || !ow_is_own_window(h) || !ow_visual || !wt_PostMessageW) return -1;
    copy = (char *)malloc(strlen(rects) + 1);
    if (!copy) return -1;
    strcpy(copy, rects);
    wt_PostMessageW(h, OW_MSG_GHOST, 0, (LPARAM)copy);
    return 0;
}
/* The hotkey must be registered from the thread that pumps the window's
 * messages (WM_HOTKEY lands in the registrar's queue), and click-through is
 * flipped from the app's server thread - so this only POSTS; the window
 * thread does the registering in its wndproc. */
#define OW_MSG_THROUGH (0x8000 + 41)   /* WM_APP + 41 */
static void ow_through_hotkey(void *h, int on) {
    if (ow_is_own_window(h) && wt_PostMessageW)
        wt_PostMessageW(h, OW_MSG_THROUGH, (WPARAM)on, 0);
}
static void *ow_controller, *ow_webview;
static volatile LONG ow_state;          /* 0 never opened, 1 open, 2 gone */
static volatile LONG ow_ready;          /* 0 pending, 1 ok, -1 failed */
static wchar_t ow_url[2048], ow_title[256];
static int ow_w, ow_h;
static ow_handler ow_on_env, ow_on_controller, ow_on_title;

static void ow_fit_webview(void) {
    RECT c;
    if (!ow_controller || !ow_hwnd) return;
    owu_GetClientRect(ow_hwnd, &c);
    ((ow_bounds_fn)ow_vt(ow_controller, 6 /* put_Bounds */))(ow_controller, c);
}
/* Hiding the window is not enough and showing it is not either: the webview
 * is a separate surface with its own visibility, and ShowWindow does not
 * touch it. A window shown without this is an empty frame with the desktop
 * showing through - the page is still there, just not being drawn.
 * ICoreWebView2Controller: 4 put_IsVisible, 12 MoveFocus. */
static void ow_set_visible(void *h, int on) {
    if (!ow_is_own_window(h) || !ow_controller) return;
    ((ow_flag_fn)ow_vt(ow_controller, 4 /* put_IsVisible */))(ow_controller, on);
    /* and the keyboard belongs to the page, not to the frame around it */
    if (on) ((ow_flag_fn)ow_vt(ow_controller, 12 /* MoveFocus */))(ow_controller, 0);
}
/* ICoreWebView2: 46 add_DocumentTitleChanged, 48 get_DocumentTitle */
static HRESULT __stdcall ow_title_changed(ow_handler *self, void *sender, void *args) {
    wchar_t *title = NULL;
    (void)self; (void)args;
    if (((ow_fn2)ow_vt(sender, 48))(sender, (void *)&title) == 0 && title) {
        owu_SetWindowTextW(ow_hwnd, title);
        owu_CoTaskMemFree(title);
    }
    return 0;
}
/* controller arrived: keep it, size it, find the webview, navigate. Under
 * visual hosting the arg is the COMPOSITION controller: hand it our root
 * visual, QI the plain controller out of it, and clear the default
 * background so the page's transparent pixels really are holes. */
static HRESULT __stdcall ow_controller_done(ow_handler *self, void *hr, void *controller) {
    long long token[2] = {0, 0};
    (void)self;
    ow_log("controller_done hr", (long long)(intptr_t)hr);
    if ((int)(intptr_t)hr != 0 || !controller) { InterlockedExchange(&ow_ready, -1); return 0; }
    if (ow_visual) {
        ((ow_fn1)ow_vt(controller, 1 /* AddRef */))(controller);
        ow_comp = controller;
        if (ow_qi(controller, &OW_IID_CONTROLLER, (void **)&ow_controller) != 0 || !ow_controller) {
            ow_log("controller qi failed", -1);
            InterlockedExchange(&ow_ready, -1);
            return 0;
        }
        ((ow_fn2)ow_vt(ow_comp, 4 /* put_RootVisualTarget */))(ow_comp, ow_dcvisual);
        ow_dcommit();
        {
            void *c2 = NULL;
            if (ow_qi(ow_controller, &OW_IID_CONTROLLER2, &c2) == 0 && c2) {
                ow_color clear = {0, 0, 0, 0};
                ((HRESULT (__stdcall *)(void *, ow_color))ow_vt(c2, 27 /* put_DefaultBackgroundColor */))(c2, clear);
            }
        }
    } else {
        ((ow_fn1)ow_vt(controller, 1 /* AddRef */))(controller);
        ow_controller = controller;
    }
    ((ow_fn2)ow_vt(ow_controller, 25 /* get_CoreWebView2 */))(ow_controller, (void *)&ow_webview);
    if (!ow_webview) { InterlockedExchange(&ow_ready, -1); return 0; }
    ((ow_fn1)ow_vt(ow_webview, 1 /* AddRef */))(ow_webview);
    ow_fit_webview();
    ow_on_title.vtbl = ow_handler_vtbl;
    ow_on_title.invoke = ow_title_changed;
    ((ow_fn3)ow_vt(ow_webview, 46 /* add_DocumentTitleChanged */))(ow_webview, &ow_on_title, token);
    ow_xwindow_watch(ow_webview);
    ow_log("navigate hr", (long long)((ow_fn2)ow_vt(ow_webview, 5 /* Navigate */))(ow_webview, ow_url));
    ((HRESULT (__stdcall *)(void *, int))ow_vt(ow_controller, 12 /* MoveFocus */))(ow_controller, 0);
    InterlockedExchange(&ow_ready, 1);
    return 0;
}

/* ---- extra windows: what window.open becomes ----
 * A page that opens a window (a room popped out, a second view of the same
 * app) gets a real window of ours, not WebView2's default popup with its
 * browser frame and no focus. Each extra is a plain hwnd-hosted webview on
 * its own top-level window - no visual hosting, no ghost mode, the frame the
 * OS gives it - living on the same thread and environment as the main
 * window. The main window still owns the process: when it closes, the app
 * ends and the extras go with it. Fixed slots, eight is plenty for rooms.
 * ICoreWebView2: 44 add_NewWindowRequested. NewWindowRequestedEventArgs:
 * 3 get_Uri, 6 put_Handled. */
#define OW_EXTRA_MAX 8
typedef struct { ow_handler h; int slot; } ow_xhandler;
typedef struct {
    HWND hwnd;
    void *controller, *webview;
    wchar_t url[2048];
    ow_xhandler on_env, on_controller, on_title, on_newwin;
    int used;
} ow_extra;
static ow_extra ow_x[OW_EXTRA_MAX];
static void *ow_env;                    /* kept from env_done (unused by the extras now) */
static HRESULT (__stdcall *ow_create_env)(const wchar_t *, const wchar_t *, void *, void *);
static wchar_t ow_data_dir[1024];
static ow_xhandler ow_main_newwin;
static void ow_xwindow_open(const wchar_t *url);
static void ow_xwindow_open_at(const wchar_t *url, int x, int y);

static void *ow_x_front(void) {
    static HWND (__stdcall *get_front)(void);
    HWND f;
    int i;
    if (!get_front) {
        HMODULE u = LoadLibraryA("user32.dll");
        if (u) get_front = (HWND (__stdcall *)(void))(void *)GetProcAddress(u, "GetForegroundWindow");
        if (!get_front) return NULL;
    }
    f = get_front();
    for (i = 0; i < OW_EXTRA_MAX; i++) if (ow_x[i].used && ow_x[i].hwnd && ow_x[i].hwnd == f) return f;
    return NULL;
}
static ow_extra *ow_x_of(HWND h) {
    int i;
    for (i = 0; i < OW_EXTRA_MAX; i++) if (ow_x[i].used && ow_x[i].hwnd == h) return &ow_x[i];
    return NULL;
}
#define OW_X_RIM 4   /* px of our own dark frame around the webview: the resize handle */
static void ow_x_fit(ow_extra *x) {
    RECT c;
    if (!x->controller || !x->hwnd) return;
    owu_GetClientRect(x->hwnd, &c);
    c.left += OW_X_RIM; c.top += OW_X_RIM; c.right -= OW_X_RIM; c.bottom -= OW_X_RIM;
    ((ow_bounds_fn)ow_vt(x->controller, 6 /* put_Bounds */))(x->controller, c);
}
static HRESULT __stdcall ow_x_title_changed(ow_handler *self, void *sender, void *args) {
    ow_extra *x = &ow_x[((ow_xhandler *)self)->slot];
    wchar_t *title = NULL;
    (void)args;
    if (((ow_fn2)ow_vt(sender, 48 /* get_DocumentTitle */))(sender, (void *)&title) == 0 && title) {
        if (x->hwnd) owu_SetWindowTextW(x->hwnd, title);
        owu_CoTaskMemFree(title);
    }
    return 0;
}
/* Any window of ours may open another: take the request, open our kind.
 * Not here, though - a controller asked for INSIDE the event handler fails
 * with ERROR_INVALID_STATE (the browser is mid-event). The url is posted to
 * the main window and the opening happens on the next message. */
#define OW_MSG_XOPEN (0x8000 + 44)     /* WM_APP + 44, lparam = malloc'd wide url */
static HRESULT __stdcall ow_new_window(ow_handler *self, void *sender, void *args) {
    wchar_t *uri = NULL;
    (void)self; (void)sender;
    if (((ow_fn2)ow_vt(args, 3 /* get_Uri */))(args, (void *)&uri) == 0 && uri) {
        wchar_t *copy = _wcsdup(uri);
        ((ow_flag_fn)ow_vt(args, 6 /* put_Handled */))(args, 1);
        if (copy && ow_hwnd && wt_PostMessageW) wt_PostMessageW(ow_hwnd, OW_MSG_XOPEN, 0, (LPARAM)copy);
        else free(copy);
        owu_CoTaskMemFree(uri);
    }
    return 0;
}
static void ow_xwindow_watch(void *webview) {
    long long token[2] = {0, 0};
    ow_main_newwin.h.vtbl = ow_handler_vtbl;
    ow_main_newwin.h.invoke = ow_new_window;
    ((ow_fn3)ow_vt(webview, 44 /* add_NewWindowRequested */))(webview, &ow_main_newwin, token);
}
static HRESULT __stdcall ow_x_env_done(ow_handler *self, void *hr, void *env) {
    ow_extra *x = &ow_x[((ow_xhandler *)self)->slot];
    ow_log("extra env_done hr", (long long)(intptr_t)hr);
    if ((int)(intptr_t)hr != 0 || !env || !x->hwnd) return 0;
    ow_log("extra controller create hr", (long long)((ow_fn3)ow_vt(env, 3 /* CreateCoreWebView2Controller */))(env, x->hwnd, &x->on_controller));
    return 0;
}
/* ---- dragging a room between windows ----
 * The page cannot see the pointer once it leaves its window, and two of our
 * windows cannot see each other at all - so the runtime follows the mouse:
 * a timer on the main window's thread reads the cursor and the button, finds
 * which of OUR windows is under it, and posts to that page where the pointer
 * is (chrome.webview message, JSON). On release: over one of ours -> that
 * page gets "drop" (with the payload the page that started the drag gave),
 * the starting page gets "done"; over nothing -> a new window opens at the
 * pointer on the payload's url, and the starting page gets "done" too.
 * ICoreWebView2: 33 PostWebMessageAsString. */
#define OW_DRAG_TIMER 7
#define OW_MSG_DRAGROOM (0x8000 + 45)  /* WM_APP + 45: start the timer on the window thread */
static struct { volatile int on; char payload[4096]; wchar_t url[2048]; HWND src, over; int whole; } ow_drag;
static HWND (__stdcall *owu_WindowFromPoint)(POINT);
static HWND (__stdcall *owu_GetAncestor)(HWND, UINT);
static short (__stdcall *owu_GetAsyncKeyState)(int);
static void *ow_webview_of(HWND h) {
    int i;
    if (h && h == ow_hwnd) return ow_webview;
    for (i = 0; i < OW_EXTRA_MAX; i++) if (ow_x[i].used && ow_x[i].hwnd == h) return ow_x[i].webview;
    return NULL;
}
static void ow_post(HWND h, const char *json) {
    void *wv = ow_webview_of(h);
    static wchar_t buf[8192];
    if (!wv) return;
    MultiByteToWideChar(CP_UTF8, 0, json, -1, buf, 8192);
    ((ow_fn2)ow_vt(wv, 33 /* PostWebMessageAsString */))(wv, buf);
}
static void ow_drag_tick(void) {
    POINT pt, c;
    HWND h, root = NULL;
    int down;
    char msg[5000];
    if (!ow_drag.on || !owu_GetCursorPos) return;
    owu_GetCursorPos(&pt);
    down = owu_GetAsyncKeyState ? (owu_GetAsyncKeyState(1 /* VK_LBUTTON */) & 0x8000) : 0;
    h = owu_WindowFromPoint ? owu_WindowFromPoint(pt) : NULL;
    if (h && owu_GetAncestor) h = owu_GetAncestor(h, 2 /* GA_ROOT */);
    if (ow_webview_of(h)) root = h;
    if (ow_drag.over && ow_drag.over != root) ow_post(ow_drag.over, "{\"dots\":\"roomdrag\",\"phase\":\"leave\"}");
    ow_drag.over = root;
    c = pt;
    if (root) {
        owu_ScreenToClient(root, &c);
        if (root != ow_hwnd) { c.x -= OW_X_RIM; c.y -= OW_X_RIM; }
    }
    if (down) {
        if (root) { snprintf(msg, sizeof msg, "{\"dots\":\"roomdrag\",\"phase\":\"move\",\"x\":%ld,\"y\":%ld}", (long)c.x, (long)c.y); ow_post(root, msg); }
        return;
    }
    /* released */
    ow_drag.on = 0;
    owu_KillTimer(ow_hwnd, OW_DRAG_TIMER);
    if (root) {
        snprintf(msg, sizeof msg, "{\"dots\":\"roomdrag\",\"phase\":\"drop\",\"x\":%ld,\"y\":%ld,\"payload\":%s}", (long)c.x, (long)c.y, ow_drag.payload);
        ow_post(root, msg);
    } else {
        ow_xwindow_open_at(ow_drag.url, pt.x - 120, pt.y - 16);
    }
    snprintf(msg, sizeof msg, "{\"dots\":\"roomdrag\",\"phase\":\"done\",\"target\":\"%s\",\"payload\":%s}", root ? "window" : "new", ow_drag.payload);
    ow_post(ow_drag.src, msg);
    /* a whole popped-out window dragged away: its old window goes */
    if (ow_drag.whole && ow_drag.src && ow_drag.src != ow_hwnd && owu_DestroyWindow) owu_DestroyWindow(ow_drag.src);
}
/* From the server thread (the page asked): remember what is dragged and
 * from where, then let the window thread start the timer. payload = the
 * page's JSON {url, title, room, whole}; url is read out of it for the
 * tear-off case. */
long long win_drag_room(const char *needle, const char *payload, const char *url, long long whole) {
    HWND src = (HWND)win_target(needle);
    if (!src || !ow_hwnd) return -1;
    if (!owu_WindowFromPoint) {
        HMODULE u = LoadLibraryA("user32.dll");
        if (u) {
            owu_WindowFromPoint = (HWND (__stdcall *)(POINT))(void *)GetProcAddress(u, "WindowFromPoint");
            owu_GetAncestor = (HWND (__stdcall *)(HWND, UINT))(void *)GetProcAddress(u, "GetAncestor");
            owu_GetAsyncKeyState = (short (__stdcall *)(int))(void *)GetProcAddress(u, "GetAsyncKeyState");
        }
    }
    strncpy(ow_drag.payload, payload, sizeof ow_drag.payload - 1);
    MultiByteToWideChar(CP_UTF8, 0, url, -1, ow_drag.url, 2048);
    ow_drag.src = src;
    ow_drag.over = NULL;
    ow_drag.whole = (int)whole;
    ow_drag.on = 1;
    if (wt_PostMessageW) wt_PostMessageW(ow_hwnd, OW_MSG_DRAGROOM, 0, 0);
    return 0;
}
static HRESULT __stdcall ow_x_controller_done(ow_handler *self, void *hr, void *controller) {
    ow_extra *x = &ow_x[((ow_xhandler *)self)->slot];
    long long token[2] = {0, 0};
    ow_log("extra controller hr", (long long)(intptr_t)hr);
    if ((int)(intptr_t)hr != 0 || !controller || !x->hwnd) return 0;
    ((ow_fn1)ow_vt(controller, 1 /* AddRef */))(controller);
    x->controller = controller;
    ((ow_fn2)ow_vt(controller, 25 /* get_CoreWebView2 */))(controller, (void *)&x->webview);
    if (!x->webview) return 0;
    ((ow_fn1)ow_vt(x->webview, 1 /* AddRef */))(x->webview);
    ow_x_fit(x);
    x->on_title.h.vtbl = ow_handler_vtbl;
    x->on_title.h.invoke = ow_x_title_changed;
    ((ow_fn3)ow_vt(x->webview, 46 /* add_DocumentTitleChanged */))(x->webview, &x->on_title, token);
    x->on_newwin.h.vtbl = ow_handler_vtbl;
    x->on_newwin.h.invoke = ow_new_window;
    ((ow_fn3)ow_vt(x->webview, 44 /* add_NewWindowRequested */))(x->webview, &x->on_newwin, token);
    ((ow_fn2)ow_vt(x->webview, 5 /* Navigate */))(x->webview, x->url);
    ((HRESULT (__stdcall *)(void *, int))ow_vt(controller, 12 /* MoveFocus */))(controller, 0);
    return 0;
}
static LRESULT __stdcall ow_x_wndproc(HWND h, UINT m, WPARAM wp, LPARAM lp) {
    ow_extra *x = ow_x_of(h);
    switch (m) {
    case WM_SIZE:
        if (x) ow_x_fit(x);
        return 0;
    case WM_SETFOCUS:
        if (x && x->controller)
            ((HRESULT (__stdcall *)(void *, int))ow_vt(x->controller, 12 /* MoveFocus */))(x->controller, 0);
        return 0;
    case WM_NCCALCSIZE:
        /* no OS frame at all (it paints a light line no attribute removes):
           the client is the whole window, our rim below is the frame */
        if (wp) return 0;
        break;
    case WM_NCHITTEST: {
        /* the rim resizes; the page's bar drags (through /api/window) */
        POINT pt; RECT c;
        int l, r, t, b;
        pt.x = (int)(short)(lp & 0xFFFF); pt.y = (int)(short)((lp >> 16) & 0xFFFF);
        owu_ScreenToClient(h, &pt);
        owu_GetClientRect(h, &c);
        l = pt.x < OW_X_RIM; r = pt.x >= c.right - OW_X_RIM; t = pt.y < OW_X_RIM; b = pt.y >= c.bottom - OW_X_RIM;
        if (t && l) return 13; if (t && r) return 14; if (b && l) return 16; if (b && r) return 17;
        if (l) return 10; if (r) return 11; if (t) return 12; if (b) return 15;
        return 1 /* HTCLIENT */;
    }
    case WM_NCLBUTTONDOWN:
        /* a press on the rim starts the OS size loop in that direction
           (SC_SIZE + WMSZ_*: the hit codes 10..17 map straight onto 1..8) */
        if (wp >= 10 && wp <= 17) { owu_DefWindowProcW(h, 0x0112 /* WM_SYSCOMMAND */, 0xF000 + (wp - 9), lp); return 0; }
        break;
    case WM_GETMINMAXINFO: {
        MONITORINFO mi;
        HMONITOR mon = owu_MonitorFromWindow(h, 2 /* MONITOR_DEFAULTTONEAREST */);
        mi.cbSize = sizeof mi;
        if (mon && owu_GetMonitorInfoW(mon, &mi)) {
            MINMAXINFO *mm = (MINMAXINFO *)lp;
            mm->ptMaxPosition.x = mi.rcWork.left - mi.rcMonitor.left;
            mm->ptMaxPosition.y = mi.rcWork.top - mi.rcMonitor.top;
            mm->ptMaxSize.x = mi.rcWork.right - mi.rcWork.left;
            mm->ptMaxSize.y = mi.rcWork.bottom - mi.rcWork.top;
            mm->ptMinTrackSize.x = 320;
            mm->ptMinTrackSize.y = 200;
            return 0;
        }
        break;
    }
    case WM_DESTROY:
        if (x) {
            if (x->controller) ((ow_fn1)ow_vt(x->controller, 24 /* Close */))(x->controller);
            x->controller = NULL; x->webview = NULL; x->hwnd = NULL; x->used = 0;
        }
        return 0;
    }
    return owu_DefWindowProcW(h, m, wp, lp);
}
/* On the window thread (the event handlers run there): a free slot, a
 * window a little smaller than the main one, offset so it does not hide it,
 * shown and brought forward, then a controller asked for on it. */
static void ow_xwindow_open(const wchar_t *url) { ow_xwindow_open_at(url, -1, -1); }
static void ow_xwindow_open_at(const wchar_t *url, int px, int py) {
    static int registered;
    int i, w, h, x0, y0;
    ow_extra *x = NULL;
    ow_xhandler *oc;
    for (i = 0; i < OW_EXTRA_MAX; i++) if (!ow_x[i].used) { x = &ow_x[i]; break; }
    if (!x || !ow_create_env) { ow_log("extra window: no slot or env", -1); return; }
    if (!registered) {
        WNDCLASSW wc;
        memset(&wc, 0, sizeof wc);
        wc.lpfnWndProc = (WNDPROC)ow_x_wndproc;
        wc.hInstance = GetModuleHandleW(NULL);
        wc.hCursor = owu_LoadCursorW(NULL, (const wchar_t *)(uintptr_t)32512 /* IDC_ARROW */);
        wc.hIcon = owu_LoadIconA(GetModuleHandleA(NULL), (const char *)(uintptr_t)1);
        if (!wc.hIcon) wc.hIcon = owu_LoadIconW(NULL, (const wchar_t *)(uintptr_t)32512);
        wc.lpszClassName = L"OrionExtraWindow";
        {   /* the rim's colour: the paper's dark tone, painted by the class */
            HMODULE g = LoadLibraryA("gdi32.dll");
            HBRUSH (__stdcall *brush)(DWORD) = g ? (HBRUSH (__stdcall *)(DWORD))(void *)GetProcAddress(g, "CreateSolidBrush") : NULL;
            if (brush) wc.hbrBackground = brush(0x00161616);   /* dots body in the dark theme - the rim vanishes into it */
        }
        owu_RegisterClassW(&wc);
        registered = 1;
    }
    memset(x, 0, sizeof *x);
    x->used = 1;
    wcsncpy(x->url, url, 2047);
    w = ow_w > 200 ? ow_w - 120 : 1000;
    h = ow_h > 200 ? ow_h - 80 : 740;
    /* stepped down-right of the screen's centre so the extras stack visibly */
    x0 = (owu_GetSystemMetrics(0) - w) / 2 + 40 + (int)(x - ow_x) * 24;
    y0 = (owu_GetSystemMetrics(1) - h) / 2 + 40 + (int)(x - ow_x) * 24;
    if (px >= 0) { x0 = px; y0 = py; }   /* a torn-off room lands under the pointer */
    if (x0 < 0) x0 = 0;
    if (y0 < 0) y0 = 0;
    /* no WS_THICKFRAME: that is what makes Windows paint a frame line no
       matter what - resizing is ours, through the rim (see NCLBUTTONDOWN) */
    x->hwnd = owu_CreateWindowExW(0, L"OrionExtraWindow", ow_title, WS_POPUP | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_CLIPCHILDREN,
                                  x0, y0, w, h, NULL, NULL, GetModuleHandleW(NULL), NULL);
    if (!x->hwnd) { x->used = 0; return; }
    if (owu_SetWindowPos)   /* re-run the frame calc the TRUE way, as for the main window */
        owu_SetWindowPos(x->hwnd, NULL, 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0004 | 0x0020);
    {   /* the thin DWM border: dark, so the frame does not read as a white line */
        HMODULE dwm = LoadLibraryA("dwmapi.dll");
        HRESULT (__stdcall *set_attr)(HWND, DWORD, const void *, DWORD) = dwm
            ? (HRESULT (__stdcall *)(HWND, DWORD, const void *, DWORD))(void *)GetProcAddress(dwm, "DwmSetWindowAttribute") : NULL;
        if (set_attr) {
            DWORD border = 0xFFFFFFFE;   /* DWMWA_COLOR_NONE: no border line at all */
            DWORD dark = 1;
            set_attr(x->hwnd, 34 /* DWMWA_BORDER_COLOR */, &border, sizeof border);
            set_attr(x->hwnd, 20 /* DWMWA_USE_IMMERSIVE_DARK_MODE */, &dark, sizeof dark);
        }
    }
    owu_ShowWindow(x->hwnd, 1 /* SW_SHOWNORMAL */);
    if (owu_SetForegroundWindow) owu_SetForegroundWindow(x->hwnd);
    oc = &x->on_controller;
    oc->h.vtbl = ow_handler_vtbl;
    oc->h.invoke = ow_x_controller_done;
    oc->slot = (int)(x - ow_x);
    x->on_title.slot = oc->slot;
    x->on_newwin.slot = oc->slot;
    /* its own environment, made the way the main window's was: the shared
       one answers ERROR_INVALID_STATE to a second controller */
    x->on_env.h.vtbl = ow_handler_vtbl;
    x->on_env.h.invoke = ow_x_env_done;
    x->on_env.slot = oc->slot;
    /* a browser process hosts ONE kind of webview: the main window is
       visual-hosted, so an hwnd-hosted extra in the same process answers
       ERROR_INVALID_STATE. A profile of its own gives the extras their own
       browser process (same server, same files; only web storage differs). */
    {
        static wchar_t xdir[1100];
        _snwprintf(xdir, 1100, L"%s-extra", ow_data_dir);
        ow_log("extra env hr", (long long)ow_create_env(NULL, ow_data_dir[0] ? xdir : NULL, NULL, &x->on_env));
    }
}
/* environment arrived: ask it for a controller on our window - the visual
 * kind when DComp is up and the runtime speaks Environment3, else the
 * child-window kind (no ghost mode there, everything else identical). */
static HRESULT __stdcall ow_env_done(ow_handler *self, void *hr, void *env) {
    void *env3 = NULL;
    (void)self;
    ow_log("env_done hr", (long long)(intptr_t)hr);
    if ((int)(intptr_t)hr != 0 || !env) { InterlockedExchange(&ow_ready, -1); return 0; }
    ((ow_fn1)ow_vt(env, 1 /* AddRef */))(env);
    ow_env = env;                       /* the extras are made from it later */
    ow_on_controller.vtbl = ow_handler_vtbl;
    ow_on_controller.invoke = ow_controller_done;
    if (ow_dcvisual && ow_qi(env, &OW_IID_ENV3, &env3) == 0 && env3) {
        ow_visual = 1;
        ow_log("hosting visual", 1);
        ((ow_fn3)ow_vt(env3, 9 /* CreateCoreWebView2CompositionController */))(env3, ow_hwnd, &ow_on_controller);
    } else {
        ow_log("hosting hwnd", 0);
        ((ow_fn3)ow_vt(env, 3 /* CreateCoreWebView2Controller */))(env, ow_hwnd, &ow_on_controller);
    }
    return 0;
}
/* Mouse, forwarded: visual hosting has no input child window - every event
 * the window gets is ours to hand the webview, message id and all (the
 * event-kind values ARE the WM_ numbers). Wheels arrive in screen coords. */
static int ow_track;
static void ow_send_mouse(HWND h, UINT m, WPARAM wp, LPARAM lp) {
    POINT pt;
    UINT vk = (UINT)(wp & 0xFFFF), mdata = 0;
    if (!ow_comp) return;
    pt.x = (int)(short)(lp & 0xFFFF);
    pt.y = (int)(short)((lp >> 16) & 0xFFFF);
    if (m == 0x020A /* WHEEL */ || m == 0x020E /* HWHEEL */) {
        mdata = (UINT)(int)(short)((wp >> 16) & 0xFFFF);
        if (owu_ScreenToClient) owu_ScreenToClient(h, &pt);
    }
    if (m == 0x020B || m == 0x020C || m == 0x020D)   /* xbutton down/up/dbl */
        mdata = (UINT)((wp >> 16) & 0xFFFF);
    if (m == 0x02A3 /* LEAVE */) { pt.x = 0; pt.y = 0; vk = 0; }
    ((HRESULT (__stdcall *)(void *, UINT, UINT, UINT, POINT))ow_vt(ow_comp, 5 /* SendMouseInput */))(ow_comp, m, vk, mdata, pt);
}

static LRESULT __stdcall ow_wndproc(HWND h, UINT m, WPARAM wp, LPARAM lp) {
    /* visual hosting: the mouse is ours to forward, buttons capture so a
       drag that leaves the window keeps reporting, and a leave is tracked
       so hover states let go */
    if (ow_visual && ((m >= 0x0200 && m <= 0x020E) || m == 0x02A3 /* MOUSELEAVE */)) {
        if (m == 0x0200 && !ow_track && owu_TrackMouseEvent) {
            TRACKMOUSEEVENT t;
            t.cbSize = sizeof t; t.dwFlags = 2 /* TME_LEAVE */; t.hwndTrack = h; t.dwHoverTime = 0;
            owu_TrackMouseEvent(&t);
            ow_track = 1;
        }
        if (m == 0x02A3) ow_track = 0;
        if ((m == 0x0201 || m == 0x0204 || m == 0x0207 || m == 0x020B) && owu_SetCapture) owu_SetCapture(h);
        if ((m == 0x0202 || m == 0x0205 || m == 0x0208 || m == 0x020C) && owu_ReleaseCapture) owu_ReleaseCapture();
        ow_send_mouse(h, m, wp, lp);
        return 0;
    }
    switch (m) {
    case WM_ERASEBKGND:
        return 1;
    case WM_SETCURSOR:
        /* no child window means no one else sets the pointer - ask the
           webview what it wants the cursor to be */
        if (ow_visual && ow_comp && (lp & 0xFFFF) == 1 /* HTCLIENT */ && owu_SetCursor) {
            void *cur = NULL;
            if (((ow_fn2)ow_vt(ow_comp, 7 /* get_Cursor */))(ow_comp, (void *)&cur) == 0 && cur) {
                owu_SetCursor((HCURSOR)cur);
                return 1;
            }
        }
        break;
    case WM_SETFOCUS:
        if (ow_controller)
            ((HRESULT (__stdcall *)(void *, int))ow_vt(ow_controller, 12 /* MoveFocus */))(ow_controller, 0);
        return 0;
    case WM_TIMER:
        if (wp == OW_GHOST_TIMER) { ow_ghost_tick(h); return 0; }
        if (wp == OW_DRAG_TIMER) { ow_drag_tick(); return 0; }
        break;
    case OW_MSG_GHOST: {
        char *csv = (char *)lp;
        if (csv) { ow_ghost_apply(h, csv); free(csv); }
        return 0;
    }
    case WM_NCCALCSIZE:
        /* keep the resize borders, remove only the caption: run the default
           calc, then give the top edge back to the client area */
        if (wp) {
            NCCALCSIZE_PARAMS *p = (NCCALCSIZE_PARAMS *)lp;
            int top = p->rgrc[0].top;
            owu_DefWindowProcW(h, m, wp, lp);
            p->rgrc[0].top = top;
            return 0;
        }
        break;
    case WM_GETMINMAXINFO: {
        /* a maximised borderless window must stop at the work area, not
           hang its (removed) frame past the screen edges */
        MONITORINFO mi;
        HMONITOR mon = owu_MonitorFromWindow(h, 2 /* MONITOR_DEFAULTTONEAREST */);
        mi.cbSize = sizeof mi;
        if (mon && owu_GetMonitorInfoW(mon, &mi)) {
            MINMAXINFO *mm = (MINMAXINFO *)lp;
            mm->ptMaxPosition.x = mi.rcWork.left - mi.rcMonitor.left;
            mm->ptMaxPosition.y = mi.rcWork.top - mi.rcMonitor.top;
            mm->ptMaxSize.x = mi.rcWork.right - mi.rcWork.left;
            mm->ptMaxSize.y = mi.rcWork.bottom - mi.rcWork.top;
            return 0;
        }
        break;
    }
    case WM_SIZE:
        ow_fit_webview();
        return 0;
    case WM_MOVE:
        if (ow_controller)
            ((ow_fn1)ow_vt(ow_controller, 23 /* NotifyParentWindowPositionChanged */))(ow_controller);
        return 0;
    case OW_MSG_DRAGROOM:
        if (owu_SetTimer) owu_SetTimer(h, OW_DRAG_TIMER, 16, NULL);
        return 0;
    case OW_MSG_XOPEN: {
        wchar_t *url = (wchar_t *)lp;
        if (url) { ow_xwindow_open(url); free(url); }
        return 0;
    }
    case OW_MSG_THROUGH:
        if (owu_RegisterHotKey && owu_UnregisterHotKey) {
            if (wp) ow_log("hotkey reg", owu_RegisterHotKey(h, 1, 0x0002 | 0x0001 /* MOD_CONTROL|MOD_ALT */, 'C'));
            else owu_UnregisterHotKey(h, 1);
        }
        return 0;
    case OW_MSG_HOTKEY:
        if (owu_RegisterHotKey) {
            int got;
            if (owu_UnregisterHotKey) owu_UnregisterHotKey(h, 2);
            /* MOD_NOREPEAT: held down is one summon, not a stream of them */
            got = owu_RegisterHotKey(h, 2, (UINT)wp | 0x4000, (UINT)lp);
            /* Whether the key is OURS is a fact the program has to be able to
               ask for. RegisterHotKey fails silently when somebody else holds
               the combination, and "nothing happened" is then indistinguishable
               from a bug anywhere else in the chain. */
            InterlockedExchange(&ow_hot_ok, got ? 1 : 0);
            ow_log("summon hotkey", got);
        }
        return 0;
    case WM_HOTKEY:
        /* ctrl+alt+c from anywhere: solid again - whichever mode was on.
           The page polls the window's state and follows suit. */
        if (wp == 2) {
            InterlockedExchange(&ow_hot_hit, 1);
            if (owu_ShowWindow) owu_ShowWindow(h, 5 /* SW_SHOW */);
            /* the same z-order assertion win_command's "show" makes: the key
               is the other way in, and both ways have to land on top */
            if (owu_SetWindowPos)
                owu_SetWindowPos(h, (HWND)(intptr_t)-1 /* HWND_TOPMOST */, 0, 0, 0, 0,
                                 0x0001 | 0x0002 /* SWP_NOSIZE|SWP_NOMOVE */);
            /* visible BEFORE foreground: handing focus to a webview that is
               still marked invisible does nothing, and then the page has the
               window but not the keyboard */
            ow_set_visible(h, 1);
            ow_take_foreground(h);
            return 0;
        }
        if (wp == 1) {
            if (ow_ghost_on) {
                ow_ghost_apply(h, "");
            } else if (wt_GetWindowLongPtr && wt_SetWindowLongPtr) {
                wt_SetWindowLongPtr(h, -20, wt_GetWindowLongPtr(h, -20) & ~(LONG_PTR)0x00000020);
                if (owu_UnregisterHotKey) owu_UnregisterHotKey(h, 1);
            }
        }
        return 0;
    case WM_CLOSE:
        ow_place_save(h);   /* where it was - read back next start */
        owu_DestroyWindow(h);
        return 0;
    case WM_DESTROY:
        /* an ABANDONED attempt (timeout -> Edge fallback took over) must not
           read as "the window closed" - that would stop the serve loop under
           the fallback window the user is actually using */
        InterlockedExchange(&ow_state, ow_abandoned ? 0 : 2);
        owu_PostQuitMessage(0);
        return 0;
    }
    return owu_DefWindowProcW(h, m, wp, lp);
}

/* WebView2Loader.dll: beside the exe, on the search path, or where a
 * single-file setup exe unpacked it. */
static HMODULE ow_loader(void) {
    char path[4096];
    const char *me = exe_path();
    HMODULE lib = NULL;
    if (me[0]) {
        size_t n = strlen(me);
        while (n > 0 && me[n-1] != '\\' && me[n-1] != '/') n--;
        if (n + 20 < sizeof path) {
            memcpy(path, me, n);
            strcpy(path + n, "WebView2Loader.dll");
            lib = LoadLibraryA(path);
        }
    }
    if (!lib) lib = LoadLibraryA("WebView2Loader.dll");
    if (!lib) {
        const char *tmp = getenv("TEMP");
        if (tmp && strlen(tmp) + 40 < sizeof path) {
            snprintf(path, sizeof path, "%s\\orion-webview\\WebView2Loader.dll", tmp);
            lib = LoadLibraryA(path);
        }
    }
    return lib;
}

/* Where the window was last time: a WINDOWPLACEMENT per app title under
 * %LOCALAPPDATA%\orion-webview\<title>.place. Read before the first show,
 * written when the message loop ends. A placement is validated by the OS
 * (an off-screen rect snaps back), so a moved monitor is harmless. */
static void ow_place_path(char *out, size_t n) {
    const char *local = getenv("LOCALAPPDATA");
    char t[256];
    int i;
    WideCharToMultiByte(CP_UTF8, 0, ow_title, -1, t, sizeof t, NULL, NULL);
    for (i = 0; t[i]; i++) if (t[i] == '\\' || t[i] == '/' || t[i] == ':' || t[i] == ' ') t[i] = '_';
    snprintf(out, n, "%s\\orion-webview\\%s.place", local ? local : ".", t);
}
static void ow_place_load(HWND h) {
    static int (__stdcall *set_place)(HWND, const WINDOWPLACEMENT *);
    WINDOWPLACEMENT wp;
    char path[1024];
    FILE *f;
    if (!set_place) { HMODULE u = LoadLibraryA("user32.dll"); if (u) set_place = (int (__stdcall *)(HWND, const WINDOWPLACEMENT *))(void *)GetProcAddress(u, "SetWindowPlacement"); }
    if (!set_place) return;
    ow_place_path(path, sizeof path);
    f = fopen(path, "rb");
    if (!f) return;
    if (fread(&wp, sizeof wp, 1, f) == 1 && wp.length == sizeof wp) {
        if (wp.showCmd == 2 /* SW_SHOWMINIMIZED */) wp.showCmd = 1;
        set_place(h, &wp);
    }
    fclose(f);
}
static void ow_place_save(HWND h) {
    static int (__stdcall *get_place)(HWND, WINDOWPLACEMENT *);
    WINDOWPLACEMENT wp;
    char path[1024];
    FILE *f;
    if (!h) return;
    if (!get_place) { HMODULE u = LoadLibraryA("user32.dll"); if (u) get_place = (int (__stdcall *)(HWND, WINDOWPLACEMENT *))(void *)GetProcAddress(u, "GetWindowPlacement"); }
    if (!get_place) return;
    wp.length = sizeof wp;
    if (!get_place(h, &wp)) return;
    ow_place_path(path, sizeof path);
    f = fopen(path, "wb");
    if (!f) return;
    fwrite(&wp, sizeof wp, 1, f);
    fclose(f);
}
static DWORD __stdcall ow_thread(LPVOID unused) {
    WNDCLASSW wc;
    MSG msg;
    HRESULT (__stdcall *create_env)(const wchar_t *, const wchar_t *, void *, void *);
    HMODULE lib = ow_loader();
    wchar_t data_dir[1024];
    const char *local;
    int sw, sh, x, y;
    (void)unused;
    if (!lib || !ow_load_user()) { InterlockedExchange(&ow_ready, -1); return 0; }
    create_env = (HRESULT (__stdcall *)(const wchar_t *, const wchar_t *, void *, void *))
        (void *)GetProcAddress(lib, "CreateCoreWebView2EnvironmentWithOptions");
    if (!create_env) { InterlockedExchange(&ow_ready, -1); return 0; }
    owu_CoInitializeEx(NULL, 0x2 /* APARTMENTTHREADED */);
    memset(&wc, 0, sizeof wc);
    wc.lpfnWndProc = (WNDPROC)ow_wndproc;
    wc.hInstance = GetModuleHandleW(NULL);
    wc.hCursor = owu_LoadCursorW(NULL, (const wchar_t *)(uintptr_t)32512 /* IDC_ARROW */);
    wc.hIcon = owu_LoadIconA(GetModuleHandleA(NULL), (const char *)(uintptr_t)1); /* orbit's icon.rc */
    if (!wc.hIcon) wc.hIcon = owu_LoadIconW(NULL, (const wchar_t *)(uintptr_t)32512 /* IDI_APPLICATION */);
    wc.lpszClassName = L"OrionOwnWindow";
    owu_RegisterClassW(&wc);
    sw = owu_GetSystemMetrics(0 /* SM_CXSCREEN */);
    sh = owu_GetSystemMetrics(1 /* SM_CYSCREEN */);
    x = (sw - ow_w) / 2; if (x < 0) x = 0;
    y = (sh - ow_h) / 2; if (y < 0) y = 0;
    /* NOREDIRECTIONBITMAP: the window has no surface of its own - what the
       DComp visual shows is ALL there is, so unpainted pixels are holes.
       (Harmless under hwnd hosting: the child carries its own surface.) */
    ow_hwnd = owu_CreateWindowExW(0x00200000 /* WS_EX_NOREDIRECTIONBITMAP */,
                                  L"OrionOwnWindow", ow_title, WS_OVERLAPPEDWINDOW,
                                  x, y, ow_w, ow_h, NULL, NULL, wc.hInstance, NULL);
    if (!ow_hwnd) { InterlockedExchange(&ow_ready, -1); return 0; }
    ow_log("dcomp", (long long)ow_dcomp_init(ow_hwnd));
    /* creation-time WM_NCCALCSIZE comes with wparam FALSE, which our caption
       removal does not touch - ask for the frame calc again now that the
       window exists, this time the TRUE way */
    if (owu_SetWindowPos)
        owu_SetWindowPos(ow_hwnd, NULL, 0, 0, 0, 0,
                         0x0001 | 0x0002 | 0x0004 | 0x0020 /* NOSIZE|NOMOVE|NOZORDER|FRAMECHANGED */);
    ow_place_load(ow_hwnd);
    owu_ShowWindow(ow_hwnd, 1 /* SW_SHOWNORMAL */);
    /* the profile lives per user, shared by every orion app window */
    local = getenv("LOCALAPPDATA");
    data_dir[0] = 0;
    if (local) {
        wchar_t wl[900];
        MultiByteToWideChar(CP_UTF8, 0, local, -1, wl, 900);
        _snwprintf(data_dir, 1024, L"%s\\orion-webview", wl);
    }
    ow_on_env.vtbl = ow_handler_vtbl;
    ow_on_env.invoke = ow_env_done;
    ow_create_env = create_env;
    wcsncpy(ow_data_dir, data_dir, 1023);
    {
        HRESULT ce = create_env(NULL, data_dir[0] ? data_dir : NULL, NULL, &ow_on_env);
        ow_log("create_env hr", (long long)ce);
        if (ce != 0) {
            owu_DestroyWindow(ow_hwnd);
            InterlockedExchange(&ow_ready, -1);
            return 0;
        }
    }
    InterlockedExchange(&ow_state, 1);
    while (owu_GetMessageW(&msg, NULL, 0, 0) > 0) {
        owu_TranslateMessage(&msg);
        owu_DispatchMessageW(&msg);
    }
    if (ow_controller) ((ow_fn1)ow_vt(ow_controller, 24 /* Close */))(ow_controller);
    {
        int i;
        for (i = 0; i < OW_EXTRA_MAX; i++)
            if (ow_x[i].used && ow_x[i].hwnd) owu_DestroyWindow(ow_x[i].hwnd);
    }
    return 0;
}

/* Open our own webview window at url. 0 when it is up (webview navigating),
 * -1 when the pieces are missing - the caller falls back to open_window. */
long long own_window_open(const char *url, const char *title, long long w, long long h) {
    HANDLE t;
    int waited = 0;
    if (ow_state == 1) return -1;              /* one per process */
    MultiByteToWideChar(CP_UTF8, 0, url, -1, ow_url, 2048);
    MultiByteToWideChar(CP_UTF8, 0, title, -1, ow_title, 256);
    ow_w = (int)w; ow_h = (int)h;
    InterlockedExchange(&ow_ready, 0);
    t = CreateThread(NULL, 0, ow_thread, NULL, 0, NULL);
    if (!t) return -1;
    CloseHandle(t);
    while (ow_ready == 0 && waited < 10000) { Sleep(20); waited += 20; }
    if (ow_ready == 1) return 0;
    /* Give up COMPLETELY: kill the half-born window so the Edge fallback is
     * the only window there is. Before this, a timeout left the own-window
     * thread alive - its webview could finish minutes later and the user got
     * TWO windows, one of them transparent until (unless) the webview came. */
    InterlockedExchange(&ow_abandoned, 1);
    if (ow_hwnd) {
        HMODULE u = LoadLibraryA("user32.dll");
        LRESULT (__stdcall *post)(void *, unsigned int, WPARAM, LPARAM) = u
            ? (LRESULT (__stdcall *)(void *, unsigned int, WPARAM, LPARAM))(void *)GetProcAddress(u, "PostMessageW")
            : NULL;
        if (post) post(ow_hwnd, 0x0010 /* WM_CLOSE */, 0, 0);
        ow_hwnd = NULL;
    }
    return -1;
}
/* 1 once an own window was opened and then closed - the serve loop's cue. */
long long own_window_gone(void) { return ow_state == 2 ? 1 : 0; }
#else
long long own_window_open(const char *url, const char *title, long long w, long long h) {
    (void)url; (void)title; (void)w; (void)h; return -1;
}
long long own_window_gone(void) { return 0; }
#endif

/* ---- setup payload: an installer exe carries its app in its own tail ----
 * A PE loader ignores whatever follows the image, so one file can be both a
 * program and its own cargo. Layout, reading from the END of the file:
 *
 *   [stub exe][app zip][manifest text][ui html]
 *   [zip_len u64][manifest_len u64][html_len u64]["ORBSETUP"]
 *
 * `orbit package` stitches with setup_stitch; the running setup.exe reads
 * itself back with setup_section (manifest/html) and setup_extract (the zip).
 * Lengths are little-endian, written a byte at a time - no struct games. */
#define SETUP_MAGIC "ORBSETUP"

static void setup_put_u64(FILE *f, unsigned long long v) {
    for (int i = 0; i < 8; i++) fputc((int)((v >> (8 * i)) & 0xff), f);
}
static unsigned long long setup_get_u64(const unsigned char *p) {
    unsigned long long v = 0;
    for (int i = 7; i >= 0; i--) v = (v << 8) | p[i];
    return v;
}
static long long setup_copy_into(FILE *out, const char *path) {
    FILE *in = fopen(path, "rb");
    char buf[65536];
    size_t n;
    long long total = 0;
    if (!in) return -1;
    while ((n = fread(buf, 1, sizeof buf, in)) > 0) {
        if (fwrite(buf, 1, n, out) != n) { fclose(in); return -1; }
        total += (long long)n;
    }
    fclose(in);
    return total;
}
/* Stitch stub + zip + manifest + ui html into `out`. 0 ok, -1 not. */
long long setup_stitch(const char *base, const char *zip, const char *manifest,
                       const char *html, const char *out) {
    FILE *f = fopen(out, "wb");
    long long zip_len, html_len, manifest_len = (long long)strlen(manifest);
    if (!f) return -1;
    if (setup_copy_into(f, base) < 0) { fclose(f); return -1; }
    zip_len = setup_copy_into(f, zip);
    if (zip_len < 0) { fclose(f); return -1; }
    if (manifest_len > 0 && fwrite(manifest, 1, (size_t)manifest_len, f) != (size_t)manifest_len) { fclose(f); return -1; }
    html_len = setup_copy_into(f, html);
    if (html_len < 0) { fclose(f); return -1; }
    setup_put_u64(f, (unsigned long long)zip_len);
    setup_put_u64(f, (unsigned long long)manifest_len);
    setup_put_u64(f, (unsigned long long)html_len);
    fwrite(SETUP_MAGIC, 1, 8, f);
    return fclose(f) == 0 ? 0 : -1;
}
/* Open this very exe and find the payload. Returns the file (positioned
 * nowhere in particular) or NULL; the three offsets/lengths come out through
 * the pointers. */
static FILE *setup_open_self(long long *zip_off, long long *zip_len,
                             long long *man_off, long long *man_len,
                             long long *html_off, long long *html_len) {
    unsigned char tail[32];
    const char *me = exe_path();
    FILE *f;
    long long end;
    if (!me[0]) return NULL;
    f = fopen(me, "rb");
    if (!f) return NULL;
    if (fseek(f, -32, SEEK_END) != 0 || fread(tail, 1, 32, f) != 32 ||
        memcmp(tail + 24, SETUP_MAGIC, 8) != 0) { fclose(f); return NULL; }
    end = ftell(f) - 32;
    *zip_len = (long long)setup_get_u64(tail);
    *man_len = (long long)setup_get_u64(tail + 8);
    *html_len = (long long)setup_get_u64(tail + 16);
    *html_off = end - *html_len;
    *man_off = *html_off - *man_len;
    *zip_off = *man_off - *zip_len;
    if (*zip_off < 0) { fclose(f); return NULL; }
    return f;
}
/* The manifest (which 0) or the ui page (which 1), "" when this exe carries
 * no payload - which is how the stub knows it was run bare. */
const char *setup_section(long long which) {
    long long zo, zl, mo, ml, ho, hl, off, len;
    FILE *f = setup_open_self(&zo, &zl, &mo, &ml, &ho, &hl);
    char *buf;
    const char *text;
    if (!f) return orion_text_from_c("");
    off = which == 0 ? mo : ho;
    len = which == 0 ? ml : hl;
    buf = (char *)malloc((size_t)len + 1);
    if (!buf || fseek(f, (long)off, SEEK_SET) != 0 ||
        fread(buf, 1, (size_t)len, f) != (size_t)len) {
        free(buf); fclose(f); return orion_text_from_c("");
    }
    buf[len] = 0;
    fclose(f);
    text = orion_text_from_c(buf);
    free(buf);
    return text;
}
/* Write the app zip to `dest`. 0 ok, -1 when there is no payload. */
long long setup_extract(const char *dest) {
    long long zo, zl, mo, ml, ho, hl, left;
    char buf[65536];
    FILE *f = setup_open_self(&zo, &zl, &mo, &ml, &ho, &hl);
    FILE *out;
    if (!f) return -1;
    out = fopen(dest, "wb");
    if (!out || fseek(f, (long)zo, SEEK_SET) != 0) { if (out) fclose(out); fclose(f); return -1; }
    left = zl;
    while (left > 0) {
        size_t want = left > (long long)sizeof buf ? sizeof buf : (size_t)left;
        if (fread(buf, 1, want, f) != want || fwrite(buf, 1, want, out) != want) {
            fclose(out); fclose(f); return -1;
        }
        left -= (long long)want;
    }
    fclose(f);
    return fclose(out) == 0 ? 0 : -1;
}

/* ---- the per-user registry, just enough for Apps & features ----
 * An installed app announces itself with a handful of values under
 * HKCU\...\Uninstall\<name> - that is the whole listing. Per-user only
 * (HKCU): no admin, no machine state, and uninstall is deleting the key.
 * advapi32 loads dynamically for the same reason user32 does above. */
#ifdef _WIN32
static long long (__stdcall *rg_CreateKey)(void *, const char *, unsigned long, char *, unsigned long, unsigned long, void *, void **, unsigned long *);
static long long (__stdcall *rg_SetValue)(void *, const char *, unsigned long, unsigned long, const unsigned char *, unsigned long);
static long long (__stdcall *rg_CloseKey)(void *);
static long long (__stdcall *rg_DeleteTree)(void *, const char *);
#define RG_HKCU ((void *)(uintptr_t)0x80000001)
static int rg_load(void) {
    HMODULE a;
    if (rg_CreateKey) return 1;
    a = LoadLibraryA("advapi32.dll");
    if (!a) return 0;
    rg_CreateKey = (long long (__stdcall *)(void *, const char *, unsigned long, char *, unsigned long, unsigned long, void *, void **, unsigned long *))(void *)GetProcAddress(a, "RegCreateKeyExA");
    rg_SetValue = (long long (__stdcall *)(void *, const char *, unsigned long, unsigned long, const unsigned char *, unsigned long))(void *)GetProcAddress(a, "RegSetValueExA");
    rg_CloseKey = (long long (__stdcall *)(void *))(void *)GetProcAddress(a, "RegCloseKey");
    rg_DeleteTree = (long long (__stdcall *)(void *, const char *))(void *)GetProcAddress(a, "RegDeleteTreeA");
    return rg_CreateKey && rg_SetValue && rg_CloseKey && rg_DeleteTree;
}
static void *rg_open(const char *subkey) {
    void *k = NULL;
    if (!rg_load()) return NULL;
    if (rg_CreateKey(RG_HKCU, subkey, 0, NULL, 0, 0x2 /* KEY_SET_VALUE */, NULL, &k, NULL) != 0) return NULL;
    return k;
}
/* (The process code page is UTF-8 - runtime/orion.manifest - so the A calls
 * store real UTF-8 names: "Skärmbild" survives.) */
long long reg_user_set_text(const char *subkey, const char *name, const char *value) {
    void *k = rg_open(subkey);
    long long rc;
    if (!k) return -1;
    rc = rg_SetValue(k, name, 0, 1 /* REG_SZ */, (const unsigned char *)value, (unsigned long)strlen(value) + 1);
    rg_CloseKey(k);
    return rc == 0 ? 0 : -1;
}
long long reg_user_set_number(const char *subkey, const char *name, long long v) {
    void *k = rg_open(subkey);
    unsigned long dw = (unsigned long)v;
    long long rc;
    if (!k) return -1;
    rc = rg_SetValue(k, name, 0, 4 /* REG_DWORD */, (const unsigned char *)&dw, 4);
    rg_CloseKey(k);
    return rc == 0 ? 0 : -1;
}
long long reg_user_delete(const char *subkey) {
    if (!rg_load()) return -1;
    return rg_DeleteTree(RG_HKCU, subkey) == 0 ? 0 : -1;
}
#else
long long reg_user_set_text(const char *subkey, const char *name, const char *value) { (void)subkey; (void)name; (void)value; return -1; }
long long reg_user_set_number(const char *subkey, const char *name, long long v) { (void)subkey; (void)name; (void)v; return -1; }
long long reg_user_delete(const char *subkey) { (void)subkey; return -1; }
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
