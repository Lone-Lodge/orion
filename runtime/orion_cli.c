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
