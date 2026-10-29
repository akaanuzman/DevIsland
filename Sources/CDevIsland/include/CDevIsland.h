#ifndef CDEVISLAND_H
#define CDEVISLAND_H
#include <stdint.h>
#include <stddef.h>
int di_socket_listen(const char *path);
int di_socket_send(const char *path, const void *bytes, size_t length);
long di_socket_receive(int descriptor, void *bytes, size_t capacity);
int di_process(int pid, int *parent, uint64_t *start, char *path, int capacity, char *tty, int tty_capacity);
#endif
