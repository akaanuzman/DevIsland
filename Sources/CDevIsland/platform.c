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
