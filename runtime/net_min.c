/* net_min.c - minimal blocking TCP for the `net` orb.
 *
 * Kept in its OWN translation unit (not orion_rt.c) so <winsock2.h> can be
 * included before anything pulls in <windows.h> - the two conflict if windows.h
 * wins the race, which orion_rt.c would cause. On Windows ws2_32 is linked by
 * the #pragma below, so no build-script flag is needed; WSAStartup is lazy, so a
 * program that never opens a socket never touches Winsock.
 *
 * Handles are returned as the platform socket cast to i64 (Orion's `int`): a
 * valid handle is >= 0, every failure is -1. Texts cross the boundary via the
 * runtime's headered layout ([hash][len][bytes][NUL]); recv fills one of those
 * and seals its length. These match the extern decls in orbs/net/lib.or.
 */
#include <stdio.h>
#include <string.h>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#pragma comment(lib, "ws2_32.lib")
typedef SOCKET net_sock;
#define NET_BAD INVALID_SOCKET
static int net_started = 0;
static void net_init(void) {
    if (!net_started) { WSADATA w; WSAStartup(MAKEWORD(2, 2), &w); net_started = 1; }
}
static int net_close_raw(net_sock s) { return closesocket(s); }
#else
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <unistd.h>
typedef int net_sock;
#define NET_BAD (-1)
static void net_init(void) {}
static int net_close_raw(net_sock s) { return close(s); }
#endif

/* Runtime helpers defined in orion_rt.c - a headered text buffer of `len`
 * bytes (returns the byte pointer), and the length stored just before it. */
char *orion_text_alloc(long long len);
long long orion_tlen_c(const char *p);

/* net_connect(host, port) -> i64 socket handle, or -1. Resolves host via
 * getaddrinfo (accepts a hostname or a dotted-quad), TCP, blocking. */
long long net_connect(const char *host, long long port) {
    net_init();
    struct addrinfo hints, *res = NULL, *it;
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    char portstr[16];
    snprintf(portstr, sizeof portstr, "%lld", port);
    if (getaddrinfo(host, portstr, &hints, &res) != 0 || !res) return -1;
    net_sock s = NET_BAD;
    for (it = res; it; it = it->ai_next) {
        s = socket(it->ai_family, it->ai_socktype, it->ai_protocol);
        if (s == NET_BAD) continue;
        if (connect(s, it->ai_addr, (int)it->ai_addrlen) == 0) break;
        net_close_raw(s);
        s = NET_BAD;
    }
    freeaddrinfo(res);
    return (s == NET_BAD) ? -1 : (long long)s;
}

/* net_send(sock, data) -> bytes sent, or -1. Sends the text's raw bytes. */
long long net_send(long long sock, const char *data) {
    long long n = orion_tlen_c(data);
    long long total = 0;
    while (total < n) {
        long long r = send((net_sock)sock, data + total, (int)(n - total), 0);
        if (r <= 0) return -1;
        total += r;
    }
    return total;
}

/* net_recv(sock, maxlen) -> Text of up to maxlen bytes; "" on close/error.
 * One blocking recv (not drained to maxlen) - a caller loops if it wants more. */
const char *net_recv(long long sock, long long maxlen) {
    if (maxlen <= 0) maxlen = 4096;
    char *buf = orion_text_alloc(maxlen);
    long long r = recv((net_sock)sock, buf, (int)maxlen, 0);
    if (r < 0) r = 0;
    buf[r] = 0;
    ((long long *)buf)[-1] = r; /* seal the real length into the header */
    return buf;
}

long long net_close(long long sock) { return net_close_raw((net_sock)sock); }

/* net_listen(port) -> server socket bound to 0.0.0.0:port, or -1. */
long long net_listen(long long port) {
    net_init();
    net_sock s = socket(AF_INET, SOCK_STREAM, 0);
    if (s == NET_BAD) return -1;
    int yes = 1;
    setsockopt(s, SOL_SOCKET, SO_REUSEADDR, (const char *)&yes, sizeof yes);
    struct sockaddr_in a;
    memset(&a, 0, sizeof a);
    a.sin_family = AF_INET;
    a.sin_addr.s_addr = htonl(INADDR_ANY);
    a.sin_port = htons((unsigned short)port);
    if (bind(s, (struct sockaddr *)&a, sizeof a) != 0) { net_close_raw(s); return -1; }
    if (listen(s, 16) != 0) { net_close_raw(s); return -1; }
    return (long long)s;
}

/* net_accept(server) -> a connected client socket, or -1. Blocks. */
long long net_accept(long long server) {
    net_sock c = accept((net_sock)server, NULL, NULL);
    return (c == NET_BAD) ? -1 : (long long)c;
}

/* net_local_port(server) -> the actual port a listen socket bound to (useful
 * after net_listen(0) picks an ephemeral port), or -1. */
long long net_local_port(long long server) {
    struct sockaddr_in a;
    socklen_t len = sizeof a;
    if (getsockname((net_sock)server, (struct sockaddr *)&a, &len) != 0) return -1;
    return (long long)ntohs(a.sin_port);
}
