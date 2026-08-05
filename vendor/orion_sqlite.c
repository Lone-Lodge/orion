/* orion_sqlite.c - the bridge between the sqlite orb and sqlite3.c.
 *
 * A project that says `use sqlite` links BOTH files in its Orbit.toml:
 *
 *     link = "vendor/sqlite3.c vendor/orion_sqlite.c"
 *
 * (copy them from orion/vendor/, or point at them relatively; precompile
 * sqlite3.c to a .o once - clang -c -Os - and name the .o instead to keep
 * builds fast).
 *
 * Shape: db handles are small ints into a fixed table. Query results come
 * back as ONE text: rows joined by '\n', columns by the unit separator
 * 0x1f - the sqlite orb splits them back apart. Parameters bind as TEXT;
 * sqlite's column affinity converts to numbers where the schema says so.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sqlite3.h"

extern const char *orion_text_from_c(const char *s);
long long orion_tlen_c(const char *p);

#define SQ_MAX 32
static sqlite3 *sq_dbs[SQ_MAX];
static char sq_err[SQ_MAX][512];

static void sq_set_err(long long h, const char *msg) {
    if (h < 0 || h >= SQ_MAX) return;
    snprintf(sq_err[h], sizeof sq_err[h], "%s", msg ? msg : "");
}

/* Open (or create) the database file. A handle >= 0, or -1. */
long long sq_open(const char *path) {
    for (long long i = 0; i < SQ_MAX; i++) {
        if (sq_dbs[i]) continue;
        if (sqlite3_open(path, &sq_dbs[i]) != SQLITE_OK) {
            sq_set_err(i, sq_dbs[i] ? sqlite3_errmsg(sq_dbs[i]) : "open failed");
            if (sq_dbs[i]) { sqlite3_close(sq_dbs[i]); sq_dbs[i] = NULL; }
            return -1;
        }
        sq_err[i][0] = 0;
        return i;
    }
    return -1;
}

long long sq_close(long long h) {
    if (h < 0 || h >= SQ_MAX || !sq_dbs[h]) return -1;
    sqlite3_close(sq_dbs[h]);
    sq_dbs[h] = NULL;
    return 0;
}

const char *sq_error(long long h) {
    return orion_text_from_c((h >= 0 && h < SQ_MAX) ? sq_err[h] : "");
}

/* Prepare + bind the 0x1f-separated params (as text) + return the stmt. */
static sqlite3_stmt *sq_prep(long long h, const char *sql, const char *params) {
    if (h < 0 || h >= SQ_MAX || !sq_dbs[h]) return NULL;
    sqlite3_stmt *st = NULL;
    if (sqlite3_prepare_v2(sq_dbs[h], sql, -1, &st, NULL) != SQLITE_OK) {
        sq_set_err(h, sqlite3_errmsg(sq_dbs[h]));
        return NULL;
    }
    if (params && params[0]) {
        int idx = 1;
        const char *p = params;
        for (;;) {
            const char *sep = strchr(p, 0x1f);
            int len = sep ? (int)(sep - p) : (int)strlen(p);
            sqlite3_bind_text(st, idx++, p, len, SQLITE_TRANSIENT);
            if (!sep) break;
            p = sep + 1;
        }
    }
    return st;
}

/* Run SQL that yields no rows (DDL, INSERT, UPDATE...). 0 ok, -1 error. */
long long sq_exec(long long h, const char *sql, const char *params) {
    sqlite3_stmt *st = sq_prep(h, sql, params);
    if (!st) return -1;
    int rc = sqlite3_step(st);
    sqlite3_finalize(st);
    if (rc != SQLITE_DONE && rc != SQLITE_ROW) {
        sq_set_err(h, sqlite3_errmsg(sq_dbs[h]));
        return -1;
    }
    sq_err[h][0] = 0;
    return 0;
}

/* Run a query; ALL rows as one text (rows '\n', columns 0x1f, NULL -> "").
 * An empty result is "". On error returns "" with sq_error set - ask
 * sq_failed right after to tell them apart. */
static long long sq_last_failed = 0;
const char *sq_query(long long h, const char *sql, const char *params) {
    sq_last_failed = 1;
    sqlite3_stmt *st = sq_prep(h, sql, params);
    if (!st) return orion_text_from_c("");
    size_t cap = 4096, len = 0;
    char *buf = (char *)malloc(cap);
    if (!buf) { sqlite3_finalize(st); return orion_text_from_c(""); }
    buf[0] = 0;
    int rc;
    long long nrows = 0;
    while ((rc = sqlite3_step(st)) == SQLITE_ROW) {
        int cols = sqlite3_column_count(st);
        for (int c = 0; c < cols; c++) {
            const unsigned char *v = sqlite3_column_text(st, c);
            const char *s = v ? (const char *)v : "";
            size_t sl = strlen(s);
            while (len + sl + 2 >= cap) {
                cap *= 2;
                char *nb = (char *)realloc(buf, cap);
                if (!nb) { free(buf); sqlite3_finalize(st); return orion_text_from_c(""); }
                buf = nb;
            }
            if (c > 0) buf[len++] = 0x1f;
            memcpy(buf + len, s, sl);
            len += sl;
        }
        buf[len++] = '\n';
        nrows++;
    }
    buf[len > 0 ? len - 1 : 0] = 0;   /* drop the trailing newline */
    if (len == 0) buf[0] = 0;
    sqlite3_finalize(st);
    if (rc != SQLITE_DONE) {
        sq_set_err(h, sqlite3_errmsg(sq_dbs[h]));
        free(buf);
        return orion_text_from_c("");
    }
    sq_err[h][0] = 0;
    sq_last_failed = 0;
    const char *out = orion_text_from_c(buf);
    free(buf);
    return out;
}

long long sq_failed(void) { return sq_last_failed; }

/* Rows changed by the last INSERT/UPDATE/DELETE. */
long long sq_changes(long long h) {
    if (h < 0 || h >= SQ_MAX || !sq_dbs[h]) return 0;
    return (long long)sqlite3_changes(sq_dbs[h]);
}

/* rowid of the last INSERT - the id your new row got. */
long long sq_last_id(long long h) {
    if (h < 0 || h >= SQ_MAX || !sq_dbs[h]) return 0;
    return (long long)sqlite3_last_insert_rowid(sq_dbs[h]);
}
