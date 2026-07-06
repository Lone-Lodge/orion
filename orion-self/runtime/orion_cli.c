/* orion_cli.c — CLI / OS primitives for self-hosted tools (orbit).
 *
 * The game runtime (orion_rt.c + win32_min.c ...) covers windows/gpu/
 * audio + orion_file_stamp. A command-line TOOL like orbit needs a
 * different surface: spawn processes, filesystem ops, exit. These are
 * that surface.
 *
 * Named to MATCH orbit's own function names (run_command, mkdir_all, ...)
 * and WITHOUT the orion_ prefix — the self-hosted compiler treats any
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
#include <stdlib.h>
#include <stdio.h>

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

/* Run a command and capture its stdout as one string (static buffer;
 * orion-self copies the returned bytes into a headered Text). */
const char *capture(const char *cmd) {
    static char cbuf[65536];
    cbuf[0] = 0;
    FILE *p = _popen(cmd, "r");
    if (!p) return cbuf;
    size_t total = 0, n;
    while (total < sizeof(cbuf) - 1 &&
           (n = fread(cbuf + total, 1, sizeof(cbuf) - 1 - total, p)) > 0)
        total += n;
    cbuf[total] = 0;
    _pclose(p);
    return cbuf;
}

#else /* POSIX */
#include <sys/stat.h>
#include <unistd.h>
#include <string.h>

long long sys_run(const char *cmd) { return (long long)system(cmd); }
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

const char *capture(const char *cmd) {
    static char cbuf[65536];
    cbuf[0] = 0;
    FILE *p = popen(cmd, "r");
    if (!p) return cbuf;
    size_t total = 0, n;
    while (total < sizeof(cbuf) - 1 &&
           (n = fread(cbuf + total, 1, sizeof(cbuf) - 1 - total, p)) > 0)
        total += n;
    cbuf[total] = 0;
    pclose(p);
    return cbuf;
}
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
