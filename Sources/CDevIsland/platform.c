#include "CDevIsland.h"
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <libproc.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

static int address(const char *path, struct sockaddr_un *addr) {
    memset(addr, 0, sizeof(*addr));
    if (strlen(path) >= sizeof(addr->sun_path)) return -1;
    addr->sun_family = AF_UNIX;
    strlcpy(addr->sun_path, path, sizeof(addr->sun_path));
    addr->sun_len = sizeof(*addr);
    return 0;
}
int di_socket_listen(const char *path) {
    struct sockaddr_un addr;
    if (address(path, &addr)) return -1;
    int fd = socket(AF_UNIX, SOCK_DGRAM, 0);
    if (fd < 0) return -1;
    unlink(path);
    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr))) { close(fd); return -1; }
    chmod(path, 0600);
    fcntl(fd, F_SETFL, O_NONBLOCK);
    return fd;
}
int di_socket_send(const char *path, const void *bytes, size_t length) {
    struct sockaddr_un addr;
    if (address(path, &addr)) return -1;
    int fd = socket(AF_UNIX, SOCK_DGRAM, 0);
    if (fd < 0) return -1;
    fcntl(fd, F_SETFL, O_NONBLOCK);
    int result = (int)sendto(fd, bytes, length, 0, (struct sockaddr *)&addr, sizeof(addr));
    close(fd);
    return result;
}
long di_socket_receive(int descriptor, void *bytes, size_t capacity) {
    return recv(descriptor, bytes, capacity, 0);
}
int di_process(int pid, int *parent, uint64_t *start, char *path, int capacity, char *tty, int tty_capacity) {
    struct proc_bsdinfo info;
    if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, sizeof(info)) != sizeof(info)) return 0;
    *parent = (int)info.pbi_ppid;
    *start = info.pbi_start_tvsec * 1000000 + info.pbi_start_tvusec;
    path[0] = 0;
    proc_pidpath(pid, path, capacity);
    tty[0] = 0;
    if (info.e_tdev != (uint32_t)-1) {
        const char *name = devname(info.e_tdev, S_IFCHR);
        if (name) snprintf(tty, tty_capacity, "/dev/%s", name);
    }
    return 1;
}

#include <poll.h>
#include <time.h>
static int64_t di_milliseconds(void) {
    struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t);
    return (int64_t)t.tv_sec * 1000 + t.tv_nsec / 1000000;
}
static int di_wait(int fd, short events, int64_t deadline) {
    for (;;) {
        int64_t left = deadline - di_milliseconds();
        if (left <= 0) return -2;
        struct pollfd item = { .fd = fd, .events = events };
        int r = poll(&item, 1, (int)left);
        if (r < 0 && errno == EINTR) continue;
        if (r <= 0) return r == 0 ? -2 : -1;
        return (item.revents & events) ? 0 : -1;
    }
}
long di_socket_request(const char *path, const void *bytes, size_t length, void *reply, size_t capacity, int timeout_ms) {
    struct sockaddr_un addr;
    if (address(path, &addr) || length > 4096 || capacity > 16384 || timeout_ms < 1 || timeout_ms > 2000) return -1;
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return -1;
    int yes = 1; setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof(yes));
    fcntl(fd, F_SETFL, O_NONBLOCK);
    int64_t deadline = di_milliseconds() + timeout_ms;
    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        if (errno != EINPROGRESS || di_wait(fd, POLLOUT, deadline)) { close(fd); return -1; }
        int error = 0; socklen_t size = sizeof(error);
        if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &size) || error) { close(fd); return -1; }
    }
    size_t sent = 0, read = 0;
    while (sent < length) {
        int ready = di_wait(fd, POLLOUT, deadline);
        if (ready) { close(fd); return ready; }
        ssize_t n = send(fd, (const char *)bytes + sent, length - sent, 0);
        if (n < 0 && (errno == EAGAIN || errno == EINTR)) continue;
        if (n <= 0) { close(fd); return -1; }
        sent += (size_t)n;
    }
    while (read < capacity) {
        int ready = di_wait(fd, POLLIN, deadline);
        if (ready) { close(fd); return ready; }
        ssize_t n = recv(fd, (char *)reply + read, capacity - read, 0);
        if (n < 0 && (errno == EAGAIN || errno == EINTR)) continue;
        if (n <= 0) { close(fd); return -1; }
        void *end = memchr((char *)reply + read, '\n', (size_t)n);
        if (end) { long count = (char *)end - (char *)reply; close(fd); return count; }
        read += (size_t)n;
    }
    close(fd); return -1;
}
